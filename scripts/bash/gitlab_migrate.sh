#!/bin/bash

#In case Gitlab instance get restarted, skip script.
GILAB_VERSION_FILE=/opt/gitlab/version-manifest.txt
if [ -f "$GILAB_VERSION_FILE" ]; then
    echo "$GILAB_VERSION_FILE exists."
    echo "Skipping Gitlab installation."
    exit 0
else 
    echo "$GILAB_VERSION_FILE does not exist."
    echo "Executing Gitlab installtion."
fi


# Install Dependencies
sudo apt-get update
# sudo apt-get install -y curl openssh-server ca-certificates tzdata perl jq
sudo apt-get install -y curl ca-certificates tzdata perl jq zip p7zip-full



# Installtion Variables
## Network variables
INSTANCE_PROTOCOL=`curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/attributes/instance-protocol` #http/https
echo "INFO: Protocol is $INSTANCE_PROTOCOL"
INSTANCE_EXTERNAL_DOMAIN=`curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/attributes/instance-external-domain`
echo "INFO: domain name is $INSTANCE_EXTERNAL_DOMAIN"
EXTERNAL_IP=`curl -H "Metadata-Flavor: Google" http://metadata/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip`
echo "INFO: external IP is $EXTERNAL_IP"

# Secrets variables
GITLAB_INITIAL_ROOT_PASSWORD_SECRET=`curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/attributes/gitlab-initial-root-pwd-secret`
GITLAB_INITIAL_ROOT_PASSWORD=`gcloud secrets versions access latest --secret=$GITLAB_INITIAL_ROOT_PASSWORD_SECRET`
GITLAB_API_TOKEN_SECRET=`curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/attributes/gitlab-api-token-secret`
GITLAB_API_TOKEN=`gcloud secrets versions access latest --secret=$GITLAB_API_TOKEN_SECRET`
GITLAB_RUNNER_REG_SECRET=`curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/attributes/gitlab-ci-runner-registration-token-secret`
GITLAB_RUNNER_REG=`gcloud secrets versions access latest --secret=$GITLAB_RUNNER_REG_SECRET`

# Migration variables
GCS_PATH_TO_BACKUP=`curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/attributes/gcs-path-to-backup`
echo "INFO: Path to backup: $GCS_PATH_TO_BACKUP"
GITLAB_BACKUP_VERSION=`curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/attributes/migrated-gitlab-version`
echo "INFO: Backup version and the version that will be installed is: $GITLAB_BACKUP_VERSION"
GITLAB_BAKCUP_PASSOWRD=`curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/attributes/migrated-gitlab-backup-password`




# External URL
EXTERNAL_URL="$INSTANCE_PROTOCOL://$INSTANCE_EXTERNAL_DOMAIN"
echo "INFO: external URL will be $EXTERNAL_URL"

############### Gitlab Installation ##############

# Install Postfix non-interactive
echo "INFO: Starting postfix installation"
sudo debconf-set-selections <<< "postfix postfix/mailname string $INSTANCE_EXTERNAL_DOMAIN"
sudo debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
sudo apt-get install --assume-yes postfix


# Install Gitlab Server
echo "INFO: Downloading and Installing Gitlab from bash script"
curl https://packages.gitlab.com/install/repositories/gitlab/gitlab-ee/script.deb.sh | sudo bash
#sudo EXTERNAL_URL=$EXTERNAL_URL apt-get install gitlab-ee
#Specific version installation:
echo "Downloading: gitlab-ee_$GITLAB_BACKUP_VERSION.0_amd64.deb/download.deb"
wget --content-disposition https://packages.gitlab.com/gitlab/gitlab-ee/packages/ubuntu/bionic/gitlab-ee_$GITLAB_BACKUP_VERSION.0_amd64.deb/download.deb
sudo EXTERNAL_URL=$EXTERNAL_URL dpkg -i gitlab-ee_$GITLAB_BACKUP_VERSION.0_amd64.deb


###############################################



###### Migration #######
echo "INFO: Starting migration..."

# Download and extract backup
echo "INFO: Downloading and extracting backup"
gsutil cp $GCS_PATH_TO_BACKUP ./backup_archived.zip
mkdir -p backup_extracted
7z x -p$GITLAB_BAKCUP_PASSOWRD backup_archived.zip -o./backup_extracted

# Migrate configuration files and SSL certificates
echo "INFO: Copying configuration files and certificates"
cp backup_extracted/gitlab* /etc/gitlab
cp -R backup_extracted/ssl /etc/gitlab

# Use the new provided external url instead of the migrated one
echo "external_url \"$EXTERNAL_URL\"" >> /etc/gitlab/gitlab.rb

# Reconfigure installtion
echo "INFO: Reconfiguring Gitlab..."
gitlab-ctl reconfigure

# Stop Gitlab services
gitlab-ctl stop unicorn
gitlab-ctl stop puma
gitlab-ctl stop sidekiq
gitlab-ctl status

# Restore from backup
BACKUP_FILENAME=$(ls backup_extracted | grep _gitlab_backup.tar)
cp backup_extracted/$BACKUP_FILENAME /var/opt/gitlab/backups/
chown git:git /var/opt/gitlab/backups/$BACKUP_FILENAME

echo "INFO: Restoring from backup snapshot... $BACKUP_FILENAME"
yes yes | gitlab-rake gitlab:backup:restore BACKUP=$(echo $BACKUP_FILENAME | cut -d "_" -f 1-5)
echo "INFO: Reconfiguring Gitlab"
gitlab-ctl reconfigure
echo "INFO: Resarting Gitlab services"
gitlab-ctl restart
echo "INFO: Checking services health"
gitlab-rake gitlab:check SANITIZE=true
echo "INFO: Checking secrets decryptability"
gitlab-rake gitlab:doctor:secrets


####### Post Gitlab Installtion #######

if [[ $INSTANCE_PROTOCOL == "https" ]]
then
    echo "INFO: Setting self-signed certificate on server."
    sudo mkdir -p /etc/gitlab/ssl
    sudo chmod 755 /etc/gitlab/ssl
    GITLAB_CERT_KEY_SECRET=`curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/attributes/gitlab-cert-key-secret`
    sudo gcloud secrets versions access latest --secret=$GITLAB_CERT_KEY_SECRET > /etc/gitlab/ssl/$INSTANCE_EXTERNAL_DOMAIN.key
    GITLAB_CERT_PUB_SECRET=`curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/attributes/gitlab-cert-public-secret`
    sudo gcloud secrets versions access latest --secret=$GITLAB_CERT_PUB_SECRET > /etc/gitlab/ssl/$INSTANCE_EXTERNAL_DOMAIN.crt
    #sudo echo "letsencrypt['enable'] = false" >> /etc/gitlab/gitlab.rb
    sudo gitlab-ctl reconfigure
    sudo gitlab-ctl restart
fi




# Short delay
sleep 20


## Seed new secrets to migrated instance ##
# Seed gitlab root password
echo "INFO: Seeding root password"
sudo gitlab-rails runner "user = User.find_by_username('root'); user.password = '$GITLAB_INITIAL_ROOT_PASSWORD'; user.password_confirmation = '$GITLAB_INITIAL_ROOT_PASSWORD'; user.save!"

# Seed the newly created Write api token of root
echo "INFO: Seeding root write api key"
sudo gitlab-rails runner "token = User.find_by_username('root').personal_access_tokens.create(scopes: [:api], name: 'Gitlab post deployment script'); token.set_token('$GITLAB_API_TOKEN'); token.save!"

# Seed shared runners registartion token
sudo gitlab-rails runner "appset = Gitlab::CurrentSettings.current_application_settings; appset.set_runners_registration_token('$GITLAB_RUNNER_REG'); appset.save!"


# Set instance level environment variables, so pipelines can utilize them
echo "INFO: Setting instance level CI/CD variables"
GCP_PROJECT_ID=`gcloud config list --format 'value(core.project)' 2>/dev/null`
curl -X POST -k -H "PRIVATE-TOKEN: $GITLAB_API_TOKEN" "https://localhost/api/v4/admin/ci/variables" --form "key=GCP_PROJECT_ID" --form "value=$GCP_PROJECT_ID"




# Remove startup script and encrypted backup pwd (prevent from running on reboot)
name=`curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/name`
zone=`curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/zone | cut -d'/' -f 4`
echo "INFO: Removing startup-script-url from metadata..."
gcloud compute instances remove-metadata "$name" --zone="$zone" --keys=startup-script-url
echo "INFO: Removing migrated-gitlab-backup-password from metadata..."
gcloud compute instances remove-metadata "$name" --zone="$zone" --keys=migrated-gitlab-backup-password
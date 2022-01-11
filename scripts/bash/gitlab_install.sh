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

sudo apt-get install -y curl ca-certificates tzdata perl jq coreutils zip p7zip-full





# Installtion Variables
## Network variables
INSTANCE_PROTOCOL=`curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/attributes/instance-protocol` #http/https
echo "INFO: Protocol is $INSTANCE_PROTOCOL"
INSTANCE_EXTERNAL_DOMAIN=`curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/attributes/instance-external-domain`
echo "INFO: domain name is $INSTANCE_EXTERNAL_DOMAIN"
EXTERNAL_IP=`curl -H "Metadata-Flavor: Google" http://metadata/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip`
echo "INFO: external IP is $EXTERNAL_IP"
GITLAB_INSTALL_VERSION="14.5.2-ee"

## Secrets variables
GITLAB_INITIAL_ROOT_PASSWORD_SECRET=`curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/attributes/gitlab-initial-root-pwd-secret`
GITLAB_INITIAL_ROOT_PASSWORD=`gcloud secrets versions access latest --secret=$GITLAB_INITIAL_ROOT_PASSWORD_SECRET`
GITLAB_RUNNER_REG_SECRET=`curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/attributes/gitlab-ci-runner-registration-token-secret`
GITLAB_RUNNER_REG=`gcloud secrets versions access latest --secret=$GITLAB_RUNNER_REG_SECRET`


## Post installation required variables
GCP_PROJECT_ID=`gcloud config list --format 'value(core.project)' 2>/dev/null`
INSTANCE_INTERNAL_HOSTNAME=`curl -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/hostname"`
INSTANCE_INTERNAL_URL=$INSTANCE_PROTOCOL://$INSTANCE_INTERNAL_HOSTNAME
INSTANCE_INTERNAL_API_V4_URL=$INSTANCE_PROTOCOL://$INSTANCE_INTERNAL_HOSTNAME/api/v4


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
#Specific version installation:
echo "Downloading: gitlab-ee_$GITLAB_INSTALL_VERSION.0_amd64.deb/download.deb"
wget --content-disposition https://packages.gitlab.com/gitlab/gitlab-ee/packages/ubuntu/bionic/gitlab-ee_$GITLAB_INSTALL_VERSION.0_amd64.deb/download.deb
sudo GITLAB_ROOT_PASSWORD=$GITLAB_INITIAL_ROOT_PASSWORD EXTERNAL_URL=$EXTERNAL_URL dpkg -i gitlab-ee_$GITLAB_INSTALL_VERSION.0_amd64.deb


if [[ $INSTANCE_PROTOCOL == "https" ]]
then
    echo "INFO: Setting self-signed certificate on server."
    sudo mkdir -p /etc/gitlab/ssl
    sudo chmod 755 /etc/gitlab/ssl
    GITLAB_CERT_KEY_SECRET=`curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/attributes/gitlab-cert-key-secret`
    sudo gcloud secrets versions access latest --secret=$GITLAB_CERT_KEY_SECRET > /etc/gitlab/ssl/$INSTANCE_EXTERNAL_DOMAIN.key
    GITLAB_CERT_PUB_SECRET=`curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/attributes/gitlab-cert-public-secret`
    sudo gcloud secrets versions access latest --secret=$GITLAB_CERT_PUB_SECRET > /etc/gitlab/ssl/$INSTANCE_EXTERNAL_DOMAIN.crt
    sudo echo "letsencrypt['enable'] = false" >> /etc/gitlab/gitlab.rb
    sudo gitlab-ctl reconfigure
    sudo gitlab-ctl restart
fi


# Short delay
sleep 20


###############################################

####### Post Gitlab Installtion #######
# Set instance level environment variables, so pipelines can utilize them
echo "INFO: Setting instance level CI/CD variables"
# New instance level variables
sudo gitlab-rails runner "Ci::InstanceVariable.new(key: 'CI_SERVER_HOST', value: '$INSTANCE_INTERNAL_HOSTNAME').save"
sudo gitlab-rails runner "Ci::InstanceVariable.new(key: 'CI_SERVER_URL', value: '$INSTANCE_INTERNAL_URL').save"
sudo gitlab-rails runner "Ci::InstanceVariable.new(key: 'CI_API_V4_URL', value: '$INSTANCE_INTERNAL_API_V4_URL').save"
sudo gitlab-rails runner "Ci::InstanceVariable.new(key: 'GCP_PROJECT_ID', value: '$GCP_PROJECT_ID').save"

# Seed shared runners registartion token
echo "INFO: Runners registration token..."
sudo gitlab-rails runner "appset = Gitlab::CurrentSettings.current_application_settings; appset.set_runners_registration_token('$GITLAB_RUNNER_REG'); appset.save!"

# Create repo groups (ci, community)
echo "INFO: Creating repositories groups"
sudo gitlab-rails runner "Group.new(name: 'CI CD Tools', path: 'ci', visibility_level: 10).save"
sudo gitlab-rails runner "Group.new(name: 'Community Tools', path: 'community', visibility_level: 10).save"


# Import SCALLOPS-RECIPES project repo
echo "INFO: Importing SCALLOPS-RECIPES repository into CI group"
sudo gitlab-rails runner "cigrp = Group.find_by_path_or_name('ci'); rootuser = User.find_by_id(1); Project.new(import_url: 'https://github.com/SygniaLabs/ScallOps-Recipes.git', name: 'Scallops Recipes', path: 'scallops-recipes', visibility_level: 10, creator: rootuser, namespace: cigrp).save"
sudo gitlab-rails runner "newprj = Project.find_by_full_path('ci/scallops-recipes'); Gitlab::GithubImport::Importer::RepositoryImporter.new(newprj, :octokit).execute" # Ignore the following error (undefined method `repository' for :octokit:Symbol)

# Seed scallops-recipes sepcific runners registration token
echo "INFO: Seeding SCALLOPS-RECIPES runners registration token"
SCALLOPS_RUNNER_REG=$GITLAB_RUNNER_REG-scallops-recipes
sudo gitlab-rails runner "scallopsprj = Project.find_by_full_path('ci/scallops-recipes'); scallopsprj.set_runners_token('$SCALLOPS_RUNNER_REG'); scallopsprj.save!"

# Remove startup script reference (prevent from running on rebbot)
name=`curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/name`
zone=`curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/zone | cut -d'/' -f 4`
gcloud compute instances remove-metadata "$name" --zone="$zone" --keys=startup-script-url


# Download backup cron executor and cron job #Backup will occur every Saturday on 10:00 UTC
DEPLOYMENT_GCS_PREFIX=`curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/attributes/gcs-prefix`
sudo gsutil cp $DEPLOYMENT_GCS_PREFIX/scripts/bash/gitlab_backup_exec.sh /gitlab_backup_exec.sh
sudo chmod +x /gitlab_backup_exec.sh
echo "0 10 * * 6 /gitlab_backup_exec.sh" > gitlab-backup-cron
sudo crontab gitlab-backup-cron
rm gitlab-backup-cron
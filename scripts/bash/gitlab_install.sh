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



#Dependencies
sudo apt-get update
sudo apt-get install -y curl openssh-server ca-certificates tzdata perl jq



#Vars
#Network
INSTANCE_PROTOCOL=`curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/attributes/instance-protocol` #http/https
echo "INFO: Protocol is $INSTANCE_PROTOCOL"
INSTANCE_EXTERNAL_DOMAIN=`curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/attributes/instance-ext-domain`
echo "INFO: domain name is $INSTANCE_EXTERNAL_DOMAIN"
EXTERNAL_IP=`curl -H "Metadata-Flavor: Google" http://metadata/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip`
echo "INFO: external IP is $EXTERNAL_IP"

#Secrets
GITLAB_INITIAL_ROOT_PASSWORD_SECRET=`curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/attributes/gitlab-initial-root-pwd-secret`
GITLAB_INITIAL_ROOT_PASSWORD=`gcloud secrets versions access latest --secret=$GITLAB_INITIAL_ROOT_PASSWORD_SECRET`
GITLAB_API_TOKEN_SECRET=`curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/attributes/gitlab-api-token-secret`
GITLAB_API_TOKEN=`gcloud secrets versions access latest --secret=$GITLAB_API_TOKEN_SECRET`
GITLAB_RUNNER_REG_SECRET=`curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/attributes/gitlab-ci-runner-registration-token-secret`
GITLAB_RUNNER_REG=`gcloud secrets versions access latest --secret=$GITLAB_RUNNER_REG_SECRET`

#Post Installtion required variables
GCP_PROJECT_ID=`gcloud config list --format 'value(core.project)' 2>/dev/null`
CI_CD_UTILS_BUKCET=`curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/attributes/cicd-utils-bucket-name`



#TBD: Support providing external domain for the Gitlab as a parameter.
: <<'END_COMMENT'
# IF not provided INSTANCE_EXTERNAL_DOMAIN, External url will be INSTANCE_PROTOCOL + :// + EXTERNAL_IP
# If INSTANCE_EXTERNAL_DOMAIN provided, External url will be INSTANCE_PROTOCOL + :// + INSTANCE_EXTERNAL_DOMAIN 
if [[ $INSTANCE_EXTERNAL_DOMAIN =~ ^[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,5}(:[0-9]{1,5})?(\/.*)?$ ]] 
then
    echo "INFO: External domain provided, setting URL"
    EXTERNAL_URL="$INSTANCE_PROTOCOL://$INSTANCE_EXTERNAL_DOMAIN"
    if [[ $INSTANCE_PROTOCOL == "https" ]]
    then
        echo "INFO: Instance protocol set to HTTPS, proceeding to name resoulution checks."
        ######### TLS Certificate sign pre-checks ################
        # The below tests if the domain resolution matches GCE external IP
        # So Lets encrypt will be able to Sign the cert.
        # TODO: Support multiple IP resolution
        # TODO: end loop after 30 iterations
        resolved_ip=$(dig +short $INSTANCE_EXTERNAL_DOMAIN | cut -d$'\n' -f 1)
        while [ $EXTERNAL_IP != $resolved_ip ]; do
        echo "External IP not match resolved IP, waiting 1 minute for update..."
        sleep 1m
        resolved_ip=$(dig +short $INSTANCE_EXTERNAL_DOMAIN | cut -d$'\n' -f 1)
        done
        echo "INFO: External IP matched resolved IP"
    fi
else
    echo "INFO: External domain not provided, setting URL as current external IP address"
    EXTERNAL_URL="$INSTANCE_PROTOCOL://$EXTERNAL_IP"
    #If INSTANCE_PROTOCOL is https and no INSTANCE_EXTERNAL_DOMAIN provided, we will need to provide self-signed certificate for installtion.
fi
END_COMMENT



EXTERNAL_URL="$INSTANCE_PROTOCOL://$INSTANCE_EXTERNAL_DOMAIN"
echo "INFO: external URL will be $EXTERNAL_URL"





#Install Postfix non-interactive
echo "INFO: Starting postfix installation"
sudo debconf-set-selections <<< "postfix postfix/mailname string $INSTANCE_EXTERNAL_DOMAIN"
sudo debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
sudo apt-get install --assume-yes postfix


#Install Gitlab Server
echo "INFO: Downloading and Installing Gitlab from bash script"
curl https://packages.gitlab.com/install/repositories/gitlab/gitlab-ee/script.deb.sh | sudo bash
sudo GITLAB_ROOT_PASSWORD=$GITLAB_INITIAL_ROOT_PASSWORD GITLAB_SHARED_RUNNERS_REGISTRATION_TOKEN=$GITLAB_RUNNER_REG EXTERNAL_URL=$EXTERNAL_URL apt-get install gitlab-ee
#Specific version installation:
#wget --content-disposition https://packages.gitlab.com/gitlab/gitlab-ee/packages/ubuntu/bionic/gitlab-ee_13.10.0-ee.0_amd64.deb/download.deb
#sudo GITLAB_ROOT_PASSWORD=$GITLAB_INITIAL_ROOT_PASSWORD GITLAB_SHARED_RUNNERS_REGISTRATION_TOKEN=$GITLAB_RUNNER_REG EXTERNAL_URL=$EXTERNAL_URL dpkg -i gitlab-ee_13.10.0-ee.0_amd64.deb


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
fi

###############################################

####### Post Gitlab Installtion #######

#Create personal token for the root account
echo "INFO: Seeding personal token for root account"
sudo gitlab-rails runner "token = User.find_by_username('root').personal_access_tokens.create(scopes: [:api], name: 'Gitlab post deployment script'); token.set_token('$GITLAB_API_TOKEN'); token.save!"


#TBD Create all actions below via gitlab-rails
#Short delay #TBD CHECK API SERVICE STATUS
sleep 120

#Set instance level environment variables, so pipelines can utilize them
echo "INFO: Setting instance level CI/CD variables"
curl --request POST --insecure --header "PRIVATE-TOKEN: $GITLAB_API_TOKEN" "https://localhost/api/v4/admin/ci/variables" --form "key=GCP_PROJECT_ID" --form "value=$GCP_PROJECT_ID"
curl --request POST --insecure --header "PRIVATE-TOKEN: $GITLAB_API_TOKEN" "https://localhost/api/v4/admin/ci/variables" --form "key=GITLAB_API_ACCESS" --form "value=$GITLAB_API_TOKEN"
curl --request POST --insecure --header "PRIVATE-TOKEN: $GITLAB_API_TOKEN" "https://localhost/api/v4/admin/ci/variables" --form "key=CI_CD_UTILS_BUKCET" --form "value=$CI_CD_UTILS_BUKCET"



#Import SCALLOPS-RECIPES project repo
echo "INFO: Importing SCALLOPS-RECIPES repository"
IMPORT_RESPONSE=`curl --location --insecure --request POST 'https://localhost/api/v4/projects' \
--header 'Content-Type: application/json' \
--header "PRIVATE-TOKEN: $GITLAB_API_TOKEN" \
--data-raw '{
    "import_url": "https://github.com/SygniaLabs/ScallOps-Recipes.git",
    "import_url_user": "",
    "import_url_password": "",
    "ci_cd_only": false,
    "name": "ScallOps-Recipes",
    "namespace_id": 1,
    "path": "scallops-recipes",
    "description": "",
    "visibility": "internal"
}'`
#echo "DEBUG: Import response: $IMPORT_RESPONSE"
IMPORTED_PROJECT_ID=`echo $IMPORT_RESPONSE | jq .id`
#echo "DEBUG: Imported project ID: $IMPORTED_PROJECT_ID"



#Short import delay 
sleep 20



#Trigger Deployment Initialization pipeline

echo "INFO: Checking import status..."
IMPORT_STATUS_RESPONSE=`curl --location --insecure --request GET "https://localhost/api/v4/projects/$IMPORTED_PROJECT_ID/import" --header "Content-Type: application/json" --header "PRIVATE-TOKEN: $GITLAB_API_TOKEN"`
#echo "DEBUG: Import status response $IMPORT_STATUS_RESPONSE"
IMPORT_STATUS=`echo $IMPORT_STATUS_RESPONSE | jq -r .import_status`


if [[ $IMPORT_STATUS == "finished" ]]
then
    echo "INFO: Import finished, triggering deployment initialization..."
    echo "INFO: Creating pipeline trigger token..."
    TRIGGER_TOKEN_RESPONSE=`curl --location --insecure --request POST --header "PRIVATE-TOKEN: $GITLAB_API_TOKEN" "https://localhost/api/v4/projects/$IMPORTED_PROJECT_ID/triggers?description=deploy-init"`
    TRIGGER_TOKEN=`echo $TRIGGER_TOKEN_RESPONSE | jq -r .token`
    #Short delay 
    sleep 5
    echo "INFO: Triggering SCALLOPS-RECIPES deployment initialization pipeline"
    curl --location --insecure -g --request POST "https://localhost/api/v4/projects/$IMPORTED_PROJECT_ID/trigger/pipeline?variables[DEPLOYMENT_INIT]=true&ref=master&token=$TRIGGER_TOKEN"
    # Delete trigger token
    #Short delay 
    sleep 5
    echo "INFO: Removing project's trigger token"
    curl --request DELETE --insecure --header "PRIVATE-TOKEN: $GITLAB_API_TOKEN" "https://localhost/api/v4/projects/$IMPORTED_PROJECT_ID/triggers/1"
else
    echo "INFO: SCALLOPS-RECIPES Import failed or still in-progress, you can trigger the pipline manually."
fi




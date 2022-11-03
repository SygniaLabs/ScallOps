#!/bin/bash

readonly RAILS_CMD_PATH=$(pwd)/railscmd.rb

check_installation () {
    local logName=$1
    #In case Gitlab instance get restarted, skip script.
    logger $logName "INFO" "Checking whether Gitlab is installed"
    GILAB_VERSION_FILE=/opt/gitlab/version-manifest.txt
    GITLAB_INSTALLED="false"
    if [ -f "$GILAB_VERSION_FILE" ]; then
        logger $logName "DEBUG" "$GILAB_VERSION_FILE exists"
        GITLAB_INSTALLED="true"
        GITLAB_EE_VERSION=$(grep gitlab-ee $GILAB_VERSION_FILE | cut -d " " -f2)-ee
        logger $logName "INFO" "Installed Gitlab version is $GITLAB_EE_VERSION"
    else         
        logger $logName "DEBUG" "$GILAB_VERSION_FILE does not exist"
    fi
}


gitlab_deps_install () {
    local logName=$1
    # Install Dependencies
    logger $logName "INFO" "Running package updater"   
    exec_wrapper $ERR_ACTION_EXIT $logName "apt-get update"

    logger $logName "INFO" "Installing dependencies"
    exec_wrapper $ERR_ACTION_EXIT $logName "apt-get install -y curl ca-certificates tzdata perl jq coreutils zip p7zip-full"
}


set_gitlab_vars () {
    local logName=$1
    logger $logName "INFO" "Fetching Gitlab network variables"
    ## Network variables
    INSTANCE_PROTOCOL=`curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/attributes/instance-protocol` #http/https
    INSTANCE_EXTERNAL_DOMAIN=`curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/attributes/instance-external-domain`
    EXTERNAL_IP=`curl -H "Metadata-Flavor: Google" http://metadata/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip`
    
    #Ext URL
    EXTERNAL_URL="$INSTANCE_PROTOCOL://$INSTANCE_EXTERNAL_DOMAIN"
    logger $logName "DEBUG" "Gitlab External URL will be $EXTERNAL_URL"   
}


reconfigure_gitlab () {
    # Sets Gitlab's certificate and External URL from configured metadata and secrets
    local logName=$1
    if [[ $INSTANCE_PROTOCOL == "https" ]]
    then
        logger $logName "INFO" "Gitlab set to HTTPS, setting self-signed certificate on server"
        mkdir -p /etc/gitlab/ssl
        chmod 755 /etc/gitlab/ssl
        GITLAB_CERT_KEY_SECRET=`curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/attributes/gitlab-cert-key-secret`
        gcloud secrets versions access latest --secret=$GITLAB_CERT_KEY_SECRET > /etc/gitlab/ssl/$INSTANCE_EXTERNAL_DOMAIN.key
        GITLAB_CERT_PUB_SECRET=`curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/attributes/gitlab-cert-public-secret`
        gcloud secrets versions access latest --secret=$GITLAB_CERT_PUB_SECRET > /etc/gitlab/ssl/$INSTANCE_EXTERNAL_DOMAIN.crt
        echo "letsencrypt['enable'] = false" >> /etc/gitlab/gitlab.rb
    fi
    
    # Use the provided external url

    logger $logName "INFO" "Setting Gitlab external url to $EXTERNAL_URL"
    echo "external_url \"$EXTERNAL_URL\"" >> /etc/gitlab/gitlab.rb

    # Reconfigure installation
    logger $logName "INFO" "Reconfiguring Gitlab"
    
    exec_wrapper $ERR_ACTION_CONT $logName "gitlab-ctl reconfigure"
    
    exec_wrapper $ERR_ACTION_CONT $logName "gitlab-ctl restart"

    logger $logName "INFO" "Updating EXTERNAL URL to CI_EXTERNAL_URL CI/CD variable"
    echo "Ci::InstanceVariable.where(key: 'CI_EXTERNAL_URL').update(value: '$EXTERNAL_URL')" > $RAILS_CMD_PATH
    exec_wrapper $ERR_ACTION_CONT $logName "gitlab-rails runner  $RAILS_CMD_PATH"
}


gitlab_install () {
    local logName=$1
    local gitlabVersion=$2
    # Install Postfix non-interactive
    logger $logName "INFO" "Starting postfix installation for domain: $INSTANCE_EXTERNAL_DOMAIN"
    debconf-set-selections <<< "postfix postfix/mailname string $INSTANCE_EXTERNAL_DOMAIN"
    debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
    exec_wrapper $ERR_ACTION_CONT $logName "apt-get install --assume-yes postfix"

    # Install Gitlab Server
    logger $logName "INFO" "Setting up Gitlab installation at version $gitlabVersion"
    curl https://packages.gitlab.com/install/repositories/gitlab/gitlab-ee/script.deb.sh | bash
    #Specific version installation:
    logger $logName "INFO" "Downloading Gitlab from https://packages.gitlab.com/gitlab/gitlab-ee/packages/ubuntu/bionic/gitlab-ee_$gitlabVersion.0_amd64.deb/download.deb"
    exec_wrapper $ERR_ACTION_EXIT $logName "wget --content-disposition https://packages.gitlab.com/gitlab/gitlab-ee/packages/ubuntu/bionic/gitlab-ee_$gitlabVersion.0_amd64.deb/download.deb"
    logger $logName "INFO" "Installing Gitlab"
    exec_wrapper $ERR_ACTION_EXIT $logName "dpkg -i gitlab-ee_$gitlabVersion.0_amd64.deb"
    
    logger $logName "INFO" "Reconfiguring Gitlab"
    exec_wrapper $ERR_ACTION_CONT $logName "gitlab-ctl reconfigure"
}


setup_cicd_vars () {
    local logName=$1
    # Set instance level environment variables, so pipelines can utilize them
    logger $logName "INFO" "Fetching values for instance level CI/CD variables"
    GCP_PROJECT_ID=`gcloud config list --format 'value(core.project)' 2>/dev/null`
    INSTANCE_INTERNAL_HOSTNAME=`curl -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/hostname"`
    INSTANCE_INTERNAL_URL=$INSTANCE_PROTOCOL://$INSTANCE_INTERNAL_HOSTNAME
    INSTANCE_INTERNAL_API_V4_URL=$INSTANCE_PROTOCOL://$INSTANCE_INTERNAL_HOSTNAME/api/v4

    local instancelvlVars="
    CI_EXTERNAL_URL=$EXTERNAL_URL 
    CI_SERVER_HOST=$INSTANCE_INTERNAL_HOSTNAME 
    CI_SERVER_URL=$INSTANCE_INTERNAL_URL 
    CI_API_V4_URL=$INSTANCE_INTERNAL_API_V4_URL 
    CONTAINER_REGISTRY_NAMESPACE=$GCP_PROJECT_ID 
    CONTAINER_REGISTRY_HOST=gcr.io
    " 
    logger $logName "DEBUG" $instancelvlVars

}

create_cicd_vars () {
    local logName=$1
    # New instance level variables
    logger $logName "INFO" "Creating instance level CI/CD variables"

    echo "Ci::InstanceVariable.new(key: 'CI_EXTERNAL_URL', value: '$EXTERNAL_URL').save" > $RAILS_CMD_PATH
    echo "Ci::InstanceVariable.new(key: 'CI_SERVER_HOST', value: '$INSTANCE_INTERNAL_HOSTNAME').save" >> $RAILS_CMD_PATH
    echo "Ci::InstanceVariable.new(key: 'CI_SERVER_URL', value: '$INSTANCE_INTERNAL_URL').save" >> $RAILS_CMD_PATH
    echo "Ci::InstanceVariable.new(key: 'CI_API_V4_URL', value: '$INSTANCE_INTERNAL_API_V4_URL').save" >> $RAILS_CMD_PATH
    echo "Ci::InstanceVariable.new(key: 'CONTAINER_REGISTRY_NAMESPACE', value: '$GCP_PROJECT_ID').save" >> $RAILS_CMD_PATH
    echo "Ci::InstanceVariable.new(key: 'CONTAINER_REGISTRY_HOST', value: 'gcr.io').save" >> $RAILS_CMD_PATH

    exec_wrapper $ERR_ACTION_CONT $logName "gitlab-rails runner $RAILS_CMD_PATH"

}

update_cicd_vars () {
    local logName=$1
    # Update instance level variables values accroding to the new GCP project and compute hostname
    logger $logName "INFO" "Updating instance level CI/CD variables"
    
    echo "Ci::InstanceVariable.where(key: 'CI_SERVER_HOST').update(value: '$INSTANCE_INTERNAL_HOSTNAME')" > $RAILS_CMD_PATH
    echo "Ci::InstanceVariable.where(key: 'CI_SERVER_URL').update(value: '$INSTANCE_INTERNAL_URL')" >> $RAILS_CMD_PATH
    echo "Ci::InstanceVariable.where(key: 'CI_API_V4_URL').update(value: '$INSTANCE_INTERNAL_API_V4_URL')" >> $RAILS_CMD_PATH
    echo "Ci::InstanceVariable.where(key: 'CONTAINER_REGISTRY_NAMESPACE').update(value: '$GCP_PROJECT_ID').save" >> $RAILS_CMD_PATH
    echo "Ci::InstanceVariable.where(key: 'CONTAINER_REGISTRY_HOST').update(value: 'gcr.io').save" >> $RAILS_CMD_PATH
    
    exec_wrapper $ERR_ACTION_CONT $logName "gitlab-rails runner $RAILS_CMD_PATH"
}


seed_instance_reg_token () {
    local logName=$1
    # Seed shared runners registartion token
    GITLAB_RUNNER_REG_SECRET=`curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/attributes/gitlab-ci-runner-registration-token-secret`
    logger $logName "INFO" "Reading shared runners registration token from secret $GITLAB_RUNNER_REG_SECRET"    
    GITLAB_RUNNER_REG=`gcloud secrets versions access latest --secret=$GITLAB_RUNNER_REG_SECRET`
    logger $logName "INFO" "Seeding shared runners registration token"
    
    echo "appset = Gitlab::CurrentSettings.current_application_settings; appset.set_runners_registration_token('$GITLAB_RUNNER_REG'); appset.save!" > $RAILS_CMD_PATH
    exec_wrapper $ERR_ACTION_CONT $logName "gitlab-rails runner $RAILS_CMD_PATH"
}


seed_gitlab_root_pwd () {
    local logName=$1
    # Seed gitlab root password
    GITLAB_INITIAL_ROOT_PASSWORD_SECRET=`curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/attributes/gitlab-initial-root-pwd-secret`
    logger $logName "INFO" "Reading gitlab root password from secret $GITLAB_INITIAL_ROOT_PASSWORD_SECRET"
    GITLAB_INITIAL_ROOT_PASSWORD=`gcloud secrets versions access latest --secret=$GITLAB_INITIAL_ROOT_PASSWORD_SECRET`
    
    logger $logName "INFO" "Seeding gitlab root password"
    echo "user = User.find_by_username('root'); user.password = '$GITLAB_INITIAL_ROOT_PASSWORD'; user.password_confirmation = '$GITLAB_INITIAL_ROOT_PASSWORD'; user.save!" > $RAILS_CMD_PATH
    exec_wrapper $ERR_ACTION_CONT $logName "gitlab-rails runner $RAILS_CMD_PATH"
}



create_groups () {
    local logName=$1
    # Create repo groups (ci, community, private)
    logger $logName "INFO" "Creating groups: ci, community, private"
    
    echo "Groups::CreateService.new(User.find_by_id(1), params = {name: 'CI CD Tools', path: 'ci', visibility_level: 10}).execute" > $RAILS_CMD_PATH
    echo "Groups::CreateService.new(User.find_by_id(1), params = {name: 'Community Tools', path: 'community', visibility_level: 10}).execute" >> $RAILS_CMD_PATH
    echo "Groups::CreateService.new(User.find_by_id(1), params = {name: 'Private Tools', path: 'private', visibility_level: 10}).execute" >> $RAILS_CMD_PATH
   
    exec_wrapper $ERR_ACTION_CONT $logName "gitlab-rails runner $RAILS_CMD_PATH"
}


import_scallops_recipes () {
    local logName=$1
    # Import SCALLOPS-RECIPES project repo
    readonly SCALLOPS_RECIPES_GIT_URL=`curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/attributes/scallops-recipes-git-url`
    local gitCredsSecretName=`curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/attributes/scallops-recipes-git-creds-secret`
    logger $logName "INFO" "Importing SCALLOPS-RECIPES repo from $SCALLOPS_RECIPES_GIT_URL to ci group"

	if [ $gitCredsSecretName != 'NONE' ]; then
		logger $logName "INFO" "Reading Git credentials from secret $gitCredsSecretName to import $SCALLOPS_RECIPES_GIT_URL repository"
        local gitCreds=`gcloud secrets versions access latest --secret=$gitCredsSecretName`
        SCALLOPS_RECIPES_GIT_URL="https://$gitCreds@${SCALLOPS_RECIPES_GIT_URL:8}"
	fi    
    
    
    logger $logName "DEBUG" "Ignore the following error: (undefined method repository for :octokit:Symbol)"
    echo "cigrp = Group.find_by_path_or_name('ci'); rootuser = User.find_by_id(1); Project.new(import_url: '$SCALLOPS_RECIPES_GIT_URL', name: 'Scallops Recipes', path: 'scallops-recipes', visibility_level: 10, creator: rootuser, namespace: cigrp).save" > $RAILS_CMD_PATH
    echo "newprj = Project.find_by_full_path('ci/scallops-recipes'); Gitlab::GithubImport::Importer::RepositoryImporter.new(newprj, :octokit).execute" >> $RAILS_CMD_PATH
    
    exec_wrapper $ERR_ACTION_CONT $logName "gitlab-rails runner $RAILS_CMD_PATH" # Ignore the following error (undefined method `repository' for :octokit:Symbol)
}


seed_scallops_recipes_runner_token () {
    local logName=$1
    # Seed scallops-recipes sepcific runners registration token
    # Make sure to invoke seed_instance_reg_token function before this one, so the $GITLAB_RUNNER_REG variable will be set
    logger $logName "INFO" "Seeding Scallops-Recipes runners registration token"
    local scallopsRunnerReg=GR1348941$GITLAB_RUNNER_REG-scallops-recipes
    
    echo "scallopsprj = Project.find_by_full_path('ci/scallops-recipes'); scallopsprj.set_runners_token('$scallopsRunnerReg'); scallopsprj.save!" > $RAILS_CMD_PATH
    exec_wrapper $ERR_ACTION_CONT $logName "gitlab-rails runner $RAILS_CMD_PATH"
}


setup_gitlab_backup () {
    local logName=$1
    local gcsPrefix=$2
    # Download backup cron executor and cron job #Backup will occur every Saturday on 10:00 UTC
    logger $logName "INFO" "Setting up backup procedure with crontab"
    exec_wrapper $ERR_ACTION_CONT $logName "gsutil cp $gcsPrefix/scripts/bash/gitlab_backup.sh /gitlab_backup.sh"
    chmod +x /gitlab_backup.sh
    echo "0 10 * * 6 /gitlab_backup.sh" > gitlab-backup-cron
    logger $logName "DEBUG" "Crontab content $(cat gitlab-backup-cron)"
    exec_wrapper $ERR_ACTION_CONT $logName "crontab gitlab-backup-cron"
    rm gitlab-backup-cron
}



get_backup_archive () {
    local logName=$1
    local gcsPathToBackup=$2
    local backupArchivePath=$3

    # Download backup
    logger $logName "INFO" "Downloading backup from $gcsPathToBackup"
    exec_wrapper $ERR_ACTION_CONT $logName "gsutil cp $gcsPathToBackup $backupArchivePath"

}


get_backup_archive_password () {
    local logName=$1    
    
    # Get the backup archive password
    logger $logName "INFO" "Getting backup password secret from instance metadata"
    GITLAB_BACKUP_PASSWORD_SECRET=`curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/attributes/gitlab-backup-key-secret`
    logger $logName "INFO" "Reading password for the backup archive from secret - $GITLAB_BACKUP_PASSWORD_SECRET"
    GITLAB_BACKUP_PASSWORD=`gcloud secrets versions access latest --secret=$GITLAB_BACKUP_PASSWORD_SECRET`
    logger $logName "DEBUG" "Fetched password with length of ${#GITLAB_BACKUP_PASSWORD} characters"
}


restore_backup () {
    local logName=$1
    local backupArchivePath=$2
    local backupDir="backup-extracted"

    # Migrate configuration files and SSL certificates

    mkdir -p $backupDir

    logger $logName "INFO" "Extracting backup from $backupArchivePath to $backupDir"
    exec_wrapper $ERR_ACTION_EXIT $logName "7z x -p$GITLAB_BACKUP_PASSWORD $backupArchivePath -o./$backupDir"


    logger $logName "INFO" "Copying configuration files and certificates from $backupDir"
    cp $backupDir/gitlab* /etc/gitlab
    cp -R $backupDir/ssl /etc/gitlab

    # Reconfigure installation
    logger $logName "INFO" "Reconfiguring Gitlab"
    exec_wrapper $ERR_ACTION_CONT $logName "gitlab-ctl reconfigure"

    # Stop Gitlab services
    logger $logName "INFO" "Stopping Gitlab services: unicorn, puma, sidekiq"
    gitlab-ctl stop unicorn
    gitlab-ctl stop puma
    gitlab-ctl stop sidekiq
    gitlab-ctl status

    # Restore from backup
    local backupFileName=$(ls $backupDir | grep _gitlab_backup.tar)
    logger $logName "INFO" "Copying extracted backup archive"
    cp $backupDir/$backupFileName /var/opt/gitlab/backups/
    chown git:git /var/opt/gitlab/backups/$backupFileName

    logger $logName "INFO" "Restoring from backup snapshot... $backupFileName"
    local restoreBackupName=$(echo $backupFileName | cut -d "_" -f 1-5)
    exec_wrapper $ERR_ACTION_EXIT $logName "yes yes | gitlab-rake gitlab:backup:restore BACKUP=$restoreBackupName"
    
    logger $logName "INFO" "Reconfiguring Gitlab"
    exec_wrapper $ERR_ACTION_CONT $logName "gitlab-ctl reconfigure"
    
    logger $logName "INFO" "Restarting Gitlab services"
    exec_wrapper $ERR_ACTION_CONT $logName "gitlab-ctl restart"
    
    logger $logName "INFO" "Checking Gitlab services health"
    exec_wrapper $ERR_ACTION_CONT $logName "gitlab-rake gitlab:check SANITIZE=true"
    
    logger $logName "INFO" "Checking secrets decryptability"    
    exec_wrapper $ERR_ACTION_CONT $logName "gitlab-rake gitlab:doctor:secrets"
}



execute_backup () {
    ### Scallops customized Gitlab backup script ###
    ## Run as root

    local logName=$1
    local gitlabVersion=$2
    local instanceName=`curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/name`
    local timestamp=`date +"%s"`
    local backupDir="backup-$timestamp"
    local backupArchiveFile="$instanceName-$gitlabVersion-$backupDir.zip"
   

    logger $logName "INFO" "Starting Gitlab backup for $instanceName"

    # Create backup folder
    mkdir -p $backupDir

    # Stop Gitlab services
    logger $logName "INFO" "Stopping Gitlab services (unicorn, sidekiq, puma)"
    gitlab-ctl stop unicorn
    gitlab-ctl stop sidekiq
    gitlab-ctl stop puma

    # Create back up TAR
    logger $logName "INFO" "Creaing backup tar file"
    exec_wrapper $ERR_ACTION_EXIT $logName "gitlab-backup create"

    # Restart Gitlab services back
    logger $logName "INFO" "Restarting gitlab services"
    exec_wrapper $ERR_ACTION_CONT $logName "gitlab-ctl restart"

    # Copy DB backup and configurations
    local mostRecentBackupName=`ls -t /var/opt/gitlab/backups/ | head -1`
    logger $logName "INFO" "Using backup: $mostRecentBackupName"

    logger $logName "INFO" "Copying DB backup, gitlab configurations and SSL ceritficates"
    cp /var/opt/gitlab/backups/$mostRecentBackupName $backupDir/
    cp /etc/gitlab/gitlab.rb $backupDir/
    cp /etc/gitlab/gitlab-secrets.json $backupDir/
    cp -R /etc/gitlab/ssl/ $backupDir/

    # Get the backup bucket name
    logger $logName "INFO" "Getting backup bucket name from instance metadata"
    GITLAB_BACKUPS_BUCKET_NAME=`curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/attributes/gitlab-backup-bucket-name`


    # Archive and encrypt backup
    logger $logName "INFO" "Archiving and encrypting backup"
    exec_wrapper $ERR_ACTION_EXIT $logName "7z a -p$GITLAB_BACKUP_PASSWORD $backupDir.zip ./$backupDir/*"

    # Upload archived backup
    logger $logName "INFO" "Uploading backup as: gs://$GITLAB_BACKUPS_BUCKET_NAME/gitlab-backups/$backupArchiveFile"
    exec_wrapper $ERR_ACTION_CONT $logName "gsutil cp $backupDir.zip gs://$GITLAB_BACKUPS_BUCKET_NAME/gitlab-backups/$backupArchiveFile"


    # Delete source directory and backup archive
    logger $logName "INFO" "Deleting processed files"
    rm -r $backupDir
    rm $backupDir.zip

    logger $logName "INFO" "Gitlab backup completed"
}
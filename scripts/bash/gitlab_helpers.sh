#!/bin/bash

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


gitlab_depsInstall () {
    local logName=$1
    # Install Dependencies
    logger $logName "INFO" "Running package updater apt-get update"   
    errMsg=$(apt-get update 2>&1)
    get_last_error $logName $? $ERR_ACTION_EXIT "$errMsg" 
    logger $logName "INFO" "Installing the following packages curl ca-certificates tzdata perl jq coreutils zip p7zip-full"
    errMsg=$(apt-get install -y curl ca-certificates tzdata perl jq coreutils zip p7zip-full 2>&1)
    get_last_error $logName $? $ERR_ACTION_EXIT "$errMsg" 
}


set_gitlabVars () {
    local logName=$1
    logger $logName "INFO" "Fetching Gitlab network variables"
    ## Network variables
    INSTANCE_PROTOCOL=`curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/attributes/instance-protocol` #http/https
    INSTANCE_EXTERNAL_DOMAIN=`curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/attributes/instance-external-domain`
    EXTERNAL_IP=`curl -H "Metadata-Flavor: Google" http://metadata/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip`
    
    #Ext URL
    EXTERNAL_URL="$INSTANCE_PROTOCOL://$INSTANCE_EXTERNAL_DOMAIN"
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
    
    errMsg=$(gitlab-ctl reconfigure 2>&1)
    get_last_error $logName $? $ERR_ACTION_CONT "$errMsg" 
    
    errMsg=$(gitlab-ctl restart 2>&1)
    get_last_error $logName $? $ERR_ACTION_CONT "$errMsg"

    logger $logName "INFO" "Updating EXTERNAL URL to CI_EXTERNAL_URL CI/CD variable"
    errMsg=$(gitlab-rails runner "Ci::InstanceVariable.where(key: 'CI_EXTERNAL_URL').update(value: '$EXTERNAL_URL')" 2>&1)
    get_last_error $logName $? $ERR_ACTION_CONT "$errMsg" 
}


gitlab_install () {
    local logName=$1
    local gitlabVersion=$2
    # Install Postfix non-interactive
    logger $logName "INFO" "Starting postfix installation for domain: $INSTANCE_EXTERNAL_DOMAIN"
    debconf-set-selections <<< "postfix postfix/mailname string $INSTANCE_EXTERNAL_DOMAIN"
    debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
    errMsg=$(apt-get install --assume-yes postfix 2>&1)
    get_last_error $logName $? $ERR_ACTION_CONT "$errMsg" 

    # Install Gitlab Server
    logger $logName "INFO" "Setting up Gitlab installation at version $gitlabVersion"
    curl https://packages.gitlab.com/install/repositories/gitlab/gitlab-ee/script.deb.sh | bash
    #Specific version installation:
    logger $logName "INFO" "Downloading Gitlab from https://packages.gitlab.com/gitlab/gitlab-ee/packages/ubuntu/bionic/gitlab-ee_$gitlabVersion.0_amd64.deb/download.deb"
    errMsg=$(wget --content-disposition https://packages.gitlab.com/gitlab/gitlab-ee/packages/ubuntu/bionic/gitlab-ee_$gitlabVersion.0_amd64.deb/download.deb 2>&1)
    get_last_error $logName $? $ERR_ACTION_EXIT "$errMsg" 
    logger $logName "INFO" "Installing Gitlab"
    errMsg=$(dpkg -i gitlab-ee_$gitlabVersion.0_amd64.deb 2>&1)
    get_last_error $logName $? $ERR_ACTION_EXIT "$errMsg"
    
    logger $logName "INFO" "Reconfiguring Gitlab"
    errMsg=$(gitlab-ctl reconfigure 2>&1)
    get_last_error $logName $? $ERR_ACTION_CONT "$errMsg"     
}


setup_cicd_vars () {
    local logName=$1
    # Set instance level environment variables, so pipelines can utilize them
    logger $logName "INFO" "Fetching values for instance level CI/CD variables"
    GCP_PROJECT_ID=`gcloud config list --format 'value(core.project)' 2>/dev/null`
    INSTANCE_INTERNAL_HOSTNAME=`curl -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/hostname"`
    INSTANCE_INTERNAL_URL=$INSTANCE_PROTOCOL://$INSTANCE_INTERNAL_HOSTNAME
    INSTANCE_INTERNAL_API_V4_URL=$INSTANCE_PROTOCOL://$INSTANCE_INTERNAL_HOSTNAME/api/v4
    
    logger $logName "INFO" "CI_EXTERNAL_URL=$EXTERNAL_URL"
    logger $logName "INFO" "CI_SERVER_HOST=$INSTANCE_INTERNAL_HOSTNAME" 
    logger $logName "INFO" "CI_SERVER_URL=$INSTANCE_INTERNAL_URL" 
    logger $logName "INFO" "CI_API_V4_URL=$INSTANCE_INTERNAL_API_V4_URL" 
    logger $logName "INFO" "CONTAINER_REGISTRY_NAMESPACE=$GCP_PROJECT_ID" 
    logger $logName "INFO" "CONTAINER_REGISTRY_HOST=gcr.io"
}

create_cicd_vars () {
    local logName=$1
    # New instance level variables
    logger $logName "INFO" "Creating instance level CI/CD variables"
    gitlab-rails runner "Ci::InstanceVariable.new(key: 'CI_EXTERNAL_URL', value: '$EXTERNAL_URL').save"
    gitlab-rails runner "Ci::InstanceVariable.new(key: 'CI_SERVER_HOST', value: '$INSTANCE_INTERNAL_HOSTNAME').save"
    gitlab-rails runner "Ci::InstanceVariable.new(key: 'CI_SERVER_URL', value: '$INSTANCE_INTERNAL_URL').save"
    gitlab-rails runner "Ci::InstanceVariable.new(key: 'CI_API_V4_URL', value: '$INSTANCE_INTERNAL_API_V4_URL').save"
    gitlab-rails runner "Ci::InstanceVariable.new(key: 'CONTAINER_REGISTRY_NAMESPACE', value: '$GCP_PROJECT_ID').save"
    gitlab-rails runner "Ci::InstanceVariable.new(key: 'CONTAINER_REGISTRY_HOST', value: 'gcr.io').save"
}

update_cicd_vars () {
    local logName=$1
    # Update instance level variables values accroding to the new GCP project and compute hostname
    logger $logName "INFO" "Updating instance level CI/CD variables"
    gitlab-rails runner "Ci::InstanceVariable.where(key: 'CI_SERVER_HOST').update(value: '$INSTANCE_INTERNAL_HOSTNAME')"
    gitlab-rails runner "Ci::InstanceVariable.where(key: 'CI_SERVER_URL').update(value: '$INSTANCE_INTERNAL_URL')"
    gitlab-rails runner "Ci::InstanceVariable.where(key: 'CI_API_V4_URL').update(value: '$INSTANCE_INTERNAL_API_V4_URL')"
    gitlab-rails runner "Ci::InstanceVariable.where(key: 'CONTAINER_REGISTRY_NAMESPACE').update(value: '$GCP_PROJECT_ID').save"
    gitlab-rails runner "Ci::InstanceVariable.where(key: 'CONTAINER_REGISTRY_HOST').update(value: 'gcr.io').save"
}


seed_instance_reg_token () {
    local logName=$1
    # Seed shared runners registartion token
    GITLAB_RUNNER_REG_SECRET=`curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/attributes/gitlab-ci-runner-registration-token-secret`
    logger $logName "INFO" "Reading shared runners registration token from secret $GITLAB_RUNNER_REG_SECRET"    
    GITLAB_RUNNER_REG=`gcloud secrets versions access latest --secret=$GITLAB_RUNNER_REG_SECRET`
    logger $logName "INFO" "Seeding shared runners registration token"
    errMsg=$(gitlab-rails runner "appset = Gitlab::CurrentSettings.current_application_settings; appset.set_runners_registration_token('$GITLAB_RUNNER_REG'); appset.save!" 2>&1)
    get_last_error $logName $? $ERR_ACTION_CONT "$errMsg" 
}


seed_gitlab_root_pwd () {
    local logName=$1
    # Seed gitlab root password
    GITLAB_INITIAL_ROOT_PASSWORD_SECRET=`curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/attributes/gitlab-initial-root-pwd-secret`
    logger $logName "INFO" "Reading gitlab root password from secret $GITLAB_INITIAL_ROOT_PASSWORD_SECRET"
    GITLAB_INITIAL_ROOT_PASSWORD=`gcloud secrets versions access latest --secret=$GITLAB_INITIAL_ROOT_PASSWORD_SECRET`
    logger $logName "INFO" "Seeding gitlab root password"
    errMsg=$(gitlab-rails runner "user = User.find_by_username('root'); user.password = '$GITLAB_INITIAL_ROOT_PASSWORD'; user.password_confirmation = '$GITLAB_INITIAL_ROOT_PASSWORD'; user.save!" 2>&1)
    get_last_error $logName $? $ERR_ACTION_CONT "$errMsg"
}



create_groups () {
    local logName=$1
    # Create repo groups (ci, community, private)
    logger $logName "INFO" "Creating groups: ci, community, private"
    errMsg=$(gitlab-rails runner "Groups::CreateService.new(User.find_by_id(1), params = {name: 'CI CD Tools', path: 'ci', visibility_level: 10}).execute" 2>&1)
    get_last_error $logName $? $ERR_ACTION_CONT "$errMsg"
    errMsg=$(gitlab-rails runner "Groups::CreateService.new(User.find_by_id(1), params = {name: 'Community Tools', path: 'community', visibility_level: 10}).execute" 2>&1)
    get_last_error $logName $? $ERR_ACTION_CONT "$errMsg"
    errMsg=$(gitlab-rails runner "Groups::CreateService.new(User.find_by_id(1), params = {name: 'Private Tools', path: 'private', visibility_level: 10}).execute" 2>&1)
    get_last_error $logName $? $ERR_ACTION_CONT "$errMsg"
}


import_scallopsRecipes () {
    local logName=$1
    # Import SCALLOPS-RECIPES project repo
    SCALLOPS_RECIPES_GIT_URL=`curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/attributes/scallops-recipes-git-url`
    local gitCredsSecretName=`curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/attributes/scallops-recipes-git-creds-secret`
    logger $logName "INFO" "Importing SCALLOPS-RECIPES repo from $SCALLOPS_RECIPES_GIT_URL to ci group"

	if [ $gitCredsSecretName != 'NONE' ]; then
		logger $logName "INFO" "Reading Git credentials from secret $gitCredsSecretName to import $SCALLOPS_RECIPES_GIT_URL repository"
        local gitCreds=`gcloud secrets versions access latest --secret=$gitCredsSecretName`
        SCALLOPS_RECIPES_GIT_URL="https://$gitCreds@${SCALLOPS_RECIPES_GIT_URL:8}"
	fi    
    gitlab-rails runner "cigrp = Group.find_by_path_or_name('ci'); rootuser = User.find_by_id(1); Project.new(import_url: '$SCALLOPS_RECIPES_GIT_URL', name: 'Scallops Recipes', path: 'scallops-recipes', visibility_level: 10, creator: rootuser, namespace: cigrp).save"
    gitlab-rails runner "newprj = Project.find_by_full_path('ci/scallops-recipes'); Gitlab::GithubImport::Importer::RepositoryImporter.new(newprj, :octokit).execute" # Ignore the following error (undefined method `repository' for :octokit:Symbol)
}


seed_scallopsRecipes_runner_token () {
    local logName=$1
    # Seed scallops-recipes sepcific runners registration token
    # Make sure to invoke seed_instance_reg_token function before this one, so the $GITLAB_RUNNER_REG variable will be set
    logger $logName "INFO" "Seeding Scallops-Recipes runners registration token"
    local scallopsRunnerReg=GR1348941$GITLAB_RUNNER_REG-scallops-recipes
    gitlab-rails runner "scallopsprj = Project.find_by_full_path('ci/scallops-recipes'); scallopsprj.set_runners_token('$scallopsRunnerReg'); scallopsprj.save!"
}


setup_gitlab_backup () {
    local logName=$1
    local gcsPrefix=$2
    # Download backup cron executor and cron job #Backup will occur every Saturday on 10:00 UTC
    logger $logName "INFO" "Setting up backup procedure with crontab"
    errMsg=$(gsutil cp $gcsPrefix/scripts/bash/gitlab_backup_exec.sh /gitlab_backup_exec.sh 2>&1)
    get_last_error $logName $? $ERR_ACTION_CONT "$errMsg" 
    chmod +x /gitlab_backup_exec.sh
    echo "0 10 * * 6 /gitlab_backup_exec.sh" > gitlab-backup-cron
    errMsg=$(crontab gitlab-backup-cron 2>&1)
    get_last_error $logName $? $ERR_ACTION_CONT "$errMsg" 
    rm gitlab-backup-cron
}



get_backup_archive () {
    local logName=$1
    local gcsPathToBackup=$2
    local backupArchivePath=$3

    # Download backup
    logger $logName "INFO" "Downloading backup from $gcsPathToBackup"
    errMsg=$(gsutil cp $gcsPathToBackup $backupArchivePath 2>&1)
    get_last_error $logName $? $ERR_ACTION_CONT "$errMsg" 

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
    errMsg=$(7z x -p$GITLAB_BACKUP_PASSWORD $backupArchivePath -o./$backupDir 2>&1)
    get_last_error $logName $? $ERR_ACTION_EXIT "$errMsg" 


    logger $logName "INFO" "Copying configuration files and certificates from $backupDir"
    cp $backupDir/gitlab* /etc/gitlab
    cp -R $backupDir/ssl /etc/gitlab

    # Reconfigure installation
    logger $logName "INFO" "Reconfiguring Gitlab"
    gitlab-ctl reconfigure

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
    errMsg=$(yes yes | gitlab-rake gitlab:backup:restore BACKUP=$restoreBackupName 2>&1)
    get_last_error $logName $? $ERR_ACTION_EXIT "$errMsg" 
    
    logger $logName "INFO" "Reconfiguring Gitlab"
    errMsg=$(gitlab-ctl reconfigure 2>&1)
    get_last_error $logName $? $ERR_ACTION_CONT "$errMsg" 
    
    logger $logName "INFO" "Restarting Gitlab services"
    errMsg=$(gitlab-ctl restart 2>&1)
    get_last_error $logName $? $ERR_ACTION_CONT "$errMsg" 
    
    logger $logName "INFO" "Checking Gitlab services health"
    errMsg=$(gitlab-rake gitlab:check SANITIZE=true 2>&1)
    get_last_error $logName $? $ERR_ACTION_CONT "$errMsg" 
    
    logger $logName "INFO" "Checking secrets decryptability"    
    errMsg=$(gitlab-rake gitlab:doctor:secrets 2>&1)
    get_last_error $logName $? $ERR_ACTION_CONT "$errMsg" 
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
    errMsg=$(gitlab-backup create 2>&1)
    get_last_error $logName $? $ERR_ACTION_EXIT "$errMsg" 

    # Restart Gitlab services back
    logger $logName "INFO" "Restarting gitlab services"
    errMsg=$(gitlab-ctl restart 2>&1)
    get_last_error $logName $? $ERR_ACTION_CONT "$errMsg" 

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
    errMsg=$(7z a -p$GITLAB_BACKUP_PASSWORD $backupDir.zip ./$backupDir/* 2>&1)
    get_last_error $logName $? $ERR_ACTION_EXIT "$errMsg" 

    # Upload archived backup
    logger $logName "INFO" "Uploading backup as: gs://$GITLAB_BACKUPS_BUCKET_NAME/gitlab-backups/$backupArchiveFile"
    errMsg=$(gsutil cp $backupDir.zip gs://$GITLAB_BACKUPS_BUCKET_NAME/gitlab-backups/$backupArchiveFile 2>&1)
    get_last_error $logName $? $ERR_ACTION_CONT "$errMsg" 


    # Delete source directory and backup archive
    logger $logName "INFO" "Deleting processed files"
    rm -r $backupDir
    rm $backupDir.zip

    logger $logName "INFO" "Gitlab backup completed"
}


get_last_error () {	
	local logName=$1
	local errCode=$2
	local errAction=$3
	local errMsg=$4
	if [ $errCode -ne 0 ]; then
		logger $logName "ERROR" "ErrCode: $errCode, ErrAction: $errAction,  Message: $errMsg"
		if [ $errAction == $ERR_ACTION_EXIT ]; then
			logger $logName "INFO" "Stopping execution due to error"
			exit 1
		fi
	fi
}
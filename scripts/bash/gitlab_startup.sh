#!/bin/bash

# Gitlab starup script
# This script will either install, migrate or reconfigure Gitlab installation according to the values set in the instance metadata.
# Installation / Migration will be executed once in a life of an instance.
# Reconfiguration will be executed on every boot.
# Reconfiguration updates the Gitlab's External URL and certificates if they changed through metadata.


#Vars
DEPLOYMENT_GCS_PREFIX=`curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/attributes/gcs-prefix`
GITLAB_INSTALL_VERSION=`curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/attributes/gitlab-version`
GCS_PATH_TO_BACKUP=`curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/attributes/gcs-path-to-backup`
GCLOUD_LOG_NAME="gitlab-startup"
BACKUP_ARCHIVE_PATH="/tmp/backup_archived.zip"
ERR_ACTION_EXIT="Exit"
ERR_ACTION_CONT="Continue"

#Imports
gsutil cp $DEPLOYMENT_GCS_PREFIX/scripts/bash/gitlab_helpers.sh ./
gsutil cp $DEPLOYMENT_GCS_PREFIX/scripts/bash/gcloud_logger.sh ./
source ./gitlab_helpers.sh
source ./gcloud_logger.sh

# Start
logger $GCLOUD_LOG_NAME "INFO" "Starting Gitlab instance setup"

set_gitlabVars $GCLOUD_LOG_NAME
check_installation $GCLOUD_LOG_NAME

if [ $GITLAB_INSTALLED == 'false' ]; then
    logger $GCLOUD_LOG_NAME "INFO" "Starting Gitlab installation"
    gitlab_depsInstall $GCLOUD_LOG_NAME 
    gitlab_install $GCLOUD_LOG_NAME $GITLAB_INSTALL_VERSION
    setup_cicd_vars $GCLOUD_LOG_NAME

    if [ $GCS_PATH_TO_BACKUP == 'NONE' ]; then
        create_groups $GCLOUD_LOG_NAME
        import_scallopsRecipes $GCLOUD_LOG_NAME
        create_cicd_vars $GCLOUD_LOG_NAME

    else         
        logger $GCLOUD_LOG_NAME "INFO" "Migrating Gitlab from provided backup $GCS_PATH_TO_BACKUP"
        get_backup_archive $GCLOUD_LOG_NAME $GCS_PATH_TO_BACKUP $BACKUP_ARCHIVE_PATH
        get_backup_archive_password $GCLOUD_LOG_NAME
        restore_backup $GCLOUD_LOG_NAME $BACKUP_ARCHIVE_PATH
        update_cicd_vars $GCLOUD_LOG_NAME
    fi

    seed_instance_reg_token $GCLOUD_LOG_NAME
    seed_gitlab_root_pwd $GCLOUD_LOG_NAME
    seed_scallopsRecipes_runner_token $GCLOUD_LOG_NAME
    setup_gitlab_backup $GCLOUD_LOG_NAME $DEPLOYMENT_GCS_PREFIX

else
    logger $GCLOUD_LOG_NAME "INFO" "Skipping Gitlab installation"
fi


reconfigure_gitlab $GCLOUD_LOG_NAME
logger $GCLOUD_LOG_NAME "INFO" "Gitlab instance setup completed"
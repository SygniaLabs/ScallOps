#!/bin/bash

PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin"

#Imports
DEPLOYMENT_GCS_PREFIX=`curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/attributes/gcs-prefix`
GCLOUD_LOG_NAME="gitlab-backup-exec"

gsutil cp $DEPLOYMENT_GCS_PREFIX/scripts/bash/gcloud_logger.sh ./
source ./gcloud_logger.sh
gsutil cp $DEPLOYMENT_GCS_PREFIX/scripts/bash/gitlab_helpers.sh ./
source ./gitlab_helpers.sh



check_installation $GCLOUD_LOG_NAME

if [ "$GITLAB_INSTALLED" == 'true' ]; then
    logger $GCLOUD_LOG_NAME "INFO" "Executing gitlab backup"
    get_backup_archive_password $GCLOUD_LOG_NAME
    execute_backup $GCLOUD_LOG_NAME $GITLAB_EE_VERSION

else
    logger $GCLOUD_LOG_NAME "ERROR" "Gitlab installation was not found!"
fi

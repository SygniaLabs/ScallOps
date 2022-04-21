#!/bin/bash


### Scallops customized Gitlab backup script ###
## Run as root/sudo

TIMESTAMP=`date +"%s"`
INSTANCE_NAME=`curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/name`
BACKUP_LOG_FILE="$INSTANCE_NAME-$TIMESTAMP-backup.log"

echo "INFO: Starting backup - $TIMESTAMP" >> $BACKUP_LOG_FILE

# Stop Gitlab services
echo "INFO: Stopping Gitlab services (unicorn, sidekiq, puma)..." >> $BACKUP_LOG_FILE
gitlab-ctl stop unicorn >> $BACKUP_LOG_FILE
gitlab-ctl stop sidekiq >> $BACKUP_LOG_FILE
gitlab-ctl stop puma >> $BACKUP_LOG_FILE

# Create back up TAR
echo "INFO: Creaing back tar file" >> $BACKUP_LOG_FILE
gitlab-backup create >> $BACKUP_LOG_FILE

# Restart Gitlab services back
echo "INFO: Restarting gitlab services" >> $BACKUP_LOG_FILE
gitlab-ctl restart >> $BACKUP_LOG_FILE


# Create backup folder

BACKUP_DIR="backup-$TIMESTAMP"
mkdir -p $BACKUP_DIR


# Copy DB backup and configurations
echo "INFO: Locating latest backup tar..." >> $BACKUP_LOG_FILE
MOST_RECENT_BACKUP_NAME=`sudo ls -t /var/opt/gitlab/backups/ | head -1`
echo "INFO: Using backup: $MOST_RECENT_BACKUP_NAME" >> $BACKUP_LOG_FILE

echo "INFO: Copying DB backup, gitlab configurations and SSL ceritficates" >> $BACKUP_LOG_FILE
cp /var/opt/gitlab/backups/$MOST_RECENT_BACKUP_NAME $BACKUP_DIR/  >> $BACKUP_LOG_FILE
cp /etc/gitlab/gitlab.rb $BACKUP_DIR/ >> $BACKUP_LOG_FILE
cp /etc/gitlab/gitlab-secrets.json $BACKUP_DIR/ >> $BACKUP_LOG_FILE
cp -R /etc/gitlab/ssl/ $BACKUP_DIR/ >> $BACKUP_LOG_FILE


# Get the backup archive password
echo "INFO: Fetching backup archive password from secrets" >> $BACKUP_LOG_FILE
GITLAB_BACKUP_PASSWORD_SECRET=`curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/attributes/gitlab-backup-key-secret`
GITLAB_BACKUP_PASSWORD=`gcloud secrets versions access latest --secret=$GITLAB_BACKUP_PASSWORD_SECRET`


# Get the backup bucket name
echo "INFO: Fetching backup target bucket" >> $BACKUP_LOG_FILE
GITLAB_BACKUPS_BUCKET_NAME=`curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/attributes/gitlab-backup-bucket-name`


# Archive and encrypt backup
echo "INFO: Archiving and encrypting backup..." >> $BACKUP_LOG_FILE
7z a -p$GITLAB_BACKUP_PASSWORD $BACKUP_DIR.zip ./$BACKUP_DIR/*  >> $BACKUP_LOG_FILE

# Upload archived backup
echo "INFO: Uploading backup as: gs://$GITLAB_BACKUPS_BUCKET_NAME/gitlab-backups/$INSTANCE_NAME-$BACKUP_DIR.zip" >> $BACKUP_LOG_FILE
gsutil cp $BACKUP_DIR.zip gs://$GITLAB_BACKUPS_BUCKET_NAME/gitlab-backups/$INSTANCE_NAME-$BACKUP_DIR.zip >> $BACKUP_LOG_FILE


# Delete source directory and backup archive
echo "INFO: Deleting processed files..." >> $BACKUP_LOG_FILE
rm -r $BACKUP_DIR
rm $BACKUP_DIR.zip

ls -la >> $BACKUP_LOG_FILE
echo "INFO: Backup completed!" >> $BACKUP_LOG_FILE

gsutil cp $BACKUP_LOG_FILE gs://$GITLAB_BACKUPS_BUCKET_NAME/gitlab-backups/$BACKUP_LOG_FILE
yes | rm $BACKUP_LOG_FILE
#!/bin/bash

PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin"

DEPLOYMENT_GCS_PREFIX=`curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/attributes/gcs-prefix`
gsutil cp $DEPLOYMENT_GCS_PREFIX/scripts/bash/gitlab_backup.sh ./gitlab_backup.sh
chmod +x gitlab_backup.sh
sudo ./gitlab_backup.sh
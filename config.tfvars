#### Required ####

project_id = ""          # GCP Project ID
infra_name = "scallops"  # The name you wish to have as a prefix for the deployment's resources. Must comply with ^[a-z]([a-z0-9]*[a-z0-9])$
backups_bucket_name = "" # The name of an existing bucket you wish to receive backups to. Terraform will create the required permission to upload the backup archive.


#### Optionals ####
operator_ips = []   # Office IP / home IPs


## External DNS ##
# Uncomment below 3 lines if wishing to supply external DNS name for accessing Gitalb instance

# external_hostname = "scallops.mydomain.com" # Requires re-deploy of the Gitlab instance to be set as external url from Gitlab's perspective. Will also update Certificate ALT names
# dns_project_id = ""                         # The project ID where the managed DNS zone is located
# dns_managed_zone_name = "mydomain-com"      # The configured managed DNS zone name


## Docker hub credentials ##
# An existing secret name storing Dockerhub credentials to fetch private container images (format is username:password or username:access-token).
# Creating Dockerhub access token https://docs.docker.com/docker-hub/access-tokens/
# Creating a secret through GCP secret manager https://cloud.google.com/secret-manager/docs/creating-and-accessing-secrets#create

# dockerhub-creds-secret = ""     # Name of the secret in secret-manager



## Default deployment values ##
# Uncommenct and modify only if needed (us-central-1 considered to be the cheapest).

# gitlab_instance_protocol = "https"  # The Gitlab instance Web server protocol, http or https.
# zone = "a"                          # Zone for the k8s cluster, Gitlab instance and network.
# region = us-central-1               # Region for the k8s cluster, Gitlab instance and network.




## Migration variables ##
# If you plan on migrating from a different gitlab instance, uncomment all migration variables below, and follow requirements.
# Requires Gsutil on the terraform deployer system as backup will be downloaded locally

# migrate_gitlab = true                   ## If performing migration from another Gitlab instance and got a backup file from previous instance. true/false.
# migrate_gitlab_version = ""             ## The Gitlab full version that you are migrating from e.g. '14.3.3-ee'
# migrate_gitlab_backup_bucket = ""       ## The Google Storage Bucket to your Gitlab backup e.g. 'mybucket1-abcd'
# migrate_gitlab_backup_path = ""         ## The path to the archived backup zip e.g 'backups/gitlab-xxx-backup.zip'
# migrate_gitlab_backup_password = ""     ## The password value decrypting the archived backup zip

## ### ### ### ####
#### Required ####

# GCP Project ID
project_id = ""
# The name you wish to have as a prefix for the deployment's resources. Must comply with [a-z]([-a-z0-9]*[a-z0-9])
infra_name = "scallops"

#### Optional ####

# Office IP / home IPs
operator_ips = [""] 


# Uncomment below 3 lines if wishing to supply external DNS name for accessing Gitalb instance
# external_hostname = "scallops.domain.tld"
dns_project_id = ""  # The project ID where the managed DNS zone is located
dns_managed_zone_name = "domain-tld" # The configured managed DNS zone name


# Default deployment values, uncommenct and modify only if needed (us-central-1 considered to be the cheapest).

# The Gitlab instance Web server protocol, http or https.
# gitlab_instance_protocol = "https" 
# Zone for the k8s cluster, Gitlab instance and network.
# zone = "a"
# Region for the k8s cluster, Gitlab instance and network.
# region = us-central-1 



## Migration variables ##
## If you plan on migrating from a different gitlab instance, uncomment all migration variables below, and follow requirements.

# migrate_gitlab = true                         ## If performing migration from another Gitlab instance and got a backup file from previous instance. true/false.
# migrate_gitlab_version = "14.3.3-ee"          ## The Gitlab full version that you are migrating from e.g. '14.3.3-ee'
# migrate_gitlab_backup_bucket = "bck1"         ## The Google Storage Bucket to your Gitlab backup e.g. 'mybucket1-abcd'
# migrate_gitlab_backup_path = "bk/gitlab.zip"  ## The path to the archived backup zip e.g 'backups/gitlab-xxx-backup.zip'
# migrate_gitlab_backup_password = "secret"     ## The password value decrypting the archived backup zip

## ### ### ### ####



##### Scallops IAC variables #####
#### Note that some variables are required (#Required), and some variables modifications will take effect also after deployment (#PostDeploymentModifiable).


## GCP Project ID
project_id = "" #Required

## The name you wish to have as a prefix for the deployment's resources. Must comply with ^[a-z]([a-z0-9]*[a-z0-9])$
infra_name = "scallops" #Required

## The name of an existing bucket you wish to receive backups to. Terraform will create the required permission to upload the backup archive.
backups_bucket_name = "" #Required #PostDeploymentModifiable

## An existing secret ID in the same GCP project (project_id) storing a password for the backup process (Allowed symbols for secret value: -_ )
## Creating a secret through GCP secret manager https://cloud.google.com/secret-manager/docs/creating-and-accessing-secrets#create
gitlab_backup_key_secret_id = "" #Required #PostDeploymentModifiable



## Gitlab version to install
## Ruuner chart version must be compaitibe with the Gitlab version -> https://docs.gitlab.com/runner/#gitlab-runner-versions
## Note the Gitlab application version from the selected Chart version -> https://artifacthub.io/packages/helm/gitlab/gitlab-runner
## You can make upgrades to your Gitlab instance from here. Just reset the instance once the `apply` completes.
# gitlab_version = "16.1.2-ee"
# runner_chart_url = "https://gitlab-charts.s3.amazonaws.com/gitlab-runner-0.54.0.tgz"


## IP addresses that can interact with the Gitlab instance via HTTP/S (Office IP / Home IPs)
# operator_ips = [] #Optional #PostDeploymentModifiable

## Enable debugging resources such as IAP Firewall rules, and export of config files
# debug_flag = false #Optional #PostDeploymentModifiable

## The Gitlab instance Web server protocol, http or https.
# gitlab_instance_protocol = "https" #Optional

## Region for the k8s cluster, Gitlab instance and network.
# region = us-central-1 #Optional

## Zone for the k8s cluster, Gitlab instance and network.
# zone = "a" #Optional



## External DNS ## #Optional #PostDeploymentModifiable #GitlabRestartRequired
## Uncomment the 3 lines below if wishing to supply external DNS name for accessing Gitalb instance

# dns_project_id = ""                           # The project ID where the managed DNS zone is located
# dns_managed_zone_name = "mydomain-com"        # The configured managed DNS zone name
# external_hostname = "scallops.mydomain.com"   # The hostname you wish to set of the instance (Must be subdomain of the managed zone)



## Docker hub credentials (https://docs.docker.com/docker-hub/access-tokens/) #Optional #PostDeploymentModifiable
## An existing secret name in secret-manager storing Dockerhub credentials to fetch private container images (format is username:password or username:access-token).
# dockerhub-creds-secret = ""


## Scallops-Recipes repository. Use the default repository or specify alternative fork in a Git path HTTPS format.
## The specified repository will be imported to Gitlab as the Scallops-Recipes repository.
## *Ignored if performing a migration
# scallops_recipes_git_url = "https://github.com/SygniaLabs/ScallOps-Recipes.git" #Optional
# scallops_recipes_git_creds_secret = "my-github-creds-secret" #Optional



## Migration variables #Optional
## If you plan on migrating from a different gitlab instance, uncomment all migration variables below, and follow requirements.
## 1. 'gitlab_backup_key_secret_id' secret must store the password value decrypting the archived backup zip.
## 2. 'gitlab_version' must be equal to the version you are migrating from.
## 3. Operation requires Gsutil on the terraform deployer system as backup will be downloaded locally

# migrate_gitlab = true                   ## If performing migration from another Gitlab instance and got a backup file from previous instance. true/false.
# migrate_gitlab_backup_bucket = ""       ## The Google Storage Bucket to your Gitlab backup e.g. 'mybucket1-abcd'
# migrate_gitlab_backup_path = ""         ## The path to the archived backup zip e.g 'backups/gitlab-xxx-backup.zip'
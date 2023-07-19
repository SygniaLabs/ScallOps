# Deployment wide variables
variable "project_id" {
    type        = string
    description = "(required) GCP Project ID to deploy to"
}

variable "dns_project_id" {
    type        = string
    description = "If provided external_hostname, specify GCP Project ID where managed zone is located"
    default     = ""
}

variable "infra_name" {
    type        = string
    description = "(required) Infrastructure name or Team name" 
    validation {
        condition     = can(regex("^[a-z]([a-z0-9]*[a-z0-9])$", var.infra_name))  // Due to Certificate SAN, and service account name translation to email, and 1 another.
        error_message = "The infrastructure name must comply with the following regex ^[a-z]([a-z0-9]*[a-z0-9])$ )."  
    }
}

# Backup variables
variable "backups_bucket_name" {
    type        = string
    description = "The name of the bucket backups are stored. Bucket must exist before apply. Terrafrom will add objectCreator permission to the gitlab svc account."
}

variable "gitlab_backup_key_secret_id" {
  description = "An existing secret ID in the same GCP project (project_id) storing a password for the backup process (Allowed symbols: -_ )"
  type        = string
  default     = ""
}

# Migration variables 
variable "migrate_gitlab" {
    type        = bool
    description = "If performing migration from another Gitlab instance and got a backup file from previous instance"
    default     = false
}


variable "migrate_gitlab_backup_bucket" {
    type        = string
    description = "The Google Storage Bucket to your Gitlab backup e.g. 'mybucket1-abcd'"
    default     = ""
}

variable "migrate_gitlab_backup_path" {
    type        = string
    description = "The path to the archived backup zip 'backups/gitlab-xxx-backup.zip'"
    default     = ""
}



# Gitlab instance related variables

variable "gitlab_instance_protocol" {
    type        = string
    description = "(optional) Protocol to use for Gitlab instance http / https"
    default     = "https"
    validation {
        condition     = can(regex("^https?$", var.gitlab_instance_protocol))
        error_message = "The gitlab_instance_protocol can be either http/https."
    }
}

variable "gitlab_version" {
    type        = string
    description = "Gitlab version to install (e.g. 15.2.1-ee). If performing migration, you must specify the Gitlab backup version from the previous instance"
    default     = "16.1.2-ee"
    validation {
        condition     = can(regex("^[0-9]+.[0-9]+.[0-9]+-ee$", var.gitlab_version))
        error_message = "Invalid Gitlab version"
    }
}

variable "plans" {
  type    = map
  default = {
    "2x8" = "n1-standard-2" #(56.72$, 0.097118$)
  }
}

variable "size" {
    type    = string
    default = "2x8"
}

variable "os_images" {
  type       = map
  default    = {
        "ubuntu" = {
          "jammy" = "ubuntu-2204-lts"
          "focal" = "ubuntu-2004-lts"
          "bionic"   = "ubuntu-1804-lts"
          }
  }
}

variable "os_name" {
  type        = string
  description = "(optional) OS Image"
  default     = "ubuntu"
}

variable "os_release" {
  type        = string
  description = "(optional) OS Image"
  default     = "focal"
}

variable "scallops_recipes_git_url" {
  type        = string
  description = "Scallops-Recipes repository. Git URL must be provided in the following format: https://<DOMAIN>/<NAMESPACE>/<Repository>.git"
  default     = "https://github.com/SygniaLabs/ScallOps-Recipes.git"
}

variable "scallops_recipes_git_creds_secret" {
  type        = string
  description = "A secret in the same project (project_id) storing Git credentials to access the provided scallops-recipes repository. Format is <user>:<access-token> or <access-token>."
  default     = ""
}

# Networking and region related variables

variable "operator_ips" {
    type        = list(string)
    description = "(required) IP addresses used to operate and access Gitlab"
}

variable "operator_ports" {
    type        = list(string)
    description = "(optional) Ports used to operate Gitlab"
    default     = ["443","80"]
}


variable "region" {
    type        = string
    description = "(optional) Region in which Gitlab and K8s will be deployed"
    default     = "us-central1"
}

variable "zone" {
    type        = string
    description = "(optional) Zone in which Gitlab GCE and K8s cluster will be deployed, K8s cluster will be Zonal and not Regional."
    default     = "a"
}



# GKE related variables
variable "gke_version" {
  description = "Kubernetes engine version"
  type        = string
  default     = "1.26.5-gke.1200" # Available version -> https://cloud.google.com/kubernetes-engine/docs/release-notes
}

variable "gke_linux_pool_version" {
  description = "GKE Linux node pool version"
  type        = string
  default     = "1.26.5-gke.1200"
}

variable "gke_windows_pool_version" {
  description = "GKE Windows node pool version"
  type        = string
  default     = "1.26.5-gke.1200"
}

variable "runner_chart_url" {
  description = "Gitlab runner Helm chart archive URL" # https://artifacthub.io/packages/helm/gitlab/gitlab-runner
  type        = string
  default     = "https://gitlab-charts.s3.amazonaws.com/gitlab-runner-0.54.0.tgz" # Correspond to Gitlab 16.1.0
}


# DNS and managed zone variables
variable "external_hostname" {
  description = "The external hostname to be configured for the instance. e.g. scallops.example.com"
  type        = string
  default     = ""
}

variable "dns_managed_zone_name" {
  description = "The name of the Cloud DNS Managed Zone in which to create the DNS A Records specified in external_hostname. Only use if provided external_hostname. e.g. example-com"
  type        = string
  default     = ""
}

variable "dns_record_ttl" {
  description = "The time-to-live for the site A records (seconds)"
  type        = number
  default     = 300
}

variable "dockerhub-creds-secret" {
  description = "An existing secret name in the same GCP project storing the Dockerhub credentials (username:password)"
  type        = string
  default     = ""
}

variable "debug_flag" {
    type        = bool
    description = "Enable debugging resources such as IAP Firewall rules, and export of config files"
    default     = false
}

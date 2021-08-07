################### Deployment Details ##########################

variable "instance_ext_domain" {
    type = string
    description = "External domain purchased for the Gitlab instance"
}

variable "gitlab_instance_protocol" {
    type = string
    description = "Protocol to use for Gitlab instance http / https"
}

variable "gitlab_initial_root_pwd_secret" {
    type = string
    description = "Secret name that stores the initial password for the Gitlab instance"
}


variable "gitlab_api_token_secret" {
    type = string
    description = "Secret name that stores the API token for the Gitlab instance"
}

variable "gitlab_runner_registration_token_secret" {
    type = string
    description = "Secret name that stores the runner registration token"
}

variable "gitlab_cert_key_secret" {
    type = string
    description = "Secret name that stores the private key for generating the certificate"
}

variable "gitlab_cert_public_secret" {
    type = string
    description = "Secret name that stores the instnace public certificate chain"
}




variable "infra_name" {
    type        = string
    description = "Infrastructure name or Team name"
}


variable "startup_script" {
    type    = string
    description = "Gitlab installation startup script"
    default = "scripts/bash/gitlab_install.sh"
}


#################### Location and network ######################


variable "region" {
    type        = string
    # GCE - Google Compute Engine
    description = "Region in which Gitlab GCE and Cluster will be deployed"
}

variable "zone" {
    type        = string
    description = "Zone in which Gitlab GCE will be deployed"
}

variable "network_tags" {
    type        = list(string)
    description = "Network tags for Gitlab instance"
}

variable "operator_ips" {
    type        = list(string)
    description = "IP addresses used to operate Gitlab"
}

variable "operator_ports" {
    type        = list(string)
    description = "Ports used to operate Gitlab"
    default     = ["443"]
}


variable "subnetwork" {
    type = string
    description = "Subnetwork ID on which GCE will be hosted"
}




################ Instance size and image ####################



variable "plans" {
  type = map
  default = {
    "2x8" = "n1-standard-2" #(56.72$, 0.097118$)
  }
}

variable "size" {
    type = string
    default = "2x8"
}


variable "machinetype" {
    type        = string
    description = "GCE machine type"
    default     = "n1-standard-2"
}

variable "osimages" {
  type = map
  default = {
    "ubuntu" = "ubuntu-1804-bionic-v20200916"
  }
}

variable "osimage" {
  type = string
  description = "(optional) OS Image"
  default = "ubuntu"
}





############ Cloud Storage #############


variable "gcs_prefix" {
    type = string
    description = "GCS hosting setup files"
}

variable "cicd_utils_bucket_name" {
    type = string
    description = "Bucket name that stores CI-CD utilities"
}


########## IAM ############


variable "serviceAccountEmail" {
    type = string
    description = "Service account's Email to attach to the instance"
}

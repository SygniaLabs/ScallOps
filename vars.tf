#### Variables ####

# Deployment wide variables
variable "project_id" {
    type        = string
    description = "GCP Project ID to deploy to"
}

variable "infra_name" {
    type        = string
    description = "Infrastructure name or Team name" 
    validation {
        condition     = can(regex("^[a-z]([-a-z0-9]*[a-z0-9])$", var.infra_name))  // Due to Certificate SAN, and service account name translation to email, and 1 another.
        error_message = "The infrastructure name must comply with the following regex [a-z]([-a-z0-9]*[a-z0-9])."  
    }
}


# Gitlab instance related variables
variable "instance_ext_domain" {
    type        = string
    description = "External domain for the Gitlab instance" //Doesn't affect the deploynment yet
    default     = "gitlab.local"  // Don't leave it empty. Certificate creation will be failed without errors!
}


variable "gitlab_instance_protocol" {
    type        = string
    description = "Protocol to use for Gitlab instance http / https"
    default     = "https"
    validation {
        condition     = can(regex("^https?$", var.gitlab_instance_protocol))
        error_message = "The gitlab_instance_protocol can be either http/https."
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


variable "osimages" {
  type       = map
  default    = {
        "ubuntu" = "ubuntu-1804-bionic-v20200916"
  }
}

variable "osimage" {
  type        = string
  description = "(optional) OS Image"
  default     = "ubuntu"
}


# Networking and region related variables

variable "operator_ips" {
    type        = list(string)
    description = "IP addresses used to operate and access Gitlab"
}

variable "operator_ports" {
    type        = list(string)
    description = "Ports used to operate Gitlab"
    default     = ["443","80"]
}


variable "region" {
    type        = string
    description = "Region in which Gitlab and K8s will be deployed"
    default     = "us-central1"
}

variable "zone" {
    type        = string
    description = "Zone in which Gitlab GCE and K8s cluster will be deployed, K8s cluster will be Zonal and not Regional."
    default     = "a"
}






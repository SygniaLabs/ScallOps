terraform {
  required_version = ">=1.5.0"
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">=4.77.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.10.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.5.1"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 3.3.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 4.44.0"
    }
  }
}
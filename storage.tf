# CICD utilities Storage

resource "random_string" "deployment_utils_bucket_suffix" {
  length           = 4
  special          = false
  lower            = true
  upper            = false
}

resource "google_storage_bucket" "deployment_utils" {
  name                        = "${var.infra_name}-utils-${random_string.deployment_utils_bucket_suffix.result}"
  location                    = "US"
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  provider                    = google.offensive-pipeline
}


resource "google_storage_bucket_object" "disable_windows_defender_ps" {
  name   = "scripts/Powershell/disabledefender.ps1"
  bucket = google_storage_bucket.deployment_utils.name
  source = "${path.module}/scripts/Powershell/disabledefender.ps1"
}


resource "google_storage_bucket_object" "gitlab_install_script" {
  name   = "scripts/bash/gitlab_install.sh"
  bucket = google_storage_bucket.deployment_utils.name
  source = "${path.module}/scripts/bash/gitlab_install.sh"
}
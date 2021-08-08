# CICD utilities Storage

resource "google_storage_bucket" "cicd_utils" {
  name                        = "${var.infra_name}-cicd-utils"
  location                    = "US"
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  provider                    = google.offensive-pipeline
}

resource "google_storage_bucket_object" "disable_windows_defender_ps" {
  name   = "scripts/Powershell/disabledefender.ps1"
  bucket = google_storage_bucket.cicd_utils.name
  source = "scripts/Powershell/disabledefender.ps1"
}

resource "google_storage_bucket_object" "gitlab_runner_helper_exe" {
  name   = "bins/gitlab-runner-helper.exe"
  bucket = google_storage_bucket.cicd_utils.name
  source = "gitlab-runner/bins/gitlab-runner-helper.exe"
}


# Gitlab instance deploy storage

resource "google_storage_bucket" "gitlab_deploy_utils" {
  name                        = "${var.infra_name}-gitlab-deploy-utils"
  location                    = "US"
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  provider                    = google.offensive-pipeline
}

resource "google_storage_bucket_object" "gitlab_install_script" {
  name   = "scripts/bash/gitlab_install.sh"
  bucket = google_storage_bucket.gitlab_deploy_utils.name
  source = "scripts/bash/gitlab_install.sh"
}
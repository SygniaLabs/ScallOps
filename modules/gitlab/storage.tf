# Gitlab instance deploy storage

resource "google_storage_bucket" "gitlab_deploy_utils" {
  name          = "${var.infra_name}-gitlab-deploy-utils"
  location      = "US"
  storage_class = "STANDARD"
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_object" "gitlab_install_script" {
  name   = "scripts/bash/gitlab_install.sh"
  bucket = google_storage_bucket.gitlab_deploy_utils.name
  source = "scripts/bash/gitlab_install.sh"
}



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

# Customized Gitlab backup script

resource "google_storage_bucket_object" "gitlab_backup_script" {
  name   = "scripts/bash/gitlab_backup.sh"
  bucket = google_storage_bucket.deployment_utils.name
  source = "${path.module}/scripts/bash/gitlab_backup.sh"
}

resource "google_storage_bucket_object" "gitlab_backup_script_exec" {
  name   = "scripts/bash/gitlab_backup_exec.sh"
  bucket = google_storage_bucket.deployment_utils.name
  source = "${path.module}/scripts/bash/gitlab_backup_exec.sh"
}

# Migration resource

resource "google_storage_bucket_object" "gitlab_migrate_script" {
  count  = var.migrate_gitlab ? 1 : 0
  name   = "scripts/bash/gitlab_migrate.sh"
  bucket = google_storage_bucket.deployment_utils.name
  source = "${path.module}/scripts/bash/gitlab_migrate.sh"
}


# Downloading in this way since state file won't support big files in resource attributes.
  resource "null_resource" "download_gitlab_backup" {
  count  = var.migrate_gitlab ? 1 : 0
  triggers = {
    gcs_backup_path = "gs://${var.migrate_gitlab_backup_bucket}/${var.migrate_gitlab_backup_path}"
  }
  provisioner "local-exec" {
    when    = create
    command = "gsutil cp gs://${var.migrate_gitlab_backup_bucket}/${var.migrate_gitlab_backup_path} ${path.module}/${var.migrate_gitlab_backup_path}"
  }
}

resource "google_storage_bucket_object" "gitlab_migrate_backup" {
  depends_on = [null_resource.download_gitlab_backup]
  count  = var.migrate_gitlab ? 1 : 0  
  name   = var.migrate_gitlab_backup_path
  bucket = google_storage_bucket.deployment_utils.name
  source = "${path.module}/${var.migrate_gitlab_backup_path}"
}

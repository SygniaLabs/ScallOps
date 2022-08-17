#### IAM svc accounts, roles and bindings ####

## Service Accounts ##

# Gitlab compute instance service account
resource "google_service_account" "gitlab_service_account" {
  account_id   = "${var.infra_name}-gitlab-svc"
  display_name = "Gitlab Service Account"
  provider     = google.offensive-pipeline
}

# GKE Container with storage.admin permission service account (Capability to push container images to GCR.IO)
resource "google_service_account" "gke_bucket_service_account" {
  account_id   = "${var.infra_name}-gke-buckt"
  display_name = "GKE Service Account for Pods to access buckets, push and pull containers"
  provider     = google.offensive-pipeline
}

## Roles ##

# Create role with permissions to backup only without read/overwrite/delete
resource "google_project_iam_custom_role" "backup_archive_role" {
  role_id     = "gitlab_backupArchive_${var.infra_name}"
  title       = "Gitlab Backup Role"
  description = "A role attached to the gitlab compute service account allowing it to update new backup archives to the specified bucket (var.backups_bucket_name)."
  permissions = [
                "storage.objects.list",
                "storage.objects.create",
                "storage.multipartUploads.create",
                "storage.multipartUploads.listParts",
                "storage.multipartUploads.abort"
                ]
  provider    = google.offensive-pipeline
}


# Role that allows startup script to remove itself from metadata
resource "google_project_iam_custom_role" "compute_metadata_role" {
  role_id     = "gitlab_setMetadata_${var.infra_name}"
  title       = "Set Metadata Custom"
  description = "A role attached to the gitlab compute instance allowing it to set compute metadata variables."
  permissions = ["compute.instances.get", "compute.instances.setMetadata"]
  provider    = google.offensive-pipeline
}


## Bindings ##

# Service account user role binding 
resource "google_project_iam_member" "sa_binding" {
  project  = var.project_id
  provider = google.offensive-pipeline
  role     = "roles/iam.serviceAccountUser"
  member   = "serviceAccount:${google_service_account.gitlab_service_account.email}"
}

# Gitlab instance IAM Binding to storage
resource "google_storage_bucket_iam_binding" "binding" {
  bucket  = google_storage_bucket.deployment_utils.name
  role    = "roles/storage.objectViewer" # To Read startup scripts on deployment utils bucket.
  members = [
    "serviceAccount:${google_service_account.gitlab_service_account.email}"
  ]
}


# Attach gitlab compute service account to the bucket with the backup role
resource "google_storage_bucket_iam_binding" "backup_bucket_binding" {
  bucket  = var.backups_bucket_name
  role    = google_project_iam_custom_role.backup_archive_role.name
  members = [
    "serviceAccount:${google_service_account.gitlab_service_account.email}"
  ]
}

# Bind the compute metadata role the the service account
resource "google_project_iam_binding" "compute_binding" {
  project  = var.project_id
  provider = google.offensive-pipeline
  role     = google_project_iam_custom_role.compute_metadata_role.name
  members  = [
    "serviceAccount:${google_service_account.gitlab_service_account.email}",
  ]
}


# Bind gcr.io storage admin to the container pusher service account
resource "google_storage_bucket_iam_member" "containeradmin_member" {
  bucket    = "artifacts.${var.project_id}.appspot.com"  # Default prefix-suffix for container registry bucket
  provider  = google.offensive-pipeline
  role      = "roles/storage.admin"
  member    = "serviceAccount:${google_service_account.gke_bucket_service_account.email}"
}

resource "google_service_account_key" "storage_admin_role" {
  service_account_id = google_service_account.gke_bucket_service_account.name
}


# IAM Bindings for Gitlab instance to secrets
resource "google_secret_manager_secret_iam_binding" "gitlab-self-key-binding" {
  project    = google_secret_manager_secret.gitlab-self-signed-cert-key.project
  secret_id  = google_secret_manager_secret.gitlab-self-signed-cert-key.secret_id
  role       = "roles/secretmanager.secretAccessor"
  members    = [
    "serviceAccount:${google_service_account.gitlab_service_account.email}",
  ]
}

resource "google_secret_manager_secret_iam_binding" "gitlab-self-crt-binding" {
  project    = google_secret_manager_secret.gitlab-self-signed-cert-crt.project
  secret_id  = google_secret_manager_secret.gitlab-self-signed-cert-crt.secret_id
  role       = "roles/secretmanager.secretAccessor"
  members    = [
    "serviceAccount:${google_service_account.gitlab_service_account.email}",
  ]
}


resource "google_secret_manager_secret_iam_binding" "gitlab_runner_registration_token" {
  project    = google_secret_manager_secret.gitlab_runner_registration_token.project
  secret_id  = google_secret_manager_secret.gitlab_runner_registration_token.secret_id
  role       = "roles/secretmanager.secretAccessor"
  members    = [
    "serviceAccount:${google_service_account.gitlab_service_account.email}",
  ]
}


resource "google_secret_manager_secret_iam_binding" "gitlab_initial_root_pwd" {
  project    = google_secret_manager_secret.gitlab_initial_root_pwd.project
  secret_id  = google_secret_manager_secret.gitlab_initial_root_pwd.secret_id
  role       = "roles/secretmanager.secretAccessor"
  members    = [
    "serviceAccount:${google_service_account.gitlab_service_account.email}",
  ]
}


resource "google_secret_manager_secret_iam_binding" "gitlab_backup_key" {
  project    = google_secret_manager_secret.gitlab_backup_key.project
  secret_id  = google_secret_manager_secret.gitlab_backup_key.secret_id
  role       = "roles/secretmanager.secretAccessor"
  members    = [
    "serviceAccount:${google_service_account.gitlab_service_account.email}",
  ]
}
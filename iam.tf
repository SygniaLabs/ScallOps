#### IAM svc accounts, roles and keys ####

# Gitlab compute instance service account
resource "google_service_account" "gitlab_service_account" {
  account_id   = "${var.infra_name}-gitlab-svc"
  display_name = "Gitlab Service Account"
  project      = var.project_id
}

# Gitlab instance IAM Binding to storage
resource "google_storage_bucket_iam_binding" "binding" {
  bucket  = google_storage_bucket.gitlab_deploy_utils.name
  role    = "roles/storage.objectViewer"
  members = [
    "serviceAccount:${google_service_account.gitlab_service_account.email}"
  ]
}

# GKE Container with storage.admin permission service account (Capability to push container images to GCR.IO)
resource "google_service_account" "gke_bucket_service_account" {
  account_id   = "${var.infra_name}-gke-buckt"
  display_name = "GKE Service Account for Pods to access buckets, push and pull containers"
  project      = var.project_id
}

resource "google_project_iam_member" "storage_admin_role" {
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.gke_bucket_service_account.email}"
  project = var.project_id
}

resource "google_service_account_key" "storage_admin_role" {
  service_account_id = google_service_account.gke_bucket_service_account.name
}


#IAM Bindings for Gitlab instance to secrets
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

resource "google_secret_manager_secret_iam_binding" "gitlab_api_token" {
  project    = google_secret_manager_secret.gitlab_api_token.project
  secret_id  = google_secret_manager_secret.gitlab_api_token.secret_id
  role       = "roles/secretmanager.secretAccessor"
  members    = [
    "serviceAccount:${google_service_account.gitlab_service_account.email}",
  ]
}
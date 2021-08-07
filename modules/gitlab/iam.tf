# IAM Bindings to storage
resource "google_storage_bucket_iam_binding" "binding" {
  bucket = google_storage_bucket.gitlab_deploy_utils.name
  role = "roles/storage.objectViewer"
  members = [
    "serviceAccount:${var.serviceAccountEmail}"
  ]
}
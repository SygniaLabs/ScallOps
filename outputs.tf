#Deployment outputs

output "gitlab_ext_ip" {
  description = "Gitlab's external IP address."
  value       = google_compute_instance.gitlab.network_interface.0.access_config.0.nat_ip
}

output "gitlab_root_password_secret" {
  description = "Secret name where Gitlab (Web UI) root account's password is stored"
  value       = google_secret_manager_secret.gitlab_initial_root_pwd.secret_id
}

output "gitlab_api_access_secret" {
  description = "Secret Name where Gitlab API access key stored, and need to be set at Gitlab Instance level"
  value       = google_secret_manager_secret.gitlab_api_token.secret_id
}
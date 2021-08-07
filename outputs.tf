#Deployment outputs

output "gitlab_ext_ip" {
  description = "Gitlab's external IP address."
  value = module.gitlab.gitlab-NAT-IP
}


output "gitlab_root_password_secret" {
  description = "Gitlab web application root's password secret name"
  value = google_secret_manager_secret.gitlab_initial_root_pwd.secret_id
}

#Gitlab Instance variables to be set:

output "gcp_project_id" {
  description = "GCP Project ID to be set at Gitlab Instance"
  value = var.project_id
}

output "gitlab_api_access_secret" {
  description = "Secret Name where Gitlab API access key stored, and need to be set at Gitlab Instance level"
  value = google_secret_manager_secret.gitlab_api_token.secret_id
}






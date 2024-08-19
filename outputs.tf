#Deployment outputs

output "gitlab_ext_ip" {
  description = "Gitlab's external IP address."
  value       = google_compute_instance.gitlab.network_interface.0.access_config.0.nat_ip
}

output "lb_ext_ip" {
  description = "Load balancer external IP address."
  value       = google_compute_global_forwarding_rule.lb_forward_rule.ip_address
}

output "gitlab_root_password_secret" {
  description = "Secret name where Gitlab (Web UI) root account's password is stored"
  value       = google_secret_manager_secret.gitlab_initial_root_pwd.secret_id
}
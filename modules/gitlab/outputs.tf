output "gitlab-NAT-IP" {
  description = "Gitlab's External IP address"
  value = google_compute_instance.gitlab.network_interface.0.access_config.0.nat_ip
}

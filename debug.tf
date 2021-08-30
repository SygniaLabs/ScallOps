### Debugging resources ####

# Firewall rules

/*
# Identity Aware Proxy (IAP)
# IAP is GCP feature used to connect to GCE over SSH with browser
# TODO: add debug flag, to deploy or not IAP
resource "google_compute_firewall" "iap_pipeline" {
  name       = "${var.infra_name}-allow-iap"
  network    = module.gcp-network.network_name
  provider   = google.offensive-pipeline
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["${var.infra_name}-gitlab"]
}
*/

# FW rule for connecting to linux nodes
# resource "google_compute_firewall" "ssh_linux_nodes" {
#   name       = "gke-${var.infra_name}-debug-linux-nodes"
#   network    = module.gcp-network.network_name
#   provider   = google.offensive-pipeline
#   allow {
#     protocol = "tcp"
#     ports    = ["22"]
#   }

#   source_ranges = var.operator_ips
#   target_tags   = ["gke-${var.infra_name}-offensive-pipeline-gke-linux-pool"]
# }

# FW rule for connecting to windows nodes
# resource "google_compute_firewall" "rdp_windows_nodes" {
#   name       = "gke-${var.infra_name}-debug-windows-nodes"
#   network    = module.gcp-network.network_name
#   provider   = google.offensive-pipeline
#   allow {
#     protocol = "tcp"
#     ports    = ["3389"]
#   }

#   source_ranges = var.operator_ips
#   target_tags   = ["gke-${var.infra_name}-offensive-pipeline-gke-windows-pool"]
# }

# DEBUG: Save Gitlab Server certificate.
/*
resource "local_file" "tls_key_pem_file" {
  content     = tls_private_key.gitlab-self-signed-cert-key.private_key_pem
  filename    = "${path.module}/gitlab.local.key"
}
resource "local_file" "tls_cert_pem_file" {
  content     = tls_self_signed_cert.gitlab-self-signed-cert.cert_pem
  filename    = "${path.module}/gitlab.local.crt"
}
*/


# DEBUG: Save kube config file
/*
resource "local_file" "kubeconfig" {
  content  = module.gke_auth.kubeconfig_raw
  filename = "${path.module}/kubeconfig"
}
*/
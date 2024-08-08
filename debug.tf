### Debugging resources ####

# Identity Aware Proxy (IAP)
# IAP is GCP feature used to connect to GCE over SSH/RDP with browser or IAP Desktop
# Adding FW rule for connecting to linux nodes, windows nodes and Gitlab instance via IAP
resource "google_compute_firewall" "iap_pipeline" {
  count      = var.debug_flag ? 1 : 0 
  name       = "${var.infra_name}-allow-iap"
  network    = module.gcp-network.network_name
  provider   = google.offensive-pipeline
  allow {
    protocol = "tcp"
    ports    = ["22","3389"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = [
                  local.gitlab_instance_name,
                  local.gke_linux_pool_tag,
                  local.gke_win_pool_tag
                  ]
}

# DEBUG: Save Gitlab Server certificate.
resource "local_file" "tls_key_pem_file" {
  count       = var.debug_flag ? 1 : 0 
  content     = tls_private_key.gitlab-self-signed-cert-key.private_key_pem
  filename    = "${path.module}/gitlab.local.key"
}
resource "local_file" "tls_cert_pem_file" {
  count       = var.debug_flag ? 1 : 0   
  content     = tls_self_signed_cert.gitlab-self-signed-cert.cert_pem
  filename    = "${path.module}/gitlab.local.crt"
}

# DEBUG: Save kube config file

module "gke_auth" {
  count        = var.debug_flag ? 1 : 0 
  source       = "terraform-google-modules/kubernetes-engine/google//modules/auth"
  project_id   = var.project_id
  cluster_name = module.gke.name
  location     = module.gke.location
}

resource "local_file" "kubeconfig" {
  depends_on   = [module.gke_auth]
  count        = var.debug_flag ? 1 : 0 
  content      = module.gke_auth[0].kubeconfig_raw
  filename     = "${path.module}/kubeconfig"
}

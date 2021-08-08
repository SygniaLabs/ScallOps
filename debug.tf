### Debugging resources ####


# Firewall rules

/*
# Identity Aware Proxy (IAP)
# IAP is GCP feature used to connect to GCE over SSH with browser
# TODO: add debug flag, to deploy or not IAP
resource "google_compute_firewall" "iap_pipeline" {
  name       = "${var.infra_name}-allow-iap"
  network    = "${var.infra_name}-offensive-pipeline-vpc"
  provider   = google.offensive-pipeline
  depends_on = [module.gcp-network]
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["${var.infra_name}-gitlab"]
}
*/



# DEBUG: Save Gitlab Server certificate.
/*
resource "local_file" "tls_key_pem_file" {
  depends_on  = [tls_private_key.gitlab-self-signed-cert-key]
  content     = tls_private_key.gitlab-self-signed-cert-key.private_key_pem
  filename    = "${path.module}/gitlab.local.key"
}
resource "local_file" "tls_cert_pem_file" {
  depends_on  = [tls_self_signed_cert.gitlab-self-signed-cert]
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
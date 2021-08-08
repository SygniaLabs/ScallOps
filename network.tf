#### Networking ####


# VPC and subnets

module "gcp-network" {
  source       = "terraform-google-modules/network/google"
  project_id   = var.project_id
  network_name = "${var.infra_name}-offensive-pipeline-vpc"

  subnets = [
    {
      subnet_name   = "${var.infra_name}-offensive-pipeline-subnet"
      subnet_ip     = "${local.vpc_main_subnet}"
      subnet_region = var.region
    },
  ]

  secondary_ranges = {
    ("${var.infra_name}-offensive-pipeline-subnet") = [
      {
        range_name    = "${var.infra_name}-gke-pods-subnet"
        ip_cidr_range = "${local.gke_pod_subnet}"
      },
      {
        range_name    = "${var.infra_name}-gke-service-subnet"
        ip_cidr_range = "${local.gke_svc_subnet}"
      }
    ]
  }
}



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



# Operators access rule
resource "google_compute_firewall" "operators" {
  depends_on    = [module.gcp-network]
  name          = "${var.infra_name}-operators-access"
  network       = "${var.infra_name}-offensive-pipeline-vpc"
  provider      = google.offensive-pipeline
  source_ranges = var.operator_ips
  target_tags   = ["${var.infra_name}-gitlab"]
  
  allow {
    protocol = "tcp"
    ports    = var.operator_ports
  }
}


# Rule allowing internal access from K8s' Pods to Gitlab
resource "google_compute_firewall" "pods-to-gitlab-access" {
  depends_on    = [module.gcp-network]
  name          = "${var.infra_name}-gke-pods-gitlab-access"
  network       = "${var.infra_name}-offensive-pipeline-vpc"
  provider      = google.offensive-pipeline
  source_ranges = [local.gke_pod_subnet]
  target_tags   = ["${var.infra_name}-gitlab"]

  allow {
    protocol = "tcp"
    ports    = var.operator_ports
  }
}
# Networking


module "gcp-network" {
  source       = "terraform-google-modules/network/google"
  #version      = "~> 3.1"
  project_id   = var.project_id
  network_name = "${var.infra_name}-offensive-pipeline-vpc"

  subnets = [
    {
      subnet_name   = "${var.infra_name}-offensive-pipeline-subnet"
      subnet_ip     = "10.0.0.0/22" # 10.0.0.0 - 10.0.3.255 , 1024 IPs
      subnet_region = var.region
    },
  ]

  secondary_ranges = {
    ("${var.infra_name}-offensive-pipeline-subnet") = [
      {
        range_name    = "${var.infra_name}-gke-pods-subnet"
        ip_cidr_range = "10.2.0.0/17" # 10.2.0.0 - 10.2.127.255 - 32,768 IPs for pods allowing 32K concurrent jobs.
      },
      {
        range_name    = "${var.infra_name}-gke-service-subnet"
        ip_cidr_range = "10.2.128.0/20" # 10.2.128.0 - 10.2.143.255 - 4096 IPs.
      },
    ]
  }
}



# Firewall rules

/*

# Identity Aware Proxy (IAP)
# IAP is GCP feature used to connect to GCE over SSH with browser
# TODO: add debug flag, to deploy or not IAP
resource "google_compute_firewall" "iap_pipeline" {
  name    = "${var.infra_name}-allow-iap"
  network = "${var.infra_name}-offensive-pipeline-vpc"
  provider = google.offensive-pipeline
  depends_on = [
    module.gcp-network
  ]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["${var.infra_name}-gitlab"]
}


# Add let's encrypt certificate validation access
# TODO: If possible find let's encrypt IPs
resource "google_compute_firewall" "letsencrypt-allow" {
  name    = "${var.infra_name}-allow-letsencrypt"
  network = "${var.infra_name}-offensive-pipeline-vpc"
  provider = google.offensive-pipeline
  depends_on = [
    module.gcp-network
  ]

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
  #Assuming let's encrypt IPs (https://www.robtex.com/dns-lookup/letsencrypt.org) , May modify to 0.0.0.0/0 if not working in the future
  source_ranges = ["0.0.0.0"]
  target_tags   = ["${var.infra_name}-gitlab"]
}
*/



# Operators access
resource "google_compute_firewall" "operators" {
  name    = "${var.infra_name}-operators-access"
  network = "${var.infra_name}-offensive-pipeline-vpc"
  provider = google.offensive-pipeline
  depends_on = [
    module.gcp-network
  ]

  allow {
    protocol = "tcp"
    ports    = var.operator_ports
  }

  source_ranges = var.operator_ips
  target_tags   = ["${var.infra_name}-gitlab"]
}

# K8s Pods access to Gitlab internally
resource "google_compute_firewall" "pods-to-gitlab-access" {
  name    = "${var.infra_name}-gke-pods-gitlab-access"
  network = "${var.infra_name}-offensive-pipeline-vpc"
  provider = google.offensive-pipeline
  depends_on = [
    module.gcp-network
  ]
  allow {
    protocol = "tcp"
    ports    = ["80","443"]
  }
  source_ranges = ["10.2.0.0/17"]
  target_tags   = ["${var.infra_name}-gitlab"]
}
# VPC and subnets

module "gcp-network" {
  source       = "terraform-google-modules/network/google"
  project_id   = var.project_id
  network_name = "${var.infra_name}-offensive-pipeline-vpc"

  subnets = [
    {
      subnet_name   = "${var.infra_name}-offensive-pipeline-subnet"
      subnet_ip     = local.vpc_main_subnet
      subnet_region = var.region
    }
  ]

  secondary_ranges = {
    ("${var.infra_name}-offensive-pipeline-subnet") = [
      {
        range_name    = "${var.infra_name}-gke-pods-subnet"
        ip_cidr_range = local.gke_pod_subnet
      },
      {
        range_name    = "${var.infra_name}-gke-service-subnet"
        ip_cidr_range = local.gke_svc_subnet
      }
    ]
  }
}


# Operators access rule
resource "google_compute_firewall" "operators" {
  name          = "${var.infra_name}-operators-access"
  network       = module.gcp-network.network_name
  provider      = google.offensive-pipeline
  source_ranges = var.operator_ips
  target_tags   = [local.gitlab_instance_name]
  
  allow {
    protocol = "tcp"
    ports    = var.operator_ports
  }
}


# Rule allowing internal access from K8s' Pods to Gitlab
resource "google_compute_firewall" "pods-to-gitlab-access" {
  name          = "${var.infra_name}-gke-pods-gitlab-access"
  network       = module.gcp-network.network_name
  provider      = google.offensive-pipeline
  source_ranges = [local.gke_pod_subnet]
  target_tags   = [local.gitlab_instance_name]

  allow {
    protocol = "tcp"
    ports    = var.operator_ports
  }
}



# DNS Record

resource "google_dns_record_set" "ext-dns" {
  provider     = google.dns_infra
  count        = var.external_hostname != "" ? 1 : 0
  name         = "${var.external_hostname}."
  type         = "A"
  ttl          = var.dns_record_ttl
  managed_zone = var.dns_managed_zone_name
  rrdatas      = [google_compute_global_forwarding_rule.lb_forward_rule.ip_address]
}


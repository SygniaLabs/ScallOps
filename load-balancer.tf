resource "google_compute_managed_ssl_certificate" "lb_proxy_ssl_cert" {
  provider  = google.offensive-pipeline
  count     = var.external_hostname != "" ? 1 : 0
  name      = "${local.gitlab_instance_name}-ssl-cert"
  managed {
    domains = [var.external_hostname]
  }
}

resource "google_compute_health_check" "gitlab_service_hc" {
  provider            = google.offensive-pipeline
  name                = "${local.gitlab_instance_name}-backend-hc"
  timeout_sec         = 5
  check_interval_sec  = 30
  healthy_threshold   = 1
  unhealthy_threshold = 3

  dynamic "http_health_check" {
    for_each = var.gitlab_instance_protocol == "http" ? [1] : []
    content {
      port_name          = "http"
      port_specification = "USE_NAMED_PORT"
      request_path       = "/robots.txt"
      proxy_header       = "NONE"
    }
  }

  dynamic "https_health_check" {
    for_each = var.gitlab_instance_protocol == "https" ? [1] : []
    content {
      port_name          = "https"
      port_specification = "USE_NAMED_PORT"
      request_path       = "/robots.txt"
      proxy_header       = "NONE"
    }
  }

}

resource "google_compute_security_policy" "lb_allow_operators_policy" {
  provider  = google.offensive-pipeline
  name      = "${local.gitlab_instance_name}-backend-allowed-ips"



  rule {
    action      = "allow"
    priority    = "1000"
    description = "Allow specific IPs"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = var.operator_ips
      }
    }
    
  }

  # Conditionally create rule for external integration address ranges
  dynamic "rule" {
    for_each = var.external_integration_ranges != null ? [1] : []
    content {
      action      = "allow"
      priority    = 1001
      description = "External Integration IP addresses"

      match {
        versioned_expr = "SRC_IPS_V1"
        config {
          src_ip_ranges = var.external_integration_ranges
        }
      }
    }
  }


  rule {
    action      = "deny(502)"
    priority    = "2147483647"
    description = "Default rule deny all addresses"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    
  }
}

resource "google_compute_backend_service" "gitlab_instance_service" {
  provider       = google.offensive-pipeline
  name           = "${local.gitlab_instance_name}-backend"
  port_name      = var.gitlab_instance_protocol
  protocol       = upper(var.gitlab_instance_protocol)
  timeout_sec    = 10
  security_policy = google_compute_security_policy.lb_allow_operators_policy.self_link
  backend {
    group = google_compute_instance_group.gitlab_instance.self_link
  }
  health_checks = [
    google_compute_health_check.gitlab_service_hc.self_link,
  ]
}

resource "google_compute_url_map" "service_url_map" {
  provider        = google.offensive-pipeline
  name            = "${local.gitlab_instance_name}-urlmap"
  default_service = google_compute_backend_service.gitlab_instance_service.self_link
}

resource "google_compute_target_https_proxy" "lb_https_proxy" {
  provider         = google.offensive-pipeline
  name             = "${local.gitlab_instance_name}-https-proxy"
  url_map          = google_compute_url_map.service_url_map.self_link
  ssl_certificates = (
        var.external_hostname != "" ?
        [google_compute_managed_ssl_certificate.lb_proxy_ssl_cert.0.self_link] : []
        )      
}

resource "google_compute_global_forwarding_rule" "lb_forward_rule" {
  provider   = google.offensive-pipeline
  name       = "${local.gitlab_instance_name}-fwd-rule"
  target     = google_compute_target_https_proxy.lb_https_proxy.self_link
  port_range = "443"
}

# https://cloud.google.com/load-balancing/docs/firewall-rules
resource "google_compute_firewall" "allow_lb_gitlab_access" {
  provider      = google.offensive-pipeline
  name          = "${local.gitlab_instance_name}-allow-lb"
  network       = module.gcp-network.network_name
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = google_compute_instance.gitlab.tags
  allow {
    protocol = "tcp"
    ports    = var.operator_ports
  }
}
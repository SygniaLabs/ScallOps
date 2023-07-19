########################### GKE Cluster #################################################


## K8s secrets and namespaces
resource "kubernetes_secret" "google-application-credentials" {
  data        = {
    "kaniko-token-secret.json" = base64decode(google_service_account_key.artifact_registry_writer.private_key)
  }
  metadata {
    name      = "kaniko-secret"
    namespace = kubernetes_namespace.sensitive-namespace.id
  }
}

resource "kubernetes_secret" "k8s_gitlab_cert_secret-sensitive" {
  data        = {
    "${local.instance_internal_domain}.crt" = tls_self_signed_cert.gitlab-self-signed-cert.cert_pem
  }
  metadata {
    name      = "${local.instance_internal_domain}-cert"
    namespace = kubernetes_namespace.sensitive-namespace.id
  }
}

resource "kubernetes_secret" "dockerhub-creds-config" {
  count       = var.dockerhub-creds-secret != "" ? 1 : 0  
  data        = {
    ".dockerconfigjson" =  jsonencode({
                auths = {
                        "https://index.docker.io/v1/" = {
                            auth = "${base64encode("${data.google_secret_manager_secret_version.dockerhub-secret[0].secret_data}")}"
                    }
                }
    })
  }
  type        = "kubernetes.io/dockerconfigjson"
  metadata {
    name      = "dockerhub-creds-jsonconfig"
    namespace = kubernetes_namespace.sensitive-namespace.id
  }
}


resource "kubernetes_namespace" "sensitive-namespace" {
  depends_on    = [module.gke.google_container_node_pool]
  metadata {
    annotations = {name = "Store Kaniko and Dockerhub creds secrets and their related pod runners"}
    name        = "sensitive"
  }
}

resource "kubernetes_secret" "k8s_gitlab_cert_secret" {
  depends_on  = [module.gke.google_container_node_pool]
  data        = {
    "${local.instance_internal_domain}.crt" = tls_self_signed_cert.gitlab-self-signed-cert.cert_pem
  }
  metadata {
    name      = "${local.instance_internal_domain}-cert"
    namespace = "default"
  }
}


# Pod disruption budget

resource "kubernetes_pod_disruption_budget_v1" "kube-dns" {
  depends_on  = [module.gke.google_container_node_pool]
  metadata {
    name      = "k8s-pdb-kube-dns"
    namespace = "kube-system"
  }
  spec {
    max_unavailable = 1
    selector {
      match_labels = {
        k8s-app = "kube-dns"
      }
    }
  }
}


resource "kubernetes_pod_disruption_budget_v1" "konnectivity-agent" {
  depends_on  = [module.gke.google_container_node_pool]
  metadata {
    name      = "k8s-pdb-konnectivity-agent"
    namespace = "kube-system"
  }
  spec {
    max_unavailable = "50%"
    selector {
      match_labels = {
        k8s-app = "konnectivity-agent"
      }
    }
  }
}


## K8s cluster

module "gke" {
  source                     = "terraform-google-modules/kubernetes-engine/google"
  version                    = "26.1.1" # https://github.com/terraform-google-modules/terraform-google-kubernetes-engine
  kubernetes_version         = var.gke_version
  project_id                 = var.project_id
  name                       = "${var.infra_name}-offensive-pipeline"
  regional                   = false
  region                     = var.region #Required if Regional true
  zones                      = ["${var.region}-${var.zone}"]
  network                    = module.gcp-network.network_name
  subnetwork                 = module.gcp-network.subnets_names[0]
  default_max_pods_per_node  = 30
  ip_range_pods              = "${var.infra_name}-gke-pods-subnet"
  ip_range_services          = "${var.infra_name}-gke-service-subnet"
  http_load_balancing        = false
  horizontal_pod_autoscaling = true
  network_policy             = false
# remove_default_node_pool   = true
  initial_node_count         = 1
  create_service_account     = true
  grant_registry_access      = true

  node_pools = [
    {
      name                   = "linux-pool"
      version                = var.gke_linux_pool_version
      machine_type           = "e2-highcpu-2"
      min_count              = 1
      max_count              = 8
      local_ssd_count        = 0
      disk_size_gb           = 100
      disk_type              = "pd-ssd"
      image_type             = "COS_CONTAINERD"
      enable_gcfs            = true
      auto_repair            = true
      auto_upgrade           = true
      spot                   = true
      initial_node_count     = 1
    }     
  ] 

  node_pools_oauth_scopes = {
    linux-pool          = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  node_pools_labels = {
    all          = {}
  }
  node_pools_metadata = {
    all = {
      disable-legacy-endpoints = true
    }
  }
  node_pools_taints = {
    all          = []
  }
  node_pools_tags = {
    linux-pool = [local.gke_linux_pool_tag]
  }
}



## K8s windows node pool

resource "google_container_node_pool" "windows-pool" {
  cluster             = module.gke.cluster_id
  initial_node_count  = 1
  location            = "${var.region}-${var.zone}"
  max_pods_per_node   = 8
  name                = "windows-pool"
  #node_count          = 0
  node_locations      = ["${var.region}-${var.zone}"]
  provider            = google.offensive-pipeline
  version             = var.gke_windows_pool_version
  autoscaling {
      max_node_count = 8
      min_node_count = 1 # at least 1 required since Gitlab K8s runner for windows has issue with scaling-up from 0->1 nodes as node-pool label cant contain the windows build version
    }

  management {
      auto_repair  = true
      auto_upgrade = false
    }

  node_config {
      disk_size_gb      = 200
      disk_type         = "pd-ssd"
      guest_accelerator = []
      image_type        = "windows_ltsc_containerd"
      labels            = {
          "cluster_name" = module.gke.name
          "node_pool"    = "windows-pool"
        }
      local_ssd_count   = 0
      machine_type      = "t2d-standard-4"
      metadata          = {
          "cluster_name"               = module.gke.name
          "disable-legacy-endpoints"   = "true"
          "node_pool"                  = "windows-pool"
          "windows"                    = "true"
          "windows-startup-script-url" = local.gke_win_pool_start_script
        }
      oauth_scopes      = ["https://www.googleapis.com/auth/cloud-platform"]
      preemptible       = true
      service_account   = module.gke.service_account
      tags              = [local.gke_win_pool_tag]
      taint             = [
          {
              effect = "PREFER_NO_SCHEDULE"
              key    = "node.kubernetes.io/os"
              value  = "windows"
            },
          {
              effect = "NO_SCHEDULE"
              key    = "node.kubernetes.io/os"
              value  = "windows"
            }
          ]

      shielded_instance_config {
        enable_integrity_monitoring = true
        enable_secure_boot          = false
        }

      workload_metadata_config {
        mode          = "GKE_METADATA"
        }
    }

  timeouts {
    create = "45m"
    delete = "45m"
    update = "45m"
    }

  upgrade_settings {
    max_surge       = 2
    max_unavailable = 0
    }
}


### Artifact Registry Repository ###

resource "google_artifact_registry_repository" "containers" {
  location      = var.region
  repository_id = local.artifact_registry_id
  description   = "Container repository created by terraform for ${var.infra_name}"
  format        = "DOCKER"
  provider      = google.offensive-pipeline  
}
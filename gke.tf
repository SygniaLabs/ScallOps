########################### GKE Cluster #################################################


## K8s secrets and namespaces

resource "kubernetes_secret" "k8s_gitlab_cert_secret" {
  depends_on  = [module.gke_auth, module.gke]
  data        = {
    "${local.instance_internal_domain}.crt" = tls_self_signed_cert.gitlab-self-signed-cert.cert_pem
  }
  metadata {
    name      = "${local.instance_internal_domain}-cert"
    namespace = "default"
  }
}


resource "kubernetes_namespace" "sensitive-namespace" {
  depends_on  = [module.gke_auth, module.gke]
  metadata {
    annotations = {name = "Store Kaniko secret and pod runner"}
    name = "sensitive"
  }
}

resource "kubernetes_secret" "google-application-credentials" {
  depends_on  = [module.gke_auth, module.gke, kubernetes_namespace.sensitive-namespace]
  data        = {
    "kaniko-token-secret.json" = base64decode(google_service_account_key.storage_admin_role.private_key)
  }
  metadata {
    name      = "kaniko-secret"
    namespace = "sensitive"
  }
}

resource "kubernetes_secret" "k8s_gitlab_cert_secret-sensitive" {
  depends_on  = [module.gke_auth, module.gke, kubernetes_namespace.sensitive-namespace]
  data        = {
    "${local.instance_internal_domain}.crt" = tls_self_signed_cert.gitlab-self-signed-cert.cert_pem
  }
  metadata {
    name      = "${local.instance_internal_domain}-cert"
    namespace = "sensitive"
  }
}

resource "kubernetes_secret" "dockerhub-creds-config" {
  depends_on  = [module.gke_auth, module.gke, kubernetes_namespace.sensitive-namespace]
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
    namespace = "sensitive"
  }
}


## K8s auth

module "gke_auth" {
  depends_on   = [module.gcp-network]
  source       = "terraform-google-modules/kubernetes-engine/google//modules/auth"
  project_id   = var.project_id
  cluster_name = module.gke.name
  location     = module.gke.location
}


## K8s cluster

module "gke" {
  depends_on                 = [google_compute_instance.gitlab]
  source                     = "terraform-google-modules/kubernetes-engine/google"
  version                    = "17.3.0"
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
#  initial_node_count         = 1
  create_service_account     = true
  grant_registry_access      = true
  

  node_pools = [
    {
      name                   = "linux-pool"
      machine_type           = "e2-highcpu-2"
      min_count              = 1
      max_count              = 8
      local_ssd_count        = 0
      disk_size_gb           = 100
      disk_type              = "pd-standard"
      image_type             = "UBUNTU" // 20.04
      auto_repair            = false
      auto_upgrade           = false
      preemptible            = false
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
    all = []
  }
}


## K8s windows node pool

resource "google_container_node_pool" "windows-pool" {
  cluster             = module.gke.cluster_id
  initial_node_count  = 1
  location            = "${var.region}-${var.zone}"
  max_pods_per_node   = 10
  name                = "windows-pool"
  #node_count          = 0
  node_locations      = ["${var.region}-${var.zone}"]
  provider            = google.offensive-pipeline
  version             = "1.20.9-gke.1001" #Make upgrades from here.
  autoscaling {
      max_node_count = 8
      min_node_count = 1 # at least 1 required since Gitlab K8s runner for windows has issue with scaling-up from 0->1 nodes as node-pool label cant contain the windows build version
    }

  management {
      auto_repair  = false
      auto_upgrade = false
    }

  node_config {
      disk_size_gb      = 200
      disk_type         = "pd-standard"
      guest_accelerator = []
      image_type        = "WINDOWS_LTSC"
      labels            = {
          "cluster_name" = module.gke.name
          "node_pool"    = "windows-pool"
        }
      local_ssd_count   = 0
      machine_type      = "n1-standard-2"
      metadata          = {
          "cluster_name"               = module.gke.name
          "disable-legacy-endpoints"   = "true"
          "node_pool"                  = "windows-pool"
          "windows"                    = "true"
          "windows-startup-script-url" = join("", [
                                              "gs://", google_storage_bucket.deployment_utils.name,
                                              "/",
                                              google_storage_bucket_object.disable_windows_defender_ps.name
                                              ])
        }
      oauth_scopes      = ["https://www.googleapis.com/auth/cloud-platform"]
      preemptible       = false
      service_account   = module.gke.service_account
      tags              = [
                           join("", ["gke-", var.infra_name, "-offensive-pipeline"]), 
                           join("", ["gke-", var.infra_name, "-offensive-pipeline-windows-pool"])

          ]
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
        node_metadata = "GKE_METADATA_SERVER"
        }
    }

  timeouts {
    create = "45m"
    delete = "45m"
    update = "45m"
    }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
    }
}

resource "kubernetes_pod_disruption_budget" "kube-dns" {
  depends_on  = [module.gke]
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


resource "kubernetes_pod_disruption_budget" "konnectivity-agent" {
  depends_on  = [module.gke]
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



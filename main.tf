########################### Gitlab Instance #################################################

resource "google_compute_instance" "gitlab" {
  depends_on   = [
                  module.gcp-network,
                  google_secret_manager_secret_version.gitlab-self-signed-cert-crt-version,
                  google_secret_manager_secret_version.gitlab-self-signed-cert-key-version,
                  google_secret_manager_secret_version.gitlab_initial_root_pwd,
                  google_secret_manager_secret_version.gitlab_runner_registration_token,
                  google_secret_manager_secret_version.gitlab_api_token
                  ]
  provider     = google.offensive-pipeline
  name         = "${var.infra_name}-gitlab"
  machine_type = var.plans[var.size]
  zone         = "${var.region}-${var.zone}"
  tags         = ["${var.infra_name}-gitlab"]


    service_account {
      email  = google_service_account.gitlab_service_account.email
      scopes = ["cloud-platform"]
    }
  
    boot_disk {
      initialize_params {
        image = var.osimages[var.osimage]
        size  = "100"
        type  = "pd-standard"
      }
    }

    network_interface {
      subnetwork = "${var.infra_name}-offensive-pipeline-subnet"
      access_config {}
    }


  metadata = {
    gcs-prefix                      = "gs://${google_storage_bucket.gitlab_deploy_utils.name}"
    startup-script-url              = join("", [
                                                "gs://", google_storage_bucket.gitlab_deploy_utils.name,
                                                "/",
                                                google_storage_bucket_object.gitlab_install_script.name
                                                ])
    cicd-utils-bucket-name          = google_storage_bucket.cicd_utils.name
    instance-ext-domain             = local.instance_internal_domain
    instance-protocol               = var.gitlab_instance_protocol
	  gitlab-initial-root-pwd-secret	= google_secret_manager_secret.gitlab_initial_root_pwd.secret_id
    gitlab-api-token-secret         = google_secret_manager_secret.gitlab_api_token.secret_id
    gitlab-cert-key-secret         	= google_secret_manager_secret.gitlab-self-signed-cert-key.secret_id
    gitlab-cert-public-secret	      = google_secret_manager_secret.gitlab-self-signed-cert-crt.secret_id
    gitlab-ci-runner-registration-token-secret = google_secret_manager_secret.gitlab_runner_registration_token.secret_id
  }
}




################################ Helm chart deployments ##############################


resource "helm_release" "gitlab-runner-linux" {
  depends_on = [
                module.gke,
                module.gke_auth
                ]
  name       = "linux"
  # repository = "https://charts.gitlab.io/gitlab"
  chart      = "https://gitlab.com/gitlab-org/charts/gitlab-runner/-/archive/v0.32.0/gitlab-runner-v0.32.0.tar.gz"
  
  values     = [
    file("gitlab-runner/linux-values.yaml")
    ]

  set {
    name  = "gitlabUrl"
    value =  "${var.gitlab_instance_protocol}://${local.instance_internal_domain}"
  }
  set {
    name  = "cloneUrl"
    value =  "${var.gitlab_instance_protocol}://${local.instance_internal_domain}"
  }
  set {
    name  = "certsSecretName"
    value = "${local.instance_internal_domain}-cert"
  }
  set_sensitive {
    name  = "runnerRegistrationToken"
    value = random_password.gitlab_runner_registration_token.result
  }
}


resource "helm_release" "gitlab-runner-win" {
  depends_on = [
                module.gke,
                module.gke_auth
                ]
  name       = "windows"
  # repository = "https://charts.gitlab.io"
  chart      = "https://gitlab.com/gitlab-org/charts/gitlab-runner/-/archive/v0.32.0/gitlab-runner-v0.32.0.tar.gz"
  
  values     = [
    file("gitlab-runner/win-values.yaml")
    ]

  set {
    name  = "gitlabUrl"
    value = "${var.gitlab_instance_protocol}://${local.instance_internal_domain}"
  }
  set {
    name  = "cloneUrl"
    value = "${var.gitlab_instance_protocol}://${local.instance_internal_domain}"
  }
  set {
    name  = "certsSecretName"
    value = "${local.instance_internal_domain}-cert"
  }
  set_sensitive {
    name  = "runnerRegistrationToken"
    value = random_password.gitlab_runner_registration_token.result
  }
}

########################### GKE Cluster #################################################


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


resource "kubernetes_secret" "google-application-credentials" {
  depends_on  = [module.gke_auth, module.gke]
  data        = {
    "kaniko-token-secret.json" = base64decode(google_service_account_key.storage_admin_role.private_key)
  }
  metadata {
    name      = "kaniko-secret"
    namespace = "default"
  }
}


module "gke_auth" {
  depends_on   = [module.gcp-network]
  source       = "terraform-google-modules/kubernetes-engine/google//modules/auth"
  project_id   = var.project_id
  cluster_name = module.gke.name
  location     = module.gke.location
}

module "gke" {
  depends_on                 = [module.gcp-network, google_compute_instance.gitlab]
  source                     = "terraform-google-modules/kubernetes-engine/google"
  version                    = "15.0.0"
  project_id                 = var.project_id
  name                       = "${var.infra_name}-offensive-pipeline-gke"
  regional                   = false
  region                     = var.region #Required if Regional true
  zones                      = ["${var.region}-${var.zone}"]
  network                    = module.gcp-network.network_name
  subnetwork                 = "${var.infra_name}-offensive-pipeline-subnet"
  default_max_pods_per_node  = 80
  ip_range_pods              = "${var.infra_name}-gke-pods-subnet"
  ip_range_services          = "${var.infra_name}-gke-service-subnet"
  http_load_balancing        = false
  horizontal_pod_autoscaling = true
  network_policy             = false
  remove_default_node_pool   = false
  initial_node_count         = 1


  node_pools = [
    {
      name                   = "linux-pool"
      machine_type           = "e2-medium"
      min_count              = 0
      max_count              = 8
      local_ssd_count        = 0
      disk_size_gb           = 100
      disk_type              = "pd-standard"
      image_type             = "UBUNTU" // 20.04
      auto_repair            = false
      auto_upgrade           = false
      service_account        = ""
      preemptible            = false
      initial_node_count     = 0
    },
    {
      name                   = "windows-pool"
      machine_type           = "n1-standard-2"
      min_count              = 1
      max_count              = 8
      local_ssd_count        = 0
      disk_size_gb           = 200
      disk_type              = "pd-standard"
      image_type             = "WINDOWS_LTSC" // 1809
      auto_repair            = false
      auto_upgrade           = false
      service_account        = ""
      preemptible            = false
      initial_node_count     = 1
    }    
  ] 

  node_pools_oauth_scopes = {
    all          = []
    windows-pool = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  node_pools_labels = {
    all          = {}
    windows-pool = {windows = true}
  }

  node_pools_metadata = {
    all = {
      disable-legacy-endpoints = true
    }

    windows-pool = {
      windows                    = true,
      windows-startup-script-url =  join("", [
                                              "gs://", google_storage_bucket.cicd_utils.name,
                                              "/",
                                              google_storage_bucket_object.disable_windows_defender_ps.name
                                              ])
    }
  }

  node_pools_taints = {
    all          = []
    windows-pool = [
        {
            key    = "node.kubernetes.io/os"
            value  = "windows"
            effect = "PREFER_NO_SCHEDULE"
        }
    ]
  }

  node_pools_tags = {
    all = []
  }
}
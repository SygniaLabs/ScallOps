############################# Gitlab instance ###############################################


# Self signed TLS certificate generation

resource "tls_private_key" "gitlab-self-signed-cert-key" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

resource "tls_self_signed_cert" "gitlab-self-signed-cert" {
  depends_on = [tls_private_key.gitlab-self-signed-cert-key]
  key_algorithm   = "ECDSA"
  private_key_pem = tls_private_key.gitlab-self-signed-cert-key.private_key_pem

  subject {
    common_name  = "gitlab.local"
    organization = "Company"
  }
  dns_names = ["${var.infra_name}-gitlab.local", local.instance_internal_domain, var.instance_ext_domain]
  ip_addresses = ["10.0.0.2"]
  validity_period_hours = 87600 //Certificate will be valid for 10 years 

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
  ]
}





# DEBUG: Save Gitlab Server certificate.
/*
resource "local_file" "tls_key_pem_file" {
  depends_on = [tls_private_key.gitlab-self-signed-cert-key]
  content  = tls_private_key.gitlab-self-signed-cert-key.private_key_pem
  filename = "${path.module}/gitlab.local.key"
}
resource "local_file" "tls_cert_pem_file" {
  depends_on = [tls_self_signed_cert.gitlab-self-signed-cert]
  content  = tls_self_signed_cert.gitlab-self-signed-cert.cert_pem
  filename = "${path.module}/gitlab.local.crt"
}
*/



module "gitlab" {
  source      = "./modules/gitlab"
  infra_name	= var.infra_name
  instance_ext_domain = local.instance_internal_domain
  gitlab_instance_protocol = var.gitlab_instance_protocol
  cicd_utils_bucket_name = google_storage_bucket.cicd_utils.name
  #Gitlab Instance Secrets and service account 
  gitlab_initial_root_pwd_secret = google_secret_manager_secret.gitlab_initial_root_pwd.secret_id
  gitlab_api_token_secret = google_secret_manager_secret.gitlab_api_token.secret_id
  gitlab_runner_registration_token_secret = google_secret_manager_secret.gitlab_runner_registration_token.secret_id
  gitlab_cert_key_secret	= google_secret_manager_secret.gitlab-self-signed-cert-key.secret_id
  gitlab_cert_public_secret	= google_secret_manager_secret.gitlab-self-signed-cert-crt.secret_id
  serviceAccountEmail = google_service_account.gitlab_service_account.email
  #Network
  network_tags = ["${var.infra_name}-gitlab"]
  subnetwork = "${var.infra_name}-offensive-pipeline-subnet"
  region = var.region
  zone = var.zone
  operator_ips = var.operator_ips
  #Storage
  gcs_prefix  = "gs://${var.infra_name}-pipeline-deploy-utils"
  #Deploymetn dependencies
  depends_on = [
    module.gcp-network,
    google_secret_manager_secret_version.gitlab-self-signed-cert-crt-version,
    google_secret_manager_secret_version.gitlab-self-signed-cert-key-version,
    google_service_account.gitlab_service_account,
    google_secret_manager_secret_version.gitlab_initial_root_pwd,
    google_secret_manager_secret_version.gitlab_runner_registration_token,
    google_secret_manager_secret_version.gitlab_api_token
  ]
  providers = {google = google.offensive-pipeline}
}




########################### GKE Cluster #################################################


module "gke" {
  source                     = "terraform-google-modules/kubernetes-engine/google"
  version                    = "15.0.0"
  project_id                 = var.project_id
  name                       = "${var.infra_name}-offensive-pipeline-gke"
  regional                   = false
  region                     = var.region #Required if Regional true
  zones                      = [join("", [var.region, "-", var.zone])]
  network                    = "${var.infra_name}-offensive-pipeline-vpc"
  subnetwork                 = "${var.infra_name}-offensive-pipeline-subnet"
  default_max_pods_per_node = 80
  depends_on = [
  module.gcp-network,
  google_service_account.gke_bucket_service_account,
  google_project_iam_member.storage_admin_role
  ]
  ip_range_pods              = "${var.infra_name}-gke-pods-subnet"
  ip_range_services          = "${var.infra_name}-gke-service-subnet"
  http_load_balancing        = false
  horizontal_pod_autoscaling = true
  network_policy             = false
  remove_default_node_pool = false
  initial_node_count = 1


  node_pools = [
    {
      name                      = "linux-pool"
      machine_type              = "e2-medium"
      min_count                 = 0
      max_count                 = 8
      local_ssd_count           = 0
      disk_size_gb              = 100
      disk_type                 = "pd-standard"
      image_type                = "UBUNTU" // 20.04
      auto_repair               = false
      auto_upgrade              = false
      service_account           = ""
      preemptible               = false
      initial_node_count        = 0
    },
    {
      name                      = "windows-pool"
      machine_type              = "n1-standard-2"
      min_count                 = 0
      max_count                 = 8
      local_ssd_count           = 0
      disk_size_gb              = 200
      disk_type                 = "pd-standard"
      image_type                = "WINDOWS_LTSC" // 1809
      auto_repair               = false
      auto_upgrade              = false
      service_account           = ""
      preemptible               = false
      initial_node_count        = 0
    }    
  ] 

  node_pools_oauth_scopes = {
    all = []
    windows-pool = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  node_pools_labels = {
    all = {}

    windows-pool = {windows = true}
  }

  node_pools_metadata = {
    all = {
      disable-legacy-endpoints = true
    }

    windows-pool = {
      windows = true,
      windows-startup-script-url =  join("", ["gs://", google_storage_bucket.cicd_utils.name, "/", google_storage_bucket_object.disable_windows_defender_ps.name])
  }
  }

  node_pools_taints = {
    all = []
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

resource "kubernetes_secret" "k8s_gitlab_cert_secret" {
  depends_on = [tls_self_signed_cert.gitlab-self-signed-cert]
  data = {
    join("", [local.instance_internal_domain, ".crt"]) = tls_self_signed_cert.gitlab-self-signed-cert.cert_pem
  }
  metadata {
    name = join("", [local.instance_internal_domain, "-cert"])
    namespace = "default"
  }
}


resource "kubernetes_secret" "google-application-credentials" {
  depends_on = [google_service_account_key.storage_admin_role]
  data = {
    "kaniko-token-secret.json" = base64decode(google_service_account_key.storage_admin_role.private_key)
  }
  metadata {
    name = "kaniko-secret"
    namespace = "default"
  }
}


module "gke_auth" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/auth"
  project_id   = var.project_id
  cluster_name = module.gke.name
  location     = module.gke.location
  depends_on = [
    module.gcp-network
  ]
}


/* DEBUG: Save kube config file
resource "local_file" "kubeconfig" {
  content  = module.gke_auth.kubeconfig_raw
  filename = "${path.module}/kubeconfig"
}

*/


################################ Helm chart deployments ##############################


resource "helm_release" "gitlab-runner-linux" {
    depends_on = [
    module.gcp-network,
    module.gke,
    module.gitlab
  ]
  name       = "linux"
  chart      = "./gitlab-runner_0.27"
  # Remote chart required variables:
  # repository = "https://charts.gitlab.io"
  # version    = "0.27.0"

values = [file("linux-values.yaml")]

  set {
    name  = "gitlabUrl"
    value =  join("", [var.gitlab_instance_protocol, "://", local.instance_internal_domain]) 
  }
  set {
    name  = "cloneUrl"
    value =  join("", [var.gitlab_instance_protocol, "://", local.instance_internal_domain]) 
  }
  set {
    name  = "certsSecretName"
    value =  join("", [local.instance_internal_domain, "-cert"]) 
  }
  set_sensitive {
    name  = "runnerRegistrationToken"
    value = random_password.gitlab_runner_registration_token.result
  }

}


resource "helm_release" "gitlab-runner-win" {
    depends_on = [
    module.gcp-network,
    module.gke,
    module.gitlab,
    helm_release.gitlab-runner-linux
  ]
  name       = "windows"
  chart      = "./gitlab-runner_0.27"
 # Remote chart required variables:
 # repository = "https://charts.gitlab.io"
 # version    = "0.27.0"

values = [file("win-values.yaml")]

  set {
    name  = "gitlabUrl"
    value =  join("", [var.gitlab_instance_protocol, "://", local.instance_internal_domain]) 
  }
  set {
    name  = "cloneUrl"
    value =  join("", [var.gitlab_instance_protocol, "://", local.instance_internal_domain]) 
  }
  set {
    name  = "certsSecretName"
    value =  join("", [local.instance_internal_domain, "-cert"]) 
  }

  set_sensitive {
    name  = "runnerRegistrationToken"
    value = random_password.gitlab_runner_registration_token.result
  }

}




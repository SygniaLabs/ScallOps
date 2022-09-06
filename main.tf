########################### Gitlab Instance #################################################

resource "google_compute_instance" "gitlab" {
  depends_on   = [
                  google_secret_manager_secret_version.gitlab-self-signed-cert-crt-version,
                  google_secret_manager_secret_version.gitlab-self-signed-cert-key-version,
                  google_secret_manager_secret_version.gitlab_initial_root_pwd,
                  google_secret_manager_secret_version.gitlab_runner_registration_token,
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
      subnetwork = module.gcp-network.subnets_self_links[0]
      access_config {}
    }


  metadata = {
    gcs-prefix                                 = "gs://${google_storage_bucket.deployment_utils.name}"
    # Migrate vars Start #
    migrated-gitlab-backup-password            = var.migrate_gitlab ? var.migrate_gitlab_backup_password : ""
    gcs-path-to-backup                         = var.migrate_gitlab ? local.gitlab_migrate_backup : ""
    migrated-gitlab-version                    = var.migrate_gitlab ? var.migrate_gitlab_version : ""
    # Migrate vars End #
    startup-script-url                         = var.migrate_gitlab ? local.gitlab_migrate_script : local.gitlab_install_script
    instance-external-domain                   = var.external_hostname != "" ? var.external_hostname : local.instance_internal_domain
    instance-protocol                          = var.gitlab_instance_protocol
    gitlab-initial-root-pwd-secret             = google_secret_manager_secret.gitlab_initial_root_pwd.secret_id
    gitlab-cert-key-secret                     = google_secret_manager_secret.gitlab-self-signed-cert-key.secret_id
    gitlab-cert-public-secret	                 = google_secret_manager_secret.gitlab-self-signed-cert-crt.secret_id
    gitlab-ci-runner-registration-token-secret = google_secret_manager_secret.gitlab_runner_registration_token.secret_id
    gitlab-backup-key-secret                   = google_secret_manager_secret.gitlab_backup_key.secret_id
    gitlab-backup-bucket-name                  = var.backups_bucket_name
    gitlab-version                             = var.gitlab_version
  }
lifecycle {
    ignore_changes = [
        metadata,
    ]
  }

}





################################ Helm chart deployments ##############################


resource "helm_release" "gitlab-runner-linux" {
  depends_on = [
                module.gke,
                module.gke_auth
                ]
  name       = "linux"
  wait       = false
  chart      = var.runner_chart_url
  
  values     = [
    file("${path.module}/gitlab-runner/linux-values.yaml")
    ]
 
  set {
    name  = "gitlabUrl"
    value =  "${var.gitlab_instance_protocol}://${local.instance_internal_domain}"
  }
  set {
    name  = "runners.cloneUrl"
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


resource "helm_release" "gitlab-runner-kaniko" {
  depends_on = [
                module.gke,
                module.gke_auth,
                kubernetes_namespace.sensitive-namespace
                ]
  name       = "kaniko"
  wait       = false
  namespace  = "sensitive"
  chart      = var.runner_chart_url
  
  values     = [
    file("${path.module}/gitlab-runner/kaniko-values.yaml")
    ]

  set {
    name  = "gitlabUrl"
    value =  "${var.gitlab_instance_protocol}://${local.instance_internal_domain}"
  }
  set {
    name  = "runners.cloneUrl"
    value =  "${var.gitlab_instance_protocol}://${local.instance_internal_domain}"
  }
  set {
    name  = "certsSecretName"
    value = "${local.instance_internal_domain}-cert"
  }
  set_sensitive {
    name  = "runnerRegistrationToken"
    value = "GR1348941${random_password.gitlab_runner_registration_token.result}-scallops-recipes"
  }
}

resource "helm_release" "gitlab-runner-dockerhub" {
  count  = var.dockerhub-creds-secret != "" ? 1 : 0  
  depends_on = [
                module.gke,
                module.gke_auth,
                kubernetes_namespace.sensitive-namespace
                ]
  name       = "dockerhub-privates"
  wait       = false
  namespace  = "sensitive"
  chart      = var.runner_chart_url
  
  values     = [
    file("${path.module}/gitlab-runner/dockerhub-values.yaml")
    ]

  set {
    name  = "gitlabUrl"
    value =  "${var.gitlab_instance_protocol}://${local.instance_internal_domain}"
  }
  set {
    name  = "runners.cloneUrl"
    value =  "${var.gitlab_instance_protocol}://${local.instance_internal_domain}"
  }
  set {
    name  = "certsSecretName"
    value = "${local.instance_internal_domain}-cert"
  }
  set {
    name  = "runners.imagePullSecrets[0]"
    value = kubernetes_secret.dockerhub-creds-config[0].metadata[0].name
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
  wait       = false
  chart      = var.runner_chart_url
  
  values     = [
    file("${path.module}/gitlab-runner/win-values.yaml")
    ]

  set {
    name  = "gitlabUrl"
    value = "${var.gitlab_instance_protocol}://${local.instance_internal_domain}"
  }
  set {
    name  = "runners.cloneUrl"
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

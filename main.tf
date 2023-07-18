########################### Gitlab Instance #################################################

resource "google_compute_instance" "gitlab" {
  depends_on   = [
                  # If migrating we have to wait for the backup to upload
                  null_resource.transfer_gitlab_backup[0],
                  # Need to wait for the secrets' values to take place in the secrets objects
                  google_secret_manager_secret_version.gitlab-self-signed-cert-crt-version,
                  google_secret_manager_secret_version.gitlab-self-signed-cert-key-version,
                  google_secret_manager_secret_version.gitlab_initial_root_pwd,
                  google_secret_manager_secret_version.gitlab_runner_registration_token,
                  # Compute instance doesn't wait for any binding related to the service account to complete. These are required for the startup scripts
                  google_storage_bucket_iam_binding.binding,
                  google_project_iam_binding.compute_binding,
                  google_storage_bucket_iam_binding.backup_bucket_binding,
                  google_secret_manager_secret_iam_binding.gitlab-self-key-binding,
                  google_secret_manager_secret_iam_binding.gitlab-self-crt-binding,
                  google_secret_manager_secret_iam_binding.gitlab_runner_registration_token,
                  google_secret_manager_secret_iam_binding.gitlab_initial_root_pwd,
                  google_secret_manager_secret_iam_member.gitlab_backup_key,
                  google_secret_manager_secret_iam_member.git_creds
                  ]
  provider     = google.offensive-pipeline
  name         = local.gitlab_instance_name
  machine_type = var.plans[var.size]
  zone         = "${var.region}-${var.zone}"
  tags         = [local.gitlab_instance_name]



    service_account {
      email  = google_service_account.gitlab_service_account.email
      scopes = ["cloud-platform"]
    }
  
    boot_disk {
      initialize_params {
        image = var.os_images[var.os_name][var.os_release]
        size  = "160"
        type  = "pd-ssd"
      }
    }

    network_interface {
      subnetwork = module.gcp-network.subnets_self_links[0]
      access_config {}
    }


  metadata = {
    gcs-prefix                                 = "gs://${google_storage_bucket.deployment_utils.name}"
    gcs-path-to-backup                         = var.migrate_gitlab ? local.gitlab_migrate_backup : "NONE" # Migration var    
    startup-script-url                         = local.gitlab_startup_script
    instance-external-domain                   = var.external_hostname != "" ? var.external_hostname : local.instance_internal_domain
    instance-protocol                          = var.gitlab_instance_protocol
    gitlab-initial-root-pwd-secret             = google_secret_manager_secret.gitlab_initial_root_pwd.secret_id
    gitlab-cert-key-secret                     = google_secret_manager_secret.gitlab-self-signed-cert-key.secret_id
    gitlab-cert-public-secret	                 = google_secret_manager_secret.gitlab-self-signed-cert-crt.secret_id
    gitlab-ci-runner-registration-token-secret = google_secret_manager_secret.gitlab_runner_registration_token.secret_id
    gitlab-backup-key-secret                   = var.gitlab_backup_key_secret_id
    gitlab-backup-bucket-name                  = var.backups_bucket_name
    target-gitlab-version                      = var.gitlab_version
    gitlab-package-dl-link                     = local.gitlab_package_dl_link
    container-registry-host                    = local.gke_registry_host
    container-registry-namespace               = local.gke_registry_namespace
    scallops-recipes-git-url                   = var.scallops_recipes_git_url
    scallops-recipes-git-creds-secret          = var.scallops_recipes_git_creds_secret != "" ? var.scallops_recipes_git_creds_secret : "NONE"
  }
}





################################ Helm chart deployments ##############################


resource "helm_release" "gitlab-runner-linux" {
  depends_on = [module.gke.google_container_node_pool]
  name       = "linux"
  wait       = false
  chart      = var.runner_chart_url
  
  values     = [
    file("${path.module}/gitlab-runner/linux-values.yaml")
    ]
 
  set {
    name  = "gitlabUrl"
    value =  local.instance_internal_url
  }
  set {
    name  = "certsSecretName"
    value = "${local.instance_internal_domain}-cert"
  }
  set_sensitive {
    name  = "runnerRegistrationToken"
    value = random_password.gitlab_runner_registration_token.result
  }
  set {
    name  = "sessionServer.enabled"
    value = "true"
  }
  set {
    name  = "sessionServer.timeout"
    value = 1800
  }
  set {
    name  = "sessionServer.loadBalancerSourceRanges[0]"
    value = "${google_compute_instance.gitlab.network_interface.0.access_config.0.nat_ip}/32"
  }
  set {
    name  = "runners.config"
    value = <<EOF
    [[runners]]
      executor = "kubernetes"
      limit = 50
      shell = "bash"
      ${format("clone_url = '%s'", "${local.instance_internal_url}")}
      [runners.kubernetes.node_selector]
        "node_pool" = "linux-pool"
      [runners.kubernetes]
        namespace = "default"
        poll_interval = 3
        poll_timeout = 3600
    EOF
  }
  set {
    name  = "concurrent"
    value = 50
  }
}


resource "helm_release" "gitlab-runner-kaniko" {
  depends_on = [kubernetes_namespace.sensitive-namespace]
  name       = "kaniko"
  wait       = false
  namespace  = "sensitive"
  chart      = var.runner_chart_url
  
  values     = [
    file("${path.module}/gitlab-runner/kaniko-values.yaml")
    ]

  set {
    name  = "gitlabUrl"
    value =  local.instance_internal_url
  }
  set {
    name  = "certsSecretName"
    value = "${local.instance_internal_domain}-cert"
  }
  set_sensitive {
    name  = "runnerRegistrationToken"
    value = "GR1348941${random_password.gitlab_runner_registration_token.result}-scallops-recipes"
  }
  set {
    name  = "runners.config"
    value = <<EOF
    [[runners]]
      executor = "kubernetes"
      shell = "bash"
      ${format("clone_url = '%s'", "${local.instance_internal_url}")}
      
      [runners.kubernetes.node_selector]
        "node_pool" = "linux-pool"

      [runners.kubernetes]
        namespace = "sensitive"
        poll_interval = 30
        poll_timeout = 3600

        [[runners.kubernetes.volumes.secret]]
          name = "kaniko-secret"
          mount_path = "/secret"
          read_only = true        
    EOF
  }
}

resource "helm_release" "gitlab-runner-dockerhub" {
  count  = var.dockerhub-creds-secret != "" ? 1 : 0  
  depends_on = [kubernetes_namespace.sensitive-namespace]
  name       = "dockerhub-privates"
  wait       = false
  namespace  = "sensitive"
  chart      = var.runner_chart_url
  
  values     = [
    file("${path.module}/gitlab-runner/dockerhub-values.yaml")
    ]

  set {
    name  = "gitlabUrl"
    value =  local.instance_internal_url
  }
  set {
    name  = "certsSecretName"
    value = "${local.instance_internal_domain}-cert"
  }
  set_sensitive {
    name  = "runnerRegistrationToken"
    value = random_password.gitlab_runner_registration_token.result
  }
  set {
    name  = "runners.config"
    value = <<EOF
    [[runners]]
      executor = "kubernetes"
      shell = "bash"
      ${format("clone_url = '%s'", "${local.instance_internal_url}")}
      [runners.kubernetes.node_selector]
        "node_pool" = "linux-pool"
      [runners.kubernetes]
        namespace = "sensitive"
        poll_interval = 30
        poll_timeout = 3600
    EOF
  }   
}


resource "helm_release" "gitlab-runner-win" {
  depends_on = [module.gke.google_container_node_pool]
  name       = "windows"
  wait       = false
  chart      = var.runner_chart_url
  
  values     = [
    file("${path.module}/gitlab-runner/win-values.yaml")
    ]

  set {
    name  = "gitlabUrl"
    value = local.instance_internal_url
  }
  set {
    name  = "certsSecretName"
    value = "${local.instance_internal_domain}-cert"
  }
  set_sensitive {
    name  = "runnerRegistrationToken"
    value = random_password.gitlab_runner_registration_token.result
  }
  set {
    name  = "runners.config"
    value = <<EOF
    [[runners]]
      executor = "kubernetes"
      limit = 30
      shell = "pwsh"
      ${format("clone_url = '%s'", "${local.instance_internal_url}")}
      # The FF_USE_POWERSHELL_PATH_RESOLVER feature flag has to be enabled for PowerShell 
      # to resolve paths for Windows correctly when Runner is operating in a Linux environment
      # but targeting Windows nodes.
      environment = ["FF_USE_POWERSHELL_PATH_RESOLVER=1"]

      [runners.kubernetes.node_selector]
        "node_pool" = "windows-pool"   
        "kubernetes.io/arch" = "amd64"
        "kubernetes.io/os" = "windows"
        "node.kubernetes.io/windows-build" = "10.0.17763"

      [runners.kubernetes.node_tolerations]
        "node.kubernetes.io/os=windows" = "NoSchedule"

      [runners.kubernetes]
        namespace = "default"
        poll_interval = 10
        poll_timeout = 3600
    EOF
  }
  set {
    name  = "concurrent"
    value = 30
  }  
}

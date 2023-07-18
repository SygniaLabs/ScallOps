locals {
    gitlab_instance_name      = "${var.infra_name}-gitlab"
    instance_internal_domain  = "${local.gitlab_instance_name}.${var.region}-${var.zone}.c.${var.project_id}.internal"
    instance_internal_url     = "${var.gitlab_instance_protocol}://${local.instance_internal_domain}"
    gitlab_package_dl_link    = join("/", [
                                         "https://packages.gitlab.com/gitlab/gitlab-ee/packages",
                                         "${var.os_name}",
                                         "${var.os_release}",
                                         "gitlab-ee_${var.gitlab_version}.0_amd64.deb",
                                         "download.deb"
                                         ])
    vpc_main_subnet           = "10.0.0.0/22" # 10.0.0.0 - 10.0.3.255 , 1024 IPs
    gke_pod_subnet            = "10.2.0.0/17" # 10.2.0.0 - 10.2.127.255 - 32,768 IPs.
    gke_svc_subnet            = "10.2.128.0/20" # 10.2.128.0 - 10.2.143.255 - 4096 IPs.
    gke_registry_host         = "${var.region}-docker.pkg.dev"
    gke_registry_namespace    = "${var.project_id}/${var.infra_name}"    
    gke_linux_pool_tag        = "gke-${var.infra_name}-offensive-pipeline-gke-linux-pool"
    gke_win_pool_tag          = "gke-${var.infra_name}-offensive-pipeline-windows-pool"
    gke_win_pool_start_script = join("/", [
                                           "gs:/", 
                                           google_storage_bucket.deployment_utils.name,
                                           google_storage_bucket_object.disable_windows_defender_ps.name
                                           ])   

    gitlab_startup_script     = join("/", [
                                           "gs:/", 
                                           google_storage_bucket.deployment_utils.name,
                                           google_storage_bucket_object.gitlab_startup_script.name
                                           ])
    
    gitlab_migrate_backup     = var.migrate_gitlab ? join("/", [
                                                                "gs:/", 
                                                                google_storage_bucket.deployment_utils.name,
                                                                var.migrate_gitlab_backup_path
                                                               ]) : ""
}
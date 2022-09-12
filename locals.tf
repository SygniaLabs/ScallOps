locals {
    instance_internal_domain  = "${var.infra_name}-gitlab.${var.region}-${var.zone}.c.${var.project_id}.internal"
    vpc_main_subnet           = "10.0.0.0/22" # 10.0.0.0 - 10.0.3.255 , 1024 IPs
    gke_pod_subnet            = "10.2.0.0/17" # 10.2.0.0 - 10.2.127.255 - 32,768 IPs.
    gke_svc_subnet            = "10.2.128.0/20" # 10.2.128.0 - 10.2.143.255 - 4096 IPs.
    gke_win_pool_start_script = "gs://${google_storage_bucket.deployment_utils.name}/${google_storage_bucket_object.disable_windows_defender_ps.name}"
    gke_linux_pool_tag       = "gke-${var.infra_name}-offensive-pipeline-gke-linux-pool"
    gke_win_pool_tag         = "gke-${var.infra_name}-offensive-pipeline-windows-pool"
    gitlab_startup_script     = "gs://${google_storage_bucket.deployment_utils.name}/${google_storage_bucket_object.gitlab_startup_script.name}"
    gitlab_migrate_backup     = var.migrate_gitlab ? join("/", [
                                                                "gs:/", 
                                                                google_storage_bucket.deployment_utils.name,
                                                                var.migrate_gitlab_backup_path
                                                               ]) : ""
}
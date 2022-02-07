locals {
    instance_internal_domain  = "${var.infra_name}-gitlab.${var.region}-${var.zone}.c.${var.project_id}.internal"
    vpc_main_subnet           = "10.0.0.0/22" # 10.0.0.0 - 10.0.3.255 , 1024 IPs
    gke_pod_subnet            = "10.2.0.0/17" # 10.2.0.0 - 10.2.127.255 - 32,768 IPs.
    gke_svc_subnet            = "10.2.128.0/20" # 10.2.128.0 - 10.2.143.255 - 4096 IPs.
    gke_win_pool_start_script = "gs://${google_storage_bucket.deployment_utils.name}/${google_storage_bucket_object.disable_windows_defender_ps.name}"
    gke_win_pool_tags         = ["gke-${var.infra_name}-offensive-pipeline","gke-${var.infra_name}-offensive-pipeline-windows-pool"]
}
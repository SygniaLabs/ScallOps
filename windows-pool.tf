resource "google_container_node_pool" "windows-pool" {
  depends_on          = [module.gke,
                         helm_release.gitlab-runner-linux,
                         helm_release.gitlab-runner-win,
                         helm_release.gitlab-runner-kaniko
                         ]
  cluster             = module.gke.cluster_id
  initial_node_count  = 0
  location            = "${var.region}-${var.zone}"
  max_pods_per_node   = 10
  name                = "windows-pool"
  node_count          = 0
  node_locations      = ["${var.region}-${var.zone}"]
  project             = var.project_id
  version             = "1.21.6-gke.1500" #Make upgrades from here.
  autoscaling {
      max_node_count = 8
      min_node_count = 0
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
          "windows"      = "true"
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
            },
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
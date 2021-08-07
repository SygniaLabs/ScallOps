resource "google_compute_instance" "gitlab" {
  depends_on = [google_storage_bucket_object.gitlab_install_script]
  name         = "${var.infra_name}-gitlab"
  machine_type = var.plans[var.size]
  zone         = "${var.region}-${var.zone}"
  boot_disk {
    initialize_params {
      image = var.osimages[var.osimage]
      size  = "100"
      type  = "pd-standard"
    }
  }

  network_interface {
    subnetwork = var.subnetwork
    access_config {
    }
  }

  tags = var.network_tags




  metadata = {
    gcs-prefix                      = join("", ["gs://",google_storage_bucket.gitlab_deploy_utils.name])
    startup-script-url              = join("", ["gs://", google_storage_bucket.gitlab_deploy_utils.name, "/scripts/bash/gitlab_install.sh"])
    cicd-utils-bucket-name          = var.cicd_utils_bucket_name
    instance-ext-domain             = var.instance_ext_domain
    instance-protocol               = var.gitlab_instance_protocol
	  gitlab-initial-root-pwd-secret	= var.gitlab_initial_root_pwd_secret
    gitlab-api-token-secret         = var.gitlab_api_token_secret
    gitlab-ci-runner-registration-token-secret = var.gitlab_runner_registration_token_secret
    gitlab-cert-key-secret         	= var.gitlab_cert_key_secret
    gitlab-cert-public-secret	= var.gitlab_cert_public_secret

  }

  service_account {
    email = var.serviceAccountEmail
    scopes = ["cloud-platform"]
  }
}
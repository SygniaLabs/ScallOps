#### Secret creation and version manager ####


# Self signed TLS certificate generation

resource "tls_private_key" "gitlab-self-signed-cert-key" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

resource "tls_self_signed_cert" "gitlab-self-signed-cert" {
  private_key_pem       = tls_private_key.gitlab-self-signed-cert-key.private_key_pem

  subject {
    common_name         = "gitlab.local"
    organization        = "Company"
  }
  
  dns_names             = flatten([
                            "${local.gitlab_instance_name}.local",
                            local.instance_internal_domain,
                            var.external_hostname != "" ? [var.external_hostname] : []
                            ])
                           
  ip_addresses          = ["10.0.0.2"]
  validity_period_hours = 87600 //Certificate will be valid for 10 years 

  allowed_uses          = [
                           "key_encipherment",
                           "digital_signature"
                           ]
}


# Gitlab server certificate

resource "google_secret_manager_secret" "gitlab-self-signed-cert-key" {
  provider   = google.offensive-pipeline
  secret_id  = "${local.gitlab_instance_name}-cert-key"
  labels     = {
        label = "gitlab-cert"
  }
  replication {
    user_managed {
           replicas {
              location = var.region
      }
    }
  }
}


resource "google_secret_manager_secret_version" "gitlab-self-signed-cert-key-version" {
  secret      = google_secret_manager_secret.gitlab-self-signed-cert-key.id
  secret_data = tls_private_key.gitlab-self-signed-cert-key.private_key_pem
}


resource "google_secret_manager_secret" "gitlab-self-signed-cert-crt" {
  provider   = google.offensive-pipeline
  secret_id  = "${local.gitlab_instance_name}-cert-crt"
  labels     = {
          label = "gitlab-cert"
  }
  replication {
    user_managed {
          replicas {
            location = var.region
      }
    }
  }
}


resource "google_secret_manager_secret_version" "gitlab-self-signed-cert-crt-version" {
  secret      = google_secret_manager_secret.gitlab-self-signed-cert-crt.id
  secret_data = tls_self_signed_cert.gitlab-self-signed-cert.cert_pem
}



# Gitlab installation & deployment

resource "random_password" "gitlab_runner_registration_token" {
  length           = 20
  special          = true
  override_special = "-_"
}
resource "random_password" "gitlab_initial_root_pwd" {
  length           = 16
  special          = true
  override_special = "-_"
}


# Gitlab runner registration token

resource "google_secret_manager_secret" "gitlab_runner_registration_token" {
  provider   = google.offensive-pipeline
  secret_id  = "${local.gitlab_instance_name}-runner-reg"
  labels     = {
          label = "gitlab"
  }
  replication {
    user_managed {
          replicas {
            location = var.region
      }
    }
  }
}


resource "google_secret_manager_secret_version" "gitlab_runner_registration_token" {
  secret      = google_secret_manager_secret.gitlab_runner_registration_token.id
  secret_data = random_password.gitlab_runner_registration_token.result
}


# Gitlab initial root password
resource "google_secret_manager_secret" "gitlab_initial_root_pwd" {
  provider   = google.offensive-pipeline
  secret_id  = "${local.gitlab_instance_name}-root-password"
  labels     = {
          label = "gitlab"
  }
  replication {
    user_managed {
          replicas {
            location = var.region
      }
    }
  }
}


resource "google_secret_manager_secret_version" "gitlab_initial_root_pwd" {
  secret      = google_secret_manager_secret.gitlab_initial_root_pwd.id
  secret_data = random_password.gitlab_initial_root_pwd.result
}


# Docker hub credentials secret

data "google_secret_manager_secret_version" "dockerhub-secret" {
  provider  = google.offensive-pipeline
  count     = var.dockerhub-creds-secret != "" ? 1 : 0
  secret    = var.dockerhub-creds-secret
}
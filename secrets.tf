#### Secret creation and version manager ####


# Gitlab server certificate

resource "google_secret_manager_secret" "gitlab-self-signed-cert-key" {
  depends_on = [tls_self_signed_cert.gitlab-self-signed-cert]
  project    = var.project_id
  secret_id  = "${var.infra_name}-gitlab-cert-key"
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
  depends_on  = [google_secret_manager_secret.gitlab-self-signed-cert-key]
  secret      = google_secret_manager_secret.gitlab-self-signed-cert-key.id
  secret_data = tls_private_key.gitlab-self-signed-cert-key.private_key_pem
}


resource "google_secret_manager_secret" "gitlab-self-signed-cert-crt" {
  depends_on = [tls_self_signed_cert.gitlab-self-signed-cert]
  project    = var.project_id
  secret_id  = "${var.infra_name}-gitlab-cert-crt"
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
  depends_on  = [google_secret_manager_secret.gitlab-self-signed-cert-crt]
  secret      = google_secret_manager_secret.gitlab-self-signed-cert-crt.id
  secret_data = tls_self_signed_cert.gitlab-self-signed-cert.cert_pem
}



# Gitlab installation & deployment

resource "random_password" "gitlab_runner_registration_token" {
  length           = 16
  special          = true
  override_special = "-_"
}
resource "random_password" "gitlab_initial_root_pwd" {
  length           = 16
  special          = true
}

resource "random_password" "gitlab_api_token" {
  length           = 16
  special          = true
  override_special = "-_"
}


# Gitlab runner registration token

resource "google_secret_manager_secret" "gitlab_runner_registration_token" {
  depends_on = [random_password.gitlab_runner_registration_token]
  project    = var.project_id
  secret_id  = "${var.infra_name}-gitlab-runner-reg"
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
  depends_on  = [google_secret_manager_secret.gitlab_runner_registration_token]
  secret      = google_secret_manager_secret.gitlab_runner_registration_token.id
  secret_data = random_password.gitlab_runner_registration_token.result
}


# Gitlab initial root password
resource "google_secret_manager_secret" "gitlab_initial_root_pwd" {
  depends_on = [random_password.gitlab_initial_root_pwd]
  project    = var.project_id
  secret_id  = "${var.infra_name}-gitlab-root-password"
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
  depends_on  = [google_secret_manager_secret.gitlab_initial_root_pwd]
  secret      = google_secret_manager_secret.gitlab_initial_root_pwd.id
  secret_data = random_password.gitlab_initial_root_pwd.result
}


# Gitlab root account personal access token (API)

resource "google_secret_manager_secret" "gitlab_api_token" {
  depends_on = [random_password.gitlab_api_token]
  project    = var.project_id
  secret_id  = "${var.infra_name}-gitlab-api-token"
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


resource "google_secret_manager_secret_version" "gitlab_api_token" {
  depends_on  = [google_secret_manager_secret.gitlab_api_token]
  secret      = google_secret_manager_secret.gitlab_api_token.id
  secret_data = random_password.gitlab_api_token.result
}
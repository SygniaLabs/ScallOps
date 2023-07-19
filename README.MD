[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=plastic)](https://opensource.org/licenses/MIT)
![Terraform](https://img.shields.io/badge/Terraform-v1.5.0-8040c9.svg?style=plastic)
![Gitlab](https://img.shields.io/badge/Gitlab-v16.1.2-fd7e14.svg?style=plastic)
![GKE](https://img.shields.io/badge/GKE-1.26.5-1A73E8.svg?style=plastic)
![ScallOps](https://img.shields.io/badge/ScallOps-v0.5-000000.svg?style=plastic)

# SCALLOPS

## Overview

ScallOps is a framework that empowers Red Teams to put more focus on what they need to do, instead of how to do it. 
It utilizes the CI/CD concept to manage and automate the weaponization and deployment of offensive tools.

Security teams and individuals can develop, collaborate and utilize the framework's "Recipes" in order to perform their Red Team tasks with greater efficiency.

You can choose to deploy the framework's infrastructure using the Terraform scripts within this repository or use your own infrastructure.
Refer to the [ScallOps-Recipes](https://github.com/SygniaLabs/ScallOps-Recipes) repository to learn more about the infrasctrucure requirements.


<p align="center">
  <img src="./img/scallops.png" alt="ScallOps logo" width="" height="300">
</p>

## Infrastructure Features
* All Gitlab's CI/CD features for designning the Recipes.
* Linux & Windows based operating systems for running the Recipes weaponization jobs.
* On-demand automated node scalability (Google Kubernets Engine).
* Access to work with private container images from your Google Artifact Registry.
* Ability to supply Docker Hub credentials and work with private container images from your Docker Hub account.
* Capability to automatically build Dockerfiles and push the images to your Artifact Registry.
* Automated, weekly Gitlab backup to a desginated bucket.
* Attach external hostname to the framework using Google DNS managed zones.
* Ability to migrate from an older Gitlab instance or upgrade a deployed instance.

## Deployment

The infrastructure can be deployed to GCP using the provided Terraform scripts.
It is mainly built from a Gitlab instance that provides the CI features and a Kubernetes cluster that execute CI jobs on the relevant operating systems.
There is also a use of Cloud Container Registry to store customized container images that we may use during operating the framework.
Google Cloud Storage is in use to store maintenance scripts and encrypted Gitlab backups.

Automated deployment Pre-requisites:
* Google Cloud subscription with **OWNER** permissions on a project (It is reccomended to use a **clean** GCP project).
* Access to GCP cloud shell or locally using Terraform with GCP credentials.
* Google Storage Bucket to store the backups. This Bucket is not required to share the same GCP project with the rest of the deployment.
* A secret storing a password which will be used to encrypt/decrypt backup archives.



Clone the repository
```bash
git clone https://github.com/SygniaLabs/ScallOps.git
cd ScallOps
nano config.tfvars
```

Carefully read the instructions related to each variable and act accordingly.

**project_id**, **infra_name**, **gitlab_backup_key_secret_id** and **backups_bucket_name** variables are required.

The code below is an example for *config.tfvars* file using all available optional features:
```bash
##### Scallops IAC variables #####
#### Note that some variables are required (#Required), and some variables modifications will take effect also after deployment (#PostDeploymentModifiable).


## GCP Project ID
project_id = "" #Required

## The name you wish to have as a prefix for the deployment's resources. Must comply with ^[a-z]([a-z0-9]*[a-z0-9])$
infra_name = "scallops" #Required

## The name of an existing bucket you wish to receive backups to. Terraform will create the required permission to upload the backup archive.
backups_bucket_name = "" #Required #PostDeploymentModifiable

## An existing secret ID in the same GCP project (project_id) storing a password for the backup process (Allowed symbols for secret value: -_ )
## Creating a secret through GCP secret manager https://cloud.google.com/secret-manager/docs/creating-and-accessing-secrets#create
gitlab_backup_key_secret_id = "" #Required #PostDeploymentModifiable



## Gitlab version to install
## Ruuner chart version must be compaitibe with the Gitlab version -> https://docs.gitlab.com/runner/#gitlab-runner-versions
## Note the Gitlab application version from the selected Chart version -> https://artifacthub.io/packages/helm/gitlab/gitlab-runner
## You can make upgrades to your Gitlab instance from here. Just reset the instance once the `apply` completes.
# gitlab_version = "16.1.2-ee"
# runner_chart_url = "https://gitlab-charts.s3.amazonaws.com/gitlab-runner-0.54.0.tgz"


## IP addresses that can interact with the Gitlab instance via HTTP/S (Office IP / Home IPs)
# operator_ips = [] #Optional #PostDeploymentModifiable

## Enable debugging resources such as IAP Firewall rules, and export of config files
# debug_flag = false #Optional #PostDeploymentModifiable

## The Gitlab instance Web server protocol, http or https.
# gitlab_instance_protocol = "https" #Optional

## Region for the k8s cluster, Gitlab instance and network.
# region = us-central-1 #Optional

## Zone for the k8s cluster, Gitlab instance and network.
# zone = "a" #Optional



## External DNS ## #Optional #PostDeploymentModifiable #GitlabRestartRequired
## Uncomment the 3 lines below if wishing to supply external DNS name for accessing Gitalb instance

# dns_project_id = ""                           # The project ID where the managed DNS zone is located
# dns_managed_zone_name = "mydomain-com"        # The configured managed DNS zone name
# external_hostname = "scallops.mydomain.com"   # The hostname you wish to set of the instance (Must be subdomain of the managed zone)



## Docker hub credentials (https://docs.docker.com/docker-hub/access-tokens/) #Optional #PostDeploymentModifiable
## An existing secret name in secret-manager storing Dockerhub credentials to fetch private container images (format is username:password or username:access-token).
# dockerhub-creds-secret = ""


## Scallops-Recipes repository. Use the default repository or specify alternative fork in a Git path HTTPS format.
## The specified repository will be imported to Gitlab as the Scallops-Recipes repository.
## *Ignored if performing a migration
# scallops_recipes_git_url = "https://github.com/SygniaLabs/ScallOps-Recipes.git" #Optional
# scallops_recipes_git_creds_secret = "my-github-creds-secret" #Optional



## Migration variables #Optional
## If you plan on migrating from a different gitlab instance, uncomment all migration variables below, and follow requirements.
## 1. 'gitlab_backup_key_secret_id' secret must store the password value decrypting the archived backup zip.
## 2. 'gitlab_version' must be equal to the version you are migrating from.
## 3. Operation requires Gsutil on the terraform deployer system as backup will be downloaded locally

# migrate_gitlab = true                   ## If performing migration from another Gitlab instance and got a backup file from previous instance. true/false.
# migrate_gitlab_backup_bucket = ""       ## The Google Storage Bucket to your Gitlab backup e.g. 'mybucket1-abcd'
# migrate_gitlab_backup_path = ""         ## The path to the archived backup zip e.g 'backups/gitlab-xxx-backup.zip'

#####
```


If using locally, make sure that you are authenticated to your GCP
```bash
gcloud auth list    # List and check currently authenticated account
gcloud auth login   # Authneticate
```


Deploy using terraform while pointing to the created configuration file
```bash
terraform init
terraform apply --var-file=./config.tfvars
```

Once deployed, you should receive the Gitlab instance IP address and the secret name where the password of the Gitlab's root account is stored.
Before accessing the Gitlab instance, you should look for 'Gitlab instance setup completed' in the Gcloud logging 'gitlab-startup' log name. 
Errors within Gitlab setup will also be logged, but not all of them will stop the setup. Checkout the entry above the error to understand which process errored.

```console
....
....
module.gke.google_container_node_pool.pools["linux-pool"]: Still creating... [7m31s elapsed]
module.gke.google_container_node_pool.pools["linux-pool"]: Creation complete after 7m32s [id=projects/my-scallops/locations/us-central1-a/clusters/scallops-offensive-pipeline/nodePools/linux-pool]
module.gke_auth.data.google_container_cluster.gke_cluster: Reading...
google_container_node_pool.windows-pool: Creating...
module.gke_auth.data.google_container_cluster.gke_cluster: Read complete after 0s [id=projects/my-scallops/locations/us-central1-a/clusters/scallops-offensive-pipeline]
kubernetes_namespace.sensitive-namespace: Creating...
kubernetes_pod_disruption_budget.kube-dns: Creating...
kubernetes_pod_disruption_budget.konnectivity-agent: Creating...
kubernetes_secret.k8s_gitlab_cert_secret: Creating...
helm_release.gitlab-runner-linux: Creating...
kubernetes_pod_disruption_budget.konnectivity-agent: Creation complete after 1s [id=kube-system/k8s-pdb-konnectivity-agent]
kubernetes_secret.k8s_gitlab_cert_secret: Creation complete after 1s [id=default/scallops-gitlab.us-central1-a.c.my-scallops.internal-cert]
kubernetes_pod_disruption_budget.kube-dns: Creation complete after 1s [id=kube-system/k8s-pdb-kube-dns]
kubernetes_namespace.sensitive-namespace: Creation complete after 1s [id=sensitive]
kubernetes_secret.google-application-credentials: Creating...
kubernetes_secret.dockerhub-creds-config[0]: Creating...
kubernetes_secret.k8s_gitlab_cert_secret-sensitive: Creating...
helm_release.gitlab-runner-win: Creating...
kubernetes_secret.dockerhub-creds-config[0]: Creation complete after 0s [id=sensitive/dockerhub-creds-jsonconfig]
kubernetes_secret.google-application-credentials: Creation complete after 0s [id=sensitive/kaniko-secret]
kubernetes_secret.k8s_gitlab_cert_secret-sensitive: Creation complete after 0s [id=sensitive/scallops-gitlab.us-central1-a.c.my-scallops.internal-cert]
helm_release.gitlab-runner-kaniko: Creating...
helm_release.gitlab-runner-dockerhub[0]: Creating...
google_container_node_pool.windows-pool: Still creating... [10s elapsed]
helm_release.gitlab-runner-linux: Still creating... [10s elapsed]
helm_release.gitlab-runner-win: Still creating... [10s elapsed]
helm_release.gitlab-runner-kaniko: Still creating... [10s elapsed]
helm_release.gitlab-runner-linux: Creation complete after 13s [id=linux]
helm_release.gitlab-runner-win: Creation complete after 13s [id=windows]
helm_release.gitlab-runner-dockerhub[0]: Still creating... [10s elapsed]
helm_release.gitlab-runner-dockerhub[0]: Creation complete after 11s [id=dockerhub-privates]
helm_release.gitlab-runner-kaniko: Creation complete after 12s [id=kaniko]
google_container_node_pool.windows-pool: Still creating... [20s elapsed]
google_container_node_pool.windows-pool: Still creating... [10m50s elapsed]
google_container_node_pool.windows-pool: Creation complete after 10m55s [id=projects/my-scallops/locations/us-central1-a/clusters/scallops-offensive-pipeline/nodePools/windows-pool]

Apply complete! Resources: 65 added, 0 changed, 0 destroyed.

Outputs:

gitlab_ext_ip = "X.X.X.X"
gitlab_root_password_secret = "scallops-gitlab-root-password"
```

[ScallOps-Recipes](https://github.com/SygniaLabs/ScallOps-Recipes) repository should be pre-imported into the Gitlab insatnce together with few instance level CI/CD variables configured. All you have left to do is executing the recipes :)
If you don't see the Recipes repository, you can import it [manually](https://docs.gitlab.com/ee/user/project/import/repo_by_url.html).
> Important! If it is your initial deployment, you must run the deployment's initialization pipeline. 
1. Refer to the imported Recipes repository at /ci/scallops-recipes in your Gitlab instance. 
2. Navigate to CI/CD -> Pipelines -> Run Pipeline.
3. Delete all variables and add 'DEPLOYMENT_INIT' with value 1.
4. Hit 'Run Pipeline' and wait for the initialization process to complete.

## Architecture

The included Terraform scripts will deploy the following resources into your GCP project:
- Compute Engine - Gitlab Instance, managing sources and CI/CD jobs
- Google Kubernetes Engine (GKE) - K8s cluster to host our CI/CD jobs
  - Default node pool - Single machine with K8s system pods and runners pods
  - Linux node pool - For the Gitlab-runners pods, and linux related jobs
  - Windows node pool - For Windows related jobs
  - Gitlab-runner Helm packages (Linux-runner, Windows-runner, Kaniko-runner, \[dockerhub-privates-runner\])
- Google Cloud Storage (GCS) - To store maintenance scripts
- Google Artifact Registry - To store cutomized container images
- Service Accounts
  1. Used by Gitlab Compute instance to pull maintenance scripts and store backup
  2. User who is attached to the GKE cluster nodes to pull container images from the project's registry (Read only)
  3. User who is attached to the Kaniko CI job runner allowing to push customized container images to Artifact Registry
- VPC network and related firewall rules to allow operation

<p align="center">
  <img src="./img/scallops-infra.png" alt="Infrastructure-layout" width="1494">
</p>



## GCP Cloud Costs

Idle / Minimal usage:
* Gitlab Instance: 51.46$ / month (n1-standard-2)
* 2 x Linux node: 2 x 10.83$ = 21.66$ / month (e2-highcpu-2 preemptible)
* Windows node: 134.34$ / month (t2d-standard-4 preemptible)
* Storage
  * Utilities & Migration bucket: 20GB (depends on backup size) - 0.40$ / month
  * Artifact Registry (depends on container images volume): 100GB - 9.95$ / month
  * Boot Disks 
    * Gitlab: Zonal SSD PD: 160 GB - 27.20$ / month
    * GKE Linux: Zonal SSD PD: 100 GB - 17$ / month
    * GKE Windows: Zonal SSD PD: 200 GB - 34$ / month
* Secret manager: 0.06$ /month
* GKE: One Zonal cluster is free per billing account
* **Total: 318$ (us-central-1)** -- [source](https://cloud.google.com/products/calculator/#id=a582ea75-5872-4616-8313-41192c043ae7)

Per Job:
* Linux: Same as idle since system already up. When scaled 0.015$ per hour for each running node.
* Windows: Same as idle since one system is already up. When scaled additional 0.2$ per hour for each running node.


## Backup procedure

The deployment requires to supply a GCS bucket name to store the [Gitlab backup](https://docs.gitlab.com/ee/raketasks/backup_restore.html#back-up-gitlab).
Backup occurs every Saturday during 10AM UTC, and is done by the Gitlab compute instance using the *[gitlab_backup.sh](scripts/bash/gitlab_backup.sh)* bash script, which is stored on GCS and setup into crontab during deployment.
The backup archive is encrypted with a password stored in GCP secret-manager which is supplied (gitlab_backup_key_secret_id) by the user during Terraform deployment.

The encrypted archive contains the following components:
* Timestamp_yyyy_mm_dd_14.5.2-ee_gitlab_backup.tar (A file containing the Gitlab DB)
* gitlab.rb (The main gitlab configuration file)
* gitlab-secret.json (A file containing keys to decrypt various DB data)
* ssl/hostname.key (SSL certificate private key belonging to the existing hostname)
* ssl/hostname.cer (SSL public certificate file belonging to the existing hostname)

The backup process log is casted to a [GCP log](https://cloud.google.com/logging/docs/view/logs-explorer-interface) named "gitlab-backup-exec".

*Note that this backup structure works with the deployment migration capability.


## Open issues
- Windows related containers are **not** built and deployed automatically to your Container Registry. For now, you will have to do it manually. You can use the supplied [Windows Dockerfiles](https://github.com/SygniaLabs/ScallOps-Recipes/tree/main/_ci-maintain/dockerfiles/windows).
- Windows related containers must include native Powershell Core (PWSH).
- Concurrent Linux related jobs are limited to 50 due to the Gitlab's instance compute resources.
- Concurrent Windows related jobs are limited to 30 due to the time it takes to pull a container image when vertical scaling is triggered.


## Security Consideration
Altough we made efforts to secure the given permissions and layout of the deployed environment, there may always be a scenario in which someone will achieve some sort of unautohrized access to the internal GCP cloud components. Therefore, it is **highly recommended to use a clean GCP project** when deploying this environment.

## References

CI/CD guides:

* CI/CD concept: https://hackernoon.com/understanding-the-basic-concepts-of-cicd-fw4k32s1
* Gitlab CI docs: https://docs.gitlab.com/ee/ci/
* Gitlab CI Runner K8s executor: https://docs.gitlab.com/runner/executors/kubernetes.html 

Infrastructure references:

* Terraform & Gcloud: https://registry.terraform.io/providers/hashicorp/google/latest/docs 
* GKE: https://cloud.google.com/kubernetes-engine/docs/concepts/kubernetes-engine-overview 
* Container registry access: https://cloud.google.com/container-registry/docs/access-control 
* Helm Charts: https://helm.sh/docs/topics/charts/ 
* Kaniko: https://github.com/GoogleContainerTools/kaniko
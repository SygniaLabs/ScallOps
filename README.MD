[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
![Terraform](https://img.shields.io/badge/Terraform-v0.14-8040c9.svg?style=plastic)
![ScallOps](https://img.shields.io/badge/ScallOps-v0.1-000000.svg?style=plastic)

# SCALLOPS

## Overview

ScallOps is a framework that empowers Red Teams to put more focus on what they need to do, instead of how to do it. 
It utilizes the CI/CD concept to manage and automate the weaponization and deployment of offensive tools.

Security teams and individuals can develop, collaborate and utilize the framework's "Recipes" in order to perform their Red Team tasks with greater efficiency.

Refer to the [ScallOps-Recipes](https://github.com/SygniaLabs/ScallOps-Recipes) repository to learn more about the features of this framework and how you can design your own Recipes.

<p align="center">
  <img src="./img/scallops.png" alt="ScallOps logo" width="" height="300">
</p>


## Deployment

The framework can be deployed to GCP using the provided Terraform scripts.
It is maninly built from a Gitlab instance that provides the CI features and a Kubernetes cluster that execute CI jobs on the relevant operating systems.
We are also using the Cloud Storage to store customized container images that we may use during operating the framework.

Pre-requisites:
* Google Cloud subscription with **OWNER** permissions on a project (It is reccomended to use a clean GCP project)
* Access to GCP cloud shell or at least Terraform 14
* Web Browser

After authneticating with your GCloud:
```bash
git clone https://github.com/SygniaLabs/ScallOps.git
cd ScallOps

***Edit config.tfvars according to your needs***

terraform init
terraform apply --var-file=./config.tfvars
```

Once deployed, you should receive the Gitlab instance IP address and the secret name where the password of the Gitlab's root account is stored.

```console
helm_release.gitlab-runner-linux: Still creating... [40s elapsed]
helm_release.gitlab-runner-linux: Creation complete after 44s [id=linux]
helm_release.gitlab-runner-win: Creating...
helm_release.gitlab-runner-win: Still creating... [10s elapsed]
helm_release.gitlab-runner-win: Still creating... [20s elapsed]
helm_release.gitlab-runner-win: Creation complete after 22s [id=windows]

Apply complete! Resources: 50 added, 0 changed, 0 destroyed.

Outputs:

gitlab_ext_ip = "1.2.3.4"
gitlab_root_password_secret = "<INFRA_NAME>-gitlab-root-password"
```

[ScallOps-Recipes](https://github.com/SygniaLabs/ScallOps-Recipes) repository should be pre-imported into the Gitlab insatnce together with all the relevant variables configured. All you have left to do is [designing](https://github.com/SygniaLabs/ScallOps-Recipes#designing-recipes) your recipes :)
If you don't see the Recipes, you can import it [manually](https://docs.gitlab.com/ee/user/project/import/repo_by_url.html).


## Architecture

The framework was built on top of GCP and coded with Terraform scripts.

GCP resources include:
- Compute Engine - Gitlab Instance, managing sources and CI/CD jobs
- Google Kubernetes Engine (GKE) - K8s cluster to host our CI/CD jobs
  - Linux node pool - For the Gitlab-runners pods, and linux related jobs
  - Windows node pool - For Windows related jobs
- CICD utilities bucket
- Gitlab deploy utilities bucket
- 2 Service Accounts
  1. Used by Gitlab Compute instance
  2. Used to push containers to Google Container Registry (GCR)
- VPC network and related firewall rules
- Container Registry is automatically created once you push the first container image

<p align="center">
  <img src="./img/scallops-infra.png" alt="Infrastructure-layout" width="1494">
</p>


## GCP Cloud Costs

Idle:
* Gitlab Instance: 51.46$ / month
* Linux node: 24.46$ / month
* Storage (depends on images volume): 100GB - 2$ / month
* Secret manager: 0.06$ /month
* GKE: One Zonal cluster is free per billing account
* **Total: 78$ (us-central-1)** -- [source](https://cloud.google.com/products/calculator/#id=8cb8ce23-5ff1-4e7a-a3b4-da2df464bfff)

Per Job:
* Linux: Same as idle since system already up. When scaled 0.09$ per hour for each running node.
* Windows: ~0.12$ on the first job (30 mins), and additional 0.006 for an average build job (2 mins).

*Note that jobs which are executed simultaneously, can use the same node resources, resulting them in using the same credit. 


## Open issues
- Currently, Gitlab runner [does not support](https://gitlab.com/gitlab-org/gitlab-runner/-/issues/4014) running jobs on Windows K8s cluster nodes. 
  However you can still work with windows containers through the workaround below:
  - Any Windows related container that you are executing your job on, must include Powershell Core (Pwsh has to be avaialble for command line)
  - To fetch previous jobs artifacts and upload outputs to the job artifact, you may utilize the API token from env variables (or create your own) together with gitlab-runner-helper.exe binary that is stored in the cicd-utils bucket.
You may find examples to workaround this issue within the ScallOps-Recipes repository as well.

- Deployment does not support the use of your own purchased domain, it currently utilizes a self-signed certificate. Don't try to change the domain on the Gitlab server, as it may break the certificate trust by the runners. This issue will be solved soon.

- Windows related containers are **not** built and deployed automatically to your Container Registry. For now, you will have to do it manually. You can use the supplied [Windows Dockerfiles](https://github.com/SygniaLabs/ScallOps-Recipes/tree/main/_ci-maintain/dockerfiles/windows).


## Security Considerations

To make the deployment and usage of this framework as smooth as possible, the following configurations were made:

1. A Gitlab's instance level CI/CD variable that holds the API key of the root account. This means that any user who will be onboarded to the Gitlab, will be able to design and trigger CI pipeline, extract this API key and further use it.

2. See [Container-Builder](https://github.com/SygniaLabs/ScallOps-Recipes/tree/main/_ci-maintain/dockerfiles) for GCP storage related security consideration.

**The bottom line:** any registered user on your Gitlab instance will have complete access to your Project's Cloud Storage and Gitlab API.

Keep in mind that having the API token available to any repository's CI settings enables you to:
- Operate with the open [issue](https://gitlab.com/gitlab-org/gitlab-runner/-/issues/4014) workaround when you require to fetch artifacts from previous jobs or upload them to the current job artifact.
- Utilize the automatic external repository importer from the [**.tools-index.json**](https://github.com/SygniaLabs/ScallOps-Recipes/tree/main/ci-tools-controllers/.tools-index.json) file.


Don't like these risks? You can waive the Tools Importer and Container Builder [features](https://github.com/SygniaLabs/ScallOps-Recipes#features) by:
1. Login with your root account and follow the [instructions](https://docs.gitlab.com/ee/user/profile/personal_access_tokens.html#revoke-a-personal-access-token) to revoke the post-deployment personal access token.
2. Browse to your GCP console, navigte to IAM & Admin -> Service Accounts -> Disable a service account with the convention: **\<INFRA-NAME\>-gke-buckt@<PROJECT_ID>.iam.gserviceaccount.com**. This account was created with permissions to push and pull containers.



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

Issues:

* K8s windows exec support: https://gitlab.com/gitlab-org/gitlab-runner/-/issues/4014 

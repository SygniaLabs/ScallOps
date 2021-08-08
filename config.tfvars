#### Required ####

# GCP Project ID
project_id = ""
# The name you wish to have as a prefix for the deployment's resources. Must comply with [a-z]([-a-z0-9]*[a-z0-9])
infra_name = ""

#### Optional ####

# Office IP / home IPs
operator_ips = [""] 


# Default deployment values, uncommenct and modify only if needed (us-central-1 considered to be the cheapest).

# The Gitlab instance Web server protocol, http or https.
# gitlab_instance_protocol = "https" 
# Zone for the k8s cluster, Gitlab instance and network.
# zone = "a"
# Region for the k8s cluster, Gitlab instance and network.
# region = us-central-1 
#Required
project_id = "" //GCP Project ID
infra_name = "" //must comply with [a-z]([-a-z0-9]*[a-z0-9])


#Optional
operator_ips = [""] # Office IP / home IPs
// Defaults
#gitlab_instance_protocol = "https" // http or https
#zone = "a"   // Zone for the k8s cluster, Gitlab instance and network
#region = us-central-1 // Region for the k8s cluster, Gitlab instance and network
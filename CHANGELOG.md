# Change Log


## [0.6] - 2024-08-19
### Added
- Added LB resource and related resources
- Added application external Certificate service
- Modify DNS record set to LB IP instead of Gitlab instance
- Assigned Gitlab to instance group
- Added option to specify external integration IP addresses.
- Upgraded google terraform provider


## [0.5] - 2023-07-19
### Added
- Enabled runner session server on linux-runner to allow the use of Interactive Web Terminal (Job Debug button)

### Changed
- Shortened runner poll intervals
- Optimize K8s performance
    - Upgraded GKE to version 1.26.5
    - Containers are now stored in Artifact Registry instead of deprecating Container Registry (GCR).
    - Modified node pools disk type to SSD
    - Modified Linux node image type to COS_CONTAINERD
    - Enabled image streaming
    - Upgraded related providers and modules
    - Modified k8s pdb resources according to provider upgrades
- Gitlab 16.1.2 upgrade
    - Default to Gitlab 16.1.2-ee and runner 0.54.0
    - Option to set target Gitlab version to upgrade the application from tf vars    
    - Added relevant locals
    - Added multiple ubuntu release options for the instance
    - Changed runner TOML config to be set from terraform instead of Helm chart Yaml.
    - Modified Gitlab instance disk to 160G SSD.
    - Added Gitlab DEB package link metadata variable.
  
### Fixed
- Backup creation bug. The created backup snapshot was not deleted after upload, causing overload to the local disk.
- Modified IAM binding to add memeber instead of overwrite all members on user resources.
- Fixed Gitlab restore bug via new exec-wrapper function.  

## [0.4] - 2022-10-22
### Added
- Option to specify Scallop-Recipes repo URL (For auto import)
- Error handling for Gitlab installation and backup Bash scripts
- Deployment TF debug option - IAP firewall rules, export configuration files
- Integration with GCP logger for Gitlab installation and backup

### Changed
- README + architecture image
- Updated K8s RBAC permissions for runners
- Removed generated backup password. Password secret is supplied by the user.
- Updated tfvars template
- Upgraded Gitlab, K8s, Runners versions
- Adjusted instance level CI/CD variables names
- Upgraded Windows node pool machine type to 4 vCPU & 16GB RAM
- Now limiting concurrent jobs for 30 in Windows and 50 in Linux
- K8s nodes are now preemptible

### Fixed
- Fixed TF resources dependencies 
- Fixed Defender disarm detection issue
- Fixed K8s Scale up issues

## [0.3] - 2022-01-07
### Added
- Added support to migrate from an older Gitlab instance
- Added Gitlab instance automatic backup capability
- K8s Pod disruption budget resources to fix scale down issue
- New runner that supports Dockerhub credentials to pull private images

### Changed
- Modified max pods per node in K8s, meanning more CI jobs simoultaneously
- Scopred bucket admin permissions to conainer registry bucket only
- Reorganized resources into seperate files
- Increased CPUs on linux pool
- Removed Gitlab API token seeding. Gitlab modifications performed using gitlab-rails console

### Fixed
- Windows Runner configuration
- Minor fixes, duplicate code removal
- Fixed Linux won't scale down problem


## [0.2] - 2021-12-21
### Fixed
- Windows Runner configuration
- Relativ paths
- Runner version update


## [0.1] - 2021-08-09
### Initial
- Initial working deployment

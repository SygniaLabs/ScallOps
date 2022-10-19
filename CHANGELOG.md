# Change Log

## [0.4] - 2022-10-22
### Fixes
- Fixed TF resources dependencies 
- Fixed Defender disarm detection issue

### Changed
- README + architecture image
- Updated K8s RBAC permissions for runners
- Removed generated backup password. Password secret is supplied by the user.
- Updated tfvars template
- Upgraded Gitlab, K8s, Runners versions
- Adjusted instance level CI/CD variables names

### Added
- Option to specify Scallop-Recipes repo URL (For auto import)
- Error handling for Gitlab installation and backup Bash scripts
- Deployment TF debug option - IAP firewall rules, export configuration files
- Integration with GCP logger for Gitlab installation and backup


## [0.3] - 2022-01-07
### Fixes
- Windows Runner configuration
- Minor fixes, duplicate code removal
- Fixed Linux won't scale down problem

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


## [0.2] - 2021-12-21
### Fixes
- Windows Runner configuration
- Relativ paths
- Runner version update


## [0.1] - 2021-08-09
### Initial
- Initial working deployment

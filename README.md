# OpenSearch Ireland Infrastructure

Terraform-managed OpenSearch cluster `imiconnect-uk-prod` in Ireland (eu-west-1).

## Quick Start

1. **Discovery**: `./scripts/discover-existing-cluster.sh`
2. **Import**: Jenkins Pipeline -> Operation: import
3. **Validate**: Jenkins Pipeline -> Operation: validate
4. **Deploy Changes**: Update `terraform.tfvars` -> Git commit -> Jenkins apply

## Repository Structure

- `terraform/` - Terraform configuration files
- `scripts/` - Automation and management scripts
- `regions/eu-west-1/` - Ireland-specific configuration
- `docs/` - Documentation

## Team Contacts

- **Primary**: myeredla@cisco.com
- **Team**: WebEx DBA Infrastructure Team
- **Slack**: #webex-infrastructure-ireland

## Links

- **State Backups**: https://github5.cisco.com/webexdba/opensearch-terraform-state
- **Jenkins Pipeline**: [opensearch-ireland-prod](jenkins-url)

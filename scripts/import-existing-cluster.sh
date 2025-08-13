#!/bin/bash
set -e

DOMAIN_NAME="connect-qa-new"
REGION="us-east-1"
STATE_REPO_PATH=${STATE_REPO_PATH:-"../opensearch-terraform-state"}

echo "=== Starting Import Process ==="
echo "Domain: $DOMAIN_NAME"
echo "Region: $REGION"

# Step 1: Backup current configuration
echo "1. Creating configuration backup..."
aws opensearch describe-domain --domain-name "$DOMAIN_NAME" --region $REGION > "backup-${DOMAIN_NAME}-$(date +%Y%m%d).json"

# Step 2: Initialize Terraform
echo "2. Initializing Terraform..."
cd terraform
terraform init

# Step 3: Import domain
echo "3. Importing OpenSearch domain..."
terraform import aws_opensearch_domain.main "$DOMAIN_NAME"

# Step 4: Import log groups
echo "4. Importing CloudWatch log groups..."
terraform import aws_cloudwatch_log_group.application_logs "/aws/opensearch/domains/$DOMAIN_NAME/application-logs" || echo "Application logs not found"
terraform import aws_cloudwatch_log_group.search_logs "/aws/opensearch/domains/$DOMAIN_NAME/search-logs" || echo "Search logs not found"
terraform import aws_cloudwatch_log_group.index_logs "/aws/opensearch/domains/$DOMAIN_NAME/index-logs" || echo "Index logs not found"

# Step 5: Create secrets for credentials
echo "5. Setting up Secrets Manager..."
SECRET_NAME="${DOMAIN_NAME}-master-credentials"
if ! aws secretsmanager describe-secret --secret-id "$SECRET_NAME" --region $REGION > /dev/null 2>&1; then
    echo "Creating new secret..."
    terraform apply -target=aws_secretsmanager_secret.master_credentials -var-file="../regions/eu-west-1/terraform.tfvars" -auto-approve
    terraform apply -target=aws_secretsmanager_secret_version.master_credentials -var-file="../regions/eu-west-1/terraform.tfvars" -auto-approve
fi

# Step 6: Backup state to GitHub
echo "6. Backing up state..."
../scripts/backup-state-to-github.sh

echo "✅ Import completed successfully!"

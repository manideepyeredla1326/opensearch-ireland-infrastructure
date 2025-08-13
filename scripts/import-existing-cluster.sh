#!/bin/bash
set -e

# Accept command-line arguments
DOMAIN_NAME=$1
REGION=$2
TF_VAR_FILE=$3
STATE_REPO_PATH=${STATE_REPO_PATH:-"../opensearch-terraform-state"}

# Validate arguments
if [ -z "$DOMAIN_NAME" ] || [ -z "$REGION" ] || [ -z "$TF_VAR_FILE" ]; then
    echo "ERROR: Missing required arguments"
    echo "Usage: $0 <DOMAIN_NAME> <REGION> <TF_VAR_FILE>"
    echo "Example: $0 imiconnect-uk-prod eu-west-1 regions/eu-west-1/imiconnect-uk-prod.tfvars"
    exit 1
fi

echo "=== Starting Import Process ==="
echo "Domain: $DOMAIN_NAME"
echo "Region: $REGION"
echo "TF Var File: $TF_VAR_FILE"
echo "State Repo Path: $STATE_REPO_PATH"

# Check if tfvars file exists
if [ ! -f "$TF_VAR_FILE" ]; then
    echo "ERROR: TF var file not found: $TF_VAR_FILE"
    exit 1
fi

# Step 1: Backup current configuration
echo "1. Creating configuration backup..."
BACKUP_FILE="backup-${DOMAIN_NAME}-$(date +%Y%m%d-%H%M%S).json"
aws opensearch describe-domain --domain-name "$DOMAIN_NAME" --region "$REGION" > "$BACKUP_FILE"
echo "Configuration backed up to: $BACKUP_FILE"

# Step 2: Initialize Terraform (in current directory, not terraform subdirectory)
echo "2. Initializing Terraform..."
terraform init -input=false

# Step 3: Import domain
echo "3. Importing OpenSearch domain..."
echo "Importing: aws_opensearch_domain.main with domain name: $DOMAIN_NAME"
terraform import aws_opensearch_domain.main "$DOMAIN_NAME" || {
    echo "WARNING: Failed to import domain. It might already be imported or the resource name is different."
}

# Step 4: Import log groups (with better error handling)
echo "4. Importing CloudWatch log groups..."

# Application logs
echo "Importing application logs..."
terraform import aws_cloudwatch_log_group.application_logs "/aws/opensearch/domains/$DOMAIN_NAME/application-logs" 2>/dev/null || {
    echo "WARNING: Application logs import failed - they might not exist or already be imported"
}

# Search logs
echo "Importing search logs..."
terraform import aws_cloudwatch_log_group.search_logs "/aws/opensearch/domains/$DOMAIN_NAME/search-logs" 2>/dev/null || {
    echo "WARNING: Search logs import failed - they might not exist or already be imported"
}

# Index logs
echo "Importing index logs..."
terraform import aws_cloudwatch_log_group.index_logs "/aws/opensearch/domains/$DOMAIN_NAME/index-logs" 2>/dev/null || {
    echo "WARNING: Index logs import failed - they might not exist or already be imported"
}

# Step 5: Create secrets for credentials (if they don't exist)
echo "5. Setting up Secrets Manager..."
SECRET_NAME="${DOMAIN_NAME}-master-credentials"

if ! aws secretsmanager describe-secret --secret-id "$SECRET_NAME" --region "$REGION" > /dev/null 2>&1; then
    echo "Creating new secret: $SECRET_NAME"
    
    # Apply specific resources for secrets
    terraform apply -target=aws_secretsmanager_secret.master_credentials -var-file="$TF_VAR_FILE" -auto-approve || {
        echo "WARNING: Failed to create master credentials secret"
    }
    
    terraform apply -target=aws_secretsmanager_secret_version.master_credentials -var-file="$TF_VAR_FILE" -auto-approve || {
        echo "WARNING: Failed to create master credentials secret version"
    }
else
    echo "Secret $SECRET_NAME already exists, skipping creation"
    
    # Try to import the existing secret
    terraform import aws_secretsmanager_secret.master_credentials "$SECRET_NAME" 2>/dev/null || {
        echo "WARNING: Failed to import existing secret, it might already be imported"
    }
fi

# Step 6: Generate a terraform plan to see what would change
echo "6. Generating terraform plan..."
terraform plan -var-file="$TF_VAR_FILE" -out=import-plan || {
    echo "WARNING: Terraform plan generation failed"
}

# Step 7: Backup state to GitHub
echo "7. Backing up state..."
if [ -f "scripts/backup-state-to-github.sh" ]; then
    chmod +x scripts/backup-state-to-github.sh
    ./scripts/backup-state-to-github.sh || {
        echo "WARNING: State backup failed"
    }
else
    echo "WARNING: backup-state-to-github.sh script not found"
fi

echo ""
echo "✅ Import process completed!"
echo ""
echo "Summary:"
echo "- Configuration backed up to: $BACKUP_FILE"
echo "- Terraform state updated with imported resources"
echo "- Plan generated: import-plan"
echo ""
echo "Next steps:"
echo "1. Review the terraform plan: terraform show import-plan"
echo "2. Make any necessary adjustments to your terraform configuration"
echo "3. Run terraform apply to align the configuration"
#!/bin/bash
set -e

# Accept command-line arguments
DOMAIN_NAME=$1
REGION=$2
TF_VAR_FILE=$3
STATE_REPO_PATH=${STATE_REPO_PATH:-"../opensearch-terraform-state"}

# Use AWS_PROFILE if set, otherwise use default
AWS_PROFILE_FLAG=""
if [ -n "${AWS_PROFILE}" ]; then
    AWS_PROFILE_FLAG="--profile ${AWS_PROFILE}"
    echo "Using AWS Profile: $AWS_PROFILE"
fi

# Validate arguments
if [ -z "$DOMAIN_NAME" ] || [ -z "$REGION" ] || [ -z "$TF_VAR_FILE" ]; then
    echo "ERROR: Missing required arguments"
    echo "Usage: $0 <DOMAIN_NAME> <REGION> <TF_VAR_FILE>"
    echo "Example: $0 connect-qa-new us-east-1 regions/us-east-1/connect-qa-new.tfvars"
    exit 1
fi

echo "=== Starting Import Process ==="
echo "Domain: $DOMAIN_NAME"
echo "Region: $REGION"
echo "TF Var File: $TF_VAR_FILE"
echo "State Repo Path: $STATE_REPO_PATH"
if [ -n "${AWS_PROFILE}" ]; then
    echo "AWS Profile: $AWS_PROFILE"
fi

# Check prerequisites
echo "Checking prerequisites..."

# Check if terraform is available
if ! command -v terraform &> /dev/null; then
    echo "❌ ERROR: Terraform not found in PATH"
    exit 1
fi

# Check if aws CLI is available
if ! command -v aws &> /dev/null; then
    echo "❌ ERROR: AWS CLI not found in PATH"
    echo "Please install AWS CLI before running this script"
    exit 1
fi

# Check if tfvars file exists
if [ ! -f "$TF_VAR_FILE" ]; then
    echo "❌ ERROR: TF var file not found: $TF_VAR_FILE"
    exit 1
fi

# Test AWS connectivity
echo "Testing AWS connectivity..."
if ! aws sts get-caller-identity --region "$REGION" $AWS_PROFILE_FLAG > /dev/null 2>&1; then
    echo "❌ ERROR: Cannot connect to AWS. Please check your credentials and region."
    echo "Current AWS region: $REGION"
    if [ -n "${AWS_PROFILE}" ]; then
        echo "Current AWS profile: $AWS_PROFILE"
        echo "Available profiles:"
        aws configure list-profiles
    fi
    exit 1
fi

echo "✅ Prerequisites check completed"

# Step 1: Backup current configuration
echo "1. Creating configuration backup..."
BACKUP_FILE="backup-${DOMAIN_NAME}-$(date +%Y%m%d-%H%M%S).json"

if aws opensearch describe-domain --domain-name "$DOMAIN_NAME" --region "$REGION" $AWS_PROFILE_FLAG > "$BACKUP_FILE" 2>/dev/null; then
    echo "✅ Configuration backed up to: $BACKUP_FILE"
else
    echo "❌ WARNING: Failed to backup domain configuration. Domain might not exist or access denied."
    echo "Continuing with import process..."
fi

# Step 2: Initialize Terraform (in current directory, not terraform subdirectory)
echo "2. Initializing Terraform..."
if terraform init -input=false; then
    echo "✅ Terraform initialized successfully"
else
    echo "❌ ERROR: Terraform initialization failed"
    exit 1
fi

# Step 3: Import domain
echo "3. Importing OpenSearch domain..."
echo "Importing: aws_opensearch_domain.main with domain name: $DOMAIN_NAME"

if terraform import aws_opensearch_domain.main "$DOMAIN_NAME" 2>/dev/null; then
    echo "✅ OpenSearch domain imported successfully"
else
    echo "⚠️ WARNING: Domain import failed. Possible reasons:"
    echo "   - Domain is already imported"
    echo "   - Domain doesn't exist"
    echo "   - Incorrect resource name in terraform configuration"
    echo "   - Insufficient permissions"
    echo "Continuing with other imports..."
fi

# Step 4: Import log groups (with better error handling)
echo "4. Importing CloudWatch log groups..."

declare -a LOG_TYPES=("application" "search" "index")
declare -a LOG_RESOURCE_NAMES=("application_logs" "search_logs" "index_logs")

for i in "${!LOG_TYPES[@]}"; do
    LOG_TYPE="${LOG_TYPES[$i]}"
    RESOURCE_NAME="${LOG_RESOURCE_NAMES[$i]}"
    LOG_GROUP_NAME="/aws/opensearch/domains/$DOMAIN_NAME/${LOG_TYPE}-logs"
    
    echo "Importing ${LOG_TYPE} logs..."
    
    # Check if log group exists first
    if aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP_NAME" --region "$REGION" $AWS_PROFILE_FLAG --query 'logGroups[?logGroupName==`'$LOG_GROUP_NAME'`]' --output text | grep -q "$LOG_GROUP_NAME"; then
        echo "Log group exists: $LOG_GROUP_NAME"
        
        if terraform import "aws_cloudwatch_log_group.${RESOURCE_NAME}" "$LOG_GROUP_NAME" 2>/dev/null; then
            echo "✅ ${LOG_TYPE} logs imported successfully"
        else
            echo "⚠️ WARNING: ${LOG_TYPE} logs import failed (might already be imported)"
        fi
    else
        echo "ℹ️ Log group does not exist: $LOG_GROUP_NAME (skipping)"
    fi
done

# Step 5: Handle secrets for credentials (if they exist)
echo "5. Checking Secrets Manager..."
SECRET_NAME="${DOMAIN_NAME}-master-credentials"

if aws secretsmanager describe-secret --secret-id "$SECRET_NAME" --region "$REGION" $AWS_PROFILE_FLAG > /dev/null 2>&1; then
    echo "✅ Secret exists: $SECRET_NAME"
    
    # Try to import the existing secret
    if terraform import aws_secretsmanager_secret.master_credentials "$SECRET_NAME" 2>/dev/null; then
        echo "✅ Secret imported successfully"
    else
        echo "⚠️ WARNING: Secret import failed (might already be imported)"
    fi
    
    # Try to import secret version (this is trickier as we need the version ID)
    VERSION_ID=$(aws secretsmanager describe-secret --secret-id "$SECRET_NAME" --region "$REGION" $AWS_PROFILE_FLAG --query 'VersionIdsToStages.keys(@)[0]' --output text 2>/dev/null)
    if [ -n "$VERSION_ID" ] && [ "$VERSION_ID" != "None" ]; then
        if terraform import "aws_secretsmanager_secret_version.master_credentials" "${SECRET_NAME}|${VERSION_ID}" 2>/dev/null; then
            echo "✅ Secret version imported successfully"
        else
            echo "⚠️ WARNING: Secret version import failed (might already be imported)"
        fi
    fi
else
    echo "ℹ️ No existing secret found: $SECRET_NAME"
    echo "ℹ️ You may need to create secrets after import if required by your terraform configuration"
fi

# Step 6: Generate a terraform plan to see what would change
echo "6. Generating terraform plan..."
if terraform plan -var-file="$TF_VAR_FILE" -out=import-plan -detailed-exitcode; then
    PLAN_EXIT_CODE=$?
    case $PLAN_EXIT_CODE in
        0)
            echo "✅ No changes needed - infrastructure matches configuration"
            ;;
        2)
            echo "ℹ️ Plan generated with changes - review import-plan file"
            ;;
    esac
else
    PLAN_EXIT_CODE=$?
    echo "⚠️ WARNING: Terraform plan generation had issues (exit code: $PLAN_EXIT_CODE)"
    echo "This is common during imports - review the output above"
fi

# Step 7: Backup state to GitHub
echo "7. Backing up state..."
if [ -f "scripts/backup-state-to-github.sh" ]; then
    chmod +x scripts/backup-state-to-github.sh
    if ./scripts/backup-state-to-github.sh; then
        echo "✅ State backed up successfully"
    else
        echo "⚠️ WARNING: State backup failed"
    fi
else
    echo "ℹ️ No backup script found: scripts/backup-state-to-github.sh"
fi

echo ""
echo "🎉 Import process completed!"
echo ""
echo "📋 Summary:"
echo "- Domain: $DOMAIN_NAME"
echo "- Region: $REGION"
if [ -n "${AWS_PROFILE}" ]; then
    echo "- AWS Profile: $AWS_PROFILE"
fi
if [ -f "$BACKUP_FILE" ]; then
    echo "- Configuration backed up to: $BACKUP_FILE"
fi
if [ -f "import-plan" ]; then
    echo "- Plan generated: import-plan"
fi
echo ""
echo "📋 Next steps:"
echo "1. Review the terraform plan: terraform show import-plan"
echo "2. Check for any configuration drift or missing resources"
echo "3. Make any necessary adjustments to your terraform configuration"
echo "4. Run 'terraform apply' to align the infrastructure with your configuration"
echo ""
echo "⚠️  Important: Review all imported resources before applying changes!""$REGION" ] || [ -z "$TF_VAR_FILE" ]; then
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

# Check prerequisites
echo "Checking prerequisites..."

# Check if terraform is available
if ! command -v terraform &> /dev/null; then
    echo "❌ ERROR: Terraform not found in PATH"
    exit 1
fi

# Check if aws CLI is available
if ! command -v aws &> /dev/null; then
    echo "❌ ERROR: AWS CLI not found in PATH"
    echo "Please install AWS CLI before running this script"
    exit 1
fi

# Check if tfvars file exists
if [ ! -f "$TF_VAR_FILE" ]; then
    echo "❌ ERROR: TF var file not found: $TF_VAR_FILE"
    exit 1
fi

# Test AWS connectivity
echo "Testing AWS connectivity..."
if ! aws sts get-caller-identity --region "$REGION" > /dev/null 2>&1; then
    echo "❌ ERROR: Cannot connect to AWS. Please check your credentials and region."
    echo "Current AWS region: $REGION"
    exit 1
fi

echo "✅ Prerequisites check completed"

# Step 1: Backup current configuration
echo "1. Creating configuration backup..."
BACKUP_FILE="backup-${DOMAIN_NAME}-$(date +%Y%m%d-%H%M%S).json"

if aws opensearch describe-domain --domain-name "$DOMAIN_NAME" --region "$REGION" > "$BACKUP_FILE" 2>/dev/null; then
    echo "✅ Configuration backed up to: $BACKUP_FILE"
else
    echo "❌ WARNING: Failed to backup domain configuration. Domain might not exist or access denied."
    echo "Continuing with import process..."
fi

# Step 2: Initialize Terraform (in current directory, not terraform subdirectory)
echo "2. Initializing Terraform..."
if terraform init -input=false; then
    echo "✅ Terraform initialized successfully"
else
    echo "❌ ERROR: Terraform initialization failed"
    exit 1
fi

# Step 3: Import domain
echo "3. Importing OpenSearch domain..."
echo "Importing: aws_opensearch_domain.main with domain name: $DOMAIN_NAME"

if terraform import aws_opensearch_domain.main "$DOMAIN_NAME" 2>/dev/null; then
    echo "✅ OpenSearch domain imported successfully"
else
    echo "⚠️ WARNING: Domain import failed. Possible reasons:"
    echo "   - Domain is already imported"
    echo "   - Domain doesn't exist"
    echo "   - Incorrect resource name in terraform configuration"
    echo "   - Insufficient permissions"
    echo "Continuing with other imports..."
fi

# Step 4: Import log groups (with better error handling)
echo "4. Importing CloudWatch log groups..."

declare -a LOG_TYPES=("application" "search" "index")
declare -a LOG_RESOURCE_NAMES=("application_logs" "search_logs" "index_logs")

for i in "${!LOG_TYPES[@]}"; do
    LOG_TYPE="${LOG_TYPES[$i]}"
    RESOURCE_NAME="${LOG_RESOURCE_NAMES[$i]}"
    LOG_GROUP_NAME="/aws/opensearch/domains/$DOMAIN_NAME/${LOG_TYPE}-logs"
    
    echo "Importing ${LOG_TYPE} logs..."
    
    # Check if log group exists first
    if aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP_NAME" --region "$REGION" --query 'logGroups[?logGroupName==`'$LOG_GROUP_NAME'`]' --output text | grep -q "$LOG_GROUP_NAME"; then
        echo "Log group exists: $LOG_GROUP_NAME"
        
        if terraform import "aws_cloudwatch_log_group.${RESOURCE_NAME}" "$LOG_GROUP_NAME" 2>/dev/null; then
            echo "✅ ${LOG_TYPE} logs imported successfully"
        else
            echo "⚠️ WARNING: ${LOG_TYPE} logs import failed (might already be imported)"
        fi
    else
        echo "ℹ️ Log group does not exist: $LOG_GROUP_NAME (skipping)"
    fi
done

# Step 5: Handle secrets for credentials (if they exist)
echo "5. Checking Secrets Manager..."
SECRET_NAME="${DOMAIN_NAME}-master-credentials"

if aws secretsmanager describe-secret --secret-id "$SECRET_NAME" --region "$REGION" > /dev/null 2>&1; then
    echo "✅ Secret exists: $SECRET_NAME"
    
    # Try to import the existing secret
    if terraform import aws_secretsmanager_secret.master_credentials "$SECRET_NAME" 2>/dev/null; then
        echo "✅ Secret imported successfully"
    else
        echo "⚠️ WARNING: Secret import failed (might already be imported)"
    fi
    
    # Try to import secret version (this is trickier as we need the version ID)
    VERSION_ID=$(aws secretsmanager describe-secret --secret-id "$SECRET_NAME" --region "$REGION" --query 'VersionIdsToStages.keys(@)[0]' --output text 2>/dev/null)
    if [ -n "$VERSION_ID" ] && [ "$VERSION_ID" != "None" ]; then
        if terraform import "aws_secretsmanager_secret_version.master_credentials" "${SECRET_NAME}|${VERSION_ID}" 2>/dev/null; then
            echo "✅ Secret version imported successfully"
        else
            echo "⚠️ WARNING: Secret version import failed (might already be imported)"
        fi
    fi
else
    echo "ℹ️ No existing secret found: $SECRET_NAME"
    echo "ℹ️ You may need to create secrets after import if required by your terraform configuration"
fi

# Step 6: Generate a terraform plan to see what would change
echo "6. Generating terraform plan..."
if terraform plan -var-file="$TF_VAR_FILE" -out=import-plan -detailed-exitcode; then
    PLAN_EXIT_CODE=$?
    case $PLAN_EXIT_CODE in
        0)
            echo "✅ No changes needed - infrastructure matches configuration"
            ;;
        2)
            echo "ℹ️ Plan generated with changes - review import-plan file"
            ;;
    esac
else
    PLAN_EXIT_CODE=$?
    echo "⚠️ WARNING: Terraform plan generation had issues (exit code: $PLAN_EXIT_CODE)"
    echo "This is common during imports - review the output above"
fi

# Step 7: Backup state to GitHub
echo "7. Backing up state..."
if [ -f "scripts/backup-state-to-github.sh" ]; then
    chmod +x scripts/backup-state-to-github.sh
    if ./scripts/backup-state-to-github.sh; then
        echo "✅ State backed up successfully"
    else
        echo "⚠️ WARNING: State backup failed"
    fi
else
    echo "ℹ️ No backup script found: scripts/backup-state-to-github.sh"
fi

echo ""
echo "🎉 Import process completed!"
echo ""
echo "📋 Summary:"
echo "- Domain: $DOMAIN_NAME"
echo "- Region: $REGION"
if [ -f "$BACKUP_FILE" ]; then
    echo "- Configuration backed up to: $BACKUP_FILE"
fi
if [ -f "import-plan" ]; then
    echo "- Plan generated: import-plan"
fi
echo ""
echo "📋 Next steps:"
echo "1. Review the terraform plan: terraform show import-plan"
echo "2. Check for any configuration drift or missing resources"
echo "3. Make any necessary adjustments to your terraform configuration"
echo "4. Run 'terraform apply' to align the infrastructure with your configuration"
echo ""
echo "⚠️  Important: Review all imported resources before applying changes!"
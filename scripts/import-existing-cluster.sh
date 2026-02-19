#!/bin/bash
set -e

# Accept command-line arguments
DOMAIN_NAME=$1
REGION=$2
TF_VAR_FILE=$3
STATE_REPO_PATH=${STATE_REPO_PATH:-"../opensearch-terraform-state"}

# Use AWS_PROFILE if set
AWS_PROFILE_FLAG=""
if [ -n "${AWS_PROFILE}" ]; then
    AWS_PROFILE_FLAG="--profile ${AWS_PROFILE}"
    echo "Using AWS Profile: $AWS_PROFILE"
fi

# Validate arguments
if [ -z "$DOMAIN_NAME" ] || [ -z "$REGION" ] || [ -z "$TF_VAR_FILE" ]; then
    echo "ERROR: Missing required arguments"
    echo "Usage: $0 <DOMAIN_NAME> <REGION> <TF_VAR_FILE>"
    echo "Example: $0 cpaas-dev-env us-east-1 regions/us-east-1/cpaas-dev-env.tfvars"
    exit 1
fi

# Store workspace root and make TF_VAR_FILE path absolute
# Store workspace root and make TF_VAR_FILE path absolute
WORKSPACE_ROOT="$(pwd)"
GIT_REPO="/Users/myeredla/Documents/opensearch-ireland-infrastructure"

if [[ "$TF_VAR_FILE" != /* ]]; then
    TF_VAR_FILE="$GIT_REPO/$TF_VAR_FILE"
fi

# Terraform config directory
TERRAFORM_DIR="$WORKSPACE_ROOT/terraform"

echo "=== Starting Import Process ==="
echo "Domain:          $DOMAIN_NAME"
echo "Region:          $REGION"
echo "TF Var File:     $TF_VAR_FILE"
echo "Terraform Dir:   $TERRAFORM_DIR"
echo "State Repo Path: $STATE_REPO_PATH"
[ -n "${AWS_PROFILE}" ] && echo "AWS Profile:     $AWS_PROFILE"

# Check prerequisites
echo "Checking prerequisites..."

if ! command -v terraform &> /dev/null; then
    echo "ERROR: Terraform not found in PATH"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    echo "ERROR: AWS CLI not found in PATH"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "ERROR: jq not found. Install with: brew install jq"
    exit 1
fi

if [ ! -d "$TERRAFORM_DIR" ]; then
    echo "ERROR: terraform/ directory not found at $TERRAFORM_DIR"
    exit 1
fi

# Test AWS connectivity
echo "Testing AWS connectivity..."
if ! aws sts get-caller-identity --region "$REGION" $AWS_PROFILE_FLAG > /dev/null 2>&1; then
    echo "ERROR: Cannot connect to AWS. Check credentials and region."
    [ -n "${AWS_PROFILE}" ] && echo "Available profiles:" && aws configure list-profiles
    exit 1
fi
echo "Prerequisites check completed"

# Auto-generate tfvars if it doesn't exist
if [ ! -f "$TF_VAR_FILE" ]; then
    echo "tfvars not found. Auto-generating from existing AWS cluster..."

    if ! aws opensearch describe-domain --domain-name "$DOMAIN_NAME" --region "$REGION" $AWS_PROFILE_FLAG > /dev/null 2>&1; then
        echo "ERROR: OpenSearch domain '$DOMAIN_NAME' not found in AWS region '$REGION'"
        exit 1
    fi

    mkdir -p "$(dirname "$TF_VAR_FILE")"

    DOMAIN_INFO=$(aws opensearch describe-domain \
        --domain-name "$DOMAIN_NAME" \
        --region "$REGION" \
        $AWS_PROFILE_FLAG \
        --output json)

    ENGINE_VERSION=$(echo "$DOMAIN_INFO"   | jq -r '.DomainStatus.EngineVersion')
    INSTANCE_TYPE=$(echo "$DOMAIN_INFO"    | jq -r '.DomainStatus.ClusterConfig.InstanceType')
    INSTANCE_COUNT=$(echo "$DOMAIN_INFO"   | jq -r '.DomainStatus.ClusterConfig.InstanceCount')
    DEDICATED_MASTER=$(echo "$DOMAIN_INFO" | jq -r '.DomainStatus.ClusterConfig.DedicatedMasterEnabled')
    MASTER_TYPE=$(echo "$DOMAIN_INFO"      | jq -r '.DomainStatus.ClusterConfig.DedicatedMasterType // ""')
    MASTER_COUNT=$(echo "$DOMAIN_INFO"     | jq -r '.DomainStatus.ClusterConfig.DedicatedMasterCount // 0')
    VOLUME_TYPE=$(echo "$DOMAIN_INFO"      | jq -r '.DomainStatus.EBSOptions.VolumeType')
    VOLUME_SIZE=$(echo "$DOMAIN_INFO"      | jq -r '.DomainStatus.EBSOptions.VolumeSize')
    IOPS=$(echo "$DOMAIN_INFO"             | jq -r '.DomainStatus.EBSOptions.Iops // 0')
    THROUGHPUT=$(echo "$DOMAIN_INFO"       | jq -r '.DomainStatus.EBSOptions.Throughput // 0')
    ENCRYPT=$(echo "$DOMAIN_INFO"          | jq -r '.DomainStatus.EncryptionAtRestOptions.Enabled')
    NODE_ENCRYPT=$(echo "$DOMAIN_INFO"     | jq -r '.DomainStatus.NodeToNodeEncryptionOptions.Enabled')
    ENFORCE_HTTPS=$(echo "$DOMAIN_INFO"    | jq -r '.DomainStatus.DomainEndpointOptions.EnforceHTTPS')
    ADV_SECURITY=$(echo "$DOMAIN_INFO"     | jq -r '.DomainStatus.AdvancedSecurityOptions.Enabled')
    CUSTOM_EP=$(echo "$DOMAIN_INFO"        | jq -r '.DomainStatus.DomainEndpointOptions.CustomEndpointEnabled // false')
    CUSTOM_EP_VAL=$(echo "$DOMAIN_INFO"    | jq -r '.DomainStatus.DomainEndpointOptions.CustomEndpoint // ""')
    CERT_ARN=$(echo "$DOMAIN_INFO"         | jq -r '.DomainStatus.DomainEndpointOptions.CustomEndpointCertificateArn // ""')
    VPC_ID=$(echo "$DOMAIN_INFO"           | jq -r '.DomainStatus.VPCOptions.VPCId // ""')
    SUBNET_IDS=$(echo "$DOMAIN_INFO"       | jq -r '.DomainStatus.VPCOptions.SubnetIds // [] | @json')
    SG_ID=$(echo "$DOMAIN_INFO"            | jq -r '.DomainStatus.VPCOptions.SecurityGroupIds[0] // ""')
    KMS_KEY=$(echo "$DOMAIN_INFO"          | jq -r '.DomainStatus.EncryptionAtRestOptions.KmsKeyId // ""')
    WARM_ENABLED=$(echo "$DOMAIN_INFO"     | jq -r '.DomainStatus.ClusterConfig.WarmEnabled // false')
    WARM_TYPE=$(echo "$DOMAIN_INFO"        | jq -r '.DomainStatus.ClusterConfig.WarmType // ""')
    WARM_COUNT=$(echo "$DOMAIN_INFO"       | jq -r '.DomainStatus.ClusterConfig.WarmCount // 0')
    AZS=$(echo "$DOMAIN_INFO"              | jq -r '.DomainStatus.VPCOptions.AvailabilityZones // ["'$REGION'a"] | @json')

    cat > "$TF_VAR_FILE" << EOF
domain_name    = "$DOMAIN_NAME"
aws_region     = "$REGION"
region_name    = "$REGION"
aws_profile    = "${AWS_PROFILE:-default}"

engine_version = "$ENGINE_VERSION"
instance_type  = "$INSTANCE_TYPE"
instance_count = $INSTANCE_COUNT

availability_zones    = $AZS
dedicated_master      = $DEDICATED_MASTER
master_instance_type  = "$MASTER_TYPE"
master_instance_count = $MASTER_COUNT

volume_type = "$VOLUME_TYPE"
volume_size = $VOLUME_SIZE
iops        = $IOPS
throughput  = $THROUGHPUT

ultrawarm_enabled   = $WARM_ENABLED
warm_instance_type  = "$WARM_TYPE"
warm_instance_count = $WARM_COUNT

encrypt_at_rest           = $ENCRYPT
node_to_node_encryption   = $NODE_ENCRYPT
enforce_https             = $ENFORCE_HTTPS
advanced_security_enabled = $ADV_SECURITY

custom_endpoint_enabled = $CUSTOM_EP
custom_endpoint         = "$CUSTOM_EP_VAL"
certificate_arn         = "$CERT_ARN"

vpc_id            = "$VPC_ID"
subnet_ids        = $SUBNET_IDS
security_group_id = "$SG_ID"
kms_key_id        = "$KMS_KEY"

tags = {}
EOF

    echo "Generated tfvars at: $TF_VAR_FILE"
else
    echo "tfvars file found: $TF_VAR_FILE"
fi

# Step 1: Backup current configuration
echo "1. Creating configuration backup..."
BACKUP_FILE="$WORKSPACE_ROOT/backup-${DOMAIN_NAME}-$(date +%Y%m%d-%H%M%S).json"
if aws opensearch describe-domain --domain-name "$DOMAIN_NAME" --region "$REGION" $AWS_PROFILE_FLAG > "$BACKUP_FILE" 2>/dev/null; then
    echo "Configuration backed up to: $BACKUP_FILE"
else
    echo "WARNING: Failed to backup domain config."
fi

# All terraform commands run from the terraform/ directory
cd "$TERRAFORM_DIR"
echo "Working directory: $(pwd)"

# Step 2: Initialize Terraform
echo "2. Initializing Terraform..."
if terraform init -input=false; then
    echo "Terraform initialized successfully"
else
    echo "ERROR: Terraform initialization failed"
    exit 1
fi

# Step 3: Import domain
echo "3. Importing OpenSearch domain..."
if terraform import -var-file="$TF_VAR_FILE" aws_opensearch_domain.main "$DOMAIN_NAME"; then
    echo "OpenSearch domain imported successfully"
else
    echo "WARNING: Domain import failed (may already be imported, or domain doesn't exist)"
fi

# Step 4: Import CloudWatch log groups
echo "4. Importing CloudWatch log groups..."
declare -a LOG_TYPES=("application" "search" "index")
declare -a LOG_RESOURCE_NAMES=("application_logs" "search_logs" "index_logs")

for i in "${!LOG_TYPES[@]}"; do
    LOG_TYPE="${LOG_TYPES[$i]}"
    RESOURCE_NAME="${LOG_RESOURCE_NAMES[$i]}"
    LOG_GROUP_NAME="/aws/opensearch/domains/$DOMAIN_NAME/${LOG_TYPE}-logs"

    if aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP_NAME" --region "$REGION" $AWS_PROFILE_FLAG \
        --query 'logGroups[?logGroupName==`'"$LOG_GROUP_NAME"'`]' --output text | grep -q "$LOG_GROUP_NAME"; then
        if terraform import -var-file="$TF_VAR_FILE" "aws_cloudwatch_log_group.${RESOURCE_NAME}" "$LOG_GROUP_NAME"; then
            echo "${LOG_TYPE} logs imported"
        else
            echo "WARNING: ${LOG_TYPE} logs import failed (may already be imported)"
        fi
    else
        echo "Log group not found, skipping: $LOG_GROUP_NAME"
    fi
done

# Step 5: Import Secrets Manager
echo "5. Checking Secrets Manager..."
SECRET_NAME="${DOMAIN_NAME}-master-credentials"
if aws secretsmanager describe-secret --secret-id "$SECRET_NAME" --region "$REGION" $AWS_PROFILE_FLAG > /dev/null 2>&1; then
    if terraform import -var-file="$TF_VAR_FILE" aws_secretsmanager_secret.master_credentials "$SECRET_NAME"; then
        echo "Secret imported"
    else
        echo "WARNING: Secret import failed (may already be imported)"
    fi

    VERSION_ID=$(aws secretsmanager describe-secret --secret-id "$SECRET_NAME" --region "$REGION" $AWS_PROFILE_FLAG \
        --query 'VersionIdsToStages.keys(@)[0]' --output text 2>/dev/null)
    if [ -n "$VERSION_ID" ] && [ "$VERSION_ID" != "None" ]; then
        terraform import -var-file="$TF_VAR_FILE" \
            "aws_secretsmanager_secret_version.master_credentials" "${SECRET_NAME}|${VERSION_ID}" \
            && echo "Secret version imported" || echo "WARNING: Secret version import failed"
    fi
else
    echo "No secret found: $SECRET_NAME"
fi

# Step 6: Terraform plan
echo "6. Generating terraform plan..."
set +e
terraform plan -var-file="$TF_VAR_FILE" -out=import-plan -detailed-exitcode
PLAN_EXIT_CODE=$?
set -e
case $PLAN_EXIT_CODE in
    0) echo "No changes needed - infrastructure matches configuration" ;;
    2) echo "Plan generated with changes - review import-plan" ;;
    *) echo "WARNING: Plan had issues (exit code: $PLAN_EXIT_CODE) - review output above" ;;
esac

# Return to workspace root for backup script
cd "$WORKSPACE_ROOT"

# Step 7: Backup state
echo "7. Backing up state..."
if [ -f "scripts/backup-state-to-github.sh" ]; then
    chmod +x scripts/backup-state-to-github.sh
    ./scripts/backup-state-to-github.sh && echo "State backed up" || echo "WARNING: State backup failed"
else
    echo "No backup script found"
fi

echo ""
echo "Import process completed!"
echo ""
echo "Summary:"
echo "  - Domain:  $DOMAIN_NAME"
echo "  - Region:  $REGION"
[ -f "$BACKUP_FILE" ] && echo "  - Backup:  $BACKUP_FILE"
[ -f "$TERRAFORM_DIR/import-plan" ] && echo "  - Plan:    $TERRAFORM_DIR/import-plan"
echo ""
echo "Next steps:"
echo "  1. Review: cd terraform && terraform show import-plan"
echo "  2. Check for drift or missing resources"
echo "  3. Run 'terraform apply' to align infrastructure with configuration"
echo ""
echo "IMPORTANT: Review all imported resources before applying changes!"

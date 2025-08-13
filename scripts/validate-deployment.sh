#!/bin/bash
set -e

DOMAIN_NAME="imiconnect-uk-prod"
REGION="eu-west-1"

echo "=== Validating Deployment ==="

# Check Terraform plan
echo "1. Checking Terraform plan..."
cd terraform
terraform plan -var-file="../regions/eu-west-1/terraform.tfvars" -detailed-exitcode

PLAN_EXIT_CODE=$?
if [ $PLAN_EXIT_CODE -eq 0 ]; then
    echo "✅ No changes detected - configuration matches!"
elif [ $PLAN_EXIT_CODE -eq 2 ]; then
    echo "⚠️  Changes detected - review plan output"
else
    echo "❌ Error in Terraform plan"
    exit 1
fi

# Check domain health
echo "2. Checking domain health..."
DOMAIN_STATUS=$(aws opensearch describe-domain --domain-name "$DOMAIN_NAME" --region $REGION)
PROCESSING=$(echo "$DOMAIN_STATUS" | jq -r '.DomainStatus.Processing')

if [ "$PROCESSING" = "false" ]; then
    echo "✅ Domain is healthy and stable"
else
    echo "⚠️  Domain is currently processing changes"
fi

# Test custom endpoint
echo "3. Testing custom endpoint..."
CUSTOM_ENDPOINT=$(echo "$DOMAIN_STATUS" | jq -r '.DomainStatus.DomainEndpointOptions.CustomEndpoint')
if [ "$CUSTOM_ENDPOINT" != "null" ]; then
    echo "✅ Custom endpoint: https://$CUSTOM_ENDPOINT"
fi

echo "✅ Validation completed!"

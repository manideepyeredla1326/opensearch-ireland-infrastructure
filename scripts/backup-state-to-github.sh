#!/bin/bash
set -e

ENVIRONMENT="ireland"
STATE_REPO_PATH=${STATE_REPO_PATH:-"../opensearch-terraform-state"}
GPG_RECIPIENT=${GPG_RECIPIENT:-"myeredla@cisco.com"}

echo "=== Backing up Terraform State to GitHub ==="

cd terraform

if [ ! -f "terraform.tfstate" ]; then
    echo "❌ No terraform.tfstate file found"
    exit 1
fi

# Create encrypted backup
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
ENCRYPTED_NAME="terraform-state-${TIMESTAMP}.tfstate.gpg"

echo "1. Encrypting state file..."
gpg --trust-model always --encrypt --armor \
    --recipient "$GPG_RECIPIENT" \
    --output "/tmp/${ENCRYPTED_NAME}" \
    terraform.tfstate

# Navigate to state repository
echo "2. Committing to GitHub..."
cd "$STATE_REPO_PATH"
git config pull.rebase false
    git pull origin main || true

# Copy encrypted state
cp "/tmp/${ENCRYPTED_NAME}" "environments/${ENVIRONMENT}/encrypted-states/"

# Create metadata
cat > "environments/${ENVIRONMENT}/metadata/state-info-${TIMESTAMP}.json" << METADATA_EOF
{
  "timestamp": "${TIMESTAMP}",
  "environment": "${ENVIRONMENT}",
  "encrypted_file": "${ENCRYPTED_NAME}",
  "created_by": "$(git config user.name)",
  "terraform_version": "$(terraform version -json | jq -r '.terraform_version')"
}
METADATA_EOF

# Update latest reference
cat > "environments/${ENVIRONMENT}/metadata/latest.json" << LATEST_EOF
{
  "latest_backup": "${ENCRYPTED_NAME}",
  "timestamp": "${TIMESTAMP}"
}
LATEST_EOF

# Commit to GitHub
git add .
git commit -m "Backup Ireland OpenSearch state - ${TIMESTAMP}"
git push origin main

# Cleanup
rm -f "/tmp/${ENCRYPTED_NAME}"

echo "✅ State backed up to GitHub!"

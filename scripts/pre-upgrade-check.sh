#!/bin/bash

DOMAIN_NAME="imiconnect-uk-prod"
REGION="eu-west-1"
TARGET_VERSION=$1

if [ -z "$TARGET_VERSION" ]; then
    echo "Usage: $0 <target_version>"
    echo "Example: $0 OpenSearch_2.13"
    exit 1
fi

echo "=== Pre-Upgrade Check ==="
echo "Target Version: $TARGET_VERSION"

# Check compatibility
echo "1. Checking version compatibility..."
COMPATIBLE=$(aws opensearch get-compatible-versions --domain-name "$DOMAIN_NAME" --region $REGION --query "CompatibleVersions[0].TargetVersions[?contains(@, '$TARGET_VERSION')]" --output text)

if [ -n "$COMPATIBLE" ]; then
    echo "✅ Upgrade to $TARGET_VERSION is compatible"
else
    echo "❌ Upgrade to $TARGET_VERSION is not compatible"
    echo "Available versions:"
    aws opensearch get-compatible-versions --domain-name "$DOMAIN_NAME" --region $REGION --query 'CompatibleVersions[0].TargetVersions' --output table
    exit 1
fi

# Check cluster health
echo "2. Checking cluster health..."
PROCESSING=$(aws opensearch describe-domain --domain-name "$DOMAIN_NAME" --region $REGION --query 'DomainStatus.Processing' --output text)
if [ "$PROCESSING" = "true" ]; then
    echo "❌ Cluster is currently processing changes. Wait before upgrading."
    exit 1
else
    echo "✅ Cluster is stable"
fi

echo "✅ Pre-upgrade check completed successfully"

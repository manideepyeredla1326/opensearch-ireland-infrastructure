#!/bin/bash
# scripts/discover-existing-cluster.sh

DOMAIN_NAME="imiconnect-uk-prod"
REGION="eu-west-1"

echo "=== OpenSearch Cluster Discovery ==="
echo "Domain: $DOMAIN_NAME"
echo "Region: $REGION"
echo

# Get domain details
aws opensearch describe-domain --domain-name "$DOMAIN_NAME" --region $REGION > "domain-config.json"

# Extract key information
echo "Current Configuration:"
echo "===================="
jq -r '.DomainStatus | {
    DomainName: .DomainName,
    EngineVersion: .EngineVersion,
    InstanceType: .ClusterConfig.InstanceType,
    InstanceCount: .ClusterConfig.InstanceCount,
    MasterInstanceType: .ClusterConfig.MasterInstanceType,
    MasterInstanceCount: .ClusterConfig.MasterInstanceCount,
    VolumeType: .EBSOptions.VolumeType,
    VolumeSize: .EBSOptions.VolumeSize,
    Iops: .EBSOptions.Iops,
    Throughput: .EBSOptions.Throughput,
    UltraWarmEnabled: .ClusterConfig.WarmEnabled,
    UltraWarmCount: .ClusterConfig.WarmCount,
    CustomEndpoint: .DomainEndpointOptions.CustomEndpoint,
    VPCId: .VPCOptions.VPCId,
    SubnetIds: .VPCOptions.SubnetIds,
    SecurityGroupIds: .VPCOptions.SecurityGroupIds
}' domain-config.json

echo "✅ Discovery completed!"
echo "Configuration saved to: domain-config.json"

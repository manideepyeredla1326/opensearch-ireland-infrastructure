# QA Region Configuration
aws_region  = "us-east-1"
region_name = "qa"
aws_profile = "imiconnect-qa" # Add this line to specify the AWS profile
domain_name = "connect-qa-new"
engine_version = "OpenSearch_1.3"

# Instance Configuration
instance_type      = "i3.large.search"
instance_count     = 1
availability_zones = ["us-east-1a"]

# Master Configuration
dedicated_master       = false
master_instance_type   = "c5.xlarge.search"
master_instance_count  = 3

# Storage Configuration
volume_type = null # No EBS enabled, so volume_type is not required
volume_size = null # No EBS enabled, so volume_size is not required
iops        = null # No EBS enabled, so iops is not required
throughput  = null # No EBS enabled, so throughput is not required

# UltraWarm Configuration
ultrawarm_enabled     = false
warm_instance_type    = null # No UltraWarm enabled
warm_instance_count   = null # No UltraWarm enabled

# Security Configuration
encrypt_at_rest            = true
node_to_node_encryption    = true
enforce_https              = true
advanced_security_enabled  = false

# Custom Endpoint
custom_endpoint_enabled = false
custom_endpoint        = null # No custom endpoint enabled
certificate_arn        = null # No custom endpoint enabled

# VPC Configuration
vpc_id             = "vpc-0fc14de788d14dbf4"
subnet_ids         = ["subnet-085a97b29f1846607"]
security_group_id  = "sg-0a62349ce6afbf6f5"

# KMS Configuration
kms_key_id = "arn:aws:kms:us-east-1:845515228646:key/b6f22c31-88ca-421d-bc86-c526f4695218"

# Tags
tags = {
  Environment = "qa"
  Project     = "connect-qa-new"
  # Other tags were not in the provided output, but you can add them here
}
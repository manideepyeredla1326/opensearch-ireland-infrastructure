
# Ireland Region Configuration
aws_region  = "eu-west-1"
region_name = "ireland"
aws_profile = "connect-prod-1" # Add this line to specify the AWS profile
domain_name = "imiconnect-uk-prod"
engine_version = "OpenSearch_2.11"

# Instance Configuration
instance_type      = "m6g.4xlarge.search"
instance_count     = 6
availability_zones = ["eu-west-1a", "eu-west-1b"]

# Master Configuration
dedicated_master       = true
master_instance_type   = "m6g.xlarge.search"
master_instance_count  = 3

# Storage Configuration
volume_type = "gp3"
volume_size = 3584
iops        = 20000
throughput  = 593

# UltraWarm Configuration
ultrawarm_enabled     = true
warm_instance_type    = "ultrawarm1.large.search"
warm_instance_count   = 2

# Security Configuration
encrypt_at_rest            = true
node_to_node_encryption    = true
enforce_https              = true
advanced_security_enabled  = true

# Custom Endpoint
custom_endpoint_enabled = true
custom_endpoint        = "esapi-uk.imiconnect.io"
certificate_arn        = "arn:aws:acm:eu-west-1:220067597209:certificate/16a66133-1f40-4029-bfa6-13260508bb29"

# VPC Configuration
vpc_id             = "vpc-59f27d3d"
subnet_ids         = ["subnet-6a402e0e", "subnet-e34dd695"]
security_group_id  = "sg-2bf3fc4c"

# KMS Configuration
kms_key_id = "arn:aws:kms:eu-west-1:220067597209:key/a5dcf83e-bb00-4764-aa6c-f7c1c81e7439"

# Tags
tags = {
  Environment = "production"
  Region      = "ireland"
  Project     = "imiconnect-opensearch"
  ManagedBy   = "terraform"
  Owner       = "myeredla@cisco.com"
}

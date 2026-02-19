domain_name    = "connect-qa"
aws_region     = "us-east-1"
region_name    = "us-east-1"
aws_profile    = "imiconnect-qa"

engine_version = "OpenSearch_1.3"
instance_type  = "m6g.xlarge.search"
instance_count = 1

availability_zones    = ["us-east-1a"]
dedicated_master      = false
master_instance_type  = "m6g.large.search"
master_instance_count = 3

volume_type = "gp3"
volume_size = 500
iops        = 3000
throughput  = 300

ultrawarm_enabled   = false
warm_instance_type  = ""
warm_instance_count = 0

encrypt_at_rest           = true
node_to_node_encryption   = true
enforce_https             = true
advanced_security_enabled = false

custom_endpoint_enabled = true
custom_endpoint         = "esapi.webexconnect.link"
certificate_arn         = "arn:aws:acm:us-east-1:845515228646:certificate/fc61e767-3709-4cdd-9dab-eed5b95d3289"

vpc_id            = "vpc-0fc14de788d14dbf4"
subnet_ids        = ["subnet-03344dcf19fcdeee0"]
security_group_id = "sg-0a62349ce6afbf6f5"
kms_key_id        = "arn:aws:kms:us-east-1:845515228646:key/b6f22c31-88ca-421d-bc86-c526f4695218"

tags = {}

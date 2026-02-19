domain_name    = "imimonitor"
aws_region     = "eu-west-1"
region_name    = "eu-west-1"
aws_profile    = "imimonitor"

engine_version = "OpenSearch_2.13"
instance_type  = "r5.2xlarge.search"
instance_count = 2

availability_zones    = ["eu-west-1a","eu-west-1b"]
dedicated_master      = true
master_instance_type  = "m5.large.search"
master_instance_count = 3

volume_type = "gp3"
volume_size = 500
iops        = 3000
throughput  = 299

ultrawarm_enabled   = false
warm_instance_type  = ""
warm_instance_count = 0

encrypt_at_rest           = true
node_to_node_encryption   = true
enforce_https             = true
advanced_security_enabled = true

custom_endpoint_enabled = false
custom_endpoint         = ""
certificate_arn         = ""

vpc_id            = "vpc-f7ee3991"
subnet_ids        = ["subnet-052b67d1e846f6a1d","subnet-1ef70278"]
security_group_id = "sg-e29a4798"
kms_key_id        = "arn:aws:kms:eu-west-1:483718609292:key/9b0f29d2-4317-40c7-baf4-802702d94847"

tags = {}

domain_name    = "imiconnect-ln-prod"
aws_region     = "eu-west-2"
region_name    = "eu-west-2"
aws_profile    = "connect-london"

engine_version = "OpenSearch_1.3"
instance_type  = "r6g.xlarge.search"
instance_count = 2

availability_zones    = ["eu-west-2a","eu-west-2b"]
dedicated_master      = true
master_instance_type  = "c6g.xlarge.search"
master_instance_count = 3

volume_type = "gp3"
volume_size = 1024
iops        = 5000
throughput  = 250

ultrawarm_enabled   = false
warm_instance_type  = ""
warm_instance_count = 0

encrypt_at_rest           = true
node_to_node_encryption   = true
enforce_https             = true
advanced_security_enabled = true

custom_endpoint_enabled = true
custom_endpoint         = "esapi-ln.imiconnect.eu"
certificate_arn         = "arn:aws:acm:eu-west-2:345960079547:certificate/8fc27fa4-116f-430e-ae32-363c81dd5456"

vpc_id            = "vpc-01b1e7c86f9ca1db5"
subnet_ids        = ["subnet-04884b141d34901fe","subnet-0983778be2a93a85c"]
security_group_id = "sg-0db044c0ee405f06f"
kms_key_id        = "arn:aws:kms:eu-west-2:345960079547:key/a283e1d1-7473-4d66-b6c8-c71fef58aca9"

tags = {}

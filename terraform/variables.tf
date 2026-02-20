variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "region_name" {
  description = "Region friendly name"
  type        = string
}

variable "domain_name" {
  description = "OpenSearch domain name"
  type        = string
}

variable "engine_version" {
  description = "OpenSearch engine version"
  type        = string
}

variable "instance_type" {
  description = "Instance type for data nodes"
  type        = string
}

variable "instance_count" {
  description = "Number of data nodes"
  type        = number
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
}

variable "dedicated_master" {
  description = "Enable dedicated master nodes"
  type        = bool
}

variable "master_instance_type" {
  description = "Master instance type"
  type        = string
}

variable "master_instance_count" {
  description = "Number of master nodes"
  type        = number
}

variable "volume_type" {
  description = "EBS volume type"
  type        = string
}

variable "volume_size" {
  description = "EBS volume size in GB"
  type        = number
}

variable "iops" {
  description = "Provisioned IOPS"
  type        = number
}

variable "throughput" {
  description = "Provisioned throughput"
  type        = number
}

variable "ultrawarm_enabled" {
  description = "Enable UltraWarm"
  type        = bool
}

variable "warm_instance_type" {
  description = "UltraWarm instance type"
  type        = string
}

variable "warm_instance_count" {
  description = "Number of UltraWarm nodes"
  type        = number
}

variable "encrypt_at_rest" {
  description = "Enable encryption at rest"
  type        = bool
}

variable "node_to_node_encryption" {
  description = "Enable node-to-node encryption"
  type        = bool
}

variable "enforce_https" {
  description = "Enforce HTTPS"
  type        = bool
}

variable "advanced_security_enabled" {
  description = "Enable fine-grained access control"
  type        = bool
}

variable "custom_endpoint_enabled" {
  description = "Enable custom endpoint"
  type        = bool
}

variable "custom_endpoint" {
  description = "Custom endpoint domain"
  type        = string
}

variable "certificate_arn" {
  description = "SSL certificate ARN"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID"
  type        = string
}

variable "kms_key_id" {
  description = "KMS key ID"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
}

variable "aws_profile" {
  description = "AWS profile name to use"
  type        = string
}

variable "master_user_password" {
  description = "Master user password (only used when advanced_security_enabled = true)"
  type        = string
  sensitive   = true
  default     = ""
}

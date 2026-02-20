# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# OpenSearch Domain
resource "aws_opensearch_domain" "main" {
  domain_name    = var.domain_name
  engine_version = var.engine_version

  cluster_config {
    instance_type            = var.instance_type
    instance_count           = var.instance_count
    dedicated_master_enabled = var.dedicated_master
    dedicated_master_type    = var.master_instance_type
    dedicated_master_count   = var.master_instance_count

    zone_awareness_enabled = length(var.availability_zones) > 1

    dynamic "zone_awareness_config" {
      for_each = length(var.availability_zones) > 1 ? [1] : []
      content {
        availability_zone_count = length(var.availability_zones)
      }
    }

    warm_enabled = var.ultrawarm_enabled
    warm_count   = var.ultrawarm_enabled ? var.warm_instance_count : null
    warm_type    = var.ultrawarm_enabled ? var.warm_instance_type : null
  }

  ebs_options {
    ebs_enabled = true
    volume_type = var.volume_type
    volume_size = var.volume_size
    iops        = var.iops
    throughput  = var.throughput
  }

  encrypt_at_rest {
    enabled    = var.encrypt_at_rest
    kms_key_id = var.kms_key_id
  }

  node_to_node_encryption {
    enabled = var.node_to_node_encryption
  }

  domain_endpoint_options {
    enforce_https                   = var.enforce_https
    tls_security_policy             = "Policy-Min-TLS-1-2-2019-07"
    custom_endpoint_enabled         = var.custom_endpoint_enabled
    custom_endpoint                 = var.custom_endpoint_enabled ? var.custom_endpoint : null
    custom_endpoint_certificate_arn = var.custom_endpoint_enabled ? var.certificate_arn : null
  }

  vpc_options {
    subnet_ids         = var.subnet_ids
    security_group_ids = [var.security_group_id]
  }

  advanced_security_options {
    enabled                        = var.advanced_security_enabled
    internal_user_database_enabled = var.advanced_security_enabled

    dynamic "master_user_options" {
      for_each = var.advanced_security_enabled ? [1] : []
      content {
        master_user_name     = "admin"
        master_user_password = var.master_user_password
      }
    }
  }

  snapshot_options {
    automated_snapshot_start_hour = 0
  }

  tags = var.tags
}

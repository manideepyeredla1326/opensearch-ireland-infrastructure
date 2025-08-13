# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Random password for master user
resource "random_password" "master_user_password" {
  length  = 32
  special = true
}

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
    
    zone_awareness_enabled   = true
    
    zone_awareness_config {
      availability_zone_count = length(var.availability_zones)
    }
    
    // UltraWarm configuration
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
    internal_user_database_enabled = true
    
    master_user_options {
      master_user_name     = "admin"
      master_user_password = random_password.master_user_password.result
    }
  }
  
  # CloudWatch logging
  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.application_logs.arn
    log_type                 = "ES_APPLICATION_LOGS"
    enabled                  = true
  }
  
  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.search_logs.arn
    log_type                 = "SEARCH_SLOW_LOGS"
    enabled                  = true
  }
  
  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.index_logs.arn
    log_type                 = "INDEX_SLOW_LOGS"
    enabled                  = true
  }
  
  snapshot_options {
    automated_snapshot_start_hour = 0
  }
  
  tags = var.tags
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "application_logs" {
  name              = "/aws/opensearch/domains/${var.domain_name}/application-logs"
  retention_in_days = 14
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "search_logs" {
  name              = "/aws/opensearch/domains/${var.domain_name}/search-logs"
  retention_in_days = 7
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "index_logs" {
  name              = "/aws/opensearch/domains/${var.domain_name}/index-logs"
  retention_in_days = 7
  tags              = var.tags
}

# Store master user credentials in Secrets Manager
resource "aws_secretsmanager_secret" "master_credentials" {
  name        = "${var.domain_name}-master-credentials"
  description = "OpenSearch master user credentials"
  tags        = var.tags
}

resource "aws_secretsmanager_secret_version" "master_credentials" {
  secret_id = aws_secretsmanager_secret.master_credentials.id
  secret_string = jsonencode({
    username        = "admin"
    password        = random_password.master_user_password.result
    domain          = aws_opensearch_domain.main.domain_name
    endpoint        = aws_opensearch_domain.main.endpoint
    custom_endpoint = var.custom_endpoint_enabled ? "https://${var.custom_endpoint}" : null
  })
}
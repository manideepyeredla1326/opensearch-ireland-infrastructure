output "domain_arn" {
  description = "ARN of the OpenSearch domain"
  value       = aws_opensearch_domain.main.arn
}

output "domain_id" {
  description = "Unique identifier for the OpenSearch domain"
  value       = aws_opensearch_domain.main.domain_id
}

output "domain_name" {
  description = "Name of the OpenSearch domain"
  value       = aws_opensearch_domain.main.domain_name
}

output "domain_endpoint" {
  description = "Domain-specific endpoint used to submit index, search, and data upload requests"
  value       = aws_opensearch_domain.main.endpoint
}

output "kibana_endpoint" {
  description = "Domain-specific endpoint for Kibana without https scheme"
  value       = aws_opensearch_domain.main.kibana_endpoint
}

output "custom_endpoint" {
  description = "Custom endpoint for the OpenSearch domain"
  value       = var.custom_endpoint_enabled ? "https://${var.custom_endpoint}" : null
}

output "master_user_secret_arn" {
  description = "ARN of the secret containing master user credentials"
  value       = aws_secretsmanager_secret.master_credentials.arn
  sensitive   = true
}

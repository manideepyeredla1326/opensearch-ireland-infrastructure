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
  description = "Domain-specific endpoint for submitting requests"
  value       = aws_opensearch_domain.main.endpoint
}

output "dashboard_endpoint" {
  description = "Domain-specific endpoint for OpenSearch Dashboards"
  value       = aws_opensearch_domain.main.dashboard_endpoint
}

output "custom_endpoint" {
  description = "Custom endpoint for the OpenSearch domain"
  value       = var.custom_endpoint_enabled ? "https://${var.custom_endpoint}" : null
}

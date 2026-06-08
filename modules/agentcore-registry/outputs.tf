output "registry_id" {
  description = "ID of the registry the records belong to."
  value       = local.registry_id
}

output "registry_arn" {
  description = "ARN of the registry (only when the module creates it)."
  value       = var.create_registry ? agentcore_registry.this[0].arn : null
}

output "registry_name" {
  description = "Name of the registry (only when the module creates it)."
  value       = var.create_registry ? agentcore_registry.this[0].name : null
}

output "record_ids" {
  description = "Map of record name to record ID."
  value       = { for k, r in agentcore_registry_record.this : k => r.id }
}

output "record_arns" {
  description = "Map of record name to record ARN."
  value       = { for k, r in agentcore_registry_record.this : k => r.arn }
}

output "record_statuses" {
  description = "Map of record name to current status (e.g. DRAFT, PENDING_APPROVAL, APPROVED)."
  value       = { for k, r in agentcore_registry_record.this : k => r.status }
}

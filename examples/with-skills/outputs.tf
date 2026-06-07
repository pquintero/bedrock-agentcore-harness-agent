output "harness_arn" {
  description = "ARN of the harness. Use with InvokeHarness."
  value       = module.data_engineer_agent.harness_arn
}

output "harness_id" {
  description = "Unique identifier of the harness."
  value       = module.data_engineer_agent.harness_id
}

output "execution_role_arn" {
  description = "ARN of the execution role assumed by the harness."
  value       = module.data_engineer_agent.execution_role_arn
}

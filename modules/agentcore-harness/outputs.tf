output "harness_id" {
  description = "Unique identifier of the AgentCore Harness."
  value       = aws_bedrockagentcore_harness.this.harness_id
}

output "harness_arn" {
  description = "ARN of the AgentCore Harness. Use this when calling InvokeHarness."
  value       = aws_bedrockagentcore_harness.this.arn
}

output "harness_name" {
  description = "Name of the AgentCore Harness."
  value       = aws_bedrockagentcore_harness.this.harness_name
}

output "execution_role_arn" {
  description = "ARN of the IAM execution role assumed by the harness."
  value       = local.execution_role_arn
}

output "execution_role_name" {
  description = "Name of the IAM execution role created by the module (null when bringing your own role)."
  value       = local.create_role ? aws_iam_role.this[0].name : null
}

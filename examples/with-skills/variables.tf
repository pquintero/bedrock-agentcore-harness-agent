variable "container_uri" {
  description = <<-EOT
    ECR URI of the custom container image (linux/arm64) that bundles the Data
    Engineer Agent Skills under ".agents/skills/<name>". For example:
    123456789012.dkr.ecr.us-east-1.amazonaws.com/data-engineer-agent:latest
  EOT
  type        = string
}

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # The aws_bedrockagentcore_harness resource was introduced in v6.49.0.
      version = ">= 6.49.0"
    }
  }
}

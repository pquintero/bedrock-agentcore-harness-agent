###############################################################################
# Basic example: a minimal harness with the default Bedrock model and the
# module-managed execution role.
###############################################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.49.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

module "research_agent" {
  source = "../../modules/agentcore-harness"

  harness_name = "research_agent"

  model = {
    bedrock = {
      model_id = "anthropic.claude-sonnet-4-20250514"
    }
  }

  system_prompt = [
    "You are a helpful research assistant. Be concise and cite sources."
  ]

  tags = {
    Project = "agentcore-demo"
    Env     = "dev"
  }
}

output "harness_arn" {
  value = module.research_agent.harness_arn
}

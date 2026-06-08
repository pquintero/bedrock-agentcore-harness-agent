###############################################################################
# Complete example: a harness with built-in tools (browser + code interpreter),
# an inline function, execution limits, sliding-window truncation, and the
# matching IAM permissions enabled on the module-managed execution role.
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

module "coding_agent" {
  source = "../../modules/agentcore-harness"

  harness_name = "coding_agent_dm"

  model = {
    bedrock = {
      model_id    = "anthropic.claude-sonnet-4-20250514"
      temperature = 0.7
      top_p       = 0.9
    }
  }

  system_prompt = [
    "You are an expert coding assistant.",
    "Prefer small, well-tested changes and explain your reasoning.",
  ]

  # Execution limits
  allowed_tools   = ["*"]
  max_iterations  = 10
  max_tokens      = 4096
  timeout_seconds = 300

  # Grant the execution role the permissions the built-in tools need.
  enable_browser_permissions          = true
  enable_code_interpreter_permissions = true

  tools = [
    {
      type              = "agentcore_browser"
      name              = "browser"
      agentcore_browser = {}
    },
    {
      type                       = "agentcore_code_interpreter"
      name                       = "code_interpreter"
      agentcore_code_interpreter = {}
    },
    {
      type = "inline_function"
      name = "get_weather"
      inline_function = {
        description = "Get the current weather for a location"
        input_schema = jsonencode({
          type = "object"
          properties = {
            location = {
              type        = "string"
              description = "City name"
            }
          }
          required = ["location"]
        })
      }
    },
  ]

  truncation = {
    strategy = "sliding_window"
    sliding_window = {
      messages_count = 50
    }
  }

  tags = {
    Project = "agentcore-demo"
    Env     = "dev"
  }
}

output "harness_arn" {
  value = module.coding_agent.harness_arn
}

output "execution_role_arn" {
  value = module.coding_agent.execution_role_arn
}

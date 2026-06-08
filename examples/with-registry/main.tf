###############################################################################
# With-registry example: deploy a harness agent and register it in the
# AWS Agent Registry as an A2A agent record, using the native agentcore provider.
#
# The agentcore provider is not published yet. Build it and use dev_overrides:
#   cd terraform-provider-agentcore && make install
#   BIN="$(go env GOBIN)"; [ -z "$BIN" ] && BIN="$(go env GOPATH)/bin"
#   sed "s#<GOBIN>#${BIN}#" ../../terraform-provider-agentcore/examples/registry/dev.tfrc.example > dev.tfrc
#   export TF_CLI_CONFIG_FILE="$(pwd)/dev.tfrc"
#   terraform plan        # no `terraform init` needed with dev_overrides
###############################################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.49.0"
    }
    agentcore = {
      source = "pquintero/agentcore"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

provider "agentcore" {
  region = "us-east-1"
}

locals {
  harness_name = "registry_demo_agent"
}

# 1) Deploy the harness agent.
module "harness" {
  source = "../../modules/agentcore-harness"

  harness_name = local.harness_name

  model = {
    bedrock = {
      model_id = "anthropic.claude-sonnet-4-20250514"
    }
  }

  system_prompt = [
    "You are a helpful assistant that answers questions about company data."
  ]

  tags = {
    Project = "agentcore-demo"
    Env     = "dev"
  }
}

# A2A agent card describing the agent. Must comply with the A2A schema (0.3).
locals {
  agent_card = {
    protocolVersion    = "0.3.0"
    name               = local.harness_name
    description        = "Demo harness agent registered via Terraform."
    url                = module.harness.harness_arn
    version            = "1.0.0"
    preferredTransport = "JSONRPC"
    capabilities = {
      streaming = true
    }
    defaultInputModes  = ["text/plain"]
    defaultOutputModes = ["text/plain"]
    skills = [
      {
        id          = "general-qa"
        name        = "General Q&A"
        description = "Answers general questions about company data."
        tags        = ["qa", "demo"]
      }
    ]
  }
}

# 2) Create a registry and register the agent as an A2A record.
module "registry" {
  source = "../../modules/agentcore-registry"

  registry_name        = "agentcore_demo_registry"
  registry_description = "Demo registry created with Terraform"

  # Auto-approve so the submitted record becomes discoverable immediately.
  auto_approval = true

  records = [
    {
      name            = local.harness_name
      descriptor_type = "A2A"
      record_version  = "1.0.0"
      description     = "Demo harness agent (A2A card)."
      descriptors = {
        a2a = {
          agent_card = {
            schema_version = "0.3"
            inline_content = jsonencode(local.agent_card)
          }
        }
      }
      submit_for_approval = true
    },
  ]
}

output "harness_arn" {
  value = module.harness.harness_arn
}

output "registry_arn" {
  value = module.registry.registry_arn
}

output "record_arns" {
  value = module.registry.record_arns
}

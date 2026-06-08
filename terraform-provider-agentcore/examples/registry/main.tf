###############################################################################
# Example usage of the agentcore provider: create a registry and register an
# A2A agent record. Run with a dev_overrides config pointing at the locally
# built provider (see the provider README).
###############################################################################

terraform {
  required_providers {
    agentcore = {
      source = "pquintero/agentcore"
    }
  }
}

provider "agentcore" {
  region = "us-east-1"
}

resource "agentcore_registry" "this" {
  name          = "agentcore_demo_registry"
  description   = "Demo registry managed by the agentcore provider"
  auto_approval = true
}

resource "agentcore_registry_record" "agent" {
  registry_id     = agentcore_registry.this.id
  name            = "my_demo_agent"
  descriptor_type = "A2A"
  record_version  = "1.0.0"
  description     = "Demo agent registered via the native Terraform provider."

  descriptors = {
    a2a = {
      agent_card = {
        schema_version = "0.3"
        inline_content = jsonencode({
          protocolVersion    = "0.3.0"
          name               = "my_demo_agent"
          description        = "Demo agent"
          url                = "arn:aws:bedrock-agentcore:us-east-1:123456789012:harness/my_demo_agent-XXXX"
          version            = "1.0.0"
          preferredTransport = "JSONRPC"
          capabilities       = { streaming = true }
          defaultInputModes  = ["text/plain"]
          defaultOutputModes = ["text/plain"]
          skills = [{
            id          = "general-qa"
            name        = "General Q&A"
            description = "Answers general questions."
            tags        = ["qa", "demo"]
          }]
        })
      }
    }
  }

  submit_for_approval = true
}

output "registry_arn" {
  value = agentcore_registry.this.arn
}

output "record_arn" {
  value = agentcore_registry_record.agent.arn
}

output "record_status" {
  value = agentcore_registry_record.agent.status
}

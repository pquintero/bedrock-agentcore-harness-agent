terraform {
  required_version = ">= 1.5.0"

  required_providers {
    # Custom provider in this repo: terraform-provider-agentcore.
    # Not published to a registry yet — use dev_overrides to point at the
    # locally built binary (see terraform-provider-agentcore/README.md).
    agentcore = {
      source = "pquintero/agentcore"
    }
  }
}

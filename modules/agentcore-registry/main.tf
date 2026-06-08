###############################################################################
# AWS Agent Registry (preview)
#
# This module manages the registry and its records using the custom
# terraform-provider-agentcore (Plugin Framework + AWS SDK for Go v2), giving a
# full declarative plan/apply/destroy lifecycle.
#
# The provider is not published yet — configure it in the root module and use
# dev_overrides to point at the locally built binary. See:
#   terraform-provider-agentcore/README.md
###############################################################################

locals {
  registry_id = var.create_registry ? agentcore_registry.this[0].id : var.existing_registry_id
  records_map = { for r in var.records : r.name => r }
}

resource "agentcore_registry" "this" {
  count = var.create_registry ? 1 : 0

  name            = var.registry_name
  description     = var.registry_description
  authorizer_type = var.authorizer_type
  auto_approval   = var.auto_approval

  lifecycle {
    precondition {
      condition     = var.registry_name != null
      error_message = "registry_name is required when create_registry is true."
    }
  }
}

resource "agentcore_registry_record" "this" {
  for_each = local.records_map

  registry_id     = local.registry_id
  name            = each.value.name
  descriptor_type = each.value.descriptor_type
  record_version  = each.value.record_version
  description     = each.value.description

  descriptors         = each.value.descriptors
  submit_for_approval = each.value.submit_for_approval

  lifecycle {
    precondition {
      condition     = var.create_registry || var.existing_registry_id != null
      error_message = "existing_registry_id is required when create_registry is false."
    }
  }
}

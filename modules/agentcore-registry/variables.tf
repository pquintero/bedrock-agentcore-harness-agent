###############################################################################
# Registry
###############################################################################

variable "create_registry" {
  description = "Whether the module creates (and owns) the registry. Set to false to register records into an existing registry referenced by existing_registry_id."
  type        = bool
  default     = true
}

variable "registry_name" {
  description = "Name of the AWS Agent Registry to create (used when create_registry is true). 1-64 chars, alphanumeric and _-./."
  type        = string
  default     = null

  validation {
    condition     = var.registry_name == null || can(regex("^[a-zA-Z0-9][a-zA-Z0-9_\\-./]{0,63}$", var.registry_name))
    error_message = "registry_name must start with an alphanumeric character and contain only a-z, A-Z, 0-9, _, -, ., / (max 64 chars)."
  }
}

variable "existing_registry_id" {
  description = "ID or ARN of an existing registry to register records into. Required when create_registry is false; ignored otherwise."
  type        = string
  default     = null
}

variable "registry_description" {
  description = "Optional description for the registry (used only when create_registry is true)."
  type        = string
  default     = null
}

variable "authorizer_type" {
  description = "Inbound authorization for the registry's search/invoke APIs: AWS_IAM or CUSTOM_JWT. Immutable after creation."
  type        = string
  default     = "AWS_IAM"

  validation {
    condition     = contains(["AWS_IAM", "CUSTOM_JWT"], var.authorizer_type)
    error_message = "authorizer_type must be either AWS_IAM or CUSTOM_JWT."
  }
}

variable "auto_approval" {
  description = "When true, submitted records are auto-approved and become discoverable; when false they go to PENDING_APPROVAL for curator approval."
  type        = bool
  default     = false
}

###############################################################################
# Records (agents/tools/skills to register)
###############################################################################

variable "records" {
  description = <<-EOT
    Registry records to create and (optionally) submit for approval.

    Each record provides exactly the descriptors block that matches its
    descriptor_type:
      - A2A           -> descriptors.a2a.agent_card
      - MCP           -> descriptors.mcp.server (+ optional descriptors.mcp.tools)
      - CUSTOM        -> descriptors.custom
      - AGENT_SKILLS  -> descriptors.agent_skills

    inline_content fields are JSON strings; use jsonencode(...) to embed objects.
  EOT
  type = list(object({
    name                = string
    descriptor_type     = string
    record_version      = optional(string)
    description         = optional(string)
    submit_for_approval = optional(bool, true)
    descriptors = object({
      a2a = optional(object({
        agent_card = object({
          schema_version = optional(string)
          inline_content = string
        })
      }))
      mcp = optional(object({
        server = object({
          schema_version = optional(string)
          inline_content = string
        })
        tools = optional(object({
          protocol_version = optional(string)
          inline_content   = string
        }))
      }))
      custom = optional(object({
        inline_content = string
      }))
      agent_skills = optional(object({
        skill_md = optional(object({
          inline_content = string
        }))
        skill_definition = optional(object({
          schema_version = optional(string)
          inline_content = string
        }))
      }))
    })
  }))
  default = []

  validation {
    condition = alltrue([
      for r in var.records : contains(["MCP", "A2A", "CUSTOM", "AGENT_SKILLS"], r.descriptor_type)
    ])
    error_message = "Each record.descriptor_type must be one of: MCP, A2A, CUSTOM, AGENT_SKILLS."
  }
}

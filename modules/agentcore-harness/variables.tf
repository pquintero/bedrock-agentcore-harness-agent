###############################################################################
# Core
###############################################################################

variable "harness_name" {
  description = "Name of the harness. Must be 1-40 characters, alphanumeric and underscores only, and start with a letter."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]{0,39}$", var.harness_name))
    error_message = "harness_name must start with a letter and contain only alphanumeric characters and underscores (max 40 chars)."
  }
}

variable "tags" {
  description = "Key-value map of tags to apply to all resources created by the module."
  type        = map(string)
  default     = {}
}

###############################################################################
# Execution role
###############################################################################

variable "create_execution_role" {
  description = "Whether the module should create the IAM execution role the harness assumes. Set to false to bring your own role via execution_role_arn."
  type        = bool
  default     = true
}

variable "execution_role_arn" {
  description = "ARN of an existing IAM role for the harness to assume. Required when create_execution_role is false; ignored otherwise."
  type        = string
  default     = null

  validation {
    condition     = var.execution_role_arn == null || can(regex("^arn:aws(-[^:]+)?:iam::[0-9]{12}:role/.+", var.execution_role_arn))
    error_message = "execution_role_arn must be a valid IAM role ARN."
  }
}

variable "execution_role_name" {
  description = "Name for the IAM execution role created by the module. Defaults to bedrock-agentcore-harness-<harness_name> when null."
  type        = string
  default     = null
}

variable "additional_execution_role_policy_arns" {
  description = "List of additional managed IAM policy ARNs to attach to the created execution role."
  type        = list(string)
  default     = []
}

variable "execution_role_inline_policy_json" {
  description = "Optional extra inline IAM policy (JSON) to attach to the created execution role for custom permissions."
  type        = string
  default     = null
}

###############################################################################
# Execution role permission toggles
###############################################################################

variable "enable_browser_permissions" {
  description = "Add AgentCore Browser permissions to the created execution role."
  type        = bool
  default     = false
}

variable "enable_code_interpreter_permissions" {
  description = "Add AgentCore Code Interpreter permissions to the created execution role."
  type        = bool
  default     = false
}

variable "enable_memory_permissions" {
  description = "Add AgentCore Memory permissions to the created execution role."
  type        = bool
  default     = false
}

variable "api_key_credential_provider_arns" {
  description = "ARNs of AgentCore Identity API key credential providers the execution role may read (for OpenAI/Gemini/LiteLLM keys)."
  type        = list(string)
  default     = []
}

###############################################################################
# Model
###############################################################################

variable "model" {
  description = <<-EOT
    Model configuration for the harness. Provide exactly one of bedrock, openai, or gemini.
    If null, the harness defaults to Anthropic Claude Sonnet on Amazon Bedrock.
  EOT
  type = object({
    bedrock = optional(object({
      model_id    = string
      max_tokens  = optional(number)
      temperature = optional(number)
      top_p       = optional(number)
    }))
    openai = optional(object({
      model_id    = string
      api_key_arn = string
      max_tokens  = optional(number)
      temperature = optional(number)
      top_p       = optional(number)
    }))
    gemini = optional(object({
      model_id    = string
      api_key_arn = string
      max_tokens  = optional(number)
      temperature = optional(number)
      top_p       = optional(number)
      top_k       = optional(number)
    }))
  })
  default = null

  validation {
    condition = var.model == null ? true : (
      length([for k, v in var.model : k if v != null]) == 1
    )
    error_message = "Provide exactly one model provider block (bedrock, openai, or gemini)."
  }
}

variable "system_prompt" {
  description = "List of system prompt text blocks defining the agent's behavior. Each entry becomes a system_prompt block."
  type        = list(string)
  default     = []
}

###############################################################################
# Tools
###############################################################################

variable "allowed_tools" {
  description = "List of tool names/glob patterns the agent is allowed to use (e.g. [\"*\"], [\"@builtin\"])."
  type        = list(string)
  default     = []
}

variable "tools" {
  description = <<-EOT
    List of tool configurations. Each item must set 'type' to one of:
    remote_mcp, agentcore_browser, agentcore_gateway, inline_function, agentcore_code_interpreter,
    and populate the matching config object.
  EOT
  type = list(object({
    type = string
    name = optional(string)

    remote_mcp = optional(object({
      url     = string
      headers = optional(map(string))
    }))

    agentcore_browser = optional(object({
      browser_arn = optional(string)
    }))

    agentcore_code_interpreter = optional(object({
      code_interpreter_arn = optional(string)
    }))

    agentcore_gateway = optional(object({
      gateway_arn = string
    }))

    inline_function = optional(object({
      description  = string
      input_schema = string
    }))
  }))
  default = []

  validation {
    condition = alltrue([
      for t in var.tools : contains(
        ["remote_mcp", "agentcore_browser", "agentcore_gateway", "inline_function", "agentcore_code_interpreter"],
        t.type
      )
    ])
    error_message = "Each tool.type must be one of: remote_mcp, agentcore_browser, agentcore_gateway, inline_function, agentcore_code_interpreter."
  }
}

###############################################################################
# Skills
###############################################################################

variable "skills" {
  description = <<-EOT
    List of paths to Agent Skills available to the harness. Each path points to a
    skill directory (containing a SKILL.md) already present in the harness
    environment, e.g. baked into a custom container image (container_uri) at a
    known path such as ".agents/skills/xlsx", or installed at session start via
    InvokeAgentRuntimeCommand. Skills configured here are passed to every
    invocation.

    Note: S3/Git skill sources are invocation-time options and are not persisted
    on the harness resource, so only path-based skills are supported here.
  EOT
  type        = list(string)
  default     = []
}

###############################################################################
# Memory
###############################################################################

variable "memory" {
  description = "AgentCore Memory configuration for persisting conversation context across sessions."
  type = object({
    arn            = string
    actor_id       = optional(string)
    messages_count = optional(number)
  })
  default = null
}

###############################################################################
# Execution limits and truncation
###############################################################################

variable "max_iterations" {
  description = "Maximum number of iterations the agent loop can perform per invocation."
  type        = number
  default     = null
}

variable "max_tokens" {
  description = "Maximum total number of output tokens across all model calls within a single invocation."
  type        = number
  default     = null
}

variable "timeout_seconds" {
  description = "Maximum duration in seconds for the agent loop execution per invocation."
  type        = number
  default     = null
}

variable "truncation" {
  description = "Truncation configuration for managing conversation context. strategy must be sliding_window, summarization, or none."
  type = object({
    strategy = string
    sliding_window = optional(object({
      messages_count = optional(number)
    }))
    summarization = optional(object({
      summary_ratio               = optional(number)
      preserve_recent_messages    = optional(number)
      summarization_system_prompt = optional(string)
    }))
  })
  default = null

  validation {
    condition     = var.truncation == null ? true : contains(["sliding_window", "summarization", "none"], var.truncation.strategy)
    error_message = "truncation.strategy must be one of: sliding_window, summarization, none."
  }
}

variable "environment_variables" {
  description = "Map of environment variables to set in the harness runtime environment."
  type        = map(string)
  default     = {}
  sensitive   = true
}

###############################################################################
# Compute environment / network
###############################################################################

variable "network_mode" {
  description = "Network mode for the harness runtime environment. Valid values: PUBLIC, VPC."
  type        = string
  default     = "PUBLIC"

  validation {
    condition     = contains(["PUBLIC", "VPC"], var.network_mode)
    error_message = "network_mode must be either PUBLIC or VPC."
  }
}

variable "vpc_config" {
  description = "VPC configuration, required when network_mode is VPC."
  type = object({
    security_groups = list(string)
    subnets         = list(string)
  })
  default = null

  validation {
    condition     = var.vpc_config == null || (try(length(var.vpc_config.subnets), 0) > 0 && try(length(var.vpc_config.security_groups), 0) > 0)
    error_message = "vpc_config must provide at least one subnet and one security group."
  }
}

variable "lifecycle_configuration" {
  description = "Optional runtime lifecycle configuration (idle/max session timeouts in seconds)."
  type = object({
    idle_runtime_session_timeout = optional(number)
    max_lifetime                 = optional(number)
  })
  default = null
}

variable "container_uri" {
  description = "Optional custom container image URI to use as the harness environment artifact."
  type        = string
  default     = null
}

###############################################################################
# Authorizer (inbound OAuth/JWT)
###############################################################################

variable "jwt_authorizer" {
  description = "Optional inbound JWT authorizer configuration. discovery_url must end with .well-known/openid-configuration."
  type = object({
    discovery_url    = string
    allowed_clients  = optional(list(string))
    allowed_audience = optional(list(string))
    allowed_scopes   = optional(list(string))
  })
  default = null
}

variable "timeouts" {
  description = "Resource operation timeouts."
  type = object({
    create = optional(string)
    update = optional(string)
    delete = optional(string)
  })
  default = null
}

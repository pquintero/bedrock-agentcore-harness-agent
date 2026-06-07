###############################################################################
# Bedrock AgentCore Harness
#
# Docs: https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/harness.html
# Resource: aws_bedrockagentcore_harness
###############################################################################

locals {
  # The provider marks `model` as required. When the caller does not supply a
  # model, fall back to Anthropic Claude Sonnet on Bedrock (the harness default).
  default_model = {
    bedrock = {
      model_id    = "anthropic.claude-sonnet-4-20250514"
      max_tokens  = null
      temperature = null
      top_p       = null
    }
    openai = null
    gemini = null
  }

  model = var.model != null ? var.model : local.default_model
}

resource "aws_bedrockagentcore_harness" "this" {
  harness_name       = var.harness_name
  execution_role_arn = local.execution_role_arn

  allowed_tools         = length(var.allowed_tools) > 0 ? var.allowed_tools : null
  max_iterations        = var.max_iterations
  max_tokens            = var.max_tokens
  timeout_seconds       = var.timeout_seconds
  environment_variables = length(var.environment_variables) > 0 ? var.environment_variables : null

  tags = var.tags

  #############################################################################
  # Model
  #############################################################################
  model {
    dynamic "bedrock_model_config" {
      for_each = try(local.model.bedrock, null) != null ? [local.model.bedrock] : []
      content {
        model_id    = bedrock_model_config.value.model_id
        max_tokens  = try(bedrock_model_config.value.max_tokens, null)
        temperature = try(bedrock_model_config.value.temperature, null)
        top_p       = try(bedrock_model_config.value.top_p, null)
      }
    }

    dynamic "openai_model_config" {
      for_each = try(local.model.openai, null) != null ? [local.model.openai] : []
      content {
        model_id    = openai_model_config.value.model_id
        api_key_arn = openai_model_config.value.api_key_arn
        max_tokens  = try(openai_model_config.value.max_tokens, null)
        temperature = try(openai_model_config.value.temperature, null)
        top_p       = try(openai_model_config.value.top_p, null)
      }
    }

    dynamic "gemini_model_config" {
      for_each = try(local.model.gemini, null) != null ? [local.model.gemini] : []
      content {
        model_id    = gemini_model_config.value.model_id
        api_key_arn = gemini_model_config.value.api_key_arn
        max_tokens  = try(gemini_model_config.value.max_tokens, null)
        temperature = try(gemini_model_config.value.temperature, null)
        top_p       = try(gemini_model_config.value.top_p, null)
        top_k       = try(gemini_model_config.value.top_k, null)
      }
    }
  }

  #############################################################################
  # System prompt
  #############################################################################
  dynamic "system_prompt" {
    for_each = var.system_prompt
    content {
      text = system_prompt.value
    }
  }

  #############################################################################
  # Tools
  #############################################################################
  dynamic "tool" {
    for_each = var.tools
    content {
      type = tool.value.type
      name = try(tool.value.name, null)

      config {
        dynamic "remote_mcp" {
          for_each = try(tool.value.remote_mcp, null) != null ? [tool.value.remote_mcp] : []
          content {
            url     = remote_mcp.value.url
            headers = try(remote_mcp.value.headers, null)
          }
        }

        dynamic "agentcore_browser" {
          for_each = try(tool.value.agentcore_browser, null) != null ? [tool.value.agentcore_browser] : []
          content {
            browser_arn = try(agentcore_browser.value.browser_arn, null)
          }
        }

        dynamic "agentcore_code_interpreter" {
          for_each = try(tool.value.agentcore_code_interpreter, null) != null ? [tool.value.agentcore_code_interpreter] : []
          content {
            code_interpreter_arn = try(agentcore_code_interpreter.value.code_interpreter_arn, null)
          }
        }

        dynamic "agentcore_gateway" {
          for_each = try(tool.value.agentcore_gateway, null) != null ? [tool.value.agentcore_gateway] : []
          content {
            gateway_arn = agentcore_gateway.value.gateway_arn
          }
        }

        dynamic "inline_function" {
          for_each = try(tool.value.inline_function, null) != null ? [tool.value.inline_function] : []
          content {
            description  = inline_function.value.description
            input_schema = inline_function.value.input_schema
          }
        }
      }
    }
  }

  #############################################################################
  # Skills
  #############################################################################
  dynamic "skill" {
    for_each = var.skills
    content {
      path = skill.value
    }
  }

  #############################################################################
  # Memory
  #############################################################################
  dynamic "memory" {
    for_each = var.memory != null ? [var.memory] : []
    content {
      agentcore_memory_configuration {
        arn            = memory.value.arn
        actor_id       = try(memory.value.actor_id, null)
        messages_count = try(memory.value.messages_count, null)
      }
    }
  }

  #############################################################################
  # Truncation (object-typed attribute) and compute environment (object-typed
  # attribute) are assigned from locals. See locals.tf.
  #############################################################################
  truncation  = local.truncation_attr
  environment = local.environment_attr

  #############################################################################
  # Custom container environment artifact
  #############################################################################
  dynamic "environment_artifact" {
    for_each = var.container_uri != null ? [var.container_uri] : []
    content {
      container_configuration {
        container_uri = environment_artifact.value
      }
    }
  }

  #############################################################################
  # Inbound JWT authorizer
  #############################################################################
  dynamic "authorizer_configuration" {
    for_each = var.jwt_authorizer != null ? [var.jwt_authorizer] : []
    content {
      custom_jwt_authorizer {
        discovery_url    = authorizer_configuration.value.discovery_url
        allowed_clients  = try(authorizer_configuration.value.allowed_clients, null)
        allowed_audience = try(authorizer_configuration.value.allowed_audience, null)
        allowed_scopes   = try(authorizer_configuration.value.allowed_scopes, null)
      }
    }
  }

  dynamic "timeouts" {
    for_each = var.timeouts != null ? [var.timeouts] : []
    content {
      create = try(timeouts.value.create, null)
      update = try(timeouts.value.update, null)
      delete = try(timeouts.value.delete, null)
    }
  }
}

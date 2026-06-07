###############################################################################
# Object-typed attribute values
#
# In the provider schema, `truncation` and `environment` are object-typed
# (list-of-object) attributes rather than nested blocks, so they are built here
# as fully-conforming structures and assigned in main.tf.
###############################################################################

locals {
  # Render the compute environment only when a non-default setting is requested.
  use_vpc            = var.network_mode == "VPC" && var.vpc_config != null
  render_environment = var.network_mode == "VPC" || var.lifecycle_configuration != null

  # ---------------------------------------------------------------------------
  # truncation attribute
  # ---------------------------------------------------------------------------
  truncation_attr = var.truncation == null ? null : [
    {
      strategy = var.truncation.strategy
      config = (try(var.truncation.sliding_window, null) != null || try(var.truncation.summarization, null) != null) ? [
        {
          sliding_window = try(var.truncation.sliding_window, null) != null ? [
            {
              messages_count = try(var.truncation.sliding_window.messages_count, null)
            }
          ] : []
          summarization = try(var.truncation.summarization, null) != null ? [
            {
              preserve_recent_messages    = try(var.truncation.summarization.preserve_recent_messages, null)
              summarization_system_prompt = try(var.truncation.summarization.summarization_system_prompt, null)
              summary_ratio               = try(var.truncation.summarization.summary_ratio, null)
            }
          ] : []
        }
      ] : []
    }
  ]

  # ---------------------------------------------------------------------------
  # environment attribute
  # ---------------------------------------------------------------------------
  environment_attr = local.render_environment ? [
    {
      agentcore_runtime_environment = [
        {
          # Computed by the service.
          agent_runtime_arn  = null
          agent_runtime_id   = null
          agent_runtime_name = null

          filesystem_configuration = []

          lifecycle_configuration = var.lifecycle_configuration != null ? [
            {
              idle_runtime_session_timeout = try(var.lifecycle_configuration.idle_runtime_session_timeout, null)
              max_lifetime                 = try(var.lifecycle_configuration.max_lifetime, null)
            }
          ] : []

          network_configuration = [
            {
              network_mode = var.network_mode
              network_mode_config = local.use_vpc ? [
                {
                  security_groups = var.vpc_config.security_groups
                  subnets         = var.vpc_config.subnets
                }
              ] : []
            }
          ]
        }
      ]
    }
  ] : null
}

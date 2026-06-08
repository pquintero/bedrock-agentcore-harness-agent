# agentcore-registry

Terraform module to register agents (and other resources) in the
[AWS Agent Registry](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/registry.html)
of Amazon Bedrock AgentCore.

This module manages the registry and its records through the custom
[`terraform-provider-agentcore`](../../terraform-provider-agentcore), so you get
a full declarative `plan`/`apply`/`destroy` lifecycle with state tracking — no
AWS CLI or shell scripts at apply time.

> **Provider setup required.** The `agentcore` provider is not published to a
> registry yet. Build and install it locally (filesystem mirror recommended),
> then configure it in your root module. See the
> [provider README](../../terraform-provider-agentcore/README.md).

## Requirements

| Name      | Version            |
| --------- | ------------------ |
| terraform | >= 1.5.0           |
| agentcore | local (this repo)  |

The root module must configure the provider, e.g.:

```hcl
terraform {
  required_providers {
    agentcore = { source = "pquintero/agentcore" }
  }
}

provider "agentcore" {
  region = "us-east-1"
}
```

## Usage

```hcl
module "registry" {
  source = "../../modules/agentcore-registry"

  registry_name        = "agentcore_demo_registry"
  registry_description = "Demo registry created with Terraform"
  auto_approval        = true # submitted records become discoverable immediately

  records = [
    {
      name            = "my_agent"
      descriptor_type = "A2A"
      record_version  = "1.0.0"
      descriptors = {
        a2a = {
          agent_card = {
            schema_version = "0.3"
            inline_content = jsonencode({
              protocolVersion = "0.3.0"
              name            = "my_agent"
              description     = "My agent"
              url             = "arn:aws:bedrock-agentcore:us-east-1:123456789012:harness/my_agent-XXXX"
              version         = "1.0.0"
            })
          }
        }
      }
      submit_for_approval = true
    },
  ]
}
```

To register records into an existing registry instead of creating one:

```hcl
module "registry" {
  source = "../../modules/agentcore-registry"

  create_registry      = false
  existing_registry_id = "abc123def456" # ID or ARN
  records              = [ /* ... */ ]
}
```

See [`examples/with-registry`](../../examples/with-registry) for a full example
that deploys a harness and registers it.

### Descriptors by type

Provide exactly the descriptors block that matches `descriptor_type`:

| `descriptor_type` | descriptors block                                                             |
| ----------------- | ------------------------------------------------------------------------------ |
| `A2A`             | `a2a = { agent_card = { schema_version, inline_content } }`                    |
| `MCP`             | `mcp = { server = { schema_version, inline_content }, tools = {...} }`        |
| `CUSTOM`          | `custom = { inline_content }`                                                  |
| `AGENT_SKILLS`    | `agent_skills = { skill_md = { inline_content }, skill_definition = {...} }`  |

`inline_content` is a JSON **string**; use `jsonencode(...)` so it is escaped
correctly.

## Inputs

| Name                   | Description                                                        | Type           | Default       |
| ---------------------- | ------------------------------------------------------------------ | -------------- | ------------- |
| `create_registry`      | Whether the module creates/owns the registry.                      | `bool`         | `true`        |
| `registry_name`        | Registry name (required when `create_registry = true`).            | `string`       | `null`        |
| `existing_registry_id` | Existing registry ID/ARN (required when `create_registry = false`).| `string`       | `null`        |
| `registry_description` | Registry description.                                              | `string`       | `null`        |
| `authorizer_type`      | `AWS_IAM` or `CUSTOM_JWT` (immutable after create).               | `string`       | `"AWS_IAM"`   |
| `auto_approval`        | Auto-approve submitted records.                                    | `bool`         | `false`       |
| `records`              | Records to create/submit (typed descriptors; see above).           | `list(object)` | `[]`          |

## Outputs

| Name              | Description                                            |
| ----------------- | ------------------------------------------------------ |
| `registry_id`     | ID of the registry the records belong to.              |
| `registry_arn`    | ARN of the registry (when created by the module).      |
| `registry_name`   | Name of the registry (when created by the module).     |
| `record_ids`      | Map of record name to record ID.                       |
| `record_arns`     | Map of record name to record ARN.                      |
| `record_statuses` | Map of record name to current status.                  |

## Notes

- Region and credentials come from the **provider** configuration, not module
  inputs.
- For records, only `submit_for_approval` is updatable in place; changing other
  fields (name, descriptors, version, type) replaces the record.
- With `auto_approval = false`, submitted records land in `PENDING_APPROVAL` and
  need a curator to approve them (out of band).

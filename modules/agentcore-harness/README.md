# bedrock-agentcore-harness-agent

Terraform module to deploy **Amazon Bedrock AgentCore Harness** agents.

The [AgentCore harness](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/harness.html)
is a managed agent loop: you declare which model the agent uses, which tools it
can call, and the instructions it follows, and AgentCore provides the compute,
tooling, memory, identity, networking, and observability. This module wraps the
[`aws_bedrockagentcore_harness`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/bedrockagentcore_harness)
resource and (optionally) provisions the IAM execution role with the
permissions recommended in the AWS docs.

> **Preview:** AgentCore harness is in public preview. This project targets
> **`us-east-1`**. (The preview is also available in `us-west-2`, `eu-central-1`,
> and `ap-southeast-2`.)

## Features

- Creates an `aws_bedrockagentcore_harness` with sensible defaults.
- Optionally creates the IAM execution role and policy (trust + base
  permissions per the AWS sample policy), with toggles for Browser, Code
  Interpreter, Memory, and API-key credential provider access.
- Supports Bedrock, OpenAI, and Gemini model providers.
- Supports built-in and remote tools (`agentcore_browser`,
  `agentcore_code_interpreter`, `agentcore_gateway`, `remote_mcp`,
  `inline_function`).
- Supports memory, truncation, execution limits, VPC networking, lifecycle
  configuration, custom container images, and inbound JWT authorization.

## Requirements

| Name      | Version    |
| --------- | ---------- |
| terraform | >= 1.5.0   |
| aws       | >= 6.49.0  |

The `aws_bedrockagentcore_harness` resource was introduced in AWS provider
`v6.49.0`.

## Usage

```hcl
module "research_agent" {
  source = "github.com/<your-org>/bedrock-agentcore-harness-agent//modules/agentcore-harness"

  harness_name = "research_agent"

  model = {
    bedrock = {
      model_id = "anthropic.claude-sonnet-4-20250514"
    }
  }

  system_prompt = [
    "You are a helpful research assistant. Be concise and cite sources."
  ]

  tags = {
    Project = "agentcore-demo"
    Env     = "dev"
  }
}
```

See the [`examples/`](../../examples) directory:

- [`examples/basic`](../../examples/basic) – minimal harness with the default
  Bedrock model and a module-managed execution role.
- [`examples/complete`](../../examples/complete) – built-in tools (browser + code
  interpreter), an inline function, execution limits, and truncation.

### Bring your own execution role

```hcl
module "agent" {
  source = "../../"

  harness_name          = "my_agent"
  create_execution_role = false
  execution_role_arn    = aws_iam_role.my_existing_role.arn

  model = {
    bedrock = { model_id = "anthropic.claude-sonnet-4-20250514" }
  }
}
```

### VPC networking

```hcl
network_mode = "VPC"
vpc_config = {
  security_groups = ["sg-0abc1234def56789a"]
  subnets         = ["subnet-0abc1234def56789a"]
}
```

> When running in VPC mode, the VPC must reach `public.ecr.aws` (NAT gateway +
> internet gateway) so the harness can pull its container image at session start.

### Agent Skills

[Agent Skills](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/harness-environment.html)
are bundles of markdown and scripts that give the agent domain knowledge on
demand. Provide paths to skills that exist in the harness environment (baked
into a custom container image, or installed at session start):

```hcl
container_uri = "123456789012.dkr.ecr.us-east-1.amazonaws.com/my-dev-env:latest"

skills = [
  ".agents/skills/xlsx",
  ".agents/skills/github",
]
```

Each skill directory must contain a `SKILL.md`. Skills configured here are
passed to every invocation. S3/Git skill sources are invocation-time options
and are not persisted on the harness resource, so only path-based skills are
supported by the module.

## Invoking the harness

This module provisions the harness. To run it, call `InvokeHarness` with the
`harness_arn` output (for example via `boto3` or the AgentCore CLI):

```python
import boto3

client = boto3.client("bedrock-agentcore", region_name="us-east-1")
response = client.invoke_harness(
    harnessArn="<module.<name>.harness_arn>",
    runtimeSessionId="1234abcd-12ab-34cd-56ef-1234567890ab",  # >= 33 chars
    messages=[{"role": "user", "content": [{"text": "Hello"}]}],
)
for event in response["stream"]:
    delta = event.get("contentBlockDelta", {}).get("delta", {})
    if "text" in delta:
        print(delta["text"], end="", flush=True)
```

## Inputs

| Name                                  | Description                                                                 | Type           | Default     |
| ------------------------------------- | --------------------------------------------------------------------------- | -------------- | ----------- |
| `harness_name`                        | Harness name (letter-led, alphanumeric/underscore, max 40).                 | `string`       | n/a (req.)  |
| `model`                               | Model config: exactly one of `bedrock`, `openai`, `gemini`.                 | `object`       | `null`*     |
| `system_prompt`                       | List of system prompt text blocks.                                          | `list(string)` | `[]`        |
| `create_execution_role`               | Create the IAM execution role.                                              | `bool`         | `true`      |
| `execution_role_arn`                  | Existing role ARN (when `create_execution_role = false`).                   | `string`       | `null`      |
| `execution_role_name`                 | Name for the created role.                                                  | `string`       | `null`      |
| `additional_execution_role_policy_arns` | Extra managed policies to attach.                                         | `list(string)` | `[]`        |
| `execution_role_inline_policy_json`   | Extra inline policy JSON for the created role.                              | `string`       | `null`      |
| `enable_browser_permissions`          | Add Browser permissions to the role.                                        | `bool`         | `false`     |
| `enable_code_interpreter_permissions` | Add Code Interpreter permissions to the role.                               | `bool`         | `false`     |
| `enable_memory_permissions`           | Add Memory permissions to the role.                                         | `bool`         | `false`     |
| `api_key_credential_provider_arns`    | API-key credential provider ARNs the role may read.                         | `list(string)` | `[]`        |
| `allowed_tools`                       | Tool name/glob patterns the agent may use.                                  | `list(string)` | `[]`        |
| `tools`                               | List of tool configurations.                                                | `list(object)` | `[]`        |
| `skills`                              | List of paths to Agent Skills in the harness environment.                   | `list(string)` | `[]`        |
| `memory`                              | AgentCore Memory configuration.                                             | `object`       | `null`      |
| `max_iterations`                      | Max agent-loop iterations per invocation.                                   | `number`       | `null`      |
| `max_tokens`                          | Max output tokens per invocation.                                           | `number`       | `null`      |
| `timeout_seconds`                     | Max agent-loop duration per invocation.                                     | `number`       | `null`      |
| `truncation`                          | Truncation config (`sliding_window`, `summarization`, `none`).              | `object`       | `null`      |
| `environment_variables`               | Environment variables for the runtime (sensitive).                          | `map(string)`  | `{}`        |
| `network_mode`                        | `PUBLIC` or `VPC`.                                                          | `string`       | `"PUBLIC"`  |
| `vpc_config`                          | Security groups and subnets (required for `VPC`).                            | `object`       | `null`      |
| `lifecycle_configuration`             | Idle/max session timeouts (seconds).                                        | `object`       | `null`      |
| `container_uri`                       | Custom container image URI.                                                 | `string`       | `null`      |
| `jwt_authorizer`                      | Inbound JWT authorizer configuration.                                       | `object`       | `null`      |
| `timeouts`                            | Resource create/update/delete timeouts.                                     | `object`       | `null`      |
| `tags`                                | Tags applied to all resources.                                              | `map(string)`  | `{}`        |

\* When `model` is `null`, the module defaults to
`anthropic.claude-sonnet-4-20250514` on Bedrock.

## Outputs

| Name                  | Description                                            |
| --------------------- | ------------------------------------------------------ |
| `harness_id`          | Unique identifier of the harness.                      |
| `harness_arn`         | ARN of the harness (use with `InvokeHarness`).         |
| `harness_name`        | Name of the harness.                                   |
| `execution_role_arn`  | ARN of the execution role assumed by the harness.      |
| `execution_role_name` | Name of the created role (`null` when bringing yours). |

## License

See repository license.

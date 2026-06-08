# terraform-provider-agentcore

A custom Terraform provider for the **Amazon Bedrock AgentCore Agent Registry**
(preview), built with the [Terraform Plugin Framework](https://developer.hashicorp.com/terraform/plugin/framework)
and the AWS SDK for Go v2 (`bedrockagentcorecontrol`).

It provides true declarative management of the registry and its records, as a
production-grade replacement for the CLI-backed
[`modules/agentcore-registry`](../modules/agentcore-registry) module.

## Why this provider?

The AgentCore Agent Registry is in preview and is **not yet exposed by the
official Terraform AWS provider**. This provider fills that gap with real
resources so you get:

- A proper `plan`/`apply`/`destroy` lifecycle with state tracking.
- No dependency on the AWS CLI or `bash` at apply time.
- Import support and computed attributes (ARNs, status).

## Resources

### `agentcore_registry`

| Attribute         | Type   | Notes                                          |
| ----------------- | ------ | ---------------------------------------------- |
| `name`            | string | Required.                                      |
| `description`     | string | Optional. Updatable in place.                  |
| `authorizer_type` | string | `AWS_IAM` (default) or `CUSTOM_JWT`. ForceNew. |
| `auto_approval`   | bool   | Optional (default false). Updatable in place.  |
| `id` / `arn` / `status` | string | Computed.                                |

### `agentcore_registry_record`

| Attribute             | Type   | Notes                                              |
| --------------------- | ------ | -------------------------------------------------- |
| `registry_id`         | string | Required. ForceNew.                                |
| `name`                | string | Required. ForceNew.                                |
| `descriptor_type`     | string | `MCP` / `A2A` / `CUSTOM` / `AGENT_SKILLS`. ForceNew. |
| `record_version`      | string | Optional. ForceNew.                                |
| `description`         | string | Optional. ForceNew.                                |
| `descriptors`         | object | Required. Typed per descriptor_type. ForceNew.     |
| `submit_for_approval` | bool   | Optional (default false). Updatable in place.      |
| `id` / `arn` / `status` | string | Computed.                                        |

The `descriptors` object mirrors the API shape:

```hcl
descriptors = {
  a2a          = { agent_card = { schema_version = "0.3", inline_content = jsonencode({...}) } }
  # or mcp      = { server = { schema_version, inline_content }, tools = { protocol_version, inline_content } }
  # or custom   = { inline_content = jsonencode({...}) }
  # or agent_skills = { skill_md = { inline_content }, skill_definition = { schema_version, inline_content } }
}
```

## Build and local use

Until this provider is published to a registry, install it locally. There are
two approaches.

### Option A — Filesystem mirror (recommended)

Works with `terraform init` and configs that also use local modules and the AWS
provider (such as `examples/with-registry`).

```bash
make install-mirror   # builds and installs into ~/.terraform.d/plugins/...

# then, in an example that uses the provider:
cd ../../examples/with-registry
terraform init        # resolves agentcore from the local mirror + aws normally
terraform plan
terraform apply
```

### Option B — dev_overrides (quick iteration)

Best when iterating on the provider itself with a config that has no other
providers/modules to install (e.g. `examples/registry`). With `dev_overrides`
you do **not** run `terraform init`.

```bash
make install          # into $GOBIN (or $GOPATH/bin)

BIN="$(go env GOBIN)"; [ -z "$BIN" ] && BIN="$(go env GOPATH)/bin"
sed "s#<GOBIN>#${BIN}#" examples/registry/dev.tfrc.example > dev.tfrc
export TF_CLI_CONFIG_FILE="$(pwd)/dev.tfrc"

cd examples/registry
terraform plan        # no `terraform init`
```

> Note: `dev_overrides` only affects plan/apply/validate, not `init`. Configs
> that also need to install local modules or other providers should use the
> filesystem mirror (Option A).

Credentials are resolved by the standard AWS SDK chain; set `region`/`profile`
in the provider block or use `AWS_REGION` / `AWS_PROFILE`.

## Import

```bash
# Registry (by id or ARN)
terraform import agentcore_registry.this <registry_id>

# Record (registry_id and record_id, comma-separated)
terraform import agentcore_registry_record.agent <registry_id>,<record_id>
```

## Development

```bash
make fmt    # gofmt -s -w .
make vet    # go vet ./...
make build  # build local binary
make test   # go test ./...
```

## Status and limitations

- **Preview API.** Field shapes may change; pin the SDK version.
- For records, only `submit_for_approval` is updatable in place; other changes
  force replacement (delete + recreate).
- `CUSTOM_JWT` registries require an authorizer configuration on the API; this
  provider currently sends `authorizer_type` only. Extend
  `registry_resource.go` to wire the JWT configuration if you need it.
- Once the official AWS provider ships native registry resources, prefer those.

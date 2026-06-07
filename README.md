# bedrock-agentcore-harness-agent

Terraform to deploy **Amazon Bedrock AgentCore Harness** agents.

The [AgentCore harness](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/harness.html)
is a managed agent loop: you declare the model, tools, and instructions, and
AgentCore provides the compute, tooling, memory, identity, networking, and
observability that turn that configuration into a running agent.

> **Region:** This project runs entirely in **`us-east-1`**.
> AgentCore harness is in public preview.

## Repository layout

```
.
├── modules/
│   └── agentcore-harness/   # Reusable Terraform module (the harness + IAM role)
│       ├── main.tf
│       ├── iam.tf
│       ├── locals.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── versions.tf
│       └── README.md        # Full module documentation (inputs/outputs)
└── examples/
    ├── basic/               # Minimal harness, default Bedrock model
    ├── complete/            # Tools, inline function, limits, truncation
    └── with-skills/         # Data Engineering agent: custom image + Agent Skills
```

## Quick start

```bash
cd examples/basic
terraform init
terraform plan
terraform apply
```

## Using the module

```hcl
module "research_agent" {
  source = "./modules/agentcore-harness"

  harness_name = "research_agent"

  model = {
    bedrock = {
      model_id = "anthropic.claude-sonnet-4-20250514"
    }
  }

  system_prompt = [
    "You are a helpful research assistant. Be concise and cite sources."
  ]
}
```

See [`modules/agentcore-harness/README.md`](./modules/agentcore-harness/README.md)
for the complete list of inputs, outputs, and usage patterns.

## Requirements

| Name      | Version   |
| --------- | --------- |
| terraform | >= 1.5.0  |
| aws       | >= 6.49.0 |

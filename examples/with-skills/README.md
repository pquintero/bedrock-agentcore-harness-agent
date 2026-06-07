# Example: Data Engineering agent with Agent Skills

This example deploys a harness for a **Data Engineering** assistant that uses a
custom container image with baked-in [Agent Skills](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/harness-environment.html)
and the AgentCore Code Interpreter.

Region: **us-east-1**.

## What it creates

- An `aws_bedrockagentcore_harness` configured with:
  - A custom container environment (`container_uri`).
  - Four baked-in skills under `.agents/skills/`: `data-modeling`, `spark-etl`,
    `sql-optimization`, `airflow-dags`.
  - The Code Interpreter tool (with matching IAM permissions).
  - Sliding-window truncation and execution limits.
- A module-managed IAM execution role.

## Files

```
with-skills/
├── main.tf                  # Module call
├── variables.tf             # container_uri input
├── outputs.tf
├── terraform.tfvars.example
├── Dockerfile               # Builds the linux/arm64 environment image
└── skills/                  # Skill bundles baked into the image
    ├── data-modeling/SKILL.md
    ├── spark-etl/SKILL.md
    ├── sql-optimization/SKILL.md
    └── airflow-dags/SKILL.md
```

## How skills work here

The `skills` directories are copied into the container image at build time (see
`Dockerfile`) under `/app/.agents/skills/<name>`. The harness `skills` input
points at those paths, so each skill (its `SKILL.md` plus any scripts) is made
available to **every** invocation. The agent pulls a skill into context on
demand when it is relevant.

> S3/Git skill sources are an invocation-time feature of `InvokeHarness` and are
> not persisted on the harness resource, so this module supports path-based
> (baked-in) skills only.

## Deploy

1. Build and push the environment image to ECR (must be `linux/arm64`):

   ```bash
   AWS_REGION=us-east-1
   ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
   REPO=data-engineer-agent

   aws ecr create-repository --repository-name "$REPO" --region "$AWS_REGION" \
     --no-cli-pager || true
   aws ecr get-login-password --region "$AWS_REGION" \
     | docker login --username AWS --password-stdin \
       "$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

   docker buildx build --platform linux/arm64 \
     -t "$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$REPO:latest" \
     --push .
   ```

2. Set the image URI and apply:

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # edit terraform.tfvars with your image URI

   terraform init
   terraform plan
   terraform apply
   ```

## Invoke

```python
import boto3, uuid

client = boto3.client("bedrock-agentcore", region_name="us-east-1")
response = client.invoke_harness(
    harnessArn="<terraform output harness_arn>",
    runtimeSessionId=str(uuid.uuid4()) + "-session",  # >= 33 chars
    messages=[{"role": "user", "content": [{"text":
        "Design a star schema for retail order events and validate the grain."}]}],
)
for event in response["stream"]:
    delta = event.get("contentBlockDelta", {}).get("delta", {})
    if "text" in delta:
        print(delta["text"], end="", flush=True)
```

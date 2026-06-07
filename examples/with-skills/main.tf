###############################################################################
# With-skills example: a Data Engineering agent that uses a custom container
# image with baked-in Agent Skills, plus the AgentCore Code Interpreter.
#
# The skills are directories (each containing a SKILL.md) packaged into the
# container image at build time at a known path (e.g. ".agents/skills/<name>").
# Skills configured on the harness are passed to every invocation.
###############################################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.49.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

module "data_engineer_agent" {
  source = "../../modules/agentcore-harness"

  harness_name = "data_engineer_agent"

  model = {
    bedrock = {
      model_id    = "anthropic.claude-sonnet-4-20250514"
      temperature = 0.2
    }
  }

  system_prompt = [
    "You are a senior data engineering assistant.",
    "You design and review ETL/ELT pipelines, write SQL and PySpark, and reason about data modeling, partitioning, and cost.",
    "Use the available skills for domain conventions and the code interpreter to validate transformations on sample data.",
  ]

  # Custom environment image (linux/arm64) that bundles the Data Engineer skills.
  # Build and push this image to ECR, then reference it here.
  container_uri = var.container_uri

  # Agent Skills baked into the container image at these paths.
  skills = [
    ".agents/skills/data-modeling",
    ".agents/skills/spark-etl",
    ".agents/skills/sql-optimization",
    ".agents/skills/airflow-dags",
  ]

  # Code Interpreter is handy for validating data transformations.
  allowed_tools                       = ["*"]
  enable_code_interpreter_permissions = true

  tools = [
    {
      type                       = "agentcore_code_interpreter"
      name                       = "code_interpreter"
      agentcore_code_interpreter = {}
    },
  ]

  # Keep recent conversation context bounded.
  truncation = {
    strategy = "sliding_window"
    sliding_window = {
      messages_count = 40
    }
  }

  max_iterations  = 15
  max_tokens      = 8192
  timeout_seconds = 600

  tags = {
    Project = "agentcore-demo"
    Role    = "data-engineer"
    Env     = "dev"
  }
}

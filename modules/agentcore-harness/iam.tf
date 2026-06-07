###############################################################################
# IAM execution role for the AgentCore Harness
#
# Trust policy and permissions follow the AWS documentation:
# https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/harness-security.html
###############################################################################

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region
  partition  = data.aws_partition.current.partition

  create_role        = var.create_execution_role
  execution_role_arn = local.create_role ? aws_iam_role.this[0].arn : var.execution_role_arn

  execution_role_name = coalesce(var.execution_role_name, "bedrock-agentcore-harness-${var.harness_name}")
}

# Trust policy: allow the AgentCore service principal to assume the role.
data "aws_iam_policy_document" "assume_role" {
  count = local.create_role ? 1 : 0

  statement {
    sid     = "AgentCoreAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["bedrock-agentcore.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  count = local.create_role ? 1 : 0

  name               = local.execution_role_name
  assume_role_policy = data.aws_iam_policy_document.assume_role[0].json
  tags               = var.tags
}

# Base execution permissions: model invocation, ECR Public pull, X-Ray, logs,
# metrics, and AgentCore workload identity.
data "aws_iam_policy_document" "execution" {
  count = local.create_role ? 1 : 0

  statement {
    sid    = "BedrockModelInvocation"
    effect = "Allow"
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
    ]
    resources = [
      "arn:${local.partition}:bedrock:*::foundation-model/*",
      "arn:${local.partition}:bedrock:${local.region}:${local.account_id}:*",
    ]
  }

  statement {
    sid       = "EcrPublicTokenAccess"
    effect    = "Allow"
    actions   = ["ecr-public:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid       = "StsForEcrPublicPull"
    effect    = "Allow"
    actions   = ["sts:GetServiceBearerToken"]
    resources = ["*"]
  }

  statement {
    sid    = "XRayTracingAccess"
    effect = "Allow"
    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords",
      "xray:GetSamplingRules",
      "xray:GetSamplingTargets",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "CloudWatchLogsGroup"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:DescribeLogStreams",
    ]
    resources = ["arn:${local.partition}:logs:${local.region}:${local.account_id}:log-group:/aws/bedrock-agentcore/runtimes/*"]
  }

  statement {
    sid       = "CloudWatchLogsDescribeGroups"
    effect    = "Allow"
    actions   = ["logs:DescribeLogGroups"]
    resources = ["arn:${local.partition}:logs:${local.region}:${local.account_id}:log-group:*"]
  }

  statement {
    sid    = "CloudWatchLogsStream"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:${local.partition}:logs:${local.region}:${local.account_id}:log-group:/aws/bedrock-agentcore/runtimes/*:log-stream:*"]
  }

  statement {
    sid       = "CloudWatchMetricsPublish"
    effect    = "Allow"
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "cloudwatch:namespace"
      values   = ["bedrock-agentcore"]
    }
  }

  statement {
    sid    = "AgentCoreWorkloadIdentity"
    effect = "Allow"
    actions = [
      "bedrock-agentcore:GetWorkloadAccessToken",
      "bedrock-agentcore:GetWorkloadAccessTokenForJWT",
    ]
    resources = [
      "arn:${local.partition}:bedrock-agentcore:${local.region}:${local.account_id}:workload-identity-directory/default",
      "arn:${local.partition}:bedrock-agentcore:${local.region}:${local.account_id}:workload-identity-directory/default/workload-identity/harness_${var.harness_name}-*",
    ]
  }

  # Optional: AgentCore Browser
  dynamic "statement" {
    for_each = var.enable_browser_permissions ? [1] : []
    content {
      sid    = "AgentCoreBrowserDefault"
      effect = "Allow"
      actions = [
        "bedrock-agentcore:StartBrowserSession",
        "bedrock-agentcore:StopBrowserSession",
        "bedrock-agentcore:GetBrowserSession",
        "bedrock-agentcore:ListBrowserSessions",
        "bedrock-agentcore:UpdateBrowserStream",
        "bedrock-agentcore:ConnectBrowserAutomationStream",
        "bedrock-agentcore:ConnectBrowserLiveViewStream",
      ]
      resources = ["arn:${local.partition}:bedrock-agentcore:${local.region}:aws:browser/*"]
    }
  }

  # Optional: AgentCore Code Interpreter
  dynamic "statement" {
    for_each = var.enable_code_interpreter_permissions ? [1] : []
    content {
      sid    = "AgentCoreCodeInterpreterDefault"
      effect = "Allow"
      actions = [
        "bedrock-agentcore:StartCodeInterpreterSession",
        "bedrock-agentcore:StopCodeInterpreterSession",
        "bedrock-agentcore:GetCodeInterpreterSession",
        "bedrock-agentcore:ListCodeInterpreterSessions",
        "bedrock-agentcore:InvokeCodeInterpreter",
      ]
      resources = ["arn:${local.partition}:bedrock-agentcore:${local.region}:aws:code-interpreter/*"]
    }
  }

  # Optional: AgentCore Memory
  dynamic "statement" {
    for_each = var.enable_memory_permissions ? [1] : []
    content {
      sid    = "AgentCoreMemory"
      effect = "Allow"
      actions = [
        "bedrock-agentcore:CreateEvent",
        "bedrock-agentcore:ListEvents",
        "bedrock-agentcore:GetEvent",
        "bedrock-agentcore:RetrieveMemoryRecords",
        "bedrock-agentcore:ListMemoryRecords",
        "bedrock-agentcore:GetMemoryRecord",
      ]
      resources = ["arn:${local.partition}:bedrock-agentcore:${local.region}:${local.account_id}:memory/*"]
    }
  }

  # Optional: read API key credential providers (third-party model keys)
  dynamic "statement" {
    for_each = length(var.api_key_credential_provider_arns) > 0 ? [1] : []
    content {
      sid       = "AgentCoreApiKeyCredentialProvider"
      effect    = "Allow"
      actions   = ["bedrock-agentcore:GetResourceApiKey"]
      resources = var.api_key_credential_provider_arns
    }
  }
}

resource "aws_iam_role_policy" "execution" {
  count = local.create_role ? 1 : 0

  name   = "${local.execution_role_name}-policy"
  role   = aws_iam_role.this[0].id
  policy = data.aws_iam_policy_document.execution[0].json
}

# Optional user-supplied inline policy for custom permissions.
resource "aws_iam_role_policy" "custom" {
  count = local.create_role && var.execution_role_inline_policy_json != null ? 1 : 0

  name   = "${local.execution_role_name}-custom"
  role   = aws_iam_role.this[0].id
  policy = var.execution_role_inline_policy_json
}

# Optional managed policy attachments.
resource "aws_iam_role_policy_attachment" "additional" {
  for_each = local.create_role ? toset(var.additional_execution_role_policy_arns) : toset([])

  role       = aws_iam_role.this[0].name
  policy_arn = each.value
}

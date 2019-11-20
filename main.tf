provider "aws" {
  profile = "default"
  region  = "eu-west-1"
}

terraform {
  backend "s3" {
    profile = "default"
    bucket  = "conju-build-alerts-remote-state"
    key     = "prod.tfstate"
    region  = "eu-west-1"
  }
}

variable "SLACK_WEBHOOK" {
  type = "string"
}

resource "aws_cloudwatch_event_rule" "event" {
  name        = "conju_pipeline_change"
  description = "An event triggered on the state change of conjugator codepipeline"

  event_pattern = <<PATTERN
{
  "source": [
    "aws.codepipeline"
  ],
  "detail-type": [
    "CodePipeline Pipeline Execution State Change"
  ],
  "detail": {
    "state": [
      "SUCCEEDED",
      "FAILED"
    ],
    "pipeline": [
      "conju-gator-pipeline"
    ]
  }
}
PATTERN
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

// This is a Resource-based permission (not an Identity-based IAM permission)
// It applies to the lambda itself, allowing invocation from another service (in this case, CW Events)
// See https://docs.aws.amazon.com/lambda/latest/dg/lambda-permissions.html for more info
resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.slack_function.function_name}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.event.arn}"
}

resource "aws_iam_policy" "lambda_logging" {
  name        = "lambda_logging"
  path        = "/"
  description = "IAM policy for logging from a lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

// Attaching the logging policy to the Lambda's role
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = "${aws_iam_role.iam_for_lambda.name}"
  policy_arn = "${aws_iam_policy.lambda_logging.arn}"
}

resource "aws_lambda_function" "slack_function" {
  filename         = "lambda_function_payload.zip"
  function_name    = "conju_build_alerts_lambda"
  role             = "${aws_iam_role.iam_for_lambda.arn}"
  handler          = "bin/notifier"
  runtime          = "go1.x"
  source_code_hash = "${filebase64sha256("lambda_function_payload.zip")}"

  environment {
    variables = {
      SLACK_WEBHOOK = "${var.SLACK_WEBHOOK}"
    }
  }
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule      = "${aws_cloudwatch_event_rule.event.name}"
  target_id = "BuildRuleLambdaTarget"
  arn       = "${aws_lambda_function.slack_function.arn}"
}

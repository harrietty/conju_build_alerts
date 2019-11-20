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

resource "aws_cloudwatch_event_rule" "event" {
  name        = "conju_state_change"
  description = "An event triggered on the state change of conjugator frontend build pipeline"

  event_pattern = <<PATTERN
{
  "source": [
    "aws.codebuild"
  ],
  "detail-type": [
    "CodeBuild Build State Change"
  ],
  "detail": {
    "build-status": [
      "SUCCEEDED",
      "FAILED",
      "STOPPED"
    ],
    "project-name": [
      "Conju-gator-cache-invalidation"
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
      slack_hook_url = "3948fjksdfj"
    }
  }
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule      = "${aws_cloudwatch_event_rule.event.name}"
  target_id = "BuildRuleLambdaTarget"
  arn       = "${aws_lambda_function.slack_function.arn}"
}

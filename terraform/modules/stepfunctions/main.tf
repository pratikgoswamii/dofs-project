# Step Functions for DOFS Order Processing

# IAM Role for Step Functions
resource "aws_iam_role" "step_function_role" {
  name = "${var.project_name}-step-function-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for Step Functions
resource "aws_iam_role_policy" "step_function_policy" {
  name = "${var.project_name}-step-function-policy-${var.environment}"
  role = aws_iam_role.step_function_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          var.validator_function_arn,
          var.order_storage_function_arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:CreateLogDelivery",
          "logs:GetLogDelivery",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      }
    ]
  })
}

# Step Function State Machine
resource "aws_sfn_state_machine" "order_processing" {
  name     = "${var.project_name}-order-processing-${var.environment}"
  role_arn = aws_iam_role.step_function_role.arn

  definition = jsonencode({
    Comment = "DOFS Order Processing Workflow"
    StartAt = "ValidateOrder"
    States = {
      ValidateOrder = {
        Type     = "Task"
        Resource = var.validator_function_arn
        Next     = "StoreOrder"
        Retry = [
          {
            ErrorEquals = ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException"]
            IntervalSeconds = 2
            MaxAttempts     = 6
            BackoffRate     = 2
          }
        ]
        Catch = [
          {
            ErrorEquals = ["States.TaskFailed"]
            Next        = "ValidationFailed"
          }
        ]
      }
      StoreOrder = {
        Type     = "Task"
        Resource = var.order_storage_function_arn
        End      = true
        Retry = [
          {
            ErrorEquals = ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException"]
            IntervalSeconds = 2
            MaxAttempts     = 6
            BackoffRate     = 2
          }
        ]
        Catch = [
          {
            ErrorEquals = ["States.TaskFailed"]
            Next        = "StorageFailed"
          }
        ]
      }
      ValidationFailed = {
        Type = "Fail"
        Cause = "Order validation failed"
        Error = "ValidationError"
      }
      StorageFailed = {
        Type = "Fail"
        Cause = "Order storage failed"
        Error = "StorageError"
      }
    }
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.step_function_logs.arn}:*"
    include_execution_data = true
    level                  = "ERROR"
  }

  tags = {
    Name        = "${var.project_name}-order-processing-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

# CloudWatch Log Group for Step Functions
resource "aws_cloudwatch_log_group" "step_function_logs" {
  name              = "/aws/stepfunctions/${var.project_name}-order-processing-${var.environment}"
  retention_in_days = 14

  tags = {
    Name        = "${var.project_name}-step-function-logs-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

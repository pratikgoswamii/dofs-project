# Compute Module - Combines Lambda Functions and Step Functions
# Resolves circular dependency by creating lambdas first, then step functions

# IAM Role for Lambda Functions
resource "aws_iam_role" "lambda_execution_role" {
  name = "${var.project_name}-lambda-execution-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for Lambda Functions
resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project_name}-lambda-policy-${var.environment}"
  role = aws_iam_role.lambda_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          var.orders_table_arn,
          var.failed_orders_table_arn,
          "${var.orders_table_arn}/*",
          "${var.failed_orders_table_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = [
          var.order_queue_arn,
          var.order_dlq_arn
        ]
      }
    ]
  })
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "api_handler_logs" {
  name              = "/aws/lambda/${var.project_name}-api-handler-${var.environment}"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "validator_logs" {
  name              = "/aws/lambda/${var.project_name}-validator-${var.environment}"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "order_storage_logs" {
  name              = "/aws/lambda/${var.project_name}-order-storage-${var.environment}"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "fulfillment_logs" {
  name              = "/aws/lambda/${var.project_name}-fulfillment-${var.environment}"
  retention_in_days = 14
}

# Lambda Functions (Created First)

# Validator Lambda
resource "aws_lambda_function" "validator" {
  filename         = "${path.module}/../../../lambdas/validator/validator.zip"
  function_name    = "${var.project_name}-validator-${var.environment}"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "validator.lambda_handler"
  runtime         = "python3.9"
  timeout         = 30

  environment {
    variables = {
      ENVIRONMENT = var.environment
    }
  }

  depends_on = [
    aws_iam_role_policy.lambda_policy,
    aws_cloudwatch_log_group.validator_logs
  ]

  tags = {
    Name        = "${var.project_name}-validator-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Order Storage Lambda
resource "aws_lambda_function" "order_storage" {
  filename         = "${path.module}/../../../lambdas/order_storage/order_storage.zip"
  function_name    = "${var.project_name}-order-storage-${var.environment}"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "order_storage.lambda_handler"
  runtime         = "python3.9"
  timeout         = 30

  environment {
    variables = {
      ORDERS_TABLE_NAME = var.orders_table_name
      ORDER_QUEUE_URL   = var.order_queue_url
      ENVIRONMENT       = var.environment
    }
  }

  depends_on = [
    aws_iam_role_policy.lambda_policy,
    aws_cloudwatch_log_group.order_storage_logs
  ]

  tags = {
    Name        = "${var.project_name}-order-storage-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Step Functions (Created After Lambdas)

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
        Resource = "arn:aws:lambda:*:*:function:${var.project_name}-*-${var.environment}"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
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
        Resource = aws_lambda_function.validator.arn
        Next     = "CheckValidation"
        Retry = [
          {
            ErrorEquals     = ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException"]
            IntervalSeconds = 2
            MaxAttempts     = 3
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
      CheckValidation = {
        Type = "Choice"
        Choices = [
          {
            Variable      = "$.valid"
            BooleanEquals = true
            Next          = "StoreOrder"
          }
        ]
        Default = "ValidationFailed"
      }
      StoreOrder = {
        Type     = "Task"
        Resource = aws_lambda_function.order_storage.arn
        End      = true
        Retry = [
          {
            ErrorEquals     = ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException"]
            IntervalSeconds = 2
            MaxAttempts     = 3
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
      }
      StorageFailed = {
        Type = "Fail"
        Cause = "Order storage failed"
      }
    }
  })

  depends_on = [
    aws_iam_role_policy.step_function_policy,
    aws_lambda_function.validator,
    aws_lambda_function.order_storage
  ]

  tags = {
    Name        = "${var.project_name}-order-processing-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Additional IAM Policy for API Handler to access Step Functions
resource "aws_iam_role_policy" "api_handler_stepfunction_policy" {
  name = "${var.project_name}-api-handler-stepfunction-policy-${var.environment}"
  role = aws_iam_role.lambda_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "states:StartExecution"
        ]
        Resource = aws_sfn_state_machine.order_processing.arn
      }
    ]
  })

  depends_on = [aws_sfn_state_machine.order_processing]
}

# API Handler Lambda (Created After Step Function)
resource "aws_lambda_function" "api_handler" {
  filename         = "${path.module}/../../../lambdas/api_handler/api_handler.zip"
  function_name    = "${var.project_name}-api-handler-${var.environment}"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "api_handler.lambda_handler"
  runtime         = "python3.9"
  timeout         = 30

  environment {
    variables = {
      STEP_FUNCTION_ARN = aws_sfn_state_machine.order_processing.arn
      ENVIRONMENT      = var.environment
    }
  }

  depends_on = [
    aws_iam_role_policy.lambda_policy,
    aws_iam_role_policy.api_handler_stepfunction_policy,
    aws_cloudwatch_log_group.api_handler_logs,
    aws_sfn_state_machine.order_processing
  ]

  tags = {
    Name        = "${var.project_name}-api-handler-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Fulfillment Lambda
resource "aws_lambda_function" "fulfillment" {
  filename         = "${path.module}/../../../lambdas/fulfill_order/fulfill_order.zip"
  function_name    = "${var.project_name}-fulfillment-${var.environment}"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "fulfill_order.lambda_handler"
  runtime         = "python3.9"
  timeout         = 300

  environment {
    variables = {
      ORDERS_TABLE_NAME        = var.orders_table_name
      FAILED_ORDERS_TABLE_NAME = var.failed_orders_table_name
      ENVIRONMENT              = var.environment
    }
  }

  depends_on = [
    aws_iam_role_policy.lambda_policy,
    aws_cloudwatch_log_group.fulfillment_logs
  ]

  tags = {
    Name        = "${var.project_name}-fulfillment-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

# SQS Event Source Mapping for Fulfillment Lambda
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = var.order_queue_arn
  function_name    = aws_lambda_function.fulfillment.arn
  batch_size       = 1
  maximum_batching_window_in_seconds = 5
  
  # Configure failure handling
  function_response_types = ["ReportBatchItemFailures"]
  
  depends_on = [aws_lambda_function.fulfillment]
}

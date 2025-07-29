# Lambda Functions for DOFS

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
          "${var.orders_table_arn}/index/*",
          "${var.failed_orders_table_arn}/index/*"
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
      },
      {
        Effect = "Allow"
        Action = [
          "states:StartExecution"
        ]
        Resource = var.step_function_arn
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = "*"
      }
    ]
  })
}

# API Handler Lambda
resource "aws_lambda_function" "api_handler" {
  filename         = "${path.module}/../../../lambdas/api_handler/api_handler.zip"
  function_name    = "${var.project_name}-api-handler-${var.environment}"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "api_handler.lambda_handler"
  runtime         = "python3.9"
  timeout         = 30

  environment {
    variables = {
      STEP_FUNCTION_ARN = var.step_function_arn
      ENVIRONMENT       = var.environment
    }
  }

  depends_on = [
    aws_iam_role_policy.lambda_policy,
    aws_cloudwatch_log_group.api_handler_logs
  ]

  tags = {
    Name        = "${var.project_name}-api-handler-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

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

# DLQ Processor Lambda
# resource "aws_lambda_function" "dlq_processor" {
#   filename         = "${path.module}/../../../lambdas/dlq_processor/dlq_processor.zip"
#   function_name    = "${var.project_name}-dlq-processor-${var.environment}"
#   role            = aws_iam_role.lambda_execution_role.arn
#   handler         = "dlq_processor.lambda_handler"
#   runtime         = "python3.9"
#   timeout         = 300

#   environment {
#     variables = {
#       FAILED_ORDERS_TABLE_NAME = var.failed_orders_table_name
#       DLQ_ALERT_SNS_TOPIC_ARN = var.dlq_alert_sns_topic_arn
#       ENVIRONMENT             = var.environment
#     }
#   }

#   depends_on = [
#     aws_iam_role_policy.lambda_policy,
#     aws_cloudwatch_log_group.dlq_processor_logs
#   ]

#   tags = {
#     Name        = "${var.project_name}-dlq-processor-${var.environment}"
#     Environment = var.environment
#     Project     = var.project_name
#   }
# }

# SQS Event Source Mapping for Fulfillment Lambda
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = var.order_queue_arn
  function_name    = aws_lambda_function.fulfillment.arn
  batch_size       = 1
  enabled          = true
}

# SQS Event Source Mapping for DLQ Processor Lambda
resource "aws_lambda_event_source_mapping" "dlq_trigger" {
  event_source_arn = var.order_dlq_arn
  function_name    = aws_lambda_function.dlq_processor.arn
  batch_size       = 1
  enabled          = true
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "api_handler_logs" {
  name              = "/aws/lambda/${var.project_name}-api-handler-${var.environment}"
  retention_in_days = 14

  tags = {
    Name        = "${var.project_name}-api-handler-logs-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_cloudwatch_log_group" "validator_logs" {
  name              = "/aws/lambda/${var.project_name}-validator-${var.environment}"
  retention_in_days = 14

  tags = {
    Name        = "${var.project_name}-validator-logs-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_cloudwatch_log_group" "order_storage_logs" {
  name              = "/aws/lambda/${var.project_name}-order-storage-${var.environment}"
  retention_in_days = 14

  tags = {
    Name        = "${var.project_name}-order-storage-logs-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_cloudwatch_log_group" "fulfillment_logs" {
  name              = "/aws/lambda/${var.project_name}-fulfillment-${var.environment}"
  retention_in_days = 14

  tags = {
    Name        = "${var.project_name}-fulfillment-logs-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_cloudwatch_log_group" "dlq_processor_logs" {
  name              = "/aws/lambda/${var.project_name}-dlq-processor-${var.environment}"
  retention_in_days = 14

  tags = {
    Name        = "${var.project_name}-dlq-processor-logs-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

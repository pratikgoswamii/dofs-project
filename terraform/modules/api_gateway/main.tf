# API Gateway Module for DOFS
resource "aws_api_gateway_rest_api" "dofs_api" {
  name        = "${var.project_name}-api"
  description = "DOFS API Gateway"
  
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# API Gateway Resource for /health
resource "aws_api_gateway_resource" "health_resource" {
  rest_api_id = aws_api_gateway_rest_api.dofs_api.id
  parent_id   = aws_api_gateway_rest_api.dofs_api.root_resource_id
  path_part   = "health"
}

# API Gateway Method for GET /health
resource "aws_api_gateway_method" "get_health" {
  rest_api_id   = aws_api_gateway_rest_api.dofs_api.id
  resource_id   = aws_api_gateway_resource.health_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

# API Gateway Integration for /health
resource "aws_api_gateway_integration" "health_lambda_integration" {
  rest_api_id = aws_api_gateway_rest_api.dofs_api.id
  resource_id = aws_api_gateway_resource.health_resource.id
  http_method = aws_api_gateway_method.get_health.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.api_handler_lambda_invoke_arn
}

# API Gateway Method Response for /health
resource "aws_api_gateway_method_response" "get_health_response" {
  rest_api_id = aws_api_gateway_rest_api.dofs_api.id
  resource_id = aws_api_gateway_resource.health_resource.id
  http_method = aws_api_gateway_method.get_health.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

# API Gateway Integration Response for /health
resource "aws_api_gateway_integration_response" "get_health_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.dofs_api.id
  resource_id = aws_api_gateway_resource.health_resource.id
  http_method = aws_api_gateway_method.get_health.http_method
  status_code = aws_api_gateway_method_response.get_health_response.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }

  depends_on = [aws_api_gateway_integration.health_lambda_integration]
}

# API Gateway Resource for /order
resource "aws_api_gateway_resource" "order_resource" {
  rest_api_id = aws_api_gateway_rest_api.dofs_api.id
  parent_id   = aws_api_gateway_rest_api.dofs_api.root_resource_id
  path_part   = "order"
}

# API Gateway Method for POST /order
resource "aws_api_gateway_method" "post_order" {
  rest_api_id   = aws_api_gateway_rest_api.dofs_api.id
  resource_id   = aws_api_gateway_resource.order_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

# API Gateway Integration with Lambda
resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id = aws_api_gateway_rest_api.dofs_api.id
  resource_id = aws_api_gateway_resource.order_resource.id
  http_method = aws_api_gateway_method.post_order.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.api_handler_lambda_invoke_arn
}

# API Gateway Method Response
resource "aws_api_gateway_method_response" "post_order_response" {
  rest_api_id = aws_api_gateway_rest_api.dofs_api.id
  resource_id = aws_api_gateway_resource.order_resource.id
  http_method = aws_api_gateway_method.post_order.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

# API Gateway Integration Response
resource "aws_api_gateway_integration_response" "post_order_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.dofs_api.id
  resource_id = aws_api_gateway_resource.order_resource.id
  http_method = aws_api_gateway_method.post_order.http_method
  status_code = aws_api_gateway_method_response.post_order_response.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }

  depends_on = [aws_api_gateway_integration.lambda_integration]
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "dofs_api_deployment" {
  depends_on = [
    aws_api_gateway_integration.health_lambda_integration,
    aws_api_gateway_integration_response.get_health_integration_response,
    aws_api_gateway_integration.lambda_integration,
    aws_api_gateway_integration_response.post_order_integration_response
  ]

  rest_api_id = aws_api_gateway_rest_api.dofs_api.id

  lifecycle {
    create_before_destroy = true
  }
}

# API Gateway Stage
resource "aws_api_gateway_stage" "dofs_api_stage" {
  deployment_id = aws_api_gateway_deployment.dofs_api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.dofs_api.id
  stage_name    = var.environment
}

# Lambda Permission for API Gateway
resource "aws_lambda_permission" "api_gateway_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = var.api_handler_lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.dofs_api.execution_arn}/*/*"
}

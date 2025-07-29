# DynamoDB Tables for DOFS

# Orders Table
resource "aws_dynamodb_table" "orders" {
  name           = "${var.project_name}-orders-${var.environment}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "order_id"

  attribute {
    name = "order_id"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  global_secondary_index {
    name            = "status-index"
    hash_key        = "status"
    projection_type = "ALL"
  }

  tags = {
    Name        = "${var.project_name}-orders-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Failed Orders Table (for DLQ processing)
resource "aws_dynamodb_table" "failed_orders" {
  name           = "${var.project_name}-failed-orders-${var.environment}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "order_id"

  attribute {
    name = "order_id"
    type = "S"
  }

  attribute {
    name = "failed_at"
    type = "S"
  }

  global_secondary_index {
    name            = "failed-at-index"
    hash_key        = "failed_at"
    projection_type = "ALL"
  }

  tags = {
    Name        = "${var.project_name}-failed-orders-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

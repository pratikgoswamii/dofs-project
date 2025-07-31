# SQS Queues for DOFS

# Dead Letter Queue
resource "aws_sqs_queue" "order_dlq" {
  name = "${var.project_name}-order-dlq-${var.environment}"

  tags = {
    Name        = "${var.project_name}-order-dlq-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Main Order Queue
resource "aws_sqs_queue" "order_queue" {
  name                      = "${var.project_name}-order-queue-${var.environment}"
  delay_seconds             = 0
  max_message_size          = 262144
  message_retention_seconds = 1209600
  receive_wait_time_seconds = 0
  visibility_timeout_seconds = 30

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.order_dlq.arn
    maxReceiveCount     = var.max_receive_count
  })

  tags = {
    Name        = "${var.project_name}-order-queue-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

# CloudWatch Alarm for DLQ depth
resource "aws_cloudwatch_metric_alarm" "dlq_alarm" {
  alarm_name          = "${var.project_name}-dlq-depth-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ApproximateNumberOfMessages"
  namespace           = "AWS/SQS"
  period              = "60"
  statistic           = "Average"
  threshold           = var.dlq_alarm_threshold
  alarm_description   = "This metric monitors DLQ depth"
  alarm_actions       = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

  dimensions = {
    QueueName = aws_sqs_queue.order_dlq.name
  }

  tags = {
    Name        = "${var.project_name}-dlq-alarm-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

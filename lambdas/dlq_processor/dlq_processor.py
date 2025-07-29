# import json
# import boto3
# import logging
# import os
# from datetime import datetime

# # Configure logging
# logger = logging.getLogger()
# logger.setLevel(logging.INFO)

# # Initialize AWS clients
# dynamodb = boto3.resource('dynamodb')
# sns = boto3.client('sns')

# def lambda_handler(event, context):
#     """
#     DLQ Processor Lambda function for DOFS project
#     Processes messages from the Dead Letter Queue and stores them in failed_orders table
#     """
#     try:
#         # Log the incoming event with structured logging
#         logger.info(json.dumps({
#             'event': 'dlq_processor_triggered',
#             'request_id': context.aws_request_id,
#             'timestamp': datetime.utcnow().isoformat(),
#             'records_count': len(event.get('Records', []))
#         }))
        
#         # Process each DLQ record
#         processed_count = 0
#         failed_count = 0
        
#         for record in event.get('Records', []):
#             try:
#                 process_dlq_record(record, context)
#                 processed_count += 1
#             except Exception as e:
#                 logger.error(json.dumps({
#                     'event': 'dlq_record_processing_error',
#                     'error': str(e),
#                     'record_id': record.get('messageId', 'unknown'),
#                     'request_id': context.aws_request_id,
#                     'timestamp': datetime.utcnow().isoformat()
#                 }))
#                 failed_count += 1
        
#         logger.info(json.dumps({
#             'event': 'dlq_processing_completed',
#             'processed_count': processed_count,
#             'failed_count': failed_count,
#             'request_id': context.aws_request_id,
#             'timestamp': datetime.utcnow().isoformat()
#         }))
        
#         return {
#             'statusCode': 200,
#             'body': json.dumps({
#                 'message': 'DLQ processing completed',
#                 'processed_count': processed_count,
#                 'failed_count': failed_count
#             })
#         }
        
#     except Exception as e:
#         logger.error(json.dumps({
#             'event': 'dlq_processor_error',
#             'request_id': context.aws_request_id,
#             'error': str(e),
#             'timestamp': datetime.utcnow().isoformat()
#         }))
        
#         return {
#             'statusCode': 500,
#             'body': json.dumps({
#                 'error': 'DLQ processor failed',
#                 'message': str(e)
#             })
#         }

# def process_dlq_record(record, context):
#     """
#     Process individual DLQ record and store in failed_orders table
#     """
#     try:
#         # Parse SQS message
#         message_body = json.loads(record['body'])
#         order_data = message_body.get('order', {})
#         order_id = order_data.get('order_id', 'unknown')
        
#         # Get message attributes
#         message_id = record.get('messageId', 'unknown')
#         receipt_handle = record.get('receiptHandle', '')
        
#         logger.info(json.dumps({
#             'event': 'processing_dlq_record',
#             'order_id': order_id,
#             'message_id': message_id,
#             'request_id': context.aws_request_id,
#             'timestamp': datetime.utcnow().isoformat()
#         }))
        
#         # Get failed orders table name from environment
#         failed_orders_table_name = os.environ.get('FAILED_ORDERS_TABLE_NAME')
#         if not failed_orders_table_name:
#             raise ValueError('FAILED_ORDERS_TABLE_NAME environment variable not set')
        
#         # Store failed order in DynamoDB
#         failed_orders_table = dynamodb.Table(failed_orders_table_name)
        
#         failed_order_record = {
#             'order_id': order_id,
#             'original_order': order_data,
#             'failed_at': datetime.utcnow().isoformat(),
#             'failure_reason': 'Order processing failed after maximum retries',
#             'message_id': message_id,
#             'dlq_processed_at': datetime.utcnow().isoformat(),
#             'retry_count': get_retry_count_from_attributes(record),
#             'source': 'dlq_processor'
#         }
        
#         failed_orders_table.put_item(Item=failed_order_record)
        
#         logger.info(json.dumps({
#             'event': 'failed_order_stored',
#             'order_id': order_id,
#             'message_id': message_id,
#             'request_id': context.aws_request_id,
#             'timestamp': datetime.utcnow().isoformat()
#         }))
        
#         # Send alert notification if SNS topic is configured
#         send_dlq_alert(order_id, order_data, context)
        
#     except Exception as e:
#         logger.error(json.dumps({
#             'event': 'dlq_record_processing_error',
#             'order_id': order_data.get('order_id', 'unknown'),
#             'error': str(e),
#             'request_id': context.aws_request_id,
#             'timestamp': datetime.utcnow().isoformat()
#         }))
#         raise e

# def get_retry_count_from_attributes(record):
#     """
#     Extract retry count from SQS message attributes
#     """
#     try:
#         attributes = record.get('attributes', {})
#         approximate_receive_count = attributes.get('ApproximateReceiveCount', '1')
#         return int(approximate_receive_count)
#     except (ValueError, TypeError):
#         return 1

# def send_dlq_alert(order_id, order_data, context):
#     """
#     Send alert notification for DLQ processing
#     """
#     try:
#         # Get SNS topic ARN from environment (optional)
#         sns_topic_arn = os.environ.get('DLQ_ALERT_SNS_TOPIC_ARN')
        
#         if not sns_topic_arn:
#             logger.info(json.dumps({
#                 'event': 'dlq_alert_skipped',
#                 'reason': 'SNS topic not configured',
#                 'order_id': order_id,
#                 'request_id': context.aws_request_id,
#                 'timestamp': datetime.utcnow().isoformat()
#             }))
#             return
        
#         # Prepare alert message
#         alert_message = {
#             'alert_type': 'DLQ_ORDER_FAILURE',
#             'order_id': order_id,
#             'customer_id': order_data.get('customer_id', 'unknown'),
#             'failed_at': datetime.utcnow().isoformat(),
#             'total_amount': order_data.get('total_amount', 0),
#             'items_count': len(order_data.get('items', [])),
#             'message': f'Order {order_id} has been moved to DLQ after multiple failed attempts'
#         }
        
#         # Send SNS notification
#         sns.publish(
#             TopicArn=sns_topic_arn,
#             Message=json.dumps(alert_message, indent=2),
#             Subject=f'DOFS Alert: Order Failed - {order_id}',
#             MessageAttributes={
#                 'alert_type': {
#                     'DataType': 'String',
#                     'StringValue': 'DLQ_ORDER_FAILURE'
#                 },
#                 'order_id': {
#                     'DataType': 'String',
#                     'StringValue': order_id
#                 }
#             }
#         )
        
#         logger.info(json.dumps({
#             'event': 'dlq_alert_sent',
#             'order_id': order_id,
#             'sns_topic_arn': sns_topic_arn,
#             'request_id': context.aws_request_id,
#             'timestamp': datetime.utcnow().isoformat()
#         }))
        
#     except Exception as e:
#         logger.warning(json.dumps({
#             'event': 'dlq_alert_failed',
#             'order_id': order_id,
#             'error': str(e),
#             'request_id': context.aws_request_id,
#             'timestamp': datetime.utcnow().isoformat()
#         }))
#         # Don't fail the entire DLQ processing if alert fails
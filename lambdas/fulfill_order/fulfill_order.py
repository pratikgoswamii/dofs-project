import json
import boto3
import logging
import os
import random
from datetime import datetime, timezone

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb')
sns = boto3.client('sns')

def lambda_handler(event, context):
    """
    Fulfill Order Lambda function for DOFS project
    Processes SQS messages and fulfills validated orders with 70% success rate
    """
    try:
        # Log the incoming event with structured logging
        logger.info(json.dumps({
            'event': 'fulfillment_triggered',
            'request_id': context.aws_request_id,
            'timestamp': datetime.now(timezone.utc).isoformat(),
            'records_count': len(event.get('Records', []))
        }))
        
        # Process each SQS record
        for record in event.get('Records', []):
            process_order_record(record, context)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'All records processed successfully',
                'processed_count': len(event.get('Records', []))
            })
        }
        
    except Exception as e:
        logger.error(json.dumps({
            'event': 'fulfillment_handler_error',
            'request_id': context.aws_request_id,
            'error': str(e),
            'timestamp': datetime.now(timezone.utc).isoformat()
        }))
        
        # Re-raise to trigger SQS retry mechanism
        raise e

def process_order_record(record, context):
    """
    Process individual SQS record containing order data
    """
    try:
        # Parse SQS message body
        message_body = json.loads(record['body'])
        order_data = message_body.get('order', {})
        order_id = order_data.get('order_id')
        
        if not order_id:
            logger.error(json.dumps({
                'event': 'invalid_order_record',
                'error': 'Missing order_id in SQS message',
                'request_id': context.aws_request_id,
                'timestamp': datetime.now(timezone.utc).isoformat()
            }))
            return
        
        logger.info(json.dumps({
            'event': 'processing_order',
            'order_id': order_id,
            'request_id': context.aws_request_id,
            'timestamp': datetime.now(timezone.utc).isoformat()
        }))
        
        # Get table names from environment
        orders_table_name = os.environ.get('ORDERS_TABLE_NAME')
        failed_orders_table_name = os.environ.get('FAILED_ORDERS_TABLE_NAME')
        
        if not orders_table_name:
            raise ValueError('ORDERS_TABLE_NAME environment variable not set')
        
        # Get DynamoDB table
        orders_table = dynamodb.Table(orders_table_name)
        
        # Update order status to 'fulfilling'
        orders_table.update_item(
            Key={'order_id': order_id},
            UpdateExpression='SET #status = :status, updated_at = :updated_at',
            ExpressionAttributeNames={'#status': 'status'},
            ExpressionAttributeValues={
                ':status': 'fulfilling',
                ':updated_at': datetime.now(timezone.utc).isoformat()
            }
        )
        
        # Simulate order fulfillment with 70% success rate
        success_rate = 0.7
        is_successful = random.random() < success_rate
        
        if is_successful:
            # Successful fulfillment
            fulfill_order_successfully(orders_table, order_id, order_data, context)
        else:
            # Failed fulfillment
            handle_fulfillment_failure(orders_table, failed_orders_table_name, order_id, order_data, context)
            
    except Exception as e:
        logger.error(json.dumps({
            'event': 'order_processing_error',
            'order_id': order_data.get('order_id', 'unknown'),
            'error': str(e),
            'request_id': context.aws_request_id,
            'timestamp': datetime.now(timezone.utc).isoformat()
        }))
        
        # Re-raise to trigger SQS retry
        raise e

def fulfill_order_successfully(orders_table, order_id, order_data, context):
    """
    Handle successful order fulfillment
    """
    try:
        # Update order status to 'fulfilled'
        orders_table.update_item(
            Key={'order_id': order_id},
            UpdateExpression='SET #status = :status, updated_at = :updated_at, fulfilled_at = :fulfilled_at',
            ExpressionAttributeNames={'#status': 'status'},
            ExpressionAttributeValues={
                ':status': 'fulfilled',
                ':updated_at': datetime.now(timezone.utc).isoformat(),
                ':fulfilled_at': datetime.now(timezone.utc).isoformat()
            }
        )
        
        logger.info(json.dumps({
            'event': 'order_fulfilled_successfully',
            'order_id': order_id,
            'request_id': context.aws_request_id,
            'timestamp': datetime.now(timezone.utc).isoformat()
        }))
        
    except Exception as e:
        logger.error(json.dumps({
            'event': 'fulfillment_update_error',
            'order_id': order_id,
            'error': str(e),
            'request_id': context.aws_request_id,
            'timestamp': datetime.now(timezone.utc).isoformat()
        }))
        raise e

def handle_fulfillment_failure(orders_table, failed_orders_table_name, order_id, order_data, context):
    """
    Handle failed order fulfillment
    """
    try:
        # Update order status to 'failed'
        orders_table.update_item(
            Key={'order_id': order_id},
            UpdateExpression='SET #status = :status, updated_at = :updated_at, failed_at = :failed_at',
            ExpressionAttributeNames={'#status': 'status'},
            ExpressionAttributeValues={
                ':status': 'failed',
                ':updated_at': datetime.now(timezone.utc).isoformat(),
                ':failed_at': datetime.now(timezone.utc).isoformat()
            }
        )
        
        # Store in failed orders table if configured
        if failed_orders_table_name:
            failed_orders_table = dynamodb.Table(failed_orders_table_name)
            
            failed_order_record = {
                'order_id': order_id,
                'original_order': order_data,
                'failed_at': datetime.now(timezone.utc).isoformat(),
                'failure_reason': 'Simulated fulfillment failure (30% failure rate)',
                'retry_count': 0
            }
            
            failed_orders_table.put_item(Item=failed_order_record)
        
        logger.warning(json.dumps({
            'event': 'order_fulfillment_failed',
            'order_id': order_id,
            'request_id': context.aws_request_id,
            'timestamp': datetime.now(timezone.utc).isoformat()
        }))
        
        # Raise exception to trigger SQS retry mechanism
        raise Exception(f'Order fulfillment failed for order {order_id}')
        
    except Exception as e:
        logger.error(json.dumps({
            'event': 'failure_handling_error',
            'order_id': order_id,
            'error': str(e),
            'request_id': context.aws_request_id,
            'timestamp': datetime.now(timezone.utc).isoformat()
        }))
        raise e

def send_fulfillment_notification(order_id, order_data):
    """
    Send notification about order fulfillment
    """
    try:
        # TODO: Replace with actual SNS topic ARN from environment
        topic_arn = 'arn:aws:sns:region:account:order-notifications'
        
        message = {
            'order_id': order_id,
            'customer_id': order_data.get('customer_id'),
            'status': 'fulfilled',
            'message': f'Order {order_id} has been successfully fulfilled'
        }
        
        sns.publish(
            TopicArn=topic_arn,
            Message=json.dumps(message),
            Subject=f'Order Fulfilled: {order_id}'
        )
        
        logger.info(f"Notification sent for order: {order_id}")
        
    except Exception as e:
        logger.warning(f"Failed to send notification for order {order_id}: {str(e)}")
        # Don't fail the entire fulfillment process if notification fails

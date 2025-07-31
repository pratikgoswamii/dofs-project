import json
import boto3
import logging
import os
import random
from datetime import datetime, timezone

## Testing CI/CD ##


# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb')

def lambda_handler(event, context):
    """
    Fulfillment Lambda - Processes orders from SQS with 70% success rate
    Failed orders will be retried by SQS and eventually sent to DLQ
    """
    try:
        logger.info(json.dumps({
            'event': 'fulfillment_started',
            'records_count': len(event.get('Records', [])),
            'request_id': context.aws_request_id
        }))
        
        # Process each SQS record (should be 1 due to batch_size=1)
        for record in event.get('Records', []):
            process_order_from_sqs(record, context)
        
        return {
            'statusCode': 200,
            'body': json.dumps({'message': 'Orders processed successfully'})
        }
        
    except Exception as e:
        logger.error(json.dumps({
            'event': 'fulfillment_handler_error',
            'error': str(e),
            'request_id': context.aws_request_id
        }))
        
        # Re-raise exception to trigger SQS retry mechanism
        raise e

def process_order_from_sqs(record, context):
    """
    Process individual SQS message containing order data
    Simulates 70% success rate - failures will trigger SQS retries
    """
    try:
        # Parse SQS message
        message_body = json.loads(record['body'])
        order_id = message_body.get('order_id')
        customer_id = message_body.get('customer_id')
        
        logger.info(json.dumps({
            'event': 'processing_order',
            'order_id': order_id,
            'customer_id': customer_id,
            'message_id': record.get('messageId'),
            'request_id': context.aws_request_id
        }))
        
        # Simulate fulfillment with 70% success rate
        success_rate = 0.7
        is_successful = random.random() < success_rate
        
        if is_successful:
            # Success case - update order status to FULFILLED
            update_order_status(order_id, 'FULFILLED')
            
            logger.info(json.dumps({
                'event': 'order_fulfilled_successfully',
                'order_id': order_id,
                'customer_id': customer_id,
                'request_id': context.aws_request_id
            }))
            
        else:
            # Failure case - this will trigger SQS retry
            logger.warning(json.dumps({
                'event': 'order_fulfillment_failed',
                'order_id': order_id,
                'customer_id': customer_id,
                'message_id': record.get('messageId'),
                'request_id': context.aws_request_id
            }))
            
            # Update order status to FAILED (for tracking)
            update_order_status(order_id, 'FAILED')
            
            # Raise exception to trigger SQS retry mechanism
            # After max retries (2), message will go to DLQ
            raise Exception(f'Fulfillment failed for order {order_id} (simulated 30% failure rate)')
            
    except json.JSONDecodeError as e:
        logger.error(json.dumps({
            'event': 'invalid_sqs_message',
            'error': str(e),
            'message_id': record.get('messageId'),
            'request_id': context.aws_request_id
        }))
        # Raise exception to trigger SQS retry and eventual DLQ
        raise e
        
    except Exception as e:
        logger.error(json.dumps({
            'event': 'order_processing_error',
            'order_id': message_body.get('order_id', 'unknown'),
            'error': str(e),
            'message_id': record.get('messageId'),
            'request_id': context.aws_request_id
        }))
        
        # Re-raise to trigger SQS retry
        raise e

def update_order_status(order_id, status):
    """
    Update order status in DynamoDB orders table
    """
    try:
        # Get table name from environment
        table_name = os.environ.get('ORDERS_TABLE_NAME')
        if not table_name:
            raise ValueError('ORDERS_TABLE_NAME environment variable not set')
        
        table = dynamodb.Table(table_name)
        
        # Update order status
        table.update_item(
            Key={'order_id': order_id},
            UpdateExpression='SET #status = :status, updated_at = :updated_at',
            ExpressionAttributeNames={'#status': 'status'},
            ExpressionAttributeValues={
                ':status': status,
                ':updated_at': datetime.now(timezone.utc).isoformat()
            }
        )
        
        logger.info(json.dumps({
            'event': 'order_status_updated',
            'order_id': order_id,
            'status': status,
            'table_name': table_name
        }))
        
    except Exception as e:
        logger.error(json.dumps({
            'event': 'status_update_error',
            'order_id': order_id,
            'error': str(e)
        }))
        # Don't fail the entire process if status update fails
        pass
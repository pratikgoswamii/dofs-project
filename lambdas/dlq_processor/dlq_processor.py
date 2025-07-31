import json
import boto3
import logging
import os
from datetime import datetime, timezone

## Testing CI/CD ##

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb')

def lambda_handler(event, context):
    """
    DLQ Processor Lambda - Processes messages from Dead Letter Queue
    Stores failed orders in failed_orders DynamoDB table
    """
    try:
        logger.info(json.dumps({
            'event': 'dlq_processing_started',
            'records_count': len(event.get('Records', [])),
            'request_id': context.aws_request_id
        }))
        
        # Process each DLQ record
        for record in event.get('Records', []):
            process_failed_order(record, context)
        
        return {
            'statusCode': 200,
            'body': json.dumps({'message': 'DLQ messages processed successfully'})
        }
        
    except Exception as e:
        logger.error(json.dumps({
            'event': 'dlq_processor_error',
            'error': str(e),
            'request_id': context.aws_request_id
        }))
        
        # Don't re-raise - we don't want DLQ messages to fail again
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Failed to process DLQ messages'})
        }

def process_failed_order(record, context):
    """
    Process individual DLQ message and store in failed_orders table
    """
    try:
        # Parse DLQ message (original SQS message)
        message_body = json.loads(record['body'])
        order_id = message_body.get('order_id')
        customer_id = message_body.get('customer_id')
        
        logger.info(json.dumps({
            'event': 'processing_failed_order',
            'order_id': order_id,
            'customer_id': customer_id,
            'message_id': record.get('messageId'),
            'request_id': context.aws_request_id
        }))
        
        # Store failed order in failed_orders table
        store_failed_order(message_body, record, context)
        
        logger.info(json.dumps({
            'event': 'failed_order_stored',
            'order_id': order_id,
            'customer_id': customer_id,
            'request_id': context.aws_request_id
        }))
        
    except Exception as e:
        logger.error(json.dumps({
            'event': 'failed_order_processing_error',
            'error': str(e),
            'message_id': record.get('messageId'),
            'request_id': context.aws_request_id
        }))
        # Don't re-raise - log error and continue

def store_failed_order(original_message, dlq_record, context):
    """
    Store failed order information in failed_orders DynamoDB table
    """
    # Get table name from environment
    table_name = os.environ.get('FAILED_ORDERS_TABLE_NAME')
    if not table_name:
        raise ValueError('FAILED_ORDERS_TABLE_NAME environment variable not set')
    
    table = dynamodb.Table(table_name)
    
    # Prepare failed order record
    failed_order_record = {
        'order_id': original_message.get('order_id'),
        'customer_id': original_message.get('customer_id'),
        'original_message': original_message,
        'dlq_message_id': dlq_record.get('messageId'),
        'failure_reason': 'Order fulfillment failed after maximum retries',
        'failed_at': datetime.now(timezone.utc).isoformat(),
        'retry_count': 2,  # Based on our max_receive_count setting
        'source_queue': 'order_queue'
    }
    
    # Store in failed_orders table
    table.put_item(Item=failed_order_record)
    
    logger.info(json.dumps({
        'event': 'failed_order_saved_to_dynamodb',
        'order_id': original_message.get('order_id'),
        'table_name': table_name
    }))
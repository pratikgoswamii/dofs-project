import json
import boto3
import logging
import os
import uuid
from datetime import datetime, timezone

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb')
sqs = boto3.client('sqs')

def lambda_handler(event, context):
    """
    Order Storage Lambda - Stores validated orders and sends to SQS
    Called by Step Function after successful validation
    """
    try:
        # Extract validated order from Step Function
        order_data = event.get('order', {})
        
        logger.info(json.dumps({
            'event': 'order_storage_started',
            'customer_id': order_data.get('customer_id'),
            'request_id': context.aws_request_id
        }))
        
        # Generate unique order ID
        order_id = str(uuid.uuid4())
        
        # Store order in DynamoDB
        stored_order = store_order_in_dynamodb(order_data, order_id)
        
        # Send order to SQS for fulfillment
        send_order_to_sqs(stored_order)
        
        logger.info(json.dumps({
            'event': 'order_stored_successfully',
            'order_id': order_id,
            'customer_id': order_data.get('customer_id'),
            'request_id': context.aws_request_id
        }))
        
        # Return success result for Step Function
        return {
            'stored': True,
            'order_id': order_id,
            'order': stored_order
        }
        
    except Exception as e:
        logger.error(json.dumps({
            'event': 'order_storage_error',
            'error': str(e),
            'customer_id': order_data.get('customer_id'),
            'request_id': context.aws_request_id
        }))
        
        # Re-raise exception to fail Step Function
        raise e

def store_order_in_dynamodb(order_data, order_id):
    """
    Store order in DynamoDB orders table
    """
    # Get table name from environment
    table_name = os.environ.get('ORDERS_TABLE_NAME')
    if not table_name:
        raise ValueError('ORDERS_TABLE_NAME environment variable not set')
    
    table = dynamodb.Table(table_name)
    
    # Prepare order record
    order_record = {
        'order_id': order_id,
        'customer_id': order_data['customer_id'],
        'items': order_data['items'],
        'total_amount': order_data['total_amount'],
        'shipping_address': order_data.get('shipping_address', {}),
        'status': 'PENDING',
        'created_at': datetime.now(timezone.utc).isoformat(),
        'updated_at': datetime.now(timezone.utc).isoformat()
    }
    
    # Store in DynamoDB
    table.put_item(Item=order_record)
    
    logger.info(json.dumps({
        'event': 'order_saved_to_dynamodb',
        'order_id': order_id,
        'table_name': table_name
    }))
    
    return order_record

def send_order_to_sqs(order_record):
    """
    Send order to SQS queue for fulfillment processing
    """
    # Get queue URL from environment
    queue_url = os.environ.get('ORDER_QUEUE_URL')
    if not queue_url:
        raise ValueError('ORDER_QUEUE_URL environment variable not set')
    
    # Prepare SQS message
    message_body = {
        'order_id': order_record['order_id'],
        'customer_id': order_record['customer_id'],
        'total_amount': order_record['total_amount'],
        'status': order_record['status'],
        'created_at': order_record['created_at']
    }
    
    # Send message to SQS
    response = sqs.send_message(
        QueueUrl=queue_url,
        MessageBody=json.dumps(message_body),
        MessageAttributes={
            'order_id': {
                'StringValue': order_record['order_id'],
                'DataType': 'String'
            },
            'customer_id': {
                'StringValue': order_record['customer_id'],
                'DataType': 'String'
            }
        }
    )
    
    logger.info(json.dumps({
        'event': 'order_sent_to_sqs',
        'order_id': order_record['order_id'],
        'message_id': response['MessageId'],
        'queue_url': queue_url
    }))
    
    return response
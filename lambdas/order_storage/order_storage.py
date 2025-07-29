import json
import boto3
import logging
from datetime import datetime, timezone
import uuid

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

"""This function saves an order into a database. It adds some useful info like timestamps and status, generates a unique ID if one isn't given, and then inserts everything into DynamoDB. If something fails, it logs the error and tells us."""

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb')

def lambda_handler(event, context):
    """
    Order Storage Lambda function for DOFS project
    Stores validated orders in DynamoDB
    """
    try:
        # Log the incoming event
        logger.info(f"Order Storage received event: {json.dumps(event)}")
        
        # Extract order data from event
        order_data = event.get('order', {})
        
        # Add metadata to order
        order_data['created_at'] = datetime.now(timezone.utc).isoformat()
        order_data['updated_at'] = datetime.now(timezone.utc).isoformat()
        order_data['status'] = 'pending'
        
        # Generate order ID if not provided
        if 'order_id' not in order_data:
            order_data['order_id'] = str(uuid.uuid4())
        
        # TODO: Replace 'orders-table' with actual table name from environment
        table_name = 'orders-table'
        
        try:
            # Get DynamoDB table
            table = dynamodb.Table(table_name)
            
            # Store the order
            response = table.put_item(Item=order_data)
            
            logger.info(f"Order stored successfully: {order_data['order_id']}")
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'Order stored successfully',
                    'order_id': order_data['order_id'],
                    'status': 'stored'
                })
            }
            
        except Exception as db_error:
            logger.error(f"Database error: {str(db_error)}")
            return {
                'statusCode': 500,
                'body': json.dumps({
                    'error': 'Database storage failed',
                    'message': str(db_error),
                    'order_id': order_data.get('order_id', 'unknown')
                })
            }
        
    except Exception as e:
        logger.error(f"Error in order storage: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': 'Order storage service error',
                'message': str(e)
            })
        }

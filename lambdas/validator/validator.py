import json
import boto3
import logging
from typing import Dict, Any

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

"""This function checks if a customer order has all the correct fields — like an order ID, customer ID, item list, and total price. It also makes sure that every item in the order has a product ID and a valid quantity. If something is missing or incorrect, it tells you what's wrong. It's like a quality check before the order moves on to the next step."""

def lambda_handler(event, context):
    """
    Validator Lambda function for DOFS project
    Validates incoming orders and data before processing
    """
    try:
        # Log the incoming event
        logger.info(f"Validator received event: {json.dumps(event)}")
        
        # Extract order data from event and return empty response if no order data is found
        order_data = event.get('order', {})
        
        # Validation results
        validation_result = {
            'is_valid': True,
            'errors': [],
            'warnings': []
        }
        
        # Validate required fields
        required_fields = ['order_id', 'customer_id', 'items', 'total_amount']
        for field in required_fields:
            if field not in order_data or not order_data[field]:
                validation_result['is_valid'] = False
                validation_result['errors'].append(f"Missing required field: {field}")
        
        # Validate order items
        if 'items' in order_data and isinstance(order_data['items'], list):
            for i, item in enumerate(order_data['items']):
                if not item.get('product_id'):
                    validation_result['is_valid'] = False
                    validation_result['errors'].append(f"Item {i}: Missing product_id")
                if not item.get('quantity') or item['quantity'] <= 0:
                    validation_result['is_valid'] = False
                    validation_result['errors'].append(f"Item {i}: Invalid quantity")
        
        # Validate total amount
        if 'total_amount' in order_data:
            try:
                amount = float(order_data['total_amount'])
                if amount <= 0:
                    validation_result['is_valid'] = False
                    validation_result['errors'].append("Total amount must be greater than 0")
            except (ValueError, TypeError):
                validation_result['is_valid'] = False
                validation_result['errors'].append("Invalid total amount format")
        
        logger.info(f"Validation result: {validation_result}")
        
        # Return format for Step Functions
        result = {
            'valid': validation_result['is_valid'],
            'order': order_data,
            'validation_result': validation_result,
            'order_id': order_data.get('order_id', 'unknown')
        }
        
        logger.info(f"Validator returning: {result}")
        return result
        
    except Exception as e:
        logger.error(f"Error in validator: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': 'Validation service error',
                'message': str(e)
            })
        }

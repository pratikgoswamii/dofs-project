import json
import logging
from datetime import datetime, timezone

## Testing CI/CD ##

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """
    Validator Lambda - Validates order data from Step Function
    Checks required fields and returns validation result
    """
    try:
        logger.info(json.dumps({
            'event': 'validation_started',
            'request_id': context.aws_request_id
        }))
        
        # Extract order data from Step Function input
        order_data = event
        
        # Validate required fields
        validation_result = validate_order(order_data)
        
        logger.info(json.dumps({
            'event': 'validation_completed',
            'valid': validation_result['valid'],
            'customer_id': order_data.get('customer_id'),
            'request_id': context.aws_request_id
        }))
        
        # Return validation result for Step Function
        return {
            'valid': validation_result['valid'],
            'order': order_data,
            'validation_errors': validation_result.get('errors', [])
        }
        
    except Exception as e:
        logger.error(json.dumps({
            'event': 'validation_error',
            'error': str(e),
            'request_id': context.aws_request_id
        }))
        
        # Return invalid result on any error
        return {
            'valid': False,
            'order': event,
            'validation_errors': [f'Validation failed: {str(e)}']
        }

def validate_order(order_data):
    """
    Validate order data - check required fields
    Returns: {'valid': bool, 'errors': []}
    """
    errors = []
    
    # Check required fields
    required_fields = ['customer_id', 'items', 'total_amount']
    
    for field in required_fields:
        if not order_data.get(field):
            errors.append(f'Missing required field: {field}')
    
    # Validate items array
    items = order_data.get('items', [])
    if not isinstance(items, list) or len(items) == 0:
        errors.append('Items must be a non-empty array')
    else:
        # Check each item has required fields
        for i, item in enumerate(items):
            if not item.get('product_id'):
                errors.append(f'Item {i}: missing product_id')
            if not isinstance(item.get('quantity'), (int, float)) or item.get('quantity') <= 0:
                errors.append(f'Item {i}: quantity must be positive number')
            if not isinstance(item.get('price'), (int, float)) or item.get('price') < 0:
                errors.append(f'Item {i}: price must be non-negative number')
    
    # Validate total_amount
    total_amount = order_data.get('total_amount')
    if not isinstance(total_amount, (int, float)) or total_amount <= 0:
        errors.append('total_amount must be positive number')
    
    return {
        'valid': len(errors) == 0,
        'errors': errors
    }
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
stepfunctions = boto3.client('stepfunctions')

def lambda_handler(event, context):
    """
    API Handler Lambda - Entry point for DOFS order processing
    Handles both health checks and order submissions
    """
    try:
        # Parse the incoming request
        http_method = event.get('httpMethod', '')
        path = event.get('path', '')
        
        logger.info(json.dumps({
            'event': 'api_request_received',
            'method': http_method,
            'path': path,
            'request_id': context.aws_request_id
        }))
        
        # Health check endpoint
        if http_method == 'GET' and path == '/health':
            return {
                'statusCode': 200,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({
                    'status': 'healthy',
                    'message': 'DOFS API is running',
                    'timestamp': datetime.now(timezone.utc).isoformat()
                })
            }
        
        # Order submission endpoint
        elif http_method == 'POST' and path == '/order':
            return handle_order_submission(event, context)
        
        # Invalid endpoint
        else:
            return {
                'statusCode': 404,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'Endpoint not found'})
            }
            
    except Exception as e:
        logger.error(json.dumps({
            'event': 'api_handler_error',
            'error': str(e),
            'request_id': context.aws_request_id
        }))
        
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': 'Internal server error'})
        }

def handle_order_submission(event, context):
    """
    Handle POST /order requests by starting Step Function execution
    """
    try:
        # Parse request body
        body = json.loads(event.get('body', '{}'))
        
        # Basic validation - just check if customer_id exists
        if not body.get('customer_id'):
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': 'customer_id is required'})
            }
        
        # Get Step Function ARN from environment
        step_function_arn = os.environ.get('STEP_FUNCTION_ARN')
        if not step_function_arn:
            raise ValueError('STEP_FUNCTION_ARN environment variable not set')
        
        # Start Step Function execution
        execution_name = f"order-{context.aws_request_id}"
        
        response = stepfunctions.start_execution(
            stateMachineArn=step_function_arn,
            name=execution_name,
            input=json.dumps(body)
        )
        
        logger.info(json.dumps({
            'event': 'step_function_started',
            'execution_arn': response['executionArn'],
            'customer_id': body.get('customer_id'),
            'request_id': context.aws_request_id
        }))
        
        # Return success response with execution ARN
        return {
            'statusCode': 202,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'message': 'Order received and processing started',
                'execution_arn': response['executionArn'],
                'customer_id': body.get('customer_id')
            })
        }
        
    except json.JSONDecodeError:
        return {
            'statusCode': 400,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': 'Invalid JSON in request body'})
        }
    except Exception as e:
        logger.error(json.dumps({
            'event': 'order_submission_error',
            'error': str(e),
            'request_id': context.aws_request_id
        }))
        
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': 'Failed to process order'})
        }
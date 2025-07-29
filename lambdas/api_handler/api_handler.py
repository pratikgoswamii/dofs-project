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
stepfunctions = boto3.client('stepfunctions')

def lambda_handler(event, context):
    """
    API Handler Lambda function for DOFS project
    Handles incoming API requests and routes them appropriately
    """
    try:
        # Log the incoming event with structured logging
        logger.info(json.dumps({
            'event': 'api_request_received',
            'request_id': context.aws_request_id,
            'timestamp': datetime.now(timezone.utc).isoformat(),
            'http_method': event.get('httpMethod', ''),
            'path': event.get('path', '')
        }))
        
        # Extract HTTP method and path
        http_method = event.get('httpMethod', '')
        path = event.get('path', '')
        
        # Health check endpoint
        if http_method == 'GET' and path == '/health':
            return {
                'statusCode': 200,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({
                    'message': 'API Handler is healthy',
                    'service': 'dofs-api-handler',
                    'timestamp': datetime.now(timezone.utc).isoformat()
                })
            }
        
        # Handle POST /order requests
        if http_method == 'POST' and path == '/order':
            return handle_order_request(event, context)
        
        # Handle unsupported endpoints
        logger.warning(json.dumps({
            'event': 'unsupported_endpoint',
            'request_id': context.aws_request_id,
            'http_method': http_method,
            'path': path
        }))
        
        return {
            'statusCode': 404,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': 'Endpoint not found',
                'message': f'{http_method} {path} is not supported'
            })
        }
        
    except Exception as e:
        logger.error(json.dumps({
            'event': 'api_handler_error',
            'request_id': context.aws_request_id,
            'error': str(e),
            'timestamp': datetime.now(timezone.utc).isoformat()
        }))
        
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': 'Internal server error',
                'message': 'An unexpected error occurred'
            })
        }

def handle_order_request(event, context):
    """
    Handle POST /order requests by triggering Step Functions
    """
    try:
        # Parse request body
        body = event.get('body', '{}')
        if isinstance(body, str):
            order_data = json.loads(body)
        else:
            order_data = body
        
        # Generate order ID if not provided
        if 'order_id' not in order_data:
            order_data['order_id'] = str(uuid.uuid4())
        
        # Add request metadata
        order_data['request_id'] = context.aws_request_id
        order_data['received_at'] = datetime.now(timezone.utc).isoformat()
        
        logger.info(json.dumps({
            'event': 'order_received',
            'order_id': order_data['order_id'],
            'request_id': context.aws_request_id,
            'timestamp': datetime.now(timezone.utc).isoformat()
        }))
        
        # Get Step Function ARN from environment
        step_function_arn = os.environ.get('STEP_FUNCTION_ARN')
        if not step_function_arn:
            raise ValueError('STEP_FUNCTION_ARN environment variable not set')
        
        # Start Step Function execution
        execution_name = f"order-{order_data['order_id']}-{int(datetime.now(timezone.utc).timestamp())}"
        
        response = stepfunctions.start_execution(
            stateMachineArn=step_function_arn,
            name=execution_name,
            input=json.dumps({'order': order_data})
        )
        
        logger.info(json.dumps({
            'event': 'step_function_started',
            'order_id': order_data['order_id'],
            'execution_arn': response['executionArn'],
            'request_id': context.aws_request_id,
            'timestamp': datetime.now(timezone.utc).isoformat()
        }))
        
        return {
            'statusCode': 202,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'message': 'Order received and processing started',
                'order_id': order_data['order_id'],
                'execution_arn': response['executionArn'],
                'timestamp': datetime.now(timezone.utc).isoformat()
            })
        }
        
    except json.JSONDecodeError as e:
        logger.error(json.dumps({
            'event': 'invalid_json',
            'error': str(e),
            'request_id': context.aws_request_id,
            'timestamp': datetime.now(timezone.utc).isoformat()
        }))
        
        return {
            'statusCode': 400,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': 'Invalid JSON',
                'message': 'Request body must be valid JSON'
            })
        }
        
    except Exception as e:
        logger.error(json.dumps({
            'event': 'order_processing_error',
            'error': str(e),
            'request_id': context.aws_request_id,
            'timestamp': datetime.now(timezone.utc).isoformat()
        }))
        
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': 'Order processing failed',
                'message': 'Unable to process order request'
            })
        }

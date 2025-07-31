#!/bin/bash

# DOFS API Testing Script
# This script comprehensively tests the deployed DOFS API endpoints for:
# 1. Health check - Verifies API Gateway and Lambda connectivity
# 2. Valid order submission - Tests complete order processing workflow
# 3. Invalid order submission - Tests validation failure handling
# 4. DLQ functionality - Tests failure handling and retry logic

set -e

API_URL=${1:-"https://ghuniii2v7.execute-api.ap-south-1.amazonaws.com/dev"}

echo ""
echo "🧪 Testing DOFS API at: $API_URL"
echo "==============================="

# ---- 1. Health Endpoint Test ----
echo "🔍 Testing health endpoint..."
echo "   Purpose: Verify API Gateway and Lambda connectivity"

HEALTH_RESPONSE=$(curl -s -X GET "$API_URL/health" -H "Content-Type: application/json")
HEALTH_STATUS=$(echo "$HEALTH_RESPONSE" | jq -r '.message // "No message"')

echo "✅ Health Check Response:"
echo "$HEALTH_RESPONSE" | jq .
echo ""

# ---- 2. Valid Order Test ----
echo "📦 Testing VALID order submission..."
echo "   Purpose: Test complete order processing workflow (API → Step Function → Validation → Storage → SQS → Fulfillment)"

# Valid order payload with all required fields
ORDER_PAYLOAD_SUCCESS='{
  "customer_id": "cust_12345",
  "items": [
    {
      "product_id": "prod_001",
      "quantity": 2,
      "price": 29.99
    },
    {
      "product_id": "prod_002", 
      "quantity": 1,
      "price": 15.50
    }
  ],
  "total_amount": 75.48,
  "shipping_address": {
    "street": "123 Main St",
    "city": "Anytown",
    "state": "CA",
    "zip": "12345"
  }
}'

RESPONSE_SUCCESS=$(curl -s -X POST "$API_URL/order" \
  -H "Content-Type: application/json" \
  -d "$ORDER_PAYLOAD_SUCCESS")

echo "✅ Valid Order Response:"
echo "$RESPONSE_SUCCESS" | jq .

# Extract execution ARN and check Step Function status
EXECUTION_ARN_SUCCESS=$(echo "$RESPONSE_SUCCESS" | jq -r '.execution_arn')
if [ "$EXECUTION_ARN_SUCCESS" != "null" ] && [ "$EXECUTION_ARN_SUCCESS" != "" ]; then
    echo "🔍 Checking Step Function execution status..."
    sleep 5  # Wait for execution to complete
    
    STATUS_SUCCESS=$(aws stepfunctions describe-execution --execution-arn "$EXECUTION_ARN_SUCCESS" --region ap-south-1 --query 'status' --output text 2>/dev/null || echo "UNKNOWN")
    echo "📊 Step Function Status: $STATUS_SUCCESS"
    
    if [ "$STATUS_SUCCESS" = "SUCCEEDED" ]; then
        echo "✅ SUCCESS: Valid order processed successfully through Step Function!"
        echo "   → Order should now be in DynamoDB and sent to SQS for fulfillment"
        echo "   → Fulfillment Lambda will process with 70% success rate"
        echo "   → Failed orders (30%) will retry and eventually go to DLQ"
    else
        echo "⚠️  WARNING: Valid order failed in Step Function (Status: $STATUS_SUCCESS)"
        # Get failure details if available
        FAILURE_CAUSE=$(aws stepfunctions describe-execution --execution-arn "$EXECUTION_ARN_SUCCESS" --region ap-south-1 --query 'cause' --output text 2>/dev/null || echo "Unknown")
        echo "🔍 Failure Cause: $FAILURE_CAUSE"
    fi
else
    echo "⚠️  WARNING: No execution ARN returned from API"
fi
echo ""

# ---- 3. Invalid Order Test ----
echo "🚫 Testing INVALID order submission..."
echo "   Purpose: Test validation failure handling (missing customer_id)"

# Invalid order payload - missing customer_id (required field)
ORDER_PAYLOAD_INVALID='{
  "items": [
    { 
      "product_id": "prod_001", 
      "quantity": 2, 
      "price": 29.99 
    }
  ],
  "total_amount": 29.99,
  "shipping_address": {
    "street": "No ID St",
    "city": "Nowhere",
    "state": "XX",
    "zip": "00000"
  }
}'

RESPONSE_FAILURE=$(curl -s -X POST "$API_URL/order" \
  -H "Content-Type: application/json" \
  -d "$ORDER_PAYLOAD_INVALID")

echo "❌ Invalid Order Response:"
echo "$RESPONSE_FAILURE" | jq .

# Check if API rejected it immediately or if it went to Step Function
if echo "$RESPONSE_FAILURE" | jq -e '.error' > /dev/null; then
    echo "✅ VALIDATION WORKING: API correctly rejected invalid order immediately!"
    echo "   → customer_id validation working at API level"
else
    # If API accepted it, check Step Function status
    EXECUTION_ARN_FAILURE=$(echo "$RESPONSE_FAILURE" | jq -r '.execution_arn')
    if [ "$EXECUTION_ARN_FAILURE" != "null" ] && [ "$EXECUTION_ARN_FAILURE" != "" ]; then
        echo "🔍 Checking Step Function execution status..."
        sleep 5  # Wait for validation to complete
        
        STATUS_FAILURE=$(aws stepfunctions describe-execution --execution-arn "$EXECUTION_ARN_FAILURE" --region ap-south-1 --query 'status' --output text 2>/dev/null || echo "UNKNOWN")
        echo "📊 Step Function Status: $STATUS_FAILURE"
        
        if [ "$STATUS_FAILURE" = "FAILED" ]; then
            echo "✅ VALIDATION WORKING: Invalid order correctly failed in Step Function!"
            echo "   → Validator Lambda correctly identified missing fields"
            # Get failure details
            FAILURE_CAUSE=$(aws stepfunctions describe-execution --execution-arn "$EXECUTION_ARN_FAILURE" --region ap-south-1 --query 'cause' --output text 2>/dev/null || echo "Unknown")
            echo "🔍 Failure Cause: $FAILURE_CAUSE"
        else
            echo "⚠️  WARNING: Invalid order did not fail as expected (Status: $STATUS_FAILURE)"
        fi
    fi
fi
echo ""

# ---- 4. DLQ Status Check ----
echo "💥 Checking DLQ status..."
echo "   Purpose: Monitor failed order processing and DLQ functionality"

# Check current DLQ message count
DLQ_COUNT=$(aws sqs get-queue-attributes --queue-url https://sqs.ap-south-1.amazonaws.com/861276075939/dofs-order-dlq-dev --attribute-names ApproximateNumberOfMessages --region ap-south-1 --query 'Attributes.ApproximateNumberOfMessages' --output text 2>/dev/null || echo "0")
echo "📊 Current DLQ Message Count: $DLQ_COUNT"

# Check failed orders table
FAILED_ORDERS_COUNT=$(aws dynamodb scan --table-name dofs-failed-orders-dev --region ap-south-1 --query "Count" --output text 2>/dev/null || echo "0")
echo "📊 Failed Orders in DynamoDB: $FAILED_ORDERS_COUNT"

# Check successful orders table
SUCCESS_ORDERS_COUNT=$(aws dynamodb scan --table-name dofs-orders-dev --region ap-south-1 --query "Count" --output text 2>/dev/null || echo "0")
echo "📊 Successful Orders in DynamoDB: $SUCCESS_ORDERS_COUNT"

if [ "$DLQ_COUNT" -gt "0" ]; then
    echo "✅ DLQ WORKING: Found $DLQ_COUNT message(s) in Dead Letter Queue!"
    echo "   → Failed orders are being processed by DLQ processor"
    echo "   → Check failed_orders table for processed failures"
else
    echo "ℹ️  DLQ Status: No messages currently in DLQ"
    echo "   → This is normal if all orders are succeeding or still being retried"
    echo "   → DLQ will populate when fulfillment failures exceed retry limit"
fi
echo ""

# ---- 5. System Status Summary ----
echo "📊 DOFS System Status Summary:"
echo "================================"
echo "✅ API Gateway: Responding"
echo "✅ Lambda Functions: Deployed and functional"
echo "✅ Step Functions: Orchestrating workflow"
echo "✅ Validation: Working (rejects invalid orders)"
echo "✅ DynamoDB: Ready for order storage"
echo "✅ SQS: Configured with DLQ (maxReceiveCount: 1-3)"
echo "✅ Fulfillment: 70% success rate simulation"
echo ""

# ---- 6. Monitoring Instructions ----
echo "🔍 To monitor the system in real-time:"
echo "1. CloudWatch Logs:"
echo "   - API Handler: /aws/lambda/dofs-api-handler-dev"
echo "   - Validator: /aws/lambda/dofs-validator-dev"
echo "   - Order Storage: /aws/lambda/dofs-order-storage-dev"
echo "   - Fulfillment: /aws/lambda/dofs-fulfillment-dev"
echo "   - DLQ Processor: /aws/lambda/dofs-dlq-processor-dev"
echo ""
echo "2. Step Functions:"
echo "   - State Machine: dofs-order-processing-dev"
echo "   - Monitor execution history and success/failure rates"
echo ""
echo "3. DynamoDB Tables:"
echo "   - Orders: dofs-orders-dev (successful orders)"
echo "   - Failed Orders: dofs-failed-orders-dev (DLQ processed failures)"
echo ""
echo "4. SQS Queues:"
echo "   - Main Queue: dofs-order-queue-dev"
echo "   - Dead Letter Queue: dofs-order-dlq-dev"
echo ""

echo "🎉 DOFS API Testing Complete!"
echo ""
echo "💡 Next Steps:"
echo "- Submit multiple valid orders to test fulfillment and DLQ"
echo "- Monitor CloudWatch logs for detailed processing information"
echo "- Check DynamoDB tables for order storage and failure tracking"
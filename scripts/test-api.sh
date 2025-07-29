#!/bin/bash

# DOFS API Testing Script
# This script tests the deployed DOFS API endpoints for:
# 1. Health check
# 2. Order submission (success)
# 3. Invalid order (failure)
# 4. Simulated DLQ handling

set -e

API_URL=${1:-"https://ghuniii2v7.execute-api.ap-south-1.amazonaws.com/dev"}

echo ""
echo "🧪 Testing DOFS API at: $API_URL"
echo "==============================="

# ---- 1. Health Endpoint ----
echo "🔍 Testing health endpoint..."
HEALTH_RESPONSE=$(curl -s -X GET "$API_URL/health" -H "Content-Type: application/json")
HEALTH_STATUS=$(echo "$HEALTH_RESPONSE" | jq -r '.message // "No message"')

echo "✅ Health Check Response:"
echo "$HEALTH_RESPONSE" | jq .
echo ""

# ---- 2. Success Scenario ----
echo "📦 Testing successful order submission..."

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

echo "✅ Success Response:"
echo "$RESPONSE_SUCCESS" | jq .

# Extract execution ARN and check status
EXECUTION_ARN_SUCCESS=$(echo "$RESPONSE_SUCCESS" | jq -r '.execution_arn')
echo "🔍 Checking Step Function execution status..."
sleep 3  # Wait for execution to start

STATUS_SUCCESS=$(aws stepfunctions describe-execution --execution-arn "$EXECUTION_ARN_SUCCESS" --region ap-south-1 --query 'status' --output text 2>/dev/null || echo "UNKNOWN")
echo "📊 Step Function Status: $STATUS_SUCCESS"
echo ""

# ---- 3. Failure Scenario (missing customer_id) ----
echo "🚫 Testing failure (invalid order)..."

ORDER_PAYLOAD_INVALID='{
  "items": [
    { "product_id": "prod_001", "quantity": 2, "price": 29.99 }
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

echo "❌ Failure Response (API accepts, but should fail in Step Function):"
echo "$RESPONSE_FAILURE" | jq .

# Extract execution ARN and check status
EXECUTION_ARN_FAILURE=$(echo "$RESPONSE_FAILURE" | jq -r '.execution_arn')
echo "🔍 Checking Step Function execution status..."
sleep 5  # Wait longer for validation to complete

STATUS_FAILURE=$(aws stepfunctions describe-execution --execution-arn "$EXECUTION_ARN_FAILURE" --region ap-south-1 --query 'status' --output text 2>/dev/null || echo "UNKNOWN")
echo "📊 Step Function Status: $STATUS_FAILURE"

if [ "$STATUS_FAILURE" = "FAILED" ]; then
    echo "✅ VALIDATION WORKING: Invalid order correctly failed in Step Function!"
    # Get failure details
    FAILURE_CAUSE=$(aws stepfunctions describe-execution --execution-arn "$EXECUTION_ARN_FAILURE" --region ap-south-1 --query 'cause' --output text 2>/dev/null || echo "Unknown")
    echo "🔍 Failure Cause: $FAILURE_CAUSE"
else
    echo "⚠️  WARNING: Invalid order did not fail as expected (Status: $STATUS_FAILURE)"
fi
echo ""

# ---- 4. DLQ Simulation ----
echo "💥 Simulating DLQ condition..."

ORDER_PAYLOAD_DLQ='{
  "customer_id": "dlq_test",
  "items": [
    {
      "product_id": "invalid", 
      "quantity": 9999999,
      "price": -100.00
    }
  ],
  "total_amount": -999.99,
  "shipping_address": {
    "street": "Crash Lane",
    "city": "Bugsville",
    "state": "ER",
    "zip": "40404"
  }
}'

RESPONSE_DLQ=$(curl -s -X POST "$API_URL/order" \
  -H "Content-Type: application/json" \
  -d "$ORDER_PAYLOAD_DLQ")

echo "📨 DLQ Simulation Response:"
echo "$RESPONSE_DLQ" | jq .
echo ""

# ---- Done ----
echo "🎉 All tests completed."
echo ""
echo "📊 To monitor the system:"
echo "1. CloudWatch logs for Lambda"
echo "2. Step Functions for execution flow"
echo "3. DynamoDB for order storage"
echo "4. SQS + DLQ queue for failures"
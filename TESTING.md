# DOFS Testing Guide

## Overview
This guide covers comprehensive testing of the DOFS (Distributed Order Fulfillment System) including success scenarios, failure handling, and CI/CD validation.

## Prerequisites
- AWS CLI configured with appropriate permissions
- `jq` installed for JSON parsing
- Access to AWS Console for monitoring

## Test Scenarios

### 1. Success Scenario Testing

#### Health Check Test
```bash
curl -X GET "https://ghuniii2v7.execute-api.ap-south-1.amazonaws.com/dev/health"
```
**Expected Response:**
```json
{
  "status": "healthy",
  "message": "DOFS API is running",
  "timestamp": "2025-01-31T10:00:00Z"
}
```

#### Valid Order Processing
```bash
curl -X POST "https://ghuniii2v7.execute-api.ap-south-1.amazonaws.com/dev/order" \
  -H "Content-Type: application/json" \
  -d '{
    "customer_id": "cust_12345",
    "items": [
      {
        "product_id": "prod_001",
        "quantity": 2,
        "price": 29.99
      }
    ],
    "total_amount": 59.98,
    "shipping_address": {
      "street": "123 Main St",
      "city": "Anytown",
      "state": "CA",
      "zip": "12345"
    }
  }'
```

**Expected Flow:**
1. API returns 202 with execution ARN
2. Step Function processes successfully
3. Order stored in DynamoDB
4. Message sent to SQS for fulfillment
5. 70% chance of successful fulfillment

**Verification:**
```bash
# Check Step Function status
aws stepfunctions describe-execution --execution-arn "EXECUTION_ARN" --region ap-south-1

# Check DynamoDB orders
aws dynamodb scan --table-name dofs-orders-dev --region ap-south-1
```

### 2. Failure and DLQ Testing

#### Validation Failure Test
```bash
curl -X POST "https://ghuniii2v7.execute-api.ap-south-1.amazonaws.com/dev/order" \
  -H "Content-Type: application/json" \
  -d '{
    "items": [
      {"product_id": "prod_001", "quantity": 2, "price": 29.99}
    ],
    "total_amount": 29.99
  }'
```

**Expected Result:**
- Step Function fails at validation step
- Order not stored in DynamoDB
- No SQS message sent

#### DLQ Testing
Submit multiple valid orders to trigger 30% fulfillment failures:

```bash
# Submit 20 orders to trigger some failures
for i in {1..20}; do
  curl -s -X POST "https://ghuniii2v7.execute-api.ap-south-1.amazonaws.com/dev/order" \
    -H "Content-Type: application/json" \
    -d "{
      \"customer_id\": \"test_$i\",
      \"items\": [{\"product_id\": \"prod_$i\", \"quantity\": 1, \"price\": 25.99}],
      \"total_amount\": 25.99,
      \"shipping_address\": {\"street\": \"$i Test St\", \"city\": \"TestCity\", \"state\": \"TC\", \"zip\": \"1000$i\"}
    }"
done
```

**Monitor DLQ:**
```bash
# Check DLQ message count
aws sqs get-queue-attributes \
  --queue-url https://sqs.ap-south-1.amazonaws.com/ACCOUNT/dofs-order-dlq-dev \
  --attribute-names ApproximateNumberOfMessages \
  --region ap-south-1

# Check failed orders table
aws dynamodb scan --table-name dofs-failed-orders-dev --region ap-south-1
```

### 3. CI/CD System Testing

#### Code Change Test
1. **Make a code change:**
   ```python
   # Add comment to any Lambda function
   ## CI/CD Test - $(date)
   ```

2. **Commit and push:**
   ```bash
   git add .
   git commit -m "Test CI/CD pipeline"
   git push
   ```

3. **Monitor pipeline:**
   ```bash
   # Check pipeline status
   aws codepipeline list-pipeline-executions \
     --pipeline-name dofs-pipeline-dev \
     --region ap-south-1 \
     --max-items 1

   # Check build logs
   aws logs describe-log-streams \
     --log-group-name /aws/codebuild/dofs-build-dev \
     --region ap-south-1 \
     --order-by LastEventTime \
     --descending \
     --max-items 1
   ```

4. **Verify deployment:**
   - Check Lambda function code in AWS Console
   - Verify "Last modified" timestamp is recent
   - Test API functionality

## Automated Testing Script

Use the provided `test-api.sh` script for comprehensive testing:

```bash
cd scripts
chmod +x test-api.sh
./test-api.sh
```

## Monitoring and Troubleshooting

### CloudWatch Logs
- **API Handler:** `/aws/lambda/dofs-api-handler-dev`
- **Validator:** `/aws/lambda/dofs-validator-dev`
- **Order Storage:** `/aws/lambda/dofs-order-storage-dev`
- **Fulfillment:** `/aws/lambda/dofs-fulfillment-dev`
- **DLQ Processor:** `/aws/lambda/dofs-dlq-processor-dev`

### Step Functions Monitoring
- Navigate to AWS Console → Step Functions
- Select `dofs-order-processing-dev`
- Monitor execution history and failure patterns

### DynamoDB Monitoring
- **Orders Table:** `dofs-orders-dev`
- **Failed Orders Table:** `dofs-failed-orders-dev`

### SQS Monitoring
- **Main Queue:** `dofs-order-queue-dev`
- **Dead Letter Queue:** `dofs-order-dlq-dev`

## Expected Results Summary

| Test Type | Expected Outcome |
|-----------|------------------|
| Health Check | 200 OK with status message |
| Valid Order | 202 Accepted, Step Function succeeds |
| Invalid Order | Step Function fails at validation |
| Fulfillment | 70% success, 30% to DLQ |
| CI/CD | Code changes deployed within 3-5 minutes |

## Performance Benchmarks

- **API Response Time:** < 500ms
- **Order Processing:** < 10 seconds end-to-end
- **CI/CD Pipeline:** 3-5 minutes total
- **DLQ Processing:** < 30 seconds after retry exhaustion
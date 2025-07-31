# DOFS Troubleshooting Guide

## Common Issues and Solutions

### 1. CI/CD Pipeline Issues

#### Pipeline Not Triggering
**Symptoms:** Git push doesn't trigger CodePipeline
**Solutions:**
```bash
# Check GitHub connection status
aws codestar-connections list-connections --region ap-south-1

# If connection is PENDING, update it in AWS Console:
# CodePipeline > Settings > Connections > Update pending connection
```

#### Lambda Functions Not Updating
**Symptoms:** Code changes not reflected in AWS Lambda
**Root Cause:** Missing `source_code_hash` in Terraform

**Solution:** Ensure all Lambda resources include:
```hcl
resource "aws_lambda_function" "example" {
  filename         = "path/to/function.zip"
  source_code_hash = filebase64sha256("path/to/function.zip")
  # ... other configuration
}
```

#### Build Failures
**Symptoms:** CodeBuild fails during execution
**Debug Steps:**
```bash
# Check build logs
aws logs describe-log-streams \
  --log-group-name /aws/codebuild/dofs-build-dev \
  --region ap-south-1 \
  --order-by LastEventTime \
  --descending

# Get specific log events
aws logs get-log-events \
  --log-group-name /aws/codebuild/dofs-build-dev \
  --log-stream-name "LOG_STREAM_NAME" \
  --region ap-south-1
```

### 2. API Gateway Issues

#### 502 Bad Gateway
**Symptoms:** API returns 502 error
**Solutions:**
```bash
# Check Lambda function logs
aws logs describe-log-streams \
  --log-group-name /aws/lambda/dofs-api-handler-dev \
  --region ap-south-1

# Test Lambda function directly
aws lambda invoke \
  --function-name dofs-api-handler-dev \
  --payload '{"httpMethod":"GET","path":"/health"}' \
  --region ap-south-1 \
  response.json
```

#### CORS Issues
**Symptoms:** Browser blocks API requests
**Solution:** Update API Gateway CORS settings in `terraform/modules/api_gateway/main.tf`

### 3. Step Functions Issues

#### Executions Failing at Validation
**Symptoms:** All orders fail at validator step
**Debug Steps:**
```bash
# Get execution details
aws stepfunctions describe-execution \
  --execution-arn "EXECUTION_ARN" \
  --region ap-south-1

# Check validator logs
aws logs filter-log-events \
  --log-group-name /aws/lambda/dofs-validator-dev \
  --region ap-south-1 \
  --start-time $(date -d '1 hour ago' +%s)000
```

#### Step Function Not Starting
**Symptoms:** API returns success but no Step Function execution
**Solution:** Check IAM permissions for API handler Lambda

### 4. DynamoDB Issues

#### Float Type Errors
**Symptoms:** "Float types are not supported" error
**Solution:** Ensure all numeric values are converted to Decimal:
```python
from decimal import Decimal

# Convert floats to Decimal
total_amount = Decimal(str(float_value))
```

#### Access Denied
**Symptoms:** Lambda can't write to DynamoDB
**Solution:** Check IAM role permissions in `terraform/modules/compute/main.tf`

### 5. SQS and DLQ Issues

#### Messages Not Processing
**Symptoms:** SQS messages remain in queue
**Debug Steps:**
```bash
# Check queue attributes
aws sqs get-queue-attributes \
  --queue-url QUEUE_URL \
  --attribute-names All \
  --region ap-south-1

# Check Lambda event source mapping
aws lambda list-event-source-mappings \
  --function-name dofs-fulfillment-dev \
  --region ap-south-1
```

#### DLQ Not Receiving Messages
**Symptoms:** Failed messages don't go to DLQ
**Solutions:**
1. Check `maxReceiveCount` setting
2. Ensure Lambda function raises exceptions (doesn't catch and ignore)
3. Verify DLQ configuration in SQS

### 6. Terraform Issues

#### State Lock
**Symptoms:** "Error acquiring the state lock"
**Solution:**
```bash
# Force unlock (use carefully)
terraform force-unlock LOCK_ID

# Or delete lock from DynamoDB if using remote state
```

#### Resource Already Exists
**Symptoms:** "Resource already exists" during apply
**Solution:**
```bash
# Import existing resource
terraform import aws_lambda_function.example function-name

# Or destroy and recreate
terraform destroy -target=resource.name
terraform apply -target=resource.name
```

### 7. Monitoring and Debugging

#### Enable Detailed Logging
Add to Lambda functions:
```python
import logging
logger = logging.getLogger()
logger.setLevel(logging.DEBUG)
```

#### CloudWatch Insights Queries
```sql
-- API Gateway errors
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 20

-- Step Function failures
fields @timestamp, @message
| filter @message like /FAILED/
| sort @timestamp desc
| limit 20
```

### 8. Performance Issues

#### Lambda Cold Starts
**Solutions:**
- Use provisioned concurrency for critical functions
- Optimize package size
- Use ARM-based processors

#### DynamoDB Throttling
**Solutions:**
- Enable auto-scaling
- Use on-demand billing
- Implement exponential backoff

### 9. Security Issues

#### IAM Permission Errors
**Debug Steps:**
```bash
# Check IAM role policies
aws iam list-attached-role-policies --role-name ROLE_NAME
aws iam get-role-policy --role-name ROLE_NAME --policy-name POLICY_NAME

# Test permissions
aws sts get-caller-identity
```

### 10. Environment-Specific Issues

#### Development vs Production
**Common Differences:**
- Resource naming (dev/prod suffixes)
- IAM permissions (more restrictive in prod)
- Monitoring thresholds
- Retry configurations

## Debug Commands Reference

```bash
# Check all DOFS resources
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Project,Values=DOFS \
  --region ap-south-1

# Monitor API Gateway
aws logs tail /aws/apigateway/dofs-api-dev --follow

# Monitor all Lambda functions
aws logs tail /aws/lambda/dofs-api-handler-dev /aws/lambda/dofs-validator-dev --follow

# Check Step Function executions
aws stepfunctions list-executions \
  --state-machine-arn STATE_MACHINE_ARN \
  --region ap-south-1

# Monitor SQS queues
watch -n 5 'aws sqs get-queue-attributes --queue-url QUEUE_URL --attribute-names ApproximateNumberOfMessages --region ap-south-1'
```

## Getting Help

1. **Check CloudWatch Logs** - Most issues are logged
2. **Review Terraform Plan** - Before applying changes
3. **Test Components Individually** - Isolate the problem
4. **Use AWS Console** - Visual debugging tools
5. **Check AWS Service Health** - Rule out service issues

## Prevention Best Practices

1. **Use Infrastructure as Code** - Version control all changes
2. **Implement Monitoring** - Set up alerts for failures
3. **Test Thoroughly** - Use the provided test scripts
4. **Document Changes** - Keep track of modifications
5. **Regular Backups** - Export important configurations
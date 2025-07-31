# DOFS (Distributed Order Fulfillment System)

🚀 **A production-ready serverless AWS application demonstrating enterprise-grade distributed system patterns**

## 📋 Overview

DOFS is a **distributed, asynchronous order processing system** built entirely on AWS serverless technologies. It demonstrates real-world patterns for:

- ✅ **Microservices Architecture** with Lambda functions
- ✅ **Event-Driven Processing** with Step Functions and SQS
- ✅ **Asynchronous Validation** and error handling
- ✅ **Scalable Data Storage** with DynamoDB
- ✅ **Infrastructure as Code** with Terraform
- ✅ **CI/CD Pipeline** with CodePipeline and CodeBuild
- ✅ **Comprehensive Monitoring** with CloudWatch

## 🏗️ Architecture

```
Client Request
      ↓
┌─────────────────┐
│   API Gateway   │ ← REST API endpoints (/health, /order)
└─────────────────┘
      ↓
┌─────────────────┐
│  API Handler    │ ← Accepts requests, starts Step Function
│    (Lambda)     │
└─────────────────┘
      ↓
┌─────────────────┐
│ Step Functions  │ ← Orchestrates validation → storage → fulfillment
│   Workflow      │
└─────────────────┘
      ↓
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Validator     │ →  │ Order Storage   │ →  │      SQS        │
│   (Lambda)      │    │    (Lambda)     │    │  Order Queue    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              ↓                        ↓
                       ┌─────────────────┐    ┌─────────────────┐
                       │   DynamoDB      │    │ Fulfill Order   │
                       │ Orders Table    │    │   (Lambda)      │
                       └─────────────────┘    └─────────────────┘
                                                       ↓
                                              ┌─────────────────┐
                                              │ 70% Success     │
                                              │ 30% → DLQ      │
                                              └─────────────────┘
```

## 🎯 Key Features

### **Asynchronous Processing Pattern**
- API immediately returns "Order received" (fast response)
- Validation happens asynchronously in Step Functions
- Invalid orders fail at validation step (not at API level)

### **Enterprise Error Handling**
- Step Function orchestrates the entire workflow
- SQS with Dead Letter Queue for failed fulfillments
- Comprehensive CloudWatch logging
- Structured JSON logging throughout

### **Scalable Architecture**
- Serverless auto-scaling
- Event-driven processing
- Separation of concerns (API ≠ Validation ≠ Storage ≠ Fulfillment)

### **Production Patterns**
- Infrastructure as Code (Terraform)
- Environment-specific configurations
- IAM least-privilege security
- Monitoring and alerting ready

## 📁 Project Structure

```
dofs-project/
├── 📂 lambdas/                    # Lambda function source code
│   ├── 🔌 api_handler/           # API Gateway request handler
│   │   ├── api_handler.py        # Main handler logic
│   │   └── api_handler.zip       # Deployment package
│   ├── ✅ validator/             # Order validation service
│   │   ├── validator.py          # Validation logic
│   │   └── validator.zip         # Deployment package
│   ├── 💾 order_storage/         # DynamoDB storage service
│   │   ├── order_storage.py      # Storage logic
│   │   └── order_storage.zip     # Deployment package
│   └── 🚚 fulfill_order/         # Order fulfillment service
│       ├── fulfill_order.py      # Fulfillment logic (70% success rate)
│       └── fulfill_order.zip     # Deployment package
├── 🏗️ terraform/                 # Infrastructure as Code
│   ├── main.tf                   # Root Terraform configuration
│   ├── variables.tf              # Input variables
│   ├── outputs.tf                # Output values
│   ├── backend.tf                # S3 backend configuration
│   └── 📦 modules/               # Reusable Terraform modules
│       ├── 🗄️ dynamodb/          # DynamoDB tables
│       ├── 📨 sqs/               # SQS queues and DLQ
│       ├── 💻 compute/           # Lambda functions + Step Functions
│       ├── 🌐 api_gateway/       # REST API configuration
│       └── 🔄 cicd/              # CI/CD pipeline (optional)
├── 🧪 scripts/                   # Testing and utility scripts
│   └── test-api.sh               # Comprehensive API testing
└── 📖 README.md                  # This documentation
```

## 🚀 Quick Start

### Prerequisites
- AWS CLI configured with appropriate permissions
- Terraform >= 1.0
- PowerShell (for Windows) or Bash (for Linux/Mac)
- jq (for JSON parsing in test scripts)

### 1. 📥 Clone and Setup
```bash
git clone https://github.com/pratikgoswamii/dofs-project.git
cd dofs-project
```

### 2. 🏗️ Deploy Infrastructure
```bash
cd terraform

# Initialize Terraform
terraform init

# Review deployment plan
terraform plan

# Deploy infrastructure
terraform apply
```

### 3. 🧪 Test the System
```bash
cd ../scripts
./test-api.sh
```

## 🔧 Configuration

### Environment Variables
The system uses these key environment variables (automatically set by Terraform):

| Variable | Description | Example |
|----------|-------------|----------|
| `ORDERS_TABLE_NAME` | DynamoDB orders table | `dofs-orders-dev` |
| `FAILED_ORDERS_TABLE_NAME` | DynamoDB failed orders table | `dofs-failed-orders-dev` |
| `ORDER_QUEUE_URL` | SQS order queue URL | `https://sqs.ap-south-1.amazonaws.com/...` |
| `ORDER_DLQ_ARN` | Dead Letter Queue ARN | `arn:aws:sqs:ap-south-1:...` |
| `STEP_FUNCTION_ARN` | Step Functions state machine ARN | `arn:aws:states:ap-south-1:...` |
| `ENVIRONMENT` | Deployment environment | `dev` |

## 🧪 Testing

### Automated Testing
The `test-api.sh` script provides comprehensive testing:

```bash
cd scripts
./test-api.sh
```

**Test Scenarios:**
1. ✅ **Health Check** → Verifies API Gateway is responding
2. ✅ **Valid Order** → Tests complete order processing workflow
3. ❌ **Invalid Order** → Tests validation failure (missing customer_id)
4. 🔄 **DLQ Simulation** → Tests failure handling and retry logic

### Expected Results
```bash
🏥 Testing health endpoint...
✅ Health Status: healthy

✅ Testing valid order...
📊 Step Function Status: SUCCEEDED

🚫 Testing failure (invalid order)...
📊 Step Function Status: FAILED
✅ VALIDATION WORKING: Invalid order correctly failed in Step Function!
```

### Manual Testing

**Health Check:**
```bash
curl -X GET "https://ghuniii2v7.execute-api.ap-south-1.amazonaws.com/dev/health"
```

**Submit Order:**
```bash
curl -X POST "https://ghuniii2v7.execute-api.ap-south-1.amazonaws.com/dev/order" \
  -H "Content-Type: application/json" \
  -d '{
    "customer_id": "cust_123",
    "items": [
      {"product_id": "prod_001", "quantity": 2, "price": 29.99}
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

## 📊 Monitoring

### CloudWatch Logs
Each Lambda function has dedicated log groups:
- `/aws/lambda/dofs-api-handler-dev`
- `/aws/lambda/dofs-validator-dev`
- `/aws/lambda/dofs-order-storage-dev`
- `/aws/lambda/dofs-fulfill-order-dev`

### Step Functions
Monitor workflow executions in AWS Console:
- **AWS Console** → **Step Functions** → **dofs-order-processing-dev**
- View execution history, success/failure rates
- Debug failed executions with detailed logs

### DynamoDB Tables
- **Orders Table:** `dofs-orders-dev` (successful orders)
- **Failed Orders Table:** `dofs-failed-orders-dev` (validation failures)

## 🛠️ Development

### Adding New Features
1. **Lambda Functions:** Add new functions in `lambdas/` directory
2. **Infrastructure:** Update Terraform modules in `terraform/modules/`
3. **Testing:** Extend `test-api.sh` with new test cases

### Local Development
```bash
# Update Lambda code
cd lambdas/validator
# Edit validator.py

# Create new deployment package
Compress-Archive -Path .\validator.py -DestinationPath .\validator.zip -Force

# Deploy updated function
aws lambda update-function-code \
  --function-name dofs-validator-dev \
  --zip-file fileb://validator.zip \
  --region ap-south-1
```

## 🔒 Security

### IAM Roles
- **Least Privilege:** Each Lambda has minimal required permissions
- **Separation:** API, validation, storage, and fulfillment use separate roles
- **Resource-Specific:** Policies target specific DynamoDB tables and SQS queues

### API Security
- **CORS:** Configured for web application integration
- **Input Validation:** Comprehensive validation in validator Lambda
- **Error Handling:** No sensitive information exposed in error responses

## 🚀 Production Considerations

### Scaling
- **Lambda Concurrency:** Configure reserved concurrency for critical functions
- **DynamoDB:** Enable auto-scaling for read/write capacity
- **SQS:** Configure appropriate visibility timeout and message retention

### Monitoring & Alerting
- **CloudWatch Alarms:** Set up alerts for error rates and latency
- **SNS Integration:** Add notification system for critical failures
- **X-Ray Tracing:** Enable for distributed tracing (optional)

### Cost Optimization
- **Lambda:** Use ARM-based processors for cost savings
- **DynamoDB:** Use on-demand billing for variable workloads
- **CloudWatch:** Set appropriate log retention periods

## 🎯 Architecture Decisions

### Why Asynchronous Processing?
- **Fast API Response:** Immediate acknowledgment improves user experience
- **Scalability:** Can handle traffic spikes without blocking
- **Resilience:** Validation failures don't impact API availability
- **Monitoring:** Clear separation of concerns for debugging

### Why Step Functions?
- **Visual Workflow:** Easy to understand and debug
- **Error Handling:** Built-in retry and error handling
- **State Management:** Maintains execution state across services
- **Integration:** Native integration with AWS services

### Why SQS + DLQ?
- **Reliability:** Guaranteed message delivery with retries
- **Decoupling:** Fulfillment service independent of order processing
- **Error Handling:** Failed messages automatically routed to DLQ
- **Scalability:** Automatic scaling based on queue depth

## 📚 Learning Outcomes

This project demonstrates:

1. **Serverless Architecture Patterns**
   - Event-driven design
   - Microservices with Lambda
   - Managed services integration

2. **Distributed Systems Concepts**
   - Asynchronous processing
   - Error handling and resilience
   - Message queuing patterns

3. **AWS Best Practices**
   - Infrastructure as Code
   - Security with IAM
   - Monitoring and logging

4. **Production Readiness**
   - Comprehensive testing
   - Error handling
   - Scalability considerations

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## 📄 License

This project is for educational purposes. See LICENSE file for details.

---

**🎉 Congratulations!** You now have a fully functional, production-ready distributed order fulfillment system running on AWS serverless infrastructure!
│   │   ├── api_gateway/      # API Gateway module
│   │   ├── lambdas/          # Lambda functions module
│   │   ├── dynamodb/         # DynamoDB module
│   │   ├── sqs/              # SQS module
│   │   ├── stepfunctions/    # Step Functions module
│   │   └── monitoring/       # CloudWatch monitoring module
│   └── cicd/                 # CI/CD infrastructure
│       ├── codebuild.tf      # CodeBuild configuration
│       ├── codepipeline.tf   # CodePipeline configuration
│       └── iam_roles.tf      # IAM roles for CI/CD
├── buildspec.yml             # CodeBuild specification
├── .github/                  # GitHub Actions (optional)
│   └── workflows/
│       └── ci.yml           # CI/CD workflow
└── README.md                # This file
```

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.0
- Python 3.9+
- Node.js 16+
- AWS SAM CLI (for local testing)

## Getting Started

### 1. Infrastructure Setup

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### 2. Deploy Lambda Functions

```bash
# Build and deploy using SAM
sam build
sam deploy --guided
```

### 3. CI/CD Setup

The project includes both AWS CodePipeline and GitHub Actions configurations:

- **AWS CodePipeline**: Configured in `terraform/cicd/`
- **GitHub Actions**: Configured in `.github/workflows/ci.yml`

## Development

### Local Testing

```bash
# Install dependencies for each Lambda
cd lambdas/api_handler && pip install -r requirements.txt
cd ../validator && pip install -r requirements.txt
cd ../order_storage && pip install -r requirements.txt
cd ../fulfill_order && pip install -r requirements.txt
```

### Running Tests

```bash
pytest tests/
```

## Architecture

This project implements a serverless order processing system with the following components:

- **API Handler**: Receives and routes API requests
- **Validator**: Validates incoming order data
- **Order Storage**: Stores orders in DynamoDB
- **Fulfill Order**: Processes order fulfillment

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests
5. Submit a pull request

## License

[Add your license information here]
" #   P i p e l i n e   t e s t   -   $ ( d a t e ) "     
 
 " #   F r e s h   c o n n e c t i o n   t e s t   -   $ ( d a t e ) "     
 
 
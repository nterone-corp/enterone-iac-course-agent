# EnterOne Course Agent - Infrastructure as Code

![AWS CloudFormation](https://img.shields.io/badge/AWS-CloudFormation-orange?logo=amazon-aws)
![AWS Lambda](https://img.shields.io/badge/AWS-Lambda-orange?logo=aws-lambda)
![API Gateway](https://img.shields.io/badge/AWS-API%20Gateway-purple?logo=amazon-api-gateway)
![OpenSearch](https://img.shields.io/badge/AWS-OpenSearch%20Serverless-blue?logo=opensearch)
![AWS SQS](https://img.shields.io/badge/AWS-SQS-red?logo=amazon-sqs)
![License](https://img.shields.io/badge/license-Proprietary-lightgrey)

Infrastructure as Code (CloudFormation) for the **EnterOne Course AI** platform. This repository deploys a complete serverless architecture including Lambda functions, API Gateway, OpenSearch Serverless for vector search, SQS queues, S3 buckets, and all required IAM roles and security configurations. Supports multiple environments (dev, staging, prod).

---

## 📑 Table of Contents

- [Architecture Overview](#-architecture-overview)
- [Stack Components](#-stack-components)
- [Deployment](#-deployment)
- [Parameters Reference](#️-parameters-reference)
- [Database Setup](#️-database-setup)
- [Security Features](#-security-features)
- [Post-Deployment Steps](#-post-deployment-steps)
- [Updating Stacks](#-updating-stacks)
- [Outputs](#-outputs)
- [File Structure](#️-file-structure)
- [Troubleshooting](#-troubleshooting)
- [Support](#-support)

---

## 🏗️ Architecture Overview

```
                              ┌─────────────────┐
                              │   CloudFront    │
                              │   Distribution  │
                              └────────┬────────┘
                                       │
                              ┌────────▼────────┐
                              │   S3 Bucket     │
                              │   (Widget)      │
                              └─────────────────┘

┌──────────┐    ┌─────────────────┐    ┌─────────────────────────────────────────┐
│          │    │                 │    │           Course Agent Lambda           │
│   User   ├───►│   API Gateway   ├───►│              (FastAPI)                  │
│          │    │                 │    │                                         │
└──────────┘    └─────────────────┘    └──────┬──────────┬──────────┬────────────┘
                                              │          │          │
                                              ▼          ▼          ▼
                                         ┌────────┐ ┌────────┐ ┌─────────┐
                                         │  RDS   │ │  AOSS  │ │ Bedrock │
                                         │Postgres│ │(Vector)│ │  (LLM)  │
                                         └────────┘ └────────┘ └─────────┘

┌─────────────────┐    ┌─────────────────────┐    ┌──────────────┐    ┌─────────────────────┐
│   S3 Bucket     │    │  Event Handler      │    │     SQS      │    │  Vectorize Lambda   │
│  (PDF Upload)   ├───►│     Lambda          ├───►│    Queue     ├───►│  (PDF Processing)   │
└─────────────────┘    └─────────────────────┘    └──────────────┘    └──────────┬──────────┘
                                                         │                       │
                                                         ▼                       ▼
                                                  ┌──────────────┐        ┌─────────────┐
                                                  │     DLQ      │        │    AOSS     │
                                                  │ (Dead Letter)│        │   (Index)   │
                                                  └──────────────┘        └─────────────┘
```

---

## 📦 Stack Components

### Backend Stack (`backend-2.yaml`)

| Resource | Type | Description |
|----------|------|-------------|
| `FastAPILambda` | Lambda | Course Agent API - handles chat requests |
| `EventHandlerLambda` | Lambda | S3/Manual event processor - triggers vectorization |
| `VectorizeFileLambda` | Lambda | PDF vectorization pipeline - processes documents |
| `VectorizeQueue` | SQS | Queue for vectorization jobs |
| `VectorizeDLQ` | SQS | Dead letter queue for failed jobs |
| `OpenSearchCollection` | AOSS | Vector search collection for course content |
| `RestApi` | API Gateway | Course Agent API endpoint with CORS |
| `ChatLogsBucket` | S3 | Session/chat log storage |
| `LambdaSecurityGroup` | Security Group | VPC access for Lambda functions |
| `APILambdaExecutionRole` | IAM Role | Execution role for Course Agent |
| `EventHandlerLambdaExecutionRole` | IAM Role | Execution role for Event Handler |
| `VectorizeLambdaExecutionRole` | IAM Role | Execution role for Vectorize Lambda |

### Frontend Stack (`frontend.yaml`)

| Resource | Type | Description |
|----------|------|-------------|
| `WebsiteBucket` | S3 | Static website hosting for chat widget |
| `CloudFrontDistribution` | CloudFront | CDN for widget delivery |
| `CloudFrontOAI` | OAI | Secure S3 access from CloudFront |

---

## 🚀 Deployment

### Prerequisites

- AWS CLI configured with appropriate credentials
- Sufficient IAM permissions (CloudFormation, Lambda, API Gateway, S3, SQS, OpenSearch, IAM, EC2, CloudFront)
- ECR repositories created with Docker images pushed:
  - `enterone/course-agent`
  - `enterone/vectorize`
  - `enterone/event-handler`
- VPC and subnets available
- RDS PostgreSQL instance running

### Deploy Backend Stack

```bash
aws cloudformation deploy \
  --template-file backend-2.yaml \
  --stack-name enterone-website-ai-backend-dev \
  --parameter-overrides file://backend.dev-params.json \
  --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM
```

### Deploy Frontend Stack

```bash
aws cloudformation deploy \
  --template-file frontend.yaml \
  --stack-name enterone-website-widget-dev \
  --parameter-overrides \
    BucketName=enterone-chat-widget \
    EnvironmentName=dev \
  --capabilities CAPABILITY_IAM
```

### Using Parameter Files

The `backend.dev-params.json` file contains environment-specific configurations. To create staging or production deployments:

1. Copy `backend.dev-params.json` to `backend.staging-params.json` or `backend.prod-params.json`
2. Update values accordingly (function names, bucket names, security groups, etc.)
3. Deploy with the appropriate parameter file

---

## ⚙️ Parameters Reference

### Backend Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `EnvironmentName` | Environment identifier (dev/staging/prod) | `dev` |
| `APIRepositoryName` | ECR repo for Course Agent | `enterone/course-agent` |
| `VectorizeFileRepositoryName` | ECR repo for Vectorize | `enterone/vectorize` |
| `EventHandlerRepositoryName` | ECR repo for Event Handler | `enterone/event-handler` |
| `ImageTag` | Docker image tag | `dev` |
| `APIFunctionName` | Name for Course Agent Lambda | `enterone-course-agent-dev` |
| `EventHandlerFunctionName` | Name for Event Handler Lambda | `enterone-event-handler-dev` |
| `VectorizeFunctionName` | Name for Vectorize Lambda | `enterone-vectorize-file-dev` |
| `ChatLogsBucketName` | S3 bucket for chat logs | `course-agent-chatlogs-dev` |
| `MemorySize` | Lambda memory allocation (MB) | `512` |
| `TimeoutSeconds` | Lambda timeout | `600` |
| `VpcId` | VPC for Lambda functions | *Required* |
| `SubnetIds` | Subnets for Lambda | *Required* |
| `ExistingTargetSecurityGroup` | RDS security group ID | *Required* |
| `PDFS3Bucket` | S3 bucket containing course PDFs | *Required* |
| `AllowedOrigin` | CORS allowed origin (widget URL) | *Required* |

### Frontend Parameters

| Parameter | Description |
|-----------|-------------|
| `BucketName` | Base name for the S3 bucket |
| `EnvironmentName` | Environment identifier (dev/staging/prod) |

---

## 🗄️ Database Setup

The `SQL policies.sql` file sets up a restricted database user for the AI agent with appropriate permissions and security policies.

**What it does:**
- Creates `ai_agent_user` with limited SELECT permissions
- Creates safe views (`ai_safe_courses`, `ai_safe_events`, `ai_safe_users`, `ai_safe_instructors`) exposing only necessary columns
- Implements Row Level Security (RLS) policies to filter active/public records
- Configures connection limits (21 connections) and timeouts (30s statement, 10s lock)

**To execute:**

```bash
psql -h <rds-endpoint> -U <admin-user> -d <database-name> -f "SQL policies.sql"
```

> ⚠️ **Important:** Update the password in the SQL file before running. The default placeholder password should be replaced with a secure, randomly generated password.

---

## 🔐 Security Features

| Feature | Description |
|---------|-------------|
| **Lambda VPC Configuration** | Lambdas run within VPC for secure RDS access |
| **Security Groups** | Dedicated SG for Lambdas with controlled egress to RDS (port 5432) |
| **OpenSearch Access Policies** | Data access limited to specific Lambda execution roles |
| **Row Level Security** | Database policies filter data based on active/public status |
| **S3 Private Access** | Buckets private; CloudFront access via OAI only |
| **CORS Configuration** | API Gateway configured with specific allowed origins |
| **IAM Least Privilege** | Separate roles per Lambda with minimal required permissions |

---

## 📋 Post-Deployment Steps

1. **Verify Lambda Functions** - Check all three functions are created and healthy in AWS Console

2. **Test API Gateway Endpoint** - Use the `ApiInvokeUrl` output to test the endpoint:
   ```bash
   curl -X GET "https://<api-id>.execute-api.<region>.amazonaws.com/dev/api/v1/health"
   ```

3. **Configure S3 Event Notification** - Set up the PDF bucket to trigger `EventHandlerLambda` on object creation:
   ```bash
   aws s3api put-bucket-notification-configuration \
     --bucket <pdf-bucket-name> \
     --notification-configuration '{
       "LambdaFunctionConfigurations": [{
         "LambdaFunctionArn": "<event-handler-lambda-arn>",
         "Events": ["s3:ObjectCreated:*"],
         "Filter": {"Key": {"FilterRules": [{"Name": "suffix", "Value": ".pdf"}]}}
       }]
     }'
   ```

4. **Trigger Initial Index Population** - Invoke Event Handler manually to populate OpenSearch index with existing PDFs

5. **Deploy Widget** - Upload the chat widget files to the S3 bucket created by the frontend stack

6. **Test End-to-End** - Access the CloudFront URL and verify the chat widget connects successfully

---

## 🔄 Updating Stacks

### Update Parameters

Modify the parameter file and redeploy:

```bash
aws cloudformation deploy \
  --template-file backend-2.yaml \
  --stack-name enterone-website-ai-backend-dev \
  --parameter-overrides file://backend.dev-params.json \
  --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM
```

### Update Lambda Code

Push new image to ECR with a new tag, then update `ImageTag` parameter:

```bash
# In parameter file, change:
# "ParameterValue": "dev"  →  "ParameterValue": "v1.2.0"

# Then redeploy
aws cloudformation deploy ...
```

### Rolling Back

```bash
aws cloudformation rollback-stack --stack-name enterone-website-ai-backend-dev
```

Or use the AWS Console to view events and initiate rollback.

---

## 📤 Outputs

### Backend Stack

| Output | Description |
|--------|-------------|
| `ApiInvokeUrl` | API Gateway endpoint URL (`https://<id>.execute-api.<region>.amazonaws.com/<env>/api/v1/`) |

### Frontend Stack

| Output | Description |
|--------|-------------|
| `DistributionDomainName` | CloudFront distribution URL |
| `WebsiteBucketName` | S3 bucket name for static files |
| `WebsiteBucketRegionalDomain` | S3 regional endpoint |

---

## 🗂️ File Structure

```
enterone-iac-course-agent/
├── backend-2.yaml              # Backend infrastructure (Lambdas, API GW, AOSS, SQS)
├── backend.dev-params.json     # Dev environment parameters
├── backend.staging-params.json # Staging parameters (to be created)
├── backend.prod-params.json    # Production parameters (to be created)
├── frontend.yaml               # Frontend infrastructure (S3, CloudFront)
├── SQL policies.sql            # Database user and permissions setup
└── README.md                   # This file
```

---

## 🐛 Troubleshooting

| Issue | Solution |
|-------|----------|
| **Lambda can't connect to RDS** | Verify Lambda SG has egress rule to RDS SG on port 5432. Check `AllowLambdaEgress` resource is applied. |
| **OpenSearch 403 error** | Verify Lambda execution role ARN is listed in `DataAccessPolicy`. Check AOSS collection is active. |
| **API Gateway 5xx errors** | Check Lambda CloudWatch logs. Verify VPC config allows Lambda to reach required services. |
| **CloudFormation rollback** | Check Events tab in CloudFormation console for specific failure reason. Common issues: duplicate resource names, insufficient permissions. |
| **SQS messages going to DLQ** | Check Vectorize Lambda logs. Verify S3 bucket permissions and OpenSearch connectivity. |
| **CORS errors on widget** | Verify `AllowedOrigin` parameter matches the exact widget URL including protocol. |

#!/bin/bash
set -e

# Bootstrap Terraform backend resources (S3 bucket + DynamoDB lock table)
# Idempotent — safe to run multiple times.

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=${AWS_REGION:-${DEFAULT_AWS_REGION:-eu-west-1}}
BUCKET_NAME="health-care-terraform-state-${AWS_ACCOUNT_ID}"
TABLE_NAME="health-care-terraform-locks"

echo "Bootstrapping Terraform backend in ${AWS_REGION}..."

# --- S3 State Bucket ---
if aws s3api head-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION" 2>/dev/null; then
  echo "S3 bucket ${BUCKET_NAME} already exists."
else
  echo "Creating S3 bucket ${BUCKET_NAME}..."
  if [ "$AWS_REGION" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION"
  else
    aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION" \
      --create-bucket-configuration LocationConstraint="$AWS_REGION"
  fi

  aws s3api put-bucket-versioning --bucket "$BUCKET_NAME" --region "$AWS_REGION" \
    --versioning-configuration Status=Enabled

  aws s3api put-bucket-encryption --bucket "$BUCKET_NAME" --region "$AWS_REGION" \
    --server-side-encryption-configuration '{
      "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]
    }'

  aws s3api put-public-access-block --bucket "$BUCKET_NAME" --region "$AWS_REGION" \
    --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

  echo "S3 bucket created."
fi

# --- DynamoDB Lock Table ---
if aws dynamodb describe-table --table-name "$TABLE_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
  echo "DynamoDB table ${TABLE_NAME} already exists."
else
  echo "Creating DynamoDB table ${TABLE_NAME}..."
  aws dynamodb create-table \
    --table-name "$TABLE_NAME" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "$AWS_REGION"

  aws dynamodb wait table-exists --table-name "$TABLE_NAME" --region "$AWS_REGION"
  echo "DynamoDB table created."
fi

echo "Bootstrap complete."

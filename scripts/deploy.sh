#!/bin/bash
set -e

ENVIRONMENT=${1:-dev}
PROJECT_NAME=${2:-health-care}
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Deploying ${PROJECT_NAME} to ${ENVIRONMENT}..."

# Get AWS details
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=${AWS_REGION:-${DEFAULT_AWS_REGION:-eu-west-1}}
IMAGE_TAG=$(git -C "$PROJECT_ROOT" rev-parse --short HEAD 2>/dev/null || echo "latest")

# 1. Bootstrap Terraform backend
echo "Ensuring Terraform backend resources exist..."
bash "$SCRIPT_DIR/bootstrap.sh"

# 2. Terraform init + first apply (ensures ECR exists)
cd "$PROJECT_ROOT/terraform"

terraform init -input=false \
  -backend-config="bucket=health-care-terraform-state-${AWS_ACCOUNT_ID}" \
  -backend-config="key=${ENVIRONMENT}/terraform.tfstate" \
  -backend-config="region=${AWS_REGION}" \
  -backend-config="dynamodb_table=health-care-terraform-locks" \
  -backend-config="encrypt=true"

if ! terraform workspace list | grep -q "$ENVIRONMENT"; then
  terraform workspace new "$ENVIRONMENT"
else
  terraform workspace select "$ENVIRONMENT"
fi

terraform apply \
  -target=aws_ecr_repository.app \
  -target=aws_ecr_lifecycle_policy.app \
  -var="project_name=$PROJECT_NAME" \
  -var="environment=$ENVIRONMENT" \
  -var="image_tag=$IMAGE_TAG" \
  -var="clerk_publishable_key=${NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY}" \
  -var="clerk_secret_key=${CLERK_SECRET_KEY}" \
  -var="openai_api_key=${OPENAI_API_KEY}" \
  -auto-approve

# 3. Build + push Docker image
ECR_URL=$(terraform output -raw ecr_repository_url)

echo "Logging in to ECR..."
aws ecr get-login-password --region "$AWS_REGION" | \
  docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

echo "Building Docker image..."
cd "$PROJECT_ROOT"
docker build \
  --build-arg NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY="${NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY}" \
  -t "${ECR_URL}:${IMAGE_TAG}" \
  -t "${ECR_URL}:latest" \
  .

echo "Pushing Docker image..."
docker push "${ECR_URL}:${IMAGE_TAG}"
docker push "${ECR_URL}:latest"

# 4. Re-apply Terraform to update App Runner with new image
cd "$PROJECT_ROOT/terraform"
terraform apply \
  -var="project_name=$PROJECT_NAME" \
  -var="environment=$ENVIRONMENT" \
  -var="image_tag=$IMAGE_TAG" \
  -var="clerk_publishable_key=${NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY}" \
  -var="clerk_secret_key=${CLERK_SECRET_KEY}" \
  -var="openai_api_key=${OPENAI_API_KEY}" \
  -auto-approve

# 5. Output
APP_URL=$(terraform output -raw app_runner_url)
echo ""
echo "Deployment complete!"
echo "App URL: $APP_URL"

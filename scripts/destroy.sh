#!/bin/bash
set -e

if [ $# -eq 0 ]; then
    echo "Error: Environment parameter is required"
    echo "Usage: $0 <environment>"
    echo "Example: $0 dev"
    echo "Available environments: dev, test, prod"
    exit 1
fi

ENVIRONMENT=$1
PROJECT_NAME=${2:-health-care}
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Preparing to destroy ${PROJECT_NAME}-${ENVIRONMENT} infrastructure..."

cd "$(dirname "$0")/../terraform"

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=${AWS_REGION:-${DEFAULT_AWS_REGION:-eu-west-1}}

echo "Ensuring Terraform backend resources exist..."
bash "$SCRIPT_DIR/bootstrap.sh"

terraform init -input=false \
  -backend-config="bucket=health-care-terraform-state-${AWS_ACCOUNT_ID}" \
  -backend-config="key=${ENVIRONMENT}/terraform.tfstate" \
  -backend-config="region=${AWS_REGION}" \
  -backend-config="dynamodb_table=health-care-terraform-locks" \
  -backend-config="encrypt=true"

if ! terraform workspace list | grep -q "$ENVIRONMENT"; then
    echo "Error: Workspace '$ENVIRONMENT' does not exist"
    terraform workspace list
    exit 1
fi

terraform workspace select "$ENVIRONMENT"

echo "Running terraform destroy..."
terraform destroy \
  -var="project_name=$PROJECT_NAME" \
  -var="environment=$ENVIRONMENT" \
  -var="image_tag=latest" \
  -var="clerk_publishable_key=placeholder" \
  -var="clerk_secret_key=placeholder" \
  -var="openai_api_key=placeholder" \
  -auto-approve

echo "Infrastructure for ${ENVIRONMENT} has been destroyed!"
echo ""
echo "To remove the workspace completely, run:"
echo "   cd terraform"
echo "   terraform workspace select default"
echo "   terraform workspace delete $ENVIRONMENT"

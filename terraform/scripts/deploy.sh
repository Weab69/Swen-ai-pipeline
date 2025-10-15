#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
CLOUD_PROVIDER=""
ENVIRONMENT=""
ACTION=""
AUTO_APPROVE=false
TERRAFORM_DIR=""

# Function to print usage
usage() {
    echo "Usage: $0 -c <cloud_provider> -e <environment> -a <action> [options]"
    echo ""
    echo "Required arguments:"
    echo "  -c, --cloud-provider  Cloud provider (aws|alibaba)"
    echo "  -e, --environment     Environment (dev|staging|prod)"
    echo "  -a, --action          Action (plan|apply|destroy|output|show)"
    echo ""
    echo "Optional arguments:"
    echo "  --auto-approve        Skip interactive approval (only for apply/destroy)"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -c aws -e dev -a plan"
    echo "  $0 -c alibaba -e prod -a apply --auto-approve"
    echo "  $0 -c aws -e staging -a destroy"
    exit 1
}

# Function to validate inputs
validate_inputs() {
    if [[ ! "$CLOUD_PROVIDER" =~ ^(aws|alibaba)$ ]]; then
        echo -e "${RED}Error: Cloud provider must be 'aws' or 'alibaba'${NC}"
        exit 1
    fi

    if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
        echo -e "${RED}Error: Environment must be 'dev', 'staging', or 'prod'${NC}"
        exit 1
    fi

    if [[ ! "$ACTION" =~ ^(plan|apply|destroy|output|show|validate)$ ]]; then
        echo -e "${RED}Error: Action must be 'plan', 'apply', 'destroy', 'output', 'show', or 'validate'${NC}"
        exit 1
    fi
}

# Function to check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}Checking prerequisites...${NC}"
    
    # Check if terraform is installed
    if ! command -v terraform &> /dev/null; then
        echo -e "${RED}Error: Terraform is not installed${NC}"
        exit 1
    fi

    # Check terraform version
    TERRAFORM_VERSION=$(terraform version | head -n1 | awk '{print $2}' | sed 's/v//')
    echo -e "${GREEN}✓ Terraform version: $TERRAFORM_VERSION${NC}"

    # Set terraform directory
    TERRAFORM_DIR="$(dirname "$0")/.."
    
    # Check if terraform directory exists
    if [[ ! -d "$TERRAFORM_DIR" ]]; then
        echo -e "${RED}Error: Terraform directory not found: $TERRAFORM_DIR${NC}"
        exit 1
    fi

    # Check if tfvars file exists
    TFVARS_FILE="$TERRAFORM_DIR/environments/$ENVIRONMENT/$CLOUD_PROVIDER.tfvars"
    if [[ ! -f "$TFVARS_FILE" ]]; then
        echo -e "${RED}Error: Configuration file not found: $TFVARS_FILE${NC}"
        exit 1
    fi

    echo -e "${GREEN}✓ Configuration file found: $TFVARS_FILE${NC}"

    # Check environment variables
    if [[ "$CLOUD_PROVIDER" == "aws" ]]; then
        if [[ -z "$AWS_ACCESS_KEY_ID" || -z "$AWS_SECRET_ACCESS_KEY" ]]; then
            echo -e "${YELLOW}Warning: AWS credentials not found in environment variables${NC}"
            echo -e "${YELLOW}Make sure you have configured AWS credentials via AWS CLI or environment variables${NC}"
        else
            echo -e "${GREEN}✓ AWS credentials found${NC}"
        fi
    elif [[ "$CLOUD_PROVIDER" == "alibaba" ]]; then
        if [[ -z "$ALICLOUD_ACCESS_KEY" || -z "$ALICLOUD_SECRET_KEY" ]]; then
            echo -e "${YELLOW}Warning: Alibaba Cloud credentials not found in environment variables${NC}"
            echo -e "${YELLOW}Make sure you have configured Alibaba Cloud credentials${NC}"
        else
            echo -e "${GREEN}✓ Alibaba Cloud credentials found${NC}"
        fi
    fi
}

# Function to initialize terraform
terraform_init() {
    echo -e "${YELLOW}Initializing Terraform...${NC}"
    cd "$TERRAFORM_DIR"
    
    terraform init -upgrade
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ Terraform initialized successfully${NC}"
    else
        echo -e "${RED}Error: Terraform initialization failed${NC}"
        exit 1
    fi
}

# Function to validate terraform configuration
terraform_validate() {
    echo -e "${YELLOW}Validating Terraform configuration...${NC}"
    cd "$TERRAFORM_DIR"
    
    terraform validate
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ Terraform configuration is valid${NC}"
    else
        echo -e "${RED}Error: Terraform configuration validation failed${NC}"
        exit 1
    fi
}

# Function to run terraform plan
terraform_plan() {
    echo -e "${YELLOW}Running Terraform plan...${NC}"
    cd "$TERRAFORM_DIR"
    
    terraform plan \
        -var-file="$TFVARS_FILE" \
        -out="terraform-$CLOUD_PROVIDER-$ENVIRONMENT.tfplan"
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ Terraform plan completed successfully${NC}"
        echo -e "${YELLOW}Plan file saved as: terraform-$CLOUD_PROVIDER-$ENVIRONMENT.tfplan${NC}"
    else
        echo -e "${RED}Error: Terraform plan failed${NC}"
        exit 1
    fi
}

# Function to run terraform apply
terraform_apply() {
    echo -e "${YELLOW}Applying Terraform configuration...${NC}"
    cd "$TERRAFORM_DIR"
    
    # Check if plan file exists
    PLAN_FILE="terraform-$CLOUD_PROVIDER-$ENVIRONMENT.tfplan"
    
    if [[ -f "$PLAN_FILE" ]]; then
        echo -e "${GREEN}Using existing plan file: $PLAN_FILE${NC}"
        if [[ "$AUTO_APPROVE" == true ]]; then
            terraform apply "$PLAN_FILE"
        else
            terraform apply "$PLAN_FILE"
        fi
    else
        echo -e "${YELLOW}No plan file found, running apply with var-file${NC}"
        if [[ "$AUTO_APPROVE" == true ]]; then
            terraform apply -var-file="$TFVARS_FILE" -auto-approve
        else
            terraform apply -var-file="$TFVARS_FILE"
        fi
    fi
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ Terraform apply completed successfully${NC}"
    else
        echo -e "${RED}Error: Terraform apply failed${NC}"
        exit 1
    fi
}

# Function to run terraform destroy
terraform_destroy() {
    echo -e "${RED}WARNING: This will destroy all resources for $CLOUD_PROVIDER $ENVIRONMENT environment${NC}"
    
    if [[ "$AUTO_APPROVE" != true ]]; then
        read -p "Are you sure you want to continue? (yes/no): " confirm
        if [[ "$confirm" != "yes" ]]; then
            echo -e "${YELLOW}Operation cancelled${NC}"
            exit 0
        fi
    fi
    
    echo -e "${YELLOW}Destroying Terraform resources...${NC}"
    cd "$TERRAFORM_DIR"
    
    if [[ "$AUTO_APPROVE" == true ]]; then
        terraform destroy -var-file="$TFVARS_FILE" -auto-approve
    else
        terraform destroy -var-file="$TFVARS_FILE"
    fi
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ Terraform destroy completed successfully${NC}"
    else
        echo -e "${RED}Error: Terraform destroy failed${NC}"
        exit 1
    fi
}

# Function to show terraform output
terraform_output() {
    echo -e "${YELLOW}Showing Terraform outputs...${NC}"
    cd "$TERRAFORM_DIR"
    
    terraform output
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ Terraform output displayed successfully${NC}"
    else
        echo -e "${RED}Error: Failed to display Terraform output${NC}"
        exit 1
    fi
}

# Function to show terraform state
terraform_show() {
    echo -e "${YELLOW}Showing Terraform state...${NC}"
    cd "$TERRAFORM_DIR"
    
    terraform show
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ Terraform state displayed successfully${NC}"
    else
        echo -e "${RED}Error: Failed to display Terraform state${NC}"
        exit 1
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--cloud-provider)
            CLOUD_PROVIDER="$2"
            shift 2
            ;;
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -a|--action)
            ACTION="$2"
            shift 2
            ;;
        --auto-approve)
            AUTO_APPROVE=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            ;;
    esac
done

# Check if required arguments are provided
if [[ -z "$CLOUD_PROVIDER" || -z "$ENVIRONMENT" || -z "$ACTION" ]]; then
    echo -e "${RED}Error: Missing required arguments${NC}"
    usage
fi

# Main execution
echo -e "${GREEN}=== Terraform Deployment Script ===${NC}"
echo -e "${YELLOW}Cloud Provider: $CLOUD_PROVIDER${NC}"
echo -e "${YELLOW}Environment: $ENVIRONMENT${NC}"
echo -e "${YELLOW}Action: $ACTION${NC}"
echo -e "${YELLOW}Auto Approve: $AUTO_APPROVE${NC}"
echo ""

validate_inputs
check_prerequisites
terraform_init

case $ACTION in
    validate)
        terraform_validate
        ;;
    plan)
        terraform_validate
        terraform_plan
        ;;
    apply)
        terraform_validate
        terraform_apply
        ;;
    destroy)
        terraform_destroy
        ;;
    output)
        terraform_output
        ;;
    show)
        terraform_show
        ;;
esac

echo -e "${GREEN}=== Deployment script completed successfully ===${NC}"

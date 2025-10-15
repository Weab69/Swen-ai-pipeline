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
MICROSERVICES=("news" "storage" "ai" "ingestion")
PROJECT_ROOT=""
BUILD_ALL=false
MICROSERVICE=""

# Function to print usage
usage() {
    echo "Usage: $0 -c <cloud_provider> -e <environment> [options]"
    echo ""
    echo "Required arguments:"
    echo "  -c, --cloud-provider  Cloud provider (aws|alibaba)"
    echo "  -e, --environment     Environment (dev|staging|prod)"
    echo ""
    echo "Optional arguments:"
    echo "  -s, --service         Specific microservice to build (news|storage|ai|ingestion)"
    echo "  --build-all          Build all microservices (default if no specific service)"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -c aws -e dev --build-all"
    echo "  $0 -c alibaba -e prod -s news"
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

    if [[ -n "$MICROSERVICE" && ! " ${MICROSERVICES[@]} " =~ " $MICROSERVICE " ]]; then
        echo -e "${RED}Error: Microservice must be one of: ${MICROSERVICES[*]}${NC}"
        exit 1
    fi
}

# Function to check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}Checking prerequisites...${NC}"
    
    # Check if docker is installed and running
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Error: Docker is not installed${NC}"
        exit 1
    fi

    if ! docker info &> /dev/null; then
        echo -e "${RED}Error: Docker daemon is not running${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Docker is available${NC}"

    # Set project root
    PROJECT_ROOT="$(dirname "$(dirname "$(dirname "$0")")")"
    
    # Check if Dockerfile exists
    if [[ ! -f "$PROJECT_ROOT/Dockerfile" ]]; then
        echo -e "${RED}Error: Dockerfile not found in project root: $PROJECT_ROOT${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Dockerfile found${NC}"

    # Check cloud-specific CLI tools
    if [[ "$CLOUD_PROVIDER" == "aws" ]]; then
        if ! command -v aws &> /dev/null; then
            echo -e "${RED}Error: AWS CLI is not installed${NC}"
            exit 1
        fi
        echo -e "${GREEN}✓ AWS CLI is available${NC}"
    elif [[ "$CLOUD_PROVIDER" == "alibaba" ]]; then
        if ! command -v aliyun &> /dev/null; then
            echo -e "${YELLOW}Warning: Alibaba Cloud CLI not found. You may need to login manually${NC}"
        else
            echo -e "${GREEN}✓ Alibaba Cloud CLI is available${NC}"
        fi
    fi
}

# Function to get registry URL from Terraform outputs
get_registry_url() {
    echo -e "${YELLOW}Getting registry URL from Terraform outputs...${NC}"
    
    TERRAFORM_DIR="$(dirname "$0")/.."
    cd "$TERRAFORM_DIR"
    
    if [[ "$CLOUD_PROVIDER" == "aws" ]]; then
        REGISTRY_URL=$(terraform output -json | jq -r '.ecr_repository_url.value // empty')
        if [[ -z "$REGISTRY_URL" || "$REGISTRY_URL" == "null" ]]; then
            # Try to get from AWS module output
            REGISTRY_URL=$(terraform output -raw aws_infrastructure[0].ecr_repository_url 2>/dev/null || echo "")
        fi
    elif [[ "$CLOUD_PROVIDER" == "alibaba" ]]; then
        REGISTRY_URL=$(terraform output -json | jq -r '.acr_repository_url.value // empty')
        if [[ -z "$REGISTRY_URL" || "$REGISTRY_URL" == "null" ]]; then
            # Try to get from Alibaba module output
            REGISTRY_URL=$(terraform output -raw alibaba_infrastructure[0].acr_repository_url 2>/dev/null || echo "")
        fi
    fi
    
    if [[ -z "$REGISTRY_URL" || "$REGISTRY_URL" == "null" ]]; then
        echo -e "${RED}Error: Could not get registry URL from Terraform outputs${NC}"
        echo -e "${YELLOW}Make sure Terraform has been applied and infrastructure exists${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Registry URL: $REGISTRY_URL${NC}"
}

# Function to authenticate with registry
authenticate_registry() {
    echo -e "${YELLOW}Authenticating with container registry...${NC}"
    
    if [[ "$CLOUD_PROVIDER" == "aws" ]]; then
        # Extract AWS region from registry URL
        AWS_REGION=$(echo "$REGISTRY_URL" | cut -d'.' -f4)
        AWS_ACCOUNT_ID=$(echo "$REGISTRY_URL" | cut -d'.' -f1 | cut -d'/' -f3)
        
        aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
        
        if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}✓ AWS ECR authentication successful${NC}"
        else
            echo -e "${RED}Error: AWS ECR authentication failed${NC}"
            exit 1
        fi
        
    elif [[ "$CLOUD_PROVIDER" == "alibaba" ]]; then
        echo -e "${YELLOW}Note: Please ensure you are logged in to Alibaba Container Registry${NC}"
        echo -e "${YELLOW}You may need to run: docker login --username=<username> registry.cn-hangzhou.aliyuncs.com${NC}"
        
        # Try to test login by checking if we can access the registry
        REGISTRY_HOST=$(echo "$REGISTRY_URL" | cut -d'/' -f1)
        if ! docker pull "$REGISTRY_HOST/hello-world:latest" &> /dev/null; then
            echo -e "${YELLOW}Warning: Could not verify ACR authentication${NC}"
        else
            echo -e "${GREEN}✓ ACR authentication verified${NC}"
        fi
    fi
}

# Function to build and push a microservice
build_and_push_service() {
    local service=$1
    echo -e "${YELLOW}Building and pushing $service microservice...${NC}"
    
    cd "$PROJECT_ROOT"
    
    # Build the image
    local image_tag="$REGISTRY_URL:$service-latest"
    local build_tag="$REGISTRY_URL:$service-$ENVIRONMENT-$(date +%s)"
    
    echo -e "${YELLOW}Building Docker image: $image_tag${NC}"
    
    docker build \
        --target production \
        --build-arg SERVICE_NAME="$service" \
        -t "$image_tag" \
        -t "$build_tag" \
        .
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ Docker build completed for $service${NC}"
    else
        echo -e "${RED}Error: Docker build failed for $service${NC}"
        return 1
    fi
    
    # Push the images
    echo -e "${YELLOW}Pushing image: $image_tag${NC}"
    docker push "$image_tag"
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ Image pushed successfully: $image_tag${NC}"
    else
        echo -e "${RED}Error: Failed to push image: $image_tag${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}Pushing image: $build_tag${NC}"
    docker push "$build_tag"
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ Image pushed successfully: $build_tag${NC}"
    else
        echo -e "${RED}Error: Failed to push image: $build_tag${NC}"
        return 1
    fi
    
    return 0
}

# Function to build and push all services
build_and_push_all() {
    echo -e "${YELLOW}Building and pushing all microservices...${NC}"
    
    local failed_services=()
    
    for service in "${MICROSERVICES[@]}"; do
        if ! build_and_push_service "$service"; then
            failed_services+=("$service")
        fi
    done
    
    if [[ ${#failed_services[@]} -eq 0 ]]; then
        echo -e "${GREEN}✓ All microservices built and pushed successfully${NC}"
    else
        echo -e "${RED}Error: Failed to build/push the following services: ${failed_services[*]}${NC}"
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
        -s|--service)
            MICROSERVICE="$2"
            shift 2
            ;;
        --build-all)
            BUILD_ALL=true
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
if [[ -z "$CLOUD_PROVIDER" || -z "$ENVIRONMENT" ]]; then
    echo -e "${RED}Error: Missing required arguments${NC}"
    usage
fi

# Set default behavior
if [[ -z "$MICROSERVICE" && "$BUILD_ALL" == false ]]; then
    BUILD_ALL=true
fi

# Main execution
echo -e "${GREEN}=== Docker Build and Push Script ===${NC}"
echo -e "${YELLOW}Cloud Provider: $CLOUD_PROVIDER${NC}"
echo -e "${YELLOW}Environment: $ENVIRONMENT${NC}"
if [[ "$BUILD_ALL" == true ]]; then
    echo -e "${YELLOW}Building: All microservices${NC}"
else
    echo -e "${YELLOW}Building: $MICROSERVICE${NC}"
fi
echo ""

validate_inputs
check_prerequisites
get_registry_url
authenticate_registry

if [[ "$BUILD_ALL" == true ]]; then
    build_and_push_all
else
    if ! build_and_push_service "$MICROSERVICE"; then
        exit 1
    fi
fi

echo -e "${GREEN}=== Build and push completed successfully ===${NC}"

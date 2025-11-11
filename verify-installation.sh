#!/bin/bash

# Installation Verification Script
# Checks if all required tools are properly installed

BOLD='\033[1m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BOLD}========================================${NC}"
echo -e "${BOLD}   Installation Verification Script${NC}"
echo -e "${BOLD}========================================${NC}\n"

PASSED=0
FAILED=0

# Function to check command exists and version
check_tool() {
    local tool=$1
    local version_cmd=$2
    local name=$3

    echo -e "\n${BOLD}${BLUE}Checking $name...${NC}"

    if command -v $tool &> /dev/null; then
        echo -e "${GREEN}✓${NC} $name is installed"
        echo -e "  Version: $(eval $version_cmd 2>&1 | head -n 1)"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $name is NOT installed"
        echo -e "  Install from: ${YELLOW}$4${NC}"
        ((FAILED++))
        return 1
    fi
}

# Check Docker
check_tool "docker" "docker --version" "Docker" "https://www.docker.com/products/docker-desktop"

# Check Docker Compose
check_tool "docker-compose" "docker-compose --version" "Docker Compose" "Included with Docker Desktop"

# Check Python
check_tool "python" "python --version" "Python" "https://www.python.org/downloads/" || \
check_tool "python3" "python3 --version" "Python" "https://www.python.org/downloads/"

# Check kubectl
check_tool "kubectl" "kubectl version --client --short 2>&1 | head -n 1" "kubectl" "https://kubernetes.io/docs/tasks/tools/"

# Check Minikube
check_tool "minikube" "minikube version --short" "Minikube" "https://minikube.sigs.k8s.io/docs/start/"

# Check Helm
check_tool "helm" "helm version --short" "Helm" "https://helm.sh/docs/intro/install/"

# Additional checks
echo -e "\n${BOLD}${BLUE}Additional Checks...${NC}"

# Check if Docker daemon is running
if docker ps &> /dev/null; then
    echo -e "${GREEN}✓${NC} Docker daemon is running"
    ((PASSED++))
else
    echo -e "${YELLOW}⚠${NC} Docker daemon is not running"
    echo -e "  Start Docker Desktop and try again"
fi

# Check Docker resources
if command -v docker &> /dev/null; then
    echo -e "${GREEN}✓${NC} Docker system info:"
    docker system info 2>/dev/null | grep -E "CPUs:|Total Memory:" | sed 's/^/  /'
fi

# Summary
echo -e "\n${BOLD}========================================${NC}"
echo -e "${BOLD}Summary${NC}"
echo -e "${BOLD}========================================${NC}"
echo -e "${GREEN}Installed: $PASSED${NC}"
echo -e "${RED}Missing:   $FAILED${NC}"

if [ $FAILED -eq 0 ]; then
    echo -e "\n${GREEN}${BOLD}✅ All tools installed successfully!${NC}\n"

    echo -e "${BOLD}You're ready to test! Run these commands:${NC}"
    echo -e ""
    echo -e "${YELLOW}# Test 1: Docker Compose (5 minutes)${NC}"
    echo -e "  docker-compose up -d"
    echo -e "  ./test-api.sh"
    echo -e ""
    echo -e "${YELLOW}# Test 2: Kubernetes/Helm (15 minutes)${NC}"
    echo -e "  ./test-kubernetes.sh"
    echo -e ""

    exit 0
else
    echo -e "\n${RED}${BOLD}❌ Some tools are missing!${NC}"
    echo -e "Please install the missing tools and run this script again.\n"
    echo -e "Installation guide: ${YELLOW}INSTALLATION-GUIDE.md${NC}\n"
    exit 1
fi

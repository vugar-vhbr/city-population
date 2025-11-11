#!/bin/bash

# Kubernetes/Helm Deployment Testing Script
# Complete end-to-end testing of the City Population API on Kubernetes

set -e

BOLD='\033[1m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BOLD}========================================${NC}"
echo -e "${BOLD}  Kubernetes Deployment Test Suite${NC}"
echo -e "${BOLD}========================================${NC}\n"

# Configuration
NAMESPACE="city-population"
RELEASE_NAME="city-population"
TIMEOUT=300

# Step counter
STEP=1

print_step() {
    echo -e "\n${BOLD}${CYAN}[Step $STEP/$1] $2${NC}"
    ((STEP++))
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Step 1: Check if Minikube is running
print_step 10 "Checking Minikube status"

if minikube status &> /dev/null; then
    print_success "Minikube is running"
else
    print_warning "Minikube is not running. Starting Minikube..."
    echo "This may take 2-3 minutes..."

    minikube start --cpus=4 --memory=8192 --driver=docker

    if [ $? -eq 0 ]; then
        print_success "Minikube started successfully"
    else
        print_error "Failed to start Minikube"
        echo "Try running: minikube delete && minikube start --cpus=4 --memory=8192"
        exit 1
    fi
fi

# Step 2: Verify kubectl connection
print_step 10 "Verifying kubectl connection"

if kubectl cluster-info &> /dev/null; then
    print_success "kubectl connected to cluster"
    kubectl cluster-info | head -n 2
else
    print_error "kubectl cannot connect to cluster"
    exit 1
fi

# Step 3: Use Minikube's Docker daemon
print_step 10 "Configuring Docker environment"

print_warning "Setting up Minikube Docker environment..."
eval $(minikube docker-env)
print_success "Using Minikube's Docker daemon"

# Step 4: Build Docker image
print_step 10 "Building Docker image"

echo "Building city-population-api:1.0.0..."
docker build -t city-population-api:1.0.0 . --quiet

if [ $? -eq 0 ]; then
    print_success "Docker image built successfully"
    docker images | grep city-population-api
else
    print_error "Docker build failed"
    exit 1
fi

# Step 5: Create namespace
print_step 10 "Creating Kubernetes namespace"

if kubectl get namespace $NAMESPACE &> /dev/null; then
    print_warning "Namespace '$NAMESPACE' already exists"
else
    kubectl create namespace $NAMESPACE
    print_success "Namespace '$NAMESPACE' created"
fi

# Step 6: Check if Helm release exists
print_step 10 "Checking existing Helm releases"

if helm list -n $NAMESPACE | grep -q $RELEASE_NAME; then
    print_warning "Helm release '$RELEASE_NAME' already exists. Uninstalling..."
    helm uninstall $RELEASE_NAME -n $NAMESPACE
    sleep 5
    print_success "Previous release removed"
fi

# Step 7: Install Helm chart
print_step 10 "Installing Helm chart"

echo "Installing $RELEASE_NAME..."
helm install $RELEASE_NAME ./helm/city-population \
    --namespace $NAMESPACE \
    --create-namespace \
    --wait \
    --timeout ${TIMEOUT}s

if [ $? -eq 0 ]; then
    print_success "Helm chart installed successfully"
else
    print_error "Helm installation failed"
    echo "Check logs: kubectl logs -n $NAMESPACE deployment/city-population-api"
    exit 1
fi

# Step 8: Wait for pods to be ready
print_step 10 "Waiting for pods to be ready"

echo "This may take 1-2 minutes..."

kubectl wait --for=condition=ready pod \
    --all \
    --namespace $NAMESPACE \
    --timeout=${TIMEOUT}s

if [ $? -eq 0 ]; then
    print_success "All pods are ready"
else
    print_error "Pods failed to become ready"
    echo "Check status: kubectl get pods -n $NAMESPACE"
    exit 1
fi

# Step 9: Check pod status
print_step 10 "Checking pod status"

echo ""
kubectl get pods -n $NAMESPACE
echo ""
kubectl get svc -n $NAMESPACE

# Step 10: Test the API
print_step 10 "Testing the API"

echo "Setting up port forwarding..."
kubectl port-forward -n $NAMESPACE service/city-population-api 8080:80 &
PORT_FORWARD_PID=$!

# Wait for port forward to establish
sleep 5

# Test health endpoint
echo -e "\n${BOLD}Testing Health Endpoint:${NC}"
HEALTH_RESPONSE=$(curl -s http://localhost:8080/health)

if echo "$HEALTH_RESPONSE" | grep -q "OK"; then
    print_success "Health check passed"
    echo "$HEALTH_RESPONSE" | jq . 2>/dev/null || echo "$HEALTH_RESPONSE"
else
    print_error "Health check failed"
    echo "$HEALTH_RESPONSE"
fi

# Test upsert endpoint
echo -e "\n${BOLD}Testing Upsert Endpoint:${NC}"
UPSERT_RESPONSE=$(curl -s -X POST http://localhost:8080/city \
    -H "Content-Type: application/json" \
    -d '{"city": "Tokyo", "population": 13960000}')

if echo "$UPSERT_RESPONSE" | grep -q "Tokyo"; then
    print_success "Upsert test passed"
    echo "$UPSERT_RESPONSE" | jq . 2>/dev/null || echo "$UPSERT_RESPONSE"
else
    print_error "Upsert test failed"
    echo "$UPSERT_RESPONSE"
fi

# Wait for Elasticsearch to index
sleep 2

# Test query endpoint
echo -e "\n${BOLD}Testing Query Endpoint:${NC}"
QUERY_RESPONSE=$(curl -s http://localhost:8080/city/tokyo)

if echo "$QUERY_RESPONSE" | grep -q "13960000"; then
    print_success "Query test passed"
    echo "$QUERY_RESPONSE" | jq . 2>/dev/null || echo "$QUERY_RESPONSE"
else
    print_error "Query test failed"
    echo "$QUERY_RESPONSE"
fi

# Stop port forwarding
kill $PORT_FORWARD_PID 2>/dev/null

# Summary
echo -e "\n${BOLD}========================================${NC}"
echo -e "${BOLD}Test Summary${NC}"
echo -e "${BOLD}========================================${NC}"

echo -e "\n${GREEN}✅ Kubernetes deployment successful!${NC}\n"

echo -e "${BOLD}Deployed Resources:${NC}"
echo -e "  • Namespace: ${CYAN}$NAMESPACE${NC}"
echo -e "  • Release: ${CYAN}$RELEASE_NAME${NC}"
echo -e "  • Pods: ${CYAN}$(kubectl get pods -n $NAMESPACE --no-headers | wc -l)${NC}"
echo -e "  • Services: ${CYAN}$(kubectl get svc -n $NAMESPACE --no-headers | wc -l)${NC}"

echo -e "\n${BOLD}Useful Commands:${NC}"
echo -e "  View pods:        ${YELLOW}kubectl get pods -n $NAMESPACE${NC}"
echo -e "  View services:    ${YELLOW}kubectl get svc -n $NAMESPACE${NC}"
echo -e "  View logs:        ${YELLOW}kubectl logs -n $NAMESPACE deployment/city-population-api${NC}"
echo -e "  Port forward:     ${YELLOW}kubectl port-forward -n $NAMESPACE service/city-population-api 8080:80${NC}"
echo -e "  Access API:       ${YELLOW}http://localhost:8080/docs${NC}"

echo -e "\n${BOLD}To access the API:${NC}"
echo -e "  1. Run: ${YELLOW}kubectl port-forward -n $NAMESPACE service/city-population-api 8080:80${NC}"
echo -e "  2. Open browser: ${CYAN}http://localhost:8080/docs${NC}"
echo -e "  3. Or run: ${YELLOW}API_URL=http://localhost:8080 ./test-api.sh${NC}"

echo -e "\n${BOLD}To cleanup:${NC}"
echo -e "  helm uninstall $RELEASE_NAME -n $NAMESPACE"
echo -e "  kubectl delete namespace $NAMESPACE"
echo -e "  minikube stop"

echo -e "\n${GREEN}${BOLD}🎉 All tests completed successfully!${NC}\n"

# City Population API - SRE Assignment

A production-ready containerized REST API for managing city population data, built with FastAPI and Elasticsearch, deployable on Kubernetes using Helm.

## Overview

This application provides a RESTful API to manage city population data with the following features:

- **Health Check Endpoint**: `/health` - Returns application and database status
- **Upsert Endpoint**: `POST /city` - Insert or update city population data
- **Query Endpoint**: `GET /city/{city_name}` - Retrieve population for a specific city
- **List Endpoint**: `GET /cities` - List all cities (bonus feature)

**Tech Stack:**
- **Application**: Python 3.11 + FastAPI (async)
- **Database**: Elasticsearch 8.12.0 (Docker Compose) / 8.5.1 (Kubernetes Helm Chart)
- **Containerization**: Docker (multi-stage build)
- **Orchestration**: Kubernetes
- **Deployment**: Helm Chart

---

##  API Access Ports

**IMPORTANT: The API port differs depending on your deployment method:**

| Deployment Method | API Base URL | Documentation | Use Case |
|-------------------|--------------|---------------|----------|
| **Docker Compose** | `http://localhost:8000` | `http://localhost:8000/docs` | Local development & testing |
| **Kubernetes (Minikube)** | `http://localhost:8080` | `http://localhost:8080/docs` | Production-like deployment |

**Quick Examples:**

Docker Compose:
```bash
curl http://localhost:8000/health
curl http://localhost:8000/cities
```

Kubernetes (with port-forward):
```bash
kubectl port-forward -n city-population service/city-population-api 8080:80
curl http://localhost:8080/health
curl http://localhost:8080/cities
```

---

## Architecture

```
┌─────────────────────┐
│   Kubernetes Cluster │
│                      │
│  ┌───────────────┐  │
│  │   Ingress     │  │  (Optional)
│  └───────┬───────┘  │
│          │          │
│  ┌───────▼───────┐  │
│  │   Service     │  │
│  │  (ClusterIP)  │  │
│  └───────┬───────┘  │
│          │          │
│  ┌───────▼───────┐  │
│  │  Deployment   │  │
│  │   (2 Pods)    │  │  ← FastAPI Application
│  └───────┬───────┘  │
│          │          │
│  ┌───────▼───────┐  │
│  │ Elasticsearch │  │
│  │  StatefulSet  │  │  ← Persistent Storage
│  └───────────────┘  │
└─────────────────────┘
```

---

## Prerequisites

### Required Tools

1. **Docker**: For building container images
   ```bash
   docker --version  # Should be 20.10+
   ```

2. **Kubernetes Cluster**: One of the following
   - Minikube (local development)
   - Docker Desktop with Kubernetes
   - Kind (Kubernetes in Docker)
   - Cloud provider (GKE, EKS, AKS)

3. **kubectl**: Kubernetes CLI tool
   ```bash
   kubectl version --client
   ```

4. **Helm**: Package manager for Kubernetes
   ```bash
   helm version  # Should be v3.0+
   ```

### Setting up Minikube (Recommended for Local Testing)

```bash
# Install Minikube (if not already installed)
# macOS
brew install minikube

# Windows (with Chocolatey)
choco install minikube

# Start Minikube with sufficient resources
minikube start --cpus=4 --memory=8192 --driver=docker

# Enable metrics-server for HPA (optional)
minikube addons enable metrics-server

# Verify cluster is running
kubectl cluster-info
```

---

## Local Development

### 1. Clone or Extract the Project

```bash
cd city-population-sre-assignment
```

### 2. Set Up Python Environment (Optional - for local testing)

```bash
# Create virtual environment
python -m venv venv

# Activate virtual environment
# On Windows
venv\Scripts\activate
# On macOS/Linux
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

### 3. Run Elasticsearch Locally (for development)

```bash
docker run -d \
  --name elasticsearch \
  -p 9200:9200 \
  -p 9300:9300 \
  -e "discovery.type=single-node" \
  -e "xpack.security.enabled=false" \
  docker.elastic.co/elasticsearch/elasticsearch:8.12.0
```

### 4. Run the Application

```bash
# Set environment variables
export ELASTICSEARCH_HOST="http://localhost:9200"
export ELASTICSEARCH_INDEX="cities"

# Run with Uvicorn
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### 5. Access API Documentation

Open your browser and navigate to:
- **Swagger UI**: http://localhost:8080/docs
- **ReDoc**: http://localhost:8080/redoc

---

## Docker Build

### 1. Build the Docker Image

```bash
# Build the image
docker build -t city-population-api:1.0.0 .

# Verify the image
docker images | grep city-population-api
```

### 2. Test the Docker Image Locally

```bash
# Run Elasticsearch (if not already running)
docker run -d \
  --name elasticsearch \
  -p 9200:9200 \
  -e "discovery.type=single-node" \
  -e "xpack.security.enabled=false" \
  docker.elastic.co/elasticsearch/elasticsearch:8.12.0

# Run the application container
docker run -d \
  --name city-api \
  -p 8000:8000 \
  -e ELASTICSEARCH_HOST="http://elasticsearch:9200" \
  --link elasticsearch:elasticsearch \
  city-population-api:1.0.0

# Check logs
docker logs -f city-api

# Test health endpoint
curl http://localhost:8000/health
```

### 3. Push to Docker Registry (Optional)

```bash
# Tag for your registry (replace with your registry URL)
docker tag city-population-api:1.0.0 <your-registry>/city-population-api:1.0.0

# Push to registry
docker push <your-registry>/city-population-api:1.0.0

# Update helm/city-population/values.yaml with your registry URL
```

---

## Kubernetes Deployment

### Option 1: Deploy with Helm (Recommended)

#### Step 1: Load Docker Image into Kubernetes

**For Minikube:**
```bash
# Use Minikube's Docker daemon
eval $(minikube docker-env)

# Build the image in Minikube's Docker
docker build -t city-population-api:1.0.0 .

# Verify image is available
minikube ssh docker images | grep city-population-api
```

**For Docker Desktop / Kind:**
```bash
# Build the image
docker build -t city-population-api:1.0.0 .

# For Kind, load the image
kind load docker-image city-population-api:1.0.0
```

#### Step 2: Download Helm Dependencies

```bash
# Navigate to the Helm chart directory
cd helm/city-population

# Download Elasticsearch chart dependency
helm dependency update

# This downloads elasticsearch-8.5.1.tgz from https://helm.elastic.co
# Output: Saving 1 charts, Downloading elasticsearch from repo

# Verify dependency is downloaded
ls charts/
# Should show: elasticsearch-8.5.1.tgz

# Return to project root
cd ../..
```

#### Step 3: Deploy with Helm

```bash
# Create a namespace (optional but recommended)
kubectl create namespace city-population

# Install the Helm chart
helm install city-population ./helm/city-population \
  --namespace city-population \
  --create-namespace

# Check deployment status
helm status city-population -n city-population

# Watch pods until they're running
kubectl get pods -n city-population -w
```

#### Step 4: Verify Deployment

```bash
# Check all resources
kubectl get all -n city-population

# Check pod logs
kubectl logs -n city-population deployment/city-population-api

# Check Elasticsearch logs
kubectl logs -n city-population statefulset/elasticsearch-master
```

### Option 2: Deploy with kubectl (Alternative)

If you prefer raw Kubernetes manifests instead of Helm:

```bash
# Generate manifests from Helm chart
helm template city-population ./helm/city-population > k8s-manifests.yaml

# Apply manifests
kubectl apply -f k8s-manifests.yaml -n city-population

# Check status
kubectl get all -n city-population
```

---

## API Documentation

###  Access the API

####  Docker Compose (Port 8000)

```bash
# Start Docker Compose
docker-compose up -d

# Access the API at http://localhost:8000
# Swagger UI: http://localhost:8000/docs
# ReDoc: http://localhost:8000/redoc
```

####  Kubernetes (Port 8080)

**Method 1: Port Forwarding (Recommended for Testing)**

```bash
# Forward the service port to localhost
kubectl port-forward -n city-population service/city-population-api 8080:80

# Access the API at http://localhost:8080
# Swagger UI: http://localhost:8080/docs
```

**Method 2: Using Minikube Service**

```bash
# Get the service URL
minikube service city-population-api -n city-population --url

# This will output a URL like: http://192.168.49.2:30123
```

**Method 3: LoadBalancer (Cloud Environments)**

```bash
# Update values.yaml to use LoadBalancer
# app.service.type: LoadBalancer

# Get external IP
kubectl get service city-population-api -n city-population

# Access via EXTERNAL-IP
```

---

### API Endpoints

**Note:** Use `localhost:8000` for Docker Compose, or `localhost:8080` for Kubernetes

#### 1. Health Check
```bash
# Docker Compose
curl http://localhost:8000/health

# Kubernetes
curl http://localhost:8080/health
```

**Response:**
```json
{
  "status": "OK",
  "database": "connected"
}
```

#### 2. Upsert City (Insert/Update)

**Docker Compose:**
```bash
# Insert a new city
curl -X POST http://localhost:8000/city \
  -H "Content-Type: application/json" \
  -d '{"city": "New York", "population": 8336817}'
```

**Kubernetes:**
```bash
# Insert a new city
curl -X POST http://localhost:8080/city \
  -H "Content-Type: application/json" \
  -d '{"city": "New York", "population": 8336817}'
```

**Windows CMD (use double quotes and escape):**
```cmd
curl -X POST http://localhost:8000/city -H "Content-Type: application/json" -d "{\"city\": \"New York\", \"population\": 8336817}"
```

**Response:**
```json
{
  "message": "City inserted successfully",
  "city": "new york",
  "population": 8336817,
  "operation": "insert"
}
```

**Update Example:**
```bash
# Docker Compose
curl -X POST http://localhost:8000/city \
  -H "Content-Type: application/json" \
  -d '{"city": "New York", "population": 8400000}'

# Kubernetes
curl -X POST http://localhost:8080/city \
  -H "Content-Type: application/json" \
  -d '{"city": "New York", "population": 8400000}'
```

**Response:**
```json
{
  "message": "City updated successfully",
  "city": "new york",
  "population": 8400000,
  "operation": "update"
}
```

#### 3. Query City Population
```bash
# Docker Compose
curl http://localhost:8000/city/new%20york

# Kubernetes
curl http://localhost:8080/city/new%20york
```

**Response:**
```json
{
  "city": "new york",
  "population": 8400000
}
```

**Error Response (404):**
```json
{
  "detail": "City 'unknown' not found"
}
```

#### 4. List All Cities (Bonus)
```bash
# Docker Compose
curl http://localhost:8000/cities

# Kubernetes
curl http://localhost:8080/cities
```

**Response:**
```json
{
  "count": 3,
  "cities": [
    {"city": "london", "population": 9002488},
    {"city": "new york", "population": 8400000},
    {"city": "tokyo", "population": 13960000}
  ]
}
```

---

## Testing the API

### Automated Test Script

Create a test script `test-api.sh`:

```bash
#!/bin/bash

API_URL="http://localhost:8080"

echo "=== Testing City Population API ==="

# Test 1: Health Check
echo "\n1. Health Check"
curl -s $API_URL/health | jq .

# Test 2: Insert Cities
echo "\n2. Insert Cities"
curl -s -X POST $API_URL/city \
  -H "Content-Type: application/json" \
  -d '{"city": "Tokyo", "population": 13960000}' | jq .

curl -s -X POST $API_URL/city \
  -H "Content-Type: application/json" \
  -d '{"city": "London", "population": 9002488}' | jq .

curl -s -X POST $API_URL/city \
  -H "Content-Type: application/json" \
  -d '{"city": "New York", "population": 8336817}' | jq .

# Test 3: Query Cities
echo "\n3. Query Cities"
curl -s $API_URL/city/tokyo | jq .
curl -s $API_URL/city/london | jq .

# Test 4: Update City
echo "\n4. Update City"
curl -s -X POST $API_URL/city \
  -H "Content-Type: application/json" \
  -d '{"city": "Tokyo", "population": 14000000}' | jq .

# Test 5: List All Cities
echo "\n5. List All Cities"
curl -s $API_URL/cities | jq .

# Test 6: Query Non-existent City (404)
echo "\n6. Query Non-existent City (Should return 404)"
curl -s -w "\nHTTP Status: %{http_code}\n" $API_URL/city/unknown | jq .

echo "\n=== Tests Complete ==="
```

Run the tests:
```bash
chmod +x test-api.sh
./test-api.sh
```

---

## Monitoring and Observability

### View Logs

```bash
# Application logs
kubectl logs -n city-population deployment/city-population-api -f

# Elasticsearch logs
kubectl logs -n city-population statefulset/elasticsearch-master -f

# All pod logs
kubectl logs -n city-population --all-containers=true -f
```

### Check Pod Health

```bash
# Describe pods
kubectl describe pod -n city-population <pod-name>

# Check resource usage
kubectl top pods -n city-population

# Check events
kubectl get events -n city-population --sort-by='.lastTimestamp'
```

### Access Elasticsearch Directly

```bash
# Port forward Elasticsearch
kubectl port-forward -n city-population service/elasticsearch-master 9200:9200

# Check cluster health
curl http://localhost:9200/_cluster/health?pretty

# View indices
curl http://localhost:9200/_cat/indices?v

# Query cities index
curl http://localhost:9200/cities/_search?pretty
```

---

## Scaling

### Manual Scaling

```bash
# Scale application pods
kubectl scale deployment city-population-api -n city-population --replicas=3

# Verify scaling
kubectl get pods -n city-population
```

### Auto-scaling with HPA

```bash
# Enable HPA in values.yaml
# autoscaling.enabled: true

# Upgrade the deployment
helm upgrade city-population ./helm/city-population -n city-population

# Check HPA status
kubectl get hpa -n city-population

# Generate load to test autoscaling
kubectl run -i --tty load-generator --rm --image=busybox --restart=Never -- /bin/sh
# Inside the pod:
while true; do wget -q -O- http://city-population-api/health; done
```

---

## Troubleshooting

### Issue: Pods are in CrashLoopBackOff

```bash
# Check pod logs
kubectl logs -n city-population <pod-name>

# Check pod events
kubectl describe pod -n city-population <pod-name>

# Common causes:
# 1. Elasticsearch not ready - wait for ES to be healthy
# 2. Image pull error - verify image exists
# 3. Resource limits too low - increase in values.yaml
```

### Issue: Elasticsearch Pod Not Starting

```bash
# Check logs
kubectl logs -n city-population elasticsearch-master-0

# Common causes:
# 1. Insufficient memory - increase elasticsearch.resources.limits.memory
# 2. PVC not binding - check storage class availability
# 3. Init container permissions issue - check SecurityContext

# Check PVC status
kubectl get pvc -n city-population
```

### Issue: Cannot Connect to API

```bash
# Verify service is running
kubectl get svc -n city-population

# Check if pods are ready
kubectl get pods -n city-population

# Test from within cluster
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://city-population-api.city-population.svc.cluster.local/health
```

### Issue: Health Endpoint Returns 503

```bash
# Check Elasticsearch connectivity
kubectl exec -it -n city-population deployment/city-population-api -- \
  curl http://elasticsearch-master:9200/_cluster/health

# Verify ConfigMap
kubectl get configmap -n city-population city-population-api-config -o yaml
```

---

## Production Recommendations

See [REFLECTION.md](REFLECTION.md) for detailed production hardening recommendations including:
- High availability setup
- Security hardening
- Monitoring and observability
- Backup and disaster recovery
- Performance optimization

---

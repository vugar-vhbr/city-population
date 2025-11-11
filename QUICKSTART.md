# Quick Start Guide

Get the City Population API up and running in 5-10 minutes!

---

## 🔌 Important: API Ports

**The API uses different ports depending on your deployment method:**

| Deployment Method | Port | Base URL | Documentation |
|-------------------|------|----------|---------------|
| **Docker Compose** | **8000** | `http://localhost:8000` | `http://localhost:8000/docs` |
| **Kubernetes (Minikube)** | **8080** | `http://localhost:8080` | `http://localhost:8080/docs` |
| **Local Python** | **8000** | `http://localhost:8000` | `http://localhost:8000/docs` |

---

## Prerequisites

- Docker installed
- Kubernetes cluster (Minikube recommended for local testing)
- kubectl configured
- Helm 3.x installed

## Option 1: Quick Start with Minikube (Recommended)

### Step 1: Start Minikube

```bash
# Start Minikube with sufficient resources
minikube start --cpus=4 --memory=8192 --driver=docker

# Verify cluster is running
kubectl cluster-info
```

### Step 2: Build and Deploy

```bash
# Navigate to project directory
cd city-population-sre-assignment

# Use Minikube's Docker daemon
eval $(minikube docker-env)

# Build the Docker image
docker build -t city-population-api:1.0.0 .

# Deploy with Helm
helm install city-population ./helm/city-population \
  --create-namespace \
  --namespace city-population

# Wait for pods to be ready (takes 1-2 minutes)
kubectl wait --for=condition=ready pod \
  --all \
  --namespace city-population \
  --timeout=300s
```

### Step 3: Access the API

```bash
# Port forward to access the API
kubectl port-forward -n city-population service/city-population-api 8080:80

# In another terminal, test the API
curl http://localhost:8080/health
```

### Step 4: Test the API

```bash
# Make the test script executable
chmod +x test-api.sh

# Run the test script
API_URL=http://localhost:8080 ./test-api.sh
```

## Option 2: Docker Compose (Fastest for Local Development)

Create a `docker-compose.yml` file:

```yaml
version: '3.8'

services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.12.0
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
      - ES_JAVA_OPTS=-Xms512m -Xmx512m
    ports:
      - "9200:9200"
    volumes:
      - es-data:/usr/share/elasticsearch/data
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9200/_cluster/health"]
      interval: 10s
      timeout: 5s
      retries: 5

  api:
    build: .
    ports:
      - "8000:8000"
    environment:
      - ELASTICSEARCH_HOST=http://elasticsearch:9200
      - ELASTICSEARCH_INDEX=cities
    depends_on:
      elasticsearch:
        condition: service_healthy

volumes:
  es-data:
```

Then run:

```bash
# Start all services
docker-compose up -d

# Check logs
docker-compose logs -f

# Test the API
curl http://localhost:8000/health

# Run tests
API_URL=http://localhost:8000 ./test-api.sh

# Stop services
docker-compose down
```

## Option 3: Local Python Development

```bash
# Install dependencies
pip install -r requirements.txt

# Start Elasticsearch
docker run -d \
  --name elasticsearch \
  -p 9200:9200 \
  -e "discovery.type=single-node" \
  -e "xpack.security.enabled=false" \
  docker.elastic.co/elasticsearch/elasticsearch:8.12.0

# Set environment variables
export ELASTICSEARCH_HOST=http://localhost:9200
export ELASTICSEARCH_INDEX=cities

# Run the application
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Access at http://localhost:8000/docs
```

## Quick API Examples

**Note:** Use the appropriate port for your deployment:
- **Kubernetes:** `localhost:8080`
- **Docker Compose / Local Python:** `localhost:8000`

### 1. Health Check
```bash
# Kubernetes
curl http://localhost:8080/health

# Docker Compose / Local Python
curl http://localhost:8000/health
```

### 2. Add Cities
```bash
# Kubernetes - Add Tokyo
curl -X POST http://localhost:8080/city \
  -H "Content-Type: application/json" \
  -d '{"city": "Tokyo", "population": 13960000}'

# Docker Compose - Add Tokyo
curl -X POST http://localhost:8000/city \
  -H "Content-Type: application/json" \
  -d '{"city": "Tokyo", "population": 13960000}'
```

### 3. Query Cities
```bash
# Kubernetes
curl http://localhost:8080/city/tokyo
curl http://localhost:8080/cities

# Docker Compose / Local Python
curl http://localhost:8000/city/tokyo
curl http://localhost:8000/cities
```

### 4. Update City
```bash
# Kubernetes
curl -X POST http://localhost:8080/city \
  -H "Content-Type: application/json" \
  -d '{"city": "Tokyo", "population": 14000000}'

# Docker Compose / Local Python
curl -X POST http://localhost:8000/city \
  -H "Content-Type: application/json" \
  -d '{"city": "Tokyo", "population": 14000000}'
```

## Access API Documentation

**Kubernetes:**
- **Swagger UI**: http://localhost:8080/docs
- **ReDoc**: http://localhost:8080/redoc

**Docker Compose / Local Python:**
- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc

## Troubleshooting

### Pods not starting?

```bash
# Check pod status
kubectl get pods -n city-population

# Check logs
kubectl logs -n city-population deployment/city-population-api
kubectl logs -n city-population statefulset/elasticsearch

# Describe pod for events
kubectl describe pod -n city-population <pod-name>
```

### Elasticsearch not ready?

```bash
# Wait for Elasticsearch to be healthy
kubectl wait --for=condition=ready pod \
  -l app=elasticsearch \
  -n city-population \
  --timeout=300s

# Check Elasticsearch health
kubectl port-forward -n city-population service/elasticsearch 9200:9200
curl http://localhost:9200/_cluster/health?pretty
```

### Cannot access API?

```bash
# Verify port-forward is running
kubectl port-forward -n city-population service/city-population-api 8080:80

# Check service
kubectl get svc -n city-population

# Test from within cluster
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://city-population-api.city-population.svc.cluster.local/health
```

## Cleanup

```bash
# Uninstall Helm release
helm uninstall city-population -n city-population

# Delete namespace
kubectl delete namespace city-population

# Stop Minikube (optional)
minikube stop

# Docker Compose cleanup
docker-compose down -v
```

## Next Steps

- Read [README.md](README.md) for detailed documentation
- Check [REFLECTION.md](REFLECTION.md) for production recommendations
- Explore the API at http://localhost:8080/docs

## Need Help?

- Check the logs: `kubectl logs -n city-population <pod-name>`
- Verify resources: `kubectl get all -n city-population`
- Review the full documentation in README.md

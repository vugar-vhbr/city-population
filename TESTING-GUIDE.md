# Complete Testing Guide

This guide walks you through testing the entire City Population API project after installing all required tools.

---

## 🔌 Important: API Ports

**The API uses different ports depending on deployment method:**

| Deployment | Port | Base URL | Documentation |
|------------|------|----------|---------------|
| **Docker Compose** | 8000 | `http://localhost:8000` | `http://localhost:8000/docs` |
| **Kubernetes** | 8080 | `http://localhost:8080` | `http://localhost:8080/docs` |

Make sure to use the correct port for the examples below!

---

## 📋 Pre-Testing Checklist

Make sure you have installed:
- ✅ Docker Desktop
- ✅ Python 3.11+
- ✅ kubectl
- ✅ Minikube
- ✅ Helm 3

**Verify installations:**
```bash
cd C:\Users\PARVIZ\Desktop\city-population-sre-assignment
./verify-installation.sh
```

---

## 🧪 Testing Phases

We'll test in 3 phases:
1. **Phase 1:** Docker Compose (5 minutes) - Fastest test
2. **Phase 2:** Kubernetes/Helm (15 minutes) - Complete deployment
3. **Phase 3:** Manual API testing - Verify all endpoints

---

## Phase 1: Docker Compose Testing ⚡

This is the fastest way to verify the application works.

### Step 1: Start the services

```bash
cd C:\Users\PARVIZ\Desktop\city-population-sre-assignment

# Start Docker Desktop first (make sure it's running)

# Start all services
docker-compose up -d
```

**Expected output:**
```
Creating network "city-population-sre-assignment_city-population-network" ... done
Creating elasticsearch ... done
Creating city-population-api ... done
```

### Step 2: Check service status

```bash
# Check if containers are running
docker-compose ps
```

**Expected output:**
```
Name                         State    Ports
----------------------------------------------------------------
city-population-api         Up       0.0.0.0:8000->8000/tcp
elasticsearch               Up       0.0.0.0:9200->9200/tcp
```

### Step 3: View logs

```bash
# Watch logs (Ctrl+C to exit)
docker-compose logs -f

# Or check individual service
docker-compose logs api
docker-compose logs elasticsearch
```

**Wait for these messages:**
- API: `Application startup complete`
- Elasticsearch: `Cluster health status changed from [YELLOW] to [GREEN]`

### Step 4: Test the API

```bash
# Make the test script executable
chmod +x test-api.sh

# Run the automated test suite
API_URL=http://localhost:8000 ./test-api.sh
```

**Expected output:**
```
========================================
City Population API - Test Suite
========================================

Test 1: Health Check
✓ PASSED

Test 2: Insert City - Tokyo
✓ PASSED

Test 3: Query City - Tokyo
✓ PASSED

...

========================================
Test Summary
========================================
Passed: 12
Failed: 0
Total: 12

✅ All tests passed! ✓
```

### Step 5: Manual API testing

```bash
# Health check
curl http://localhost:8000/health

# Insert a city
curl -X POST http://localhost:8000/city \
  -H "Content-Type: application/json" \
  -d '{"city": "Paris", "population": 2161000}'

# Query the city
curl http://localhost:8000/city/paris

# List all cities
curl http://localhost:8000/cities
```

### Step 6: Access API documentation

Open your browser and visit:
- **Swagger UI:** http://localhost:8000/docs
- **ReDoc:** http://localhost:8000/redoc

### Step 7: Cleanup

```bash
# Stop services
docker-compose down

# Remove volumes (optional - deletes data)
docker-compose down -v
```

---

## Phase 2: Kubernetes/Helm Testing 🚀

This tests the complete Kubernetes deployment.

### Step 1: Run the automated Kubernetes test

```bash
cd C:\Users\PARVIZ\Desktop\city-population-sre-assignment

# Make script executable
chmod +x test-kubernetes.sh

# Run the test (takes 10-15 minutes)
./test-kubernetes.sh
```

**What it does:**
1. ✅ Starts Minikube (if not running)
2. ✅ Builds Docker image
3. ✅ Installs Helm chart
4. ✅ Waits for pods to be ready
5. ✅ Tests all API endpoints
6. ✅ Shows deployment summary

**Expected output:**
```
========================================
  Kubernetes Deployment Test Suite
========================================

[Step 1/10] Checking Minikube status
✓ Minikube is running

[Step 2/10] Verifying kubectl connection
✓ kubectl connected to cluster

...

[Step 10/10] Testing the API
✓ Health check passed
✓ Upsert test passed
✓ Query test passed

========================================
Test Summary
========================================

✅ Kubernetes deployment successful!
```

### Step 2: Manual Kubernetes verification

```bash
# View all resources
kubectl get all -n city-population

# Check pod status
kubectl get pods -n city-population

# Check services
kubectl get svc -n city-population

# View pod logs
kubectl logs -n city-population deployment/city-population-api

# View Elasticsearch logs
kubectl logs -n city-population statefulset/elasticsearch
```

### Step 3: Access the API in Kubernetes

```bash
# Port forward to access the API
kubectl port-forward -n city-population service/city-population-api 8080:80

# In another terminal, test the API
curl http://localhost:8080/health

# Or run the test suite
API_URL=http://localhost:8080 ./test-api.sh
```

### Step 4: Test scaling

```bash
# Scale the application to 3 replicas
kubectl scale deployment city-population-api -n city-population --replicas=3

# Watch pods scale up
kubectl get pods -n city-population -w

# Verify all replicas are running
kubectl get pods -n city-population
```

### Step 5: Test rolling updates

```bash
# Trigger a rolling update by changing an environment variable
helm upgrade city-population ./helm/city-population \
  -n city-population \
  --set app.env.DEBUG=true \
  --wait

# Watch the rolling update
kubectl rollout status deployment/city-population-api -n city-population
```

### Step 6: Check Elasticsearch health

```bash
# Port forward Elasticsearch
kubectl port-forward -n city-population service/elasticsearch 9200:9200

# In another terminal, check cluster health
curl http://localhost:9200/_cluster/health?pretty

# View indices
curl http://localhost:9200/_cat/indices?v

# Query the cities index
curl http://localhost:9200/cities/_search?pretty
```

### Step 7: View Helm release info

```bash
# List Helm releases
helm list -n city-population

# Get release status
helm status city-population -n city-population

# Get release values
helm get values city-population -n city-population

# View all resources
helm get manifest city-population -n city-population
```

### Step 8: Cleanup

```bash
# Uninstall Helm release
helm uninstall city-population -n city-population

# Delete namespace
kubectl delete namespace city-population

# Stop Minikube (optional)
minikube stop

# Delete Minikube cluster (optional - fresh start)
minikube delete
```

---

## Phase 3: Manual API Testing 🔍

Comprehensive manual testing of all endpoints.

### Prerequisites

Make sure the API is accessible (either via docker-compose or Kubernetes port-forward):
- Docker Compose: http://localhost:8000
- Kubernetes: http://localhost:8080 (with port-forward)

### Test 1: Health Check Endpoint

```bash
# Request
curl http://localhost:8000/health

# Expected Response (200 OK)
{
  "status": "OK",
  "database": "connected"
}
```

### Test 2: Upsert Endpoint - Insert

```bash
# Insert Tokyo
curl -X POST http://localhost:8000/city \
  -H "Content-Type: application/json" \
  -d '{"city": "Tokyo", "population": 13960000}'

# Expected Response (200 OK)
{
  "message": "City inserted successfully",
  "city": "tokyo",
  "population": 13960000,
  "operation": "insert"
}
```

### Test 3: Query Endpoint

```bash
# Query Tokyo
curl http://localhost:8000/city/tokyo

# Expected Response (200 OK)
{
  "city": "tokyo",
  "population": 13960000
}
```

### Test 4: Upsert Endpoint - Update

```bash
# Update Tokyo's population
curl -X POST http://localhost:8000/city \
  -H "Content-Type: application/json" \
  -d '{"city": "Tokyo", "population": 14000000}'

# Expected Response (200 OK)
{
  "message": "City updated successfully",
  "city": "tokyo",
  "population": 14000000,
  "operation": "update"
}
```

### Test 5: List All Cities

```bash
# List all cities
curl http://localhost:8000/cities

# Expected Response (200 OK)
{
  "count": 1,
  "cities": [
    {
      "city": "tokyo",
      "population": 14000000
    }
  ]
}
```

### Test 6: Query Non-existent City

```bash
# Query unknown city
curl http://localhost:8000/city/atlantis

# Expected Response (404 Not Found)
{
  "detail": "City 'atlantis' not found"
}
```

### Test 7: Invalid Input - Negative Population

```bash
# Try to insert negative population
curl -X POST http://localhost:8000/city \
  -H "Content-Type: application/json" \
  -d '{"city": "Test", "population": -1000}'

# Expected Response (400 Bad Request or 422)
{
  "detail": "Population must be a non-negative integer"
}
```

### Test 8: Invalid Input - Empty City Name

```bash
# Try to insert empty city name
curl -X POST http://localhost:8000/city \
  -H "Content-Type: application/json" \
  -d '{"city": "", "population": 1000}'

# Expected Response (422 Unprocessable Entity)
{
  "detail": [
    {
      "loc": ["body", "city"],
      "msg": "ensure this value has at least 1 characters",
      "type": "value_error.any_str.min_length"
    }
  ]
}
```

### Test 9: Case Insensitivity

```bash
# Insert with mixed case
curl -X POST http://localhost:8000/city \
  -H "Content-Type: application/json" \
  -d '{"city": "New York", "population": 8336817}'

# Query with different case
curl http://localhost:8000/city/NEW%20YORK
curl http://localhost:8000/city/new%20york
curl http://localhost:8000/city/NeW%20yOrK

# All should return the same result
{
  "city": "new york",
  "population": 8336817
}
```

### Test 10: Load Testing (Optional)

```bash
# Insert multiple cities
cities=("London:9002488" "Paris:2161000" "Berlin:3769495" "Madrid:3223334" "Rome:2873494")

for city_data in "${cities[@]}"; do
  IFS=':' read -r city pop <<< "$city_data"
  curl -X POST http://localhost:8000/city \
    -H "Content-Type: application/json" \
    -d "{\"city\": \"$city\", \"population\": $pop}"
  echo ""
done

# List all cities
curl http://localhost:8000/cities | jq .
```

---

## 📊 Test Results Checklist

After completing all tests, verify:

### Docker Compose Tests
- [ ] Docker containers start successfully
- [ ] Health endpoint returns OK
- [ ] Can insert cities
- [ ] Can query cities
- [ ] Can update cities
- [ ] Can list all cities
- [ ] API documentation accessible
- [ ] All automated tests pass

### Kubernetes Tests
- [ ] Minikube starts successfully
- [ ] Docker image builds
- [ ] Helm chart installs
- [ ] All pods become ready
- [ ] Health probes work
- [ ] Can access API via port-forward
- [ ] All API endpoints work
- [ ] Scaling works
- [ ] Rolling updates work
- [ ] Elasticsearch is healthy

### API Tests
- [ ] Health check works
- [ ] Insert operation works
- [ ] Update operation works
- [ ] Query operation works
- [ ] List operation works
- [ ] 404 for non-existent cities
- [ ] Validation rejects negative population
- [ ] Validation rejects empty city name
- [ ] Case-insensitive queries work

---

## 🆘 Troubleshooting

### Docker Compose Issues

**Containers won't start:**
```bash
# Check Docker is running
docker ps

# View logs
docker-compose logs

# Restart services
docker-compose restart

# Full cleanup and restart
docker-compose down -v
docker-compose up -d
```

**Port conflicts:**
```bash
# Check if ports are in use
netstat -an | grep 8000
netstat -an | grep 9200

# Change ports in docker-compose.yml if needed
```

### Kubernetes Issues

**Pods not starting:**
```bash
# Check pod status
kubectl get pods -n city-population

# Describe pod for events
kubectl describe pod -n city-population <pod-name>

# Check logs
kubectl logs -n city-population <pod-name>

# Check Elasticsearch logs
kubectl logs -n city-population elasticsearch-0
```

**Image pull errors:**
```bash
# Make sure you're using Minikube's Docker
eval $(minikube docker-env)

# Rebuild image
docker build -t city-population-api:1.0.0 .

# Verify image exists
docker images | grep city-population-api
```

**Helm installation fails:**
```bash
# Uninstall and try again
helm uninstall city-population -n city-population

# Check Helm chart syntax
helm lint ./helm/city-population

# Dry run to see what would be created
helm install city-population ./helm/city-population \
  -n city-population \
  --dry-run --debug
```

**API not accessible:**
```bash
# Check service
kubectl get svc -n city-population

# Check port-forward is running
ps aux | grep port-forward

# Restart port-forward
kubectl port-forward -n city-population service/city-population-api 8080:80
```

---

## ✅ Success Criteria

Your tests are successful if:

1. ✅ All Docker Compose tests pass
2. ✅ All Kubernetes deployment steps complete
3. ✅ All API endpoints return expected responses
4. ✅ Automated test script passes with 0 failures
5. ✅ API documentation is accessible
6. ✅ Elasticsearch stores and retrieves data correctly
7. ✅ Health probes work in Kubernetes
8. ✅ Application can scale

---

## 🎉 Next Steps

After successful testing:

1. **Document your findings** - Add notes to REFLECTION.md
2. **Create screenshots** - Capture successful test outputs
3. **Prepare submission:**
   - ZIP the project folder
   - Or push to GitHub
   - Include test results/screenshots

4. **Optional enhancements:**
   - Enable HPA: Set `autoscaling.enabled=true` in values.yaml
   - Enable Ingress: Set `ingress.enabled=true` in values.yaml
   - Add monitoring: Install Prometheus/Grafana
   - Add more cities and test performance

---

## 📞 Need Help?

If tests fail:
1. Check the Troubleshooting section above
2. Review logs: `docker-compose logs` or `kubectl logs`
3. Verify all tools are installed: `./verify-installation.sh`
4. Check README.md for detailed documentation
5. Ensure Docker Desktop is running and healthy

**Common issues:**
- Docker Desktop not running → Start Docker Desktop
- Port conflicts → Change ports in configuration
- Out of memory → Increase Docker Desktop memory limit
- Minikube won't start → Try `minikube delete` then `minikube start`

Good luck with testing! 🚀

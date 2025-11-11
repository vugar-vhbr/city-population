# 🚀 START HERE - Complete Testing Workflow

Welcome! This guide will take you from installation to complete testing in a structured way.

---

## 🔌 Important: API Ports

**Before you start, know which port to use:**

| Deployment Method | Port | API URL | Documentation |
|-------------------|------|---------|---------------|
| **Docker Compose** | 8000 | `http://localhost:8000` | `http://localhost:8000/docs` |
| **Kubernetes (Minikube)** | 8080 | `http://localhost:8080` | `http://localhost:8080/docs` |

---

## 📍 Current Location

You are here: `C:\Users\PARVIZ\Desktop\city-population-sre-assignment`

---

## 🎯 Your Goal

Test the complete City Population API including:
- ✅ Docker Compose deployment
- ✅ Kubernetes/Helm deployment
- ✅ All API endpoints
- ✅ Production-ready configurations

---

## 📚 Quick Navigation

| File | Purpose | When to Use |
|------|---------|-------------|
| **INSTALLATION-GUIDE.md** | Install all required tools | Read this FIRST |
| **verify-installation.sh** | Verify tools are installed | After installing tools |
| **TESTING-GUIDE.md** | Complete testing instructions | Main testing reference |
| **test-kubernetes.sh** | Automated Kubernetes test | One-command K8s testing |
| **test-api.sh** | API endpoint testing | Test all API endpoints |
| **README.md** | Project documentation | Deployment reference |
| **QUICKSTART.md** | 5-minute quick start | Fast setup guide |
| **REFLECTION.md** | Production recommendations | Review after testing |

---

## 🔄 Complete Workflow

### Phase 1: Installation (30-45 minutes)

```
┌─────────────────────────────────────┐
│  1. Read INSTALLATION-GUIDE.md      │
│  2. Install all 5 tools:            │
│     • Docker Desktop                │
│     • Python 3.11+                  │
│     • kubectl                       │
│     • Minikube                      │
│     • Helm 3                        │
│  3. Restart your terminal           │
│  4. Run: ./verify-installation.sh   │
└─────────────────────────────────────┘
```

**Commands:**
```bash
# 1. Open INSTALLATION-GUIDE.md and follow instructions
notepad INSTALLATION-GUIDE.md

# 2. After installing all tools, verify:
./verify-installation.sh
```

---

### Phase 2: Docker Compose Testing (5 minutes)

```
┌─────────────────────────────────────┐
│  1. Start Docker Desktop            │
│  2. Run: docker-compose up -d       │
│  3. Wait 30 seconds                 │
│  4. Run: ./test-api.sh              │
│  5. Open: http://localhost:8000/docs│
└─────────────────────────────────────┘
```

**Commands:**
```bash
# Make sure Docker Desktop is running, then:
docker-compose up -d
docker-compose ps
docker-compose logs -f  # Wait for "Application startup complete"

# Test the API (in a new terminal)
chmod +x test-api.sh
API_URL=http://localhost:8000 ./test-api.sh

# Open browser
start http://localhost:8000/docs
```

**Expected Result:** All 12 tests should pass ✅

---

### Phase 3: Kubernetes Testing (15 minutes)

```
┌─────────────────────────────────────┐
│  1. Stop docker-compose             │
│  2. Run: ./test-kubernetes.sh       │
│  3. Wait for completion             │
│  4. Access API via port-forward     │
│  5. Run tests again                 │
└─────────────────────────────────────┘
```

**Commands:**
```bash
# Stop docker-compose first
docker-compose down

# Run automated Kubernetes test
chmod +x test-kubernetes.sh
./test-kubernetes.sh

# This will:
# - Start Minikube
# - Build Docker image
# - Install Helm chart
# - Deploy everything
# - Test the API
```

**Expected Result:** Complete K8s deployment with all tests passing ✅

---

### Phase 4: Manual Verification (10 minutes)

```
┌─────────────────────────────────────┐
│  1. Check all K8s resources         │
│  2. Test API manually               │
│  3. Verify scaling works            │
│  4. Check Elasticsearch health      │
│  5. Review logs                     │
└─────────────────────────────────────┘
```

**Commands:**
```bash
# Check Kubernetes resources
kubectl get all -n city-population
kubectl get pods -n city-population

# Port forward to access API
kubectl port-forward -n city-population service/city-population-api 8080:80

# In another terminal, test manually
curl http://localhost:8080/health
curl -X POST http://localhost:8080/city \
  -H "Content-Type: application/json" \
  -d '{"city": "Paris", "population": 2161000}'
curl http://localhost:8080/city/paris

# Test scaling
kubectl scale deployment city-population-api -n city-population --replicas=3
kubectl get pods -n city-population

# View logs
kubectl logs -n city-population deployment/city-population-api
```

---

## 📋 Testing Checklist

### Before Testing
- [ ] All 5 tools installed
- [ ] `./verify-installation.sh` passes
- [ ] Docker Desktop is running
- [ ] Terminal has been restarted

### Docker Compose Tests
- [ ] `docker-compose up -d` succeeds
- [ ] Containers are running
- [ ] Health endpoint returns OK
- [ ] `./test-api.sh` passes (12/12 tests)
- [ ] API docs accessible at http://localhost:8000/docs

### Kubernetes Tests
- [ ] Minikube starts successfully
- [ ] Docker image builds
- [ ] Helm chart installs
- [ ] All pods become ready
- [ ] Port-forward works
- [ ] API endpoints respond correctly
- [ ] Can scale deployment

### Manual Verification
- [ ] Can insert cities
- [ ] Can query cities
- [ ] Can update cities
- [ ] Can list all cities
- [ ] 404 for non-existent cities
- [ ] Validation works correctly
- [ ] Elasticsearch stores data
- [ ] Logs show no errors

---

## 🎯 Success Criteria

You're done when:
✅ All Docker Compose tests pass
✅ Kubernetes deployment completes successfully
✅ All API endpoints work correctly
✅ No errors in logs
✅ Can scale the application
✅ Health checks are green

---

## 🆘 Quick Troubleshooting

### Docker Issues
```bash
# Docker won't start
# → Open Docker Desktop manually

# Port already in use
docker-compose down
# → Wait 10 seconds, try again

# Containers crash
docker-compose logs
# → Check error messages
```

### Kubernetes Issues
```bash
# Minikube won't start
minikube delete
minikube start --cpus=4 --memory=8192

# Pods not ready
kubectl get pods -n city-population
kubectl describe pod -n city-population <pod-name>

# Helm install fails
helm uninstall city-population -n city-population
# → Wait 10 seconds, try again
```

### API Issues
```bash
# API not responding
# → Wait 30 seconds after starting
# → Check logs: docker-compose logs api

# Tests failing
# → Make sure Elasticsearch is ready
# → Wait 1-2 minutes after startup
```

---

## 📖 Detailed References

Need more information? Check these files:

| Topic | File |
|-------|------|
| Tool installation | INSTALLATION-GUIDE.md |
| Complete testing steps | TESTING-GUIDE.md |
| Project overview | README.md |
| Quick start | QUICKSTART.md |
| API documentation | README.md (API section) |
| Production setup | REFLECTION.md |
| Configuration | helm/city-population/values.yaml |

---

## 🔥 Quick Commands Reference

```bash
# ===== INSTALLATION =====
./verify-installation.sh

# ===== DOCKER COMPOSE =====
docker-compose up -d                    # Start services
docker-compose ps                       # Check status
docker-compose logs -f                  # View logs
./test-api.sh                          # Run tests
docker-compose down                     # Stop services

# ===== KUBERNETES =====
./test-kubernetes.sh                   # Automated test
kubectl get all -n city-population     # View resources
kubectl get pods -n city-population    # View pods
kubectl logs -n city-population deployment/city-population-api
kubectl port-forward -n city-population service/city-population-api 8080:80

# ===== HELM =====
helm list -n city-population           # List releases
helm status city-population -n city-population
helm uninstall city-population -n city-population

# ===== MINIKUBE =====
minikube start --cpus=4 --memory=8192  # Start cluster
minikube status                        # Check status
minikube dashboard                     # Open dashboard
minikube stop                          # Stop cluster
```

---

## 🎬 Let's Start!

**Step 1:** Open the installation guide
```bash
notepad INSTALLATION-GUIDE.md
# Or
cat INSTALLATION-GUIDE.md
```

**Step 2:** Install all tools (follow the guide)

**Step 3:** Come back here and continue to Phase 2

---

## 📞 Need Help?

1. **Installation issues** → See INSTALLATION-GUIDE.md
2. **Testing issues** → See TESTING-GUIDE.md
3. **API questions** → See README.md
4. **Configuration** → See helm/city-population/values.yaml

---

## ✅ What's Next After Testing?

1. **Document results** - Take screenshots of successful tests
2. **Review REFLECTION.md** - Production recommendations
3. **Prepare submission:**
   - ZIP the entire folder, or
   - Push to GitHub repository
4. **Optional:** Try production recommendations from REFLECTION.md

---

## 🎉 You're Ready!

All files are prepared and ready for testing.

**Next step:** Open `INSTALLATION-GUIDE.md` and start installing the tools!

```bash
notepad INSTALLATION-GUIDE.md
```

Good luck! 🚀

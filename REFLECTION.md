# SRE Assignment Reflection

## Challenges Faced During Implementation

### 1. Elasticsearch Connection Timing

**Challenge**: The application pods were crashing during startup because they attempted to connect to Elasticsearch before it was fully ready.

**Solution**: Implemented an init container in the Kubernetes deployment that waits for Elasticsearch to be available on port 9200 before starting the application container. Additionally, added retry logic in the Elasticsearch client with proper timeout handling.

```yaml
initContainers:
  - name: wait-for-elasticsearch
    image: busybox:1.36
    command: ['sh', '-c']
    args:
      - |
        until nc -z elasticsearch 9200; do
          echo "Waiting for Elasticsearch..."
          sleep 5
        done
```

### 2. Container Security Hardening

**Challenge**: Running containers as root poses security risks, but Elasticsearch requires specific file permissions.

**Solution**:
- Created a non-root user in the application Dockerfile with UID 1000
- Used multi-stage Docker builds to minimize attack surface
- Implemented proper security contexts in Kubernetes manifests
- Added an init container for Elasticsearch to fix permissions before the main container starts

### 3. Asynchronous Operations with Elasticsearch

**Challenge**: Initial implementation used synchronous Elasticsearch client which blocked the event loop, reducing throughput.

**Solution**: Migrated to the async Elasticsearch client (`AsyncElasticsearch`) and implemented async/await patterns throughout the application for better concurrency and performance under load.

### 4. Health Probe Configuration

**Challenge**: Kubernetes health probes were failing prematurely, causing unnecessary pod restarts during Elasticsearch index creation.

**Solution**:
- Increased `initialDelaySeconds` to allow for startup time
- Differentiated between liveness and readiness probes with different thresholds
- Made the health endpoint check actual Elasticsearch connectivity, not just application status

### 5. Index Mapping Creation

**Challenge**: Without proper index mappings, Elasticsearch was creating inefficient default mappings for city data.

**Solution**: Implemented automatic index creation with explicit mappings during application startup:
- Used `keyword` type for city names (exact matching)
- Used `long` type for population (integer values)
- Configured appropriate shard and replica counts

### 6. Development vs. Production Configuration

**Challenge**: Different environments require different configurations (single-node ES for dev, cluster for prod).

**Solution**:
- Used Helm values to parameterize all environment-specific settings
- Created sensible defaults for development in `values.yaml`
- Documented production-ready configurations in comments
- Used environment variables for all configurable parameters

---

## Suggestions for Scaling to Production-Ready Environment

### 1. High Availability (HA) Setup

#### Application Layer
```yaml
# Increase replicas for redundancy
app:
  replicaCount: 3  # Minimum 3 for HA across availability zones

# Enable Pod Disruption Budget
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: city-population-api-pdb
spec:
  minAvailable: 2  # Keep at least 2 pods available during updates
  selector:
    matchLabels:
      app: city-population-api
```

#### Elasticsearch Cluster
```yaml
elasticsearch:
  # Multi-node cluster for HA
  master:
    replicaCount: 3  # Odd number for quorum
  data:
    replicaCount: 3  # Multiple data nodes for redundancy

  # Enable anti-affinity to spread pods across nodes
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchLabels:
              app: elasticsearch
          topologyKey: kubernetes.io/hostname
```

#### Database Backup Strategy
```bash
# Implement Elasticsearch snapshots
# Register snapshot repository
PUT /_snapshot/backup_repo
{
  "type": "s3",
  "settings": {
    "bucket": "city-population-backups",
    "region": "us-east-1"
  }
}

# Automated daily snapshots
PUT /_snapshot/backup_repo/daily_snapshot
{
  "indices": "cities",
  "ignore_unavailable": true,
  "include_global_state": false
}

# Implement CronJob for scheduled backups
apiVersion: batch/v1
kind: CronJob
metadata:
  name: elasticsearch-backup
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: curlimages/curl
            command: ["/bin/sh"]
            args:
              - -c
              - |
                curl -X PUT "elasticsearch:9200/_snapshot/backup_repo/snapshot_$(date +%Y%m%d)" \
                  -H 'Content-Type: application/json' \
                  -d '{"indices": "cities", "ignore_unavailable": true}'
```

---

### 2. Observability and Monitoring

#### Metrics Collection
```yaml
# Install Prometheus Operator
helm install prometheus prometheus-community/kube-prometheus-stack

# Add ServiceMonitor for the application
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: city-population-api
spec:
  selector:
    matchLabels:
      app: city-population-api
  endpoints:
  - port: http
    path: /metrics
    interval: 30s
```

#### Application Metrics
```python
# Add prometheus-fastapi-instrumentator to requirements.txt
from prometheus_fastapi_instrumentator import Instrumentator

# In main.py
Instrumentator().instrument(app).expose(app)

# Metrics to track:
# - Request rate (requests/second)
# - Request duration (latency percentiles)
# - Error rate (5xx responses)
# - Database connection pool usage
# - Active connections to Elasticsearch
```

#### Logging Infrastructure
```yaml
# Deploy EFK Stack (Elasticsearch, Fluentd, Kibana)
# Or use managed services (AWS CloudWatch, GCP Cloud Logging, Datadog)

# Add structured logging
# In application code, use JSON formatter
import json
import logging

class JSONFormatter(logging.Formatter):
    def format(self, record):
        log_data = {
            "timestamp": self.formatTime(record),
            "level": record.levelname,
            "message": record.getMessage(),
            "service": "city-population-api",
            "trace_id": getattr(record, 'trace_id', None)
        }
        return json.dumps(log_data)
```

#### Distributed Tracing
```python
# Add OpenTelemetry for distributed tracing
from opentelemetry import trace
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.exporter.jaeger import JaegerExporter

# Configure tracing
tracer = trace.get_tracer(__name__)
FastAPIInstrumentor.instrument_app(app)

# Export to Jaeger/Zipkin/Tempo
jaeger_exporter = JaegerExporter(
    agent_host_name="jaeger",
    agent_port=6831,
)
```

#### Alerting Rules
```yaml
# Prometheus AlertManager rules
groups:
  - name: city-population-api
    rules:
      # High error rate
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.05
        for: 5m
        annotations:
          summary: "High error rate detected"

      # API latency
      - alert: HighLatency
        expr: histogram_quantile(0.95, http_request_duration_seconds_bucket) > 1
        for: 10m
        annotations:
          summary: "95th percentile latency > 1s"

      # Elasticsearch down
      - alert: ElasticsearchDown
        expr: up{job="elasticsearch"} == 0
        for: 1m
        annotations:
          summary: "Elasticsearch is down"

      # Pod restarts
      - alert: PodRestarting
        expr: rate(kube_pod_container_status_restarts_total[15m]) > 0
        annotations:
          summary: "Pod is restarting frequently"
```

---

### 3. Security Hardening

#### Network Security
```yaml
# Implement NetworkPolicy to restrict traffic
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: city-population-api-netpol
spec:
  podSelector:
    matchLabels:
      app: city-population-api
  policyTypes:
  - Ingress
  - Egress
  ingress:
    # Allow from ingress controller only
    - from:
      - namespaceSelector:
          matchLabels:
            name: ingress-nginx
      ports:
      - protocol: TCP
        port: 8000
  egress:
    # Allow to Elasticsearch only
    - to:
      - podSelector:
          matchLabels:
            app: elasticsearch
      ports:
      - protocol: TCP
        port: 9200
    # Allow DNS
    - to:
      - namespaceSelector: {}
      ports:
      - protocol: UDP
        port: 53
```

#### Enable Elasticsearch Security
```yaml
# Enable X-Pack security
elasticsearch:
  env:
    - name: xpack.security.enabled
      value: "true"
    - name: xpack.security.transport.ssl.enabled
      value: "true"

# Store credentials in Kubernetes Secret
apiVersion: v1
kind: Secret
metadata:
  name: elasticsearch-credentials
type: Opaque
data:
  username: ZWxhc3RpYw==  # base64 encoded
  password: <generated-password>

# Update application to use credentials
env:
  - name: ELASTICSEARCH_USER
    valueFrom:
      secretKeyRef:
        name: elasticsearch-credentials
        key: username
  - name: ELASTICSEARCH_PASSWORD
    valueFrom:
      secretKeyRef:
        name: elasticsearch-credentials
        key: password
```

#### TLS/SSL for API
```yaml
# Enable TLS in Ingress
ingress:
  enabled: true
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
  tls:
    - secretName: city-api-tls
      hosts:
        - api.citydata.com

# Install cert-manager for automatic certificate management
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
```

#### API Authentication
```python
# Add API key authentication
from fastapi.security import APIKeyHeader
from fastapi import Security, HTTPException

api_key_header = APIKeyHeader(name="X-API-Key")

async def verify_api_key(api_key: str = Security(api_key_header)):
    # Verify against database or secret manager
    if api_key not in valid_api_keys:
        raise HTTPException(status_code=403, detail="Invalid API key")
    return api_key

# Protect endpoints
@app.post("/city")
async def upsert_city(
    city_data: CityPopulation,
    api_key: str = Security(verify_api_key)
):
    # Implementation
```

#### Runtime Security
```yaml
# Use Pod Security Standards
apiVersion: v1
kind: Namespace
metadata:
  name: city-population
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted

# Scan images for vulnerabilities with Trivy
trivy image city-population-api:1.0.0

# Implement admission controller (OPA Gatekeeper or Kyverno)
# to enforce security policies
```

---

### 4. Performance Optimization

#### Application Layer
```python
# Enable connection pooling
self.client = AsyncElasticsearch(
    hosts=[self.hosts],
    max_retries=3,
    retry_on_timeout=True,
    # Connection pool settings
    maxsize=25,  # Maximum connections
    timeout=30
)

# Implement caching for frequently accessed data
from fastapi_cache import FastAPICache
from fastapi_cache.backends.redis import RedisBackend
from fastapi_cache.decorator import cache

@cache(expire=300)  # Cache for 5 minutes
async def get_city_population(city_name: str):
    # Implementation
```

#### Database Optimization
```yaml
# Tune Elasticsearch for production
elasticsearch:
  env:
    - name: ES_JAVA_OPTS
      value: "-Xms2g -Xmx2g"  # Set heap to 50% of container memory

  # Use faster storage class
  persistence:
    storageClass: "ssd"  # or "gp3" on AWS
    size: 50Gi

# Enable index lifecycle management for large datasets
PUT _ilm/policy/cities_policy
{
  "policy": {
    "phases": {
      "hot": {
        "actions": {
          "rollover": {
            "max_size": "50GB",
            "max_age": "30d"
          }
        }
      },
      "warm": {
        "min_age": "30d",
        "actions": {
          "shrink": {
            "number_of_shards": 1
          }
        }
      }
    }
  }
}
```

#### Kubernetes Resource Optimization
```yaml
# Right-size resource requests and limits
app:
  resources:
    requests:
      memory: "256Mi"
      cpu: "200m"
    limits:
      memory: "512Mi"
      cpu: "1000m"

# Enable Horizontal Pod Autoscaling
autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 20
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80

# Implement Vertical Pod Autoscaler for optimal resource allocation
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: city-population-api-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: city-population-api
  updatePolicy:
    updateMode: "Auto"
```

---

### 5. Disaster Recovery and Business Continuity

#### Backup Strategy
```yaml
# Automated Elasticsearch snapshots
apiVersion: batch/v1
kind: CronJob
metadata:
  name: elasticsearch-snapshot
spec:
  schedule: "0 */6 * * *"  # Every 6 hours
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: snapshot
            image: curlimages/curl
            command: ["/bin/sh", "-c"]
            args:
              - |
                curl -X PUT "elasticsearch:9200/_snapshot/s3_repository/snapshot_$(date +%Y%m%d_%H%M%S)" \
                  -H 'Content-Type: application/json' \
                  -d '{"indices": "cities", "ignore_unavailable": true, "include_global_state": false}'
          restartPolicy: OnFailure

# Retention policy: Keep daily for 7 days, weekly for 4 weeks
```

#### Multi-Region Deployment
```yaml
# Deploy to multiple Kubernetes clusters in different regions
# Use cross-region replication for Elasticsearch

# Global load balancer (e.g., AWS Route53, GCP Cloud Load Balancing)
# to distribute traffic across regions

# Example with Elasticsearch CCR (Cross-Cluster Replication)
PUT /cities/_ccr/follow
{
  "remote_cluster": "cluster-us-west",
  "leader_index": "cities"
}
---

## Summary

This implementation provides a solid foundation for a production-grade city population management API. The suggestions above address critical production concerns:

1. **Reliability**: HA setup, health checks, graceful degradation
2. **Security**: Network policies, TLS, authentication, vulnerability scanning
3. **Observability**: Comprehensive monitoring, logging, tracing, alerting
4. **Performance**: Caching, connection pooling, auto-scaling, resource optimization
5. **Resilience**: Backup/restore, multi-region deployment, chaos testing
6. **Automation**: CI/CD pipelines, automated testing, infrastructure as code

Implementing these recommendations will ensure the application is ready for production workloads with enterprise-grade reliability, security, and performance.

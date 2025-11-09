# Scalability and Reliability Considerations

## Overview

This document outlines the strategies, patterns, and best practices to ensure the e-commerce platform can scale to handle millions of users while maintaining high availability and reliability.

---

## 1. Scalability Strategy

### Horizontal vs Vertical Scaling

| Aspect | Horizontal Scaling | Vertical Scaling |
|--------|-------------------|------------------|
| **Approach** | Add more servers | Increase server capacity |
| **Cost** | More cost-effective long-term | Expensive, hardware limits |
| **Availability** | Higher (distributed) | Single point of failure |
| **Implementation** | Our primary strategy | Used for databases initially |

### Auto-Scaling Configuration

#### Application Services

```yaml
# Kubernetes HPA (Horizontal Pod Autoscaler)
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: product-service-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: product-service
  minReplicas: 3
  maxReplicas: 50
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
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 100
        periodSeconds: 30
```

**Scaling Triggers**:
- CPU utilization > 70%
- Memory utilization > 80%
- Request queue length > 100
- Response time > 500ms (p95)

#### Database Scaling

**PostgreSQL**:
```
Master (Write): 1 instance (vertical scaling initially)
Read Replicas: 3+ instances (horizontal scaling)
Connection Pooling: PgBouncer (max 1000 connections per replica)
```

**MongoDB**:
```
Sharding Strategy: Hash-based on product_id
Replica Sets: 3 nodes per shard (1 primary, 2 secondaries)
Minimum Shards: 3
Maximum Shards: Dynamic based on data size
```

**Redis**:
```
Cluster Mode: Enabled
Nodes: 6 (3 masters, 3 replicas)
Auto-failover: Enabled
Memory per node: 64GB
Eviction policy: allkeys-lru
```

---

## 2. Load Balancing

### Multi-Layer Load Balancing

```
┌─────────────────────────────────────────────┐
│     Global Load Balancer (CloudFlare)       │
│            (DNS-based routing)              │
└─────────────────────────────────────────────┘
                    │
        ┌───────────┴───────────┐
        ▼                       ▼
┌──────────────┐        ┌──────────────┐
│  Region US   │        │  Region EU   │
│   (Primary)  │        │  (Replica)   │
└──────────────┘        └──────────────┘
        │
        ▼
┌─────────────────────────────────────────────┐
│    Application Load Balancer (ALB/NGINX)    │
│         (Layer 7 - Application)             │
└─────────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────────┐
│         Kubernetes Service (ClusterIP)      │
│         (Layer 4 - Transport)               │
└─────────────────────────────────────────────┘
        │
        ▼
   [Pod 1] [Pod 2] [Pod 3] ... [Pod N]
```

### Load Balancing Algorithms

| Service | Algorithm | Reason |
|---------|-----------|--------|
| API Gateway | Least Connections | Distributes long-running requests |
| Product Service | Round Robin | Stateless, uniform requests |
| Search Service | Weighted Round Robin | Different node capacities |
| Order Service | IP Hash | Session affinity for cart |

### Health Checks

```yaml
# Kubernetes Liveness & Readiness Probes
livenessProbe:
  httpGet:
    path: /health/live
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /health/ready
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 5
  timeoutSeconds: 3
  successThreshold: 1
  failureThreshold: 3
```

**Health Check Endpoints**:
- `/health/live`: Is the service running?
- `/health/ready`: Can the service handle requests?
- `/health/metrics`: Prometheus metrics

---

## 3. Caching Strategy

### Multi-Layer Caching

```
┌─────────────────────────────────────────────┐
│        CDN (CloudFlare) - Edge Cache         │
│   Static Assets, Product Images (1 day TTL) │
└─────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────┐
│       Redis Cluster - Application Cache      │
│   Session, Cart, Product (5-30 min TTL)     │
└─────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────┐
│      Application In-Memory Cache (Local)     │
│   Configuration, Static Data (5 min TTL)    │
└─────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────┐
│          Database Query Cache                │
│       (Query results cached by DB)           │
└─────────────────────────────────────────────┘
```

### Caching Patterns

#### 1. Cache-Aside (Lazy Loading)

```go
func GetProduct(productID string) (*Product, error) {
    // Try cache first
    cachedProduct, err := redis.Get(ctx, "product:"+productID)
    if err == nil {
        return cachedProduct, nil
    }
    
    // Cache miss - fetch from database
    product, err := db.GetProduct(productID)
    if err != nil {
        return nil, err
    }
    
    // Store in cache
    redis.Set(ctx, "product:"+productID, product, 30*time.Minute)
    
    return product, nil
}
```

#### 2. Write-Through Cache

```go
func UpdateProduct(product *Product) error {
    // Update database
    err := db.UpdateProduct(product)
    if err != nil {
        return err
    }
    
    // Update cache
    redis.Set(ctx, "product:"+product.ID, product, 30*time.Minute)
    
    return nil
}
```

#### 3. Write-Behind (Write-Back) Cache

```go
func AddToCart(userID, productID string, quantity int) error {
    // Write to cache immediately
    cart := getCartFromCache(userID)
    cart.AddItem(productID, quantity)
    redis.Set(ctx, "cart:"+userID, cart, 7*24*time.Hour)
    
    // Async write to database (via message queue)
    kafka.Publish("cart.updates", CartUpdateEvent{
        UserID: userID,
        Cart: cart,
    })
    
    return nil
}
```

### Cache Invalidation Strategies

#### Time-Based (TTL)
```
Product catalog: 30 minutes
User session: 1 hour
Cart: 7 days
Static assets: 1 year (with versioned URLs)
```

#### Event-Based
```go
// When product is updated
func OnProductUpdated(product *Product) {
    // Invalidate cache
    redis.Delete(ctx, "product:"+product.ID)
    redis.Delete(ctx, "product:search:*") // Clear search results
    
    // Publish event for search index update
    kafka.Publish("product.updated", product)
}
```

#### Manual Invalidation
```
Admin trigger: Flush specific cache keys
API endpoint: POST /api/v1/admin/cache/invalidate
```

### Cache Key Naming Convention

```
Entity:Identifier:SubResource
Examples:
  - product:prod_123
  - user:user_uuid:profile
  - cart:session_abc123
  - search:query:wireless+headphones:page:1
  - inventory:prod_123:var_001
```

---

## 4. Database Optimization

### Indexing Strategy

#### PostgreSQL Indexes

```sql
-- B-tree indexes for equality and range queries
CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_orders_created_at ON orders(created_at DESC);

-- Composite indexes for common query patterns
CREATE INDEX idx_orders_user_status ON orders(user_id, status);

-- Partial indexes for filtered queries
CREATE INDEX idx_orders_pending ON orders(user_id) WHERE status = 'pending';

-- Covering indexes (include columns)
CREATE INDEX idx_products_category_cover ON products(category_id) 
    INCLUDE (name, price);

-- Full-text search
CREATE INDEX idx_products_search ON products 
    USING GIN (to_tsvector('english', name || ' ' || description));
```

#### MongoDB Indexes

```javascript
// Compound indexes
db.products.createIndex({ category_id: 1, price: 1, rating: -1 });

// Text search
db.products.createIndex({ name: "text", description: "text", tags: "text" });

// Geospatial (for store locator)
db.stores.createIndex({ location: "2dsphere" });

// TTL index (auto-delete expired documents)
db.sessions.createIndex({ "expireAt": 1 }, { expireAfterSeconds: 0 });
```

### Query Optimization

#### Use EXPLAIN ANALYZE

```sql
EXPLAIN ANALYZE
SELECT o.*, u.email
FROM orders o
JOIN users u ON o.user_id = u.id
WHERE o.status = 'pending'
  AND o.created_at > NOW() - INTERVAL '30 days'
ORDER BY o.created_at DESC
LIMIT 20;
```

**Optimization Checklist**:
- ✅ Use indexes on WHERE, JOIN, ORDER BY columns
- ✅ Avoid SELECT * (fetch only needed columns)
- ✅ Use LIMIT for pagination
- ✅ Avoid N+1 queries (use JOINs or batch loading)
- ✅ Use prepared statements
- ✅ Monitor slow query log

### Connection Pooling

```yaml
# PgBouncer configuration
[databases]
ecommerce_db = host=db.example.com port=5432 dbname=ecommerce

[pgbouncer]
pool_mode = transaction
max_client_conn = 1000
default_pool_size = 25
reserve_pool_size = 5
reserve_pool_timeout = 3
max_db_connections = 100
```

### Database Sharding

#### User-Based Sharding (Orders, Payments)

```
Shard Key: user_id (hash-based)
Shards: 4 initially (expandable to 16)

Shard 0: user_id hash % 4 == 0
Shard 1: user_id hash % 4 == 1
Shard 2: user_id hash % 4 == 2
Shard 3: user_id hash % 4 == 3
```

**Shard Router** (application layer):
```go
func GetShardForUser(userID string) int {
    hash := murmur3.Hash32([]byte(userID))
    return int(hash % NUM_SHARDS)
}

func GetOrdersByUser(userID string) ([]Order, error) {
    shard := GetShardForUser(userID)
    db := getDBConnection(shard)
    return db.Query("SELECT * FROM orders WHERE user_id = ?", userID)
}
```

#### Product-Based Sharding (Inventory)

```
Shard Key: product_id (range-based)
Shard 0: product_id < 10000000
Shard 1: 10000000 <= product_id < 20000000
Shard 2: 20000000 <= product_id < 30000000
...
```

### Read/Write Splitting

```
┌──────────────┐
│   Writer     │ ◄──── All writes (INSERT, UPDATE, DELETE)
│   (Master)   │
└──────────────┘
       │
       │ (Replication)
       │
       ├────────────┬────────────┬────────────┐
       ▼            ▼            ▼            ▼
┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐
│ Reader 1 │ │ Reader 2 │ │ Reader 3 │ │ Reader 4 │
│ (Replica)│ │ (Replica)│ │ (Replica)│ │ (Replica)│
└──────────┘ └──────────┘ └──────────┘ └──────────┘
      ▲            ▲            ▲            ▲
      │            │            │            │
      └────────────┴────────────┴────────────┘
                All reads (SELECT)
```

---

## 5. Asynchronous Processing

### Message Queue Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   Apache Kafka Cluster                   │
│                      (5 Brokers)                        │
└─────────────────────────────────────────────────────────┘
                          │
          ┌───────────────┼───────────────┐
          ▼               ▼               ▼
    ┌──────────┐   ┌──────────┐   ┌──────────┐
    │  Topic:  │   │  Topic:  │   │  Topic:  │
    │  orders  │   │inventory │   │  emails  │
    └──────────┘   └──────────┘   └──────────┘
          │               │               │
          ▼               ▼               ▼
    ┌──────────┐   ┌──────────┐   ┌──────────┐
    │Consumer  │   │Consumer  │   │Consumer  │
    │ Groups   │   │ Groups   │   │ Groups   │
    └──────────┘   └──────────┘   └──────────┘
```

### Event-Driven Patterns

#### 1. Event Sourcing (Inventory)

```go
type InventoryEvent struct {
    EventID      string    `json:"event_id"`
    EventType    string    `json:"event_type"` // added, removed, reserved
    ProductID    string    `json:"product_id"`
    Quantity     int       `json:"quantity"`
    Timestamp    time.Time `json:"timestamp"`
    Metadata     map[string]interface{}
}

// All inventory changes are events
func RecordInventoryEvent(event InventoryEvent) {
    // Store event
    db.SaveEvent(event)
    
    // Update current state
    inventory := getCurrentInventory(event.ProductID)
    inventory.ApplyEvent(event)
    db.UpdateInventory(inventory)
    
    // Publish for downstream consumers
    kafka.Publish("inventory.events", event)
}
```

#### 2. CQRS (Command Query Responsibility Segregation)

```
┌────────────┐                    ┌────────────┐
│  Commands  │                    │  Queries   │
│  (Writes)  │                    │  (Reads)   │
└────────────┘                    └────────────┘
      │                                  │
      ▼                                  ▼
┌────────────┐                    ┌────────────┐
│  Write DB  │───Event Stream────▶│  Read DB   │
│(PostgreSQL)│                    │  (MongoDB/ │
│            │                    │ ElasticSearch)
└────────────┘                    └────────────┘
```

### Background Job Processing

#### Job Queue (BullMQ with Redis)

```typescript
// Producer
import { Queue } from 'bullmq';

const emailQueue = new Queue('email', {
  connection: redisConnection,
  defaultJobOptions: {
    attempts: 3,
    backoff: {
      type: 'exponential',
      delay: 2000,
    },
    removeOnComplete: 100,
    removeOnFail: 1000,
  },
});

// Add job
await emailQueue.add('order-confirmation', {
  to: 'user@example.com',
  orderId: 'order_123',
  template: 'order-confirmation',
});

// Consumer
import { Worker } from 'bullmq';

const worker = new Worker('email', async (job) => {
  const { to, orderId, template } = job.data;
  await sendEmail(to, template, { orderId });
}, {
  connection: redisConnection,
  concurrency: 10,
});
```

**Job Types**:
- Email notifications (high priority)
- SMS notifications (high priority)
- Image processing (medium priority)
- Report generation (low priority)
- Data analytics (low priority)
- Search index updates (medium priority)

---

## 6. Fault Tolerance & Resilience

### Circuit Breaker Pattern

```go
import "github.com/sony/gobreaker"

var cb *gobreaker.CircuitBreaker

func init() {
    settings := gobreaker.Settings{
        Name:        "PaymentService",
        MaxRequests: 3,  // Half-open state: max requests to test
        Interval:    60 * time.Second,  // Window to count failures
        Timeout:     30 * time.Second,  // Open → Half-Open timeout
        ReadyToTrip: func(counts gobreaker.Counts) bool {
            failureRatio := float64(counts.TotalFailures) / float64(counts.Requests)
            return counts.Requests >= 10 && failureRatio >= 0.5
        },
        OnStateChange: func(name string, from, to gobreaker.State) {
            log.Printf("Circuit breaker %s: %s → %s", name, from, to)
        },
    }
    cb = gobreaker.NewCircuitBreaker(settings)
}

func ProcessPayment(order *Order) error {
    result, err := cb.Execute(func() (interface{}, error) {
        return paymentGateway.Charge(order)
    })
    
    if err != nil {
        // Circuit is open or request failed
        return handlePaymentFailure(order, err)
    }
    
    return handlePaymentSuccess(order, result)
}
```

**Circuit States**:
1. **Closed**: Normal operation
2. **Open**: Failing, reject requests immediately
3. **Half-Open**: Test if service recovered

### Retry Strategy

```go
import "github.com/avast/retry-go"

func CallExternalAPI() error {
    return retry.Do(
        func() error {
            return externalAPI.Call()
        },
        retry.Attempts(3),
        retry.Delay(1*time.Second),
        retry.DelayType(retry.BackOffDelay),
        retry.OnRetry(func(n uint, err error) {
            log.Printf("Retry attempt %d: %v", n, err)
        }),
    )
}
```

**Retry Policy**:
- Exponential backoff: 1s, 2s, 4s, 8s
- Max attempts: 3-5
- Jitter: Add randomness to avoid thundering herd
- Idempotency: Ensure operations are safe to retry

### Timeout Management

```go
ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
defer cancel()

result, err := db.QueryContext(ctx, "SELECT * FROM products WHERE id = ?", id)
if err != nil {
    if err == context.DeadlineExceeded {
        return errors.New("database query timeout")
    }
    return err
}
```

**Timeout Guidelines**:
| Operation | Timeout |
|-----------|---------|
| Database query | 5s |
| API call (internal) | 10s |
| API call (external) | 30s |
| Payment processing | 60s |
| File upload | 120s |

### Bulkhead Pattern

Isolate resources to prevent cascading failures.

```go
// Separate connection pools per service
var (
    userServicePool     *sql.DB  // Max 50 connections
    productServicePool  *sql.DB  // Max 100 connections
    orderServicePool    *sql.DB  // Max 200 connections
)

// Separate goroutine pools
var (
    emailWorkerPool = workerpool.New(10)
    imageWorkerPool = workerpool.New(5)
    analyticsPool   = workerpool.New(20)
)
```

---

## 7. High Availability

### Multi-Region Deployment

```
┌─────────────────────────────────────────────────────────────┐
│                   Global Load Balancer                       │
│              (Route 53 / CloudFlare)                        │
└─────────────────────────────────────────────────────────────┘
                          │
              ┌───────────┴───────────┐
              ▼                       ▼
┌──────────────────────┐    ┌──────────────────────┐
│   US-EAST-1 (Primary)│    │   EU-WEST-1 (Replica)│
│   - All services     │    │   - Read-only        │
│   - Master DB        │    │   - Read replica DB  │
│   - Active-Active    │    │   - Failover ready   │
└──────────────────────┘    └──────────────────────┘
              │                       │
              ▼                       ▼
┌──────────────────────┐    ┌──────────────────────┐
│  US-WEST-2 (Standby) │    │  AP-SOUTH-1 (Standby)│
│   - Read-only        │    │   - Read-only        │
│   - Read replica DB  │    │   - Read replica DB  │
│   - Failover ready   │    │   - Failover ready   │
└──────────────────────┘    └──────────────────────┘
```

### Database Replication

#### PostgreSQL Streaming Replication

```
Master (Read-Write)
  │
  ├─► Replica 1 (Read-Only) - Same AZ
  ├─► Replica 2 (Read-Only) - Different AZ
  └─► Replica 3 (Read-Only) - Different Region
```

**Failover Strategy**:
1. Automated failover using Patroni
2. Promotion time: < 30 seconds
3. Synchronous replication for critical data
4. Asynchronous for read replicas

### Service Redundancy

```yaml
# Kubernetes deployment with pod anti-affinity
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-service
spec:
  replicas: 6
  selector:
    matchLabels:
      app: order-service
  template:
    metadata:
      labels:
        app: order-service
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - order-service
            topologyKey: kubernetes.io/hostname
      containers:
      - name: order-service
        image: order-service:latest
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
```

### Disaster Recovery

#### Backup Strategy

| Data Type | Backup Frequency | Retention | Location |
|-----------|-----------------|-----------|----------|
| Database (PostgreSQL) | Continuous WAL + Daily | 30 days | S3 (multi-region) |
| Database (MongoDB) | Hourly | 7 days | S3 (multi-region) |
| Redis | Hourly RDB | 3 days | S3 |
| File Storage | Daily | 90 days | S3 (IA after 30 days) |
| Configuration | On change | Forever | Git + S3 |

#### Recovery Procedures

**RTO (Recovery Time Objective)**: 1 hour
**RPO (Recovery Point Objective)**: 5 minutes

**Recovery Steps**:
1. Activate standby region
2. Promote read replica to master
3. Update DNS records
4. Restore from latest backup (if needed)
5. Verify data integrity
6. Resume traffic

---

## 8. Monitoring & Observability

### Metrics Collection

```yaml
# Prometheus configuration
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'kubernetes-pods'
    kubernetes_sd_configs:
    - role: pod
    relabel_configs:
    - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
      action: keep
      regex: true
    - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
      action: replace
      target_label: __metrics_path__
      regex: (.+)
```

### Key Metrics

#### Golden Signals

1. **Latency**: Time to service a request
   ```promql
   histogram_quantile(0.95, 
     rate(http_request_duration_seconds_bucket[5m])
   )
   ```

2. **Traffic**: Requests per second
   ```promql
   rate(http_requests_total[5m])
   ```

3. **Errors**: Failed requests
   ```promql
   rate(http_requests_total{status=~"5.."}[5m])
   ```

4. **Saturation**: Resource utilization
   ```promql
   100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
   ```

#### Business Metrics

- Orders per minute
- Revenue per hour
- Cart abandonment rate
- Checkout conversion rate
- Average order value
- Product views
- Search queries

### Distributed Tracing

```go
import (
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/trace"
)

func ProcessOrder(ctx context.Context, order *Order) error {
    tracer := otel.Tracer("order-service")
    ctx, span := tracer.Start(ctx, "ProcessOrder")
    defer span.End()
    
    // Validate order
    ctx, validateSpan := tracer.Start(ctx, "ValidateOrder")
    err := validateOrder(order)
    validateSpan.End()
    if err != nil {
        span.RecordError(err)
        return err
    }
    
    // Process payment
    ctx, paymentSpan := tracer.Start(ctx, "ProcessPayment")
    err = processPayment(ctx, order)
    paymentSpan.End()
    if err != nil {
        span.RecordError(err)
        return err
    }
    
    return nil
}
```

### Alerting Rules

```yaml
# Prometheus alert rules
groups:
  - name: ecommerce_alerts
    rules:
    - alert: HighErrorRate
      expr: |
        rate(http_requests_total{status=~"5.."}[5m]) > 0.05
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "High error rate detected"
        description: "Error rate is {{ $value }} (> 5%)"
    
    - alert: HighLatency
      expr: |
        histogram_quantile(0.95, 
          rate(http_request_duration_seconds_bucket[5m])
        ) > 1
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High latency detected"
        description: "P95 latency is {{ $value }}s (> 1s)"
    
    - alert: DatabaseConnectionPoolExhausted
      expr: |
        db_connections_active / db_connections_max > 0.9
      for: 2m
      labels:
        severity: critical
      annotations:
        summary: "Database connection pool exhausted"
        description: "{{ $value }}% connections in use"
```

### Logging Strategy

```json
{
  "timestamp": "2025-01-20T15:45:00.123Z",
  "level": "INFO",
  "service": "order-service",
  "trace_id": "abc123def456",
  "span_id": "span789",
  "user_id": "user_uuid",
  "request_id": "req_xyz",
  "method": "POST",
  "path": "/api/v1/orders",
  "status": 201,
  "latency_ms": 234,
  "message": "Order created successfully",
  "metadata": {
    "order_id": "order_uuid",
    "total": 174.38
  }
}
```

**Log Levels**:
- **DEBUG**: Development only
- **INFO**: Normal operations
- **WARN**: Recoverable errors, degraded performance
- **ERROR**: Errors requiring attention
- **FATAL**: System crashes

---

## 9. Security Hardening

### Defense in Depth

```
┌─────────────────────────────────────────────────┐
│  Layer 1: Network Security                      │
│  - VPC, Subnets, Security Groups                │
│  - WAF, DDoS Protection                         │
└─────────────────────────────────────────────────┘
                    │
┌─────────────────────────────────────────────────┐
│  Layer 2: API Gateway Security                  │
│  - Rate Limiting, Authentication                │
│  - Request Validation, CORS                     │
└─────────────────────────────────────────────────┘
                    │
┌─────────────────────────────────────────────────┐
│  Layer 3: Application Security                  │
│  - Input Validation, Output Encoding            │
│  - Authorization, Session Management            │
└─────────────────────────────────────────────────┘
                    │
┌─────────────────────────────────────────────────┐
│  Layer 4: Data Security                         │
│  - Encryption at Rest and in Transit            │
│  - Data Masking, Tokenization                   │
└─────────────────────────────────────────────────┘
```

### Rate Limiting

```go
import "golang.org/x/time/rate"

// Per-user rate limiter
var userLimiters = make(map[string]*rate.Limiter)

func getUserLimiter(userID string) *rate.Limiter {
    if limiter, exists := userLimiters[userID]; exists {
        return limiter
    }
    
    // 100 requests per minute, burst of 20
    limiter := rate.NewLimiter(rate.Limit(100.0/60.0), 20)
    userLimiters[userID] = limiter
    return limiter
}

func RateLimitMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        userID := getUserIDFromToken(r)
        limiter := getUserLimiter(userID)
        
        if !limiter.Allow() {
            http.Error(w, "Rate limit exceeded", http.StatusTooManyRequests)
            return
        }
        
        next.ServeHTTP(w, r)
    })
}
```

### Data Encryption

**At Rest**:
- Database: AES-256 encryption
- File storage: S3 server-side encryption (SSE-S3 or SSE-KMS)
- Backups: Encrypted before upload

**In Transit**:
- TLS 1.3 for all communications
- Certificate pinning for mobile apps
- Mutual TLS (mTLS) between services

---

## 10. Performance Optimization

### Performance Budget

| Metric | Target | Maximum |
|--------|--------|---------|
| API Response Time (p95) | < 200ms | < 500ms |
| Database Query Time (p95) | < 50ms | < 100ms |
| Page Load Time (FCP) | < 1.5s | < 3s |
| Time to Interactive (TTI) | < 3s | < 5s |
| Search Results | < 200ms | < 500ms |

### CDN Configuration

```nginx
# CloudFlare cache rules
location ~* \.(jpg|jpeg|png|gif|webp|svg|ico)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
}

location ~* \.(css|js)$ {
    expires 30d;
    add_header Cache-Control "public";
}

location /api/ {
    # No caching for API
    add_header Cache-Control "no-store, no-cache, must-revalidate";
}
```

### Image Optimization

```
Original Upload → Optimize → Generate Variants → Store → Serve via CDN

Variants:
- Thumbnail: 150x150
- Small: 300x300
- Medium: 800x800
- Large: 1200x1200

Formats:
- WebP (modern browsers)
- JPEG (fallback)

Optimization:
- Compression: 80% quality
- Lazy loading
- Responsive images (srcset)
```

---

## 11. Cost Optimization

### Resource Right-Sizing

```bash
# Analyze actual usage
kubectl top nodes
kubectl top pods

# Adjust resources based on actual usage
# CPU: Request = avg usage, Limit = 2x avg
# Memory: Request = avg usage, Limit = 1.5x avg
```

### Auto-Scaling Policy

```
Scale Out:
- CPU > 70% for 2 minutes
- Memory > 80% for 2 minutes
- Queue length > 100

Scale In:
- CPU < 30% for 10 minutes
- Memory < 40% for 10 minutes
- Minimum replicas maintained
```

### Cost Monitoring

```
Daily Cost Dashboard:
- Compute: $XX/day
- Database: $XX/day
- Storage: $XX/day
- Data Transfer: $XX/day
- Total: $XX/day

Alerts:
- Daily cost > $200
- Month-to-date > budget
- Unusual spending patterns
```

---

## 12. Capacity Planning

### Current Capacity (10k concurrent users)

| Resource | Current | Utilization | Headroom |
|----------|---------|-------------|----------|
| API Gateway | 20 instances | 40% | 60% |
| Services | 50 pods | 50% | 50% |
| Database Connections | 500 | 60% | 40% |
| Redis Memory | 64GB | 55% | 45% |
| Kafka Throughput | 10k msg/s | 30% | 70% |

### Growth Projections

| Users | Services | Database | Redis | Estimated Cost |
|-------|----------|----------|-------|----------------|
| 10k | 50 pods | 1 master + 3 replicas | 64GB x 3 | $5,700/month |
| 50k | 150 pods | 2 masters + 6 replicas | 128GB x 6 | $18,000/month |
| 100k | 300 pods | 4 masters + 12 replicas | 256GB x 9 | $35,000/month |

---

## 13. Testing Strategy

### Load Testing

```javascript
// k6 load test script
import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  stages: [
    { duration: '2m', target: 100 },   // Ramp up
    { duration: '5m', target: 100 },   // Stay at 100 users
    { duration: '2m', target: 1000 },  // Spike
    { duration: '5m', target: 1000 },  // Stay at 1000
    { duration: '2m', target: 0 },     // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'], // 95% of requests < 500ms
    http_req_failed: ['rate<0.01'],   // Error rate < 1%
  },
};

export default function () {
  let response = http.get('https://api.example.com/products');
  check(response, {
    'status is 200': (r) => r.status === 200,
    'response time < 500ms': (r) => r.timings.duration < 500,
  });
  sleep(1);
}
```

### Chaos Engineering

```yaml
# Chaos Mesh experiment
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  name: pod-failure
spec:
  action: pod-failure
  mode: one
  selector:
    namespaces:
      - production
    labelSelectors:
      'app': 'order-service'
  duration: '30s'
  scheduler:
    cron: '@every 1h'
```

**Chaos Experiments**:
- Random pod failures
- Network latency injection
- Database connection drops
- Disk I/O throttling
- CPU stress

---

## Summary

### Key Scalability Features

✅ Horizontal auto-scaling for all services  
✅ Multi-layer caching (CDN, Redis, application)  
✅ Database sharding and read replicas  
✅ Asynchronous processing with message queues  
✅ CDN for static content delivery  

### Key Reliability Features

✅ Multi-region deployment  
✅ Circuit breakers and retries  
✅ Comprehensive monitoring and alerting  
✅ Automated failover and disaster recovery  
✅ 99.9% uptime SLA target  

### Performance Targets

- API Response: < 200ms (p95)
- Page Load: < 3s
- Search: < 500ms
- Availability: 99.9%
- Error Rate: < 0.1%

This architecture is designed to scale from 10k to 1M+ concurrent users with minimal changes to the core design.


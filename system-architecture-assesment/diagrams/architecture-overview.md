# Architecture Visual Overview

This document provides visual representations of the e-commerce platform architecture from different perspectives.

---

## 1. System Context Diagram (C4 Level 1)

```
┌──────────────────────────────────────────────────────────────────────┐
│                                                                      │
│                         E-Commerce Platform                          │
│                                                                      │
│   "A scalable e-commerce platform supporting 10k+ concurrent users"  │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
         ▲                  ▲                  ▲                  ▲
         │                  │                  │                  │
         │                  │                  │                  │
    ┌────────┐         ┌────────┐         ┌────────┐         ┌────────┐
    │Customer│         │ Admin  │         │ Vendor │         │ Support│
    │ User   │         │  User  │         │  User  │         │ Staff  │
    └────────┘         └────────┘         └────────┘         └────────┘
         │                  │                  │                  │
         │                  │                  │                  │
         ▼                  ▼                  ▼                  ▼
┌──────────────────────────────────────────────────────────────────────┐
│                     E-Commerce System                                │
│                                                                      │
│  - Browse & Search Products                                          │
│  - Manage Shopping Cart                                              │
│  - Place & Track Orders                                              │
│  - Process Payments                                                  │
│  - Write & Read Reviews                                              │
│  - Manage Inventory (Admin/Vendor)                                   │
└──────────────────────────────────────────────────────────────────────┘
         │                      │                       │
         │                      │                       │
         ▼                      ▼                       ▼
    ┌────────┐            ┌───────────┐            ┌─────────┐
    │Payment │            │   Email   │            │  SMS    │
    │Gateway │            │  Service  │            │ Service │
    │(Stripe)│            │(SendGrid) │            │(Twilio) │
    └────────┘            └───────────┘            └─────────┘
```

---

## 2. Container Diagram (C4 Level 2)

```
┌─────────────────────────────────────────────────────────────────────┐
│                          FRONTEND LAYER                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐              │
│  │   Web App   │    │ Mobile App  │    │Admin Panel  │              │
│  │  (Next.js)  │    │  (Flutter)  │    │  (React)    │              │
│  └─────────────┘    └─────────────┘    └─────────────┘              │
│         │                   │                   │                   │
└─────────┼───────────────────┼───────────────────┼───────────────────┘
          │                   │                   │
          └───────────────────┴───────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                       API GATEWAY LAYER                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│                  ┌─────────────────────────┐                        │
│                  │     API Gateway (Kong)  │                        │
│                  │  - Authentication       │                        │
│                  │  - Rate Limiting        │                        │
│                  │  - Routing              │                        │
│                  └─────────────────────────┘                        │
│                              │                                      │
└──────────────────────────────┼──────────────────────────────────────┘
                               │
                               │
       ┌───────────────────────┼───────────────────────┐
       │                       │                       │
       ▼                       ▼                       ▼
┌───────────────────────────────────────────────────────────────────┐
│                    MICROSERVICES LAYER                            │
├───────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐   │
│  │   User     │  │  Product   │  │ Inventory  │  │   Order    │   │
│  │  Service   │  │  Service   │  │  Service   │  │  Service   │   │
│  │ (Node.js)  │  │  (Java)    │  │   (Go)     │  │   (Go)     │   │
│  └────────────┘  └────────────┘  └────────────┘  └────────────┘   │
│        │               │                │               │         │
│        │               │                │               │         │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐   │
│  │  Payment   │  │   Search   │  │Notification│  │   Review   │   │
│  │  Service   │  │  Service   │  │  Service   │  │  Service   │   │
│  │   (Go)     │  │(Elastic)   │  │ (Node.js)  │  │ (Node.js)  │   │
│  └────────────┘  └────────────┘  └────────────┘  └────────────┘   │
│        │               │                │               │         │
│        │               │                │               │         │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐                   │
│  │Recommend   │  │ Analytics  │  │   Cart     │                   │
│  │  Service   │  │  Service   │  │  Service   │                   │
│  │  (Python)  │  │  (Python)  │  │ (Node.js)  │                   │
│  └────────────┘  └────────────┘  └────────────┘                   │
│                                                                   │
└───────────────────────────────┬───────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      MESSAGE QUEUE LAYER                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│                    ┌───────────────────────┐                        │
│                    │    Apache Kafka       │                        │
│                    │   (Event Streaming)   │                        │
│                    └───────────────────────┘                        │
│                                                                     │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         DATA LAYER                                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌─────────────┐    │
│  │PostgreSQL  │  │  MongoDB   │  │   Redis    │  │Elasticsearch│    │
│  │(Relational)│  │(Documents) │  │  (Cache)   │  │  (Search)   │    │
│  └────────────┘  └────────────┘  └────────────┘  └─────────────┘    │
│                                                                     │
│  ┌────────────┐  ┌────────────┐                                     │
│  │     S3     │  │ Cassandra  │                                     │
│  │ (Storage)  │  │(Time Series)                                     │
│  └────────────┘  └────────────┘                                     │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 3. Request Flow Diagrams

### 3.1 Browse Products

```
┌────────┐
│ Client │
└────┬───┘
     │
     │ 1. GET /api/v1/products?category=electronics
     ▼
┌──────────────┐
│ API Gateway  │
└──────┬───────┘
       │ 2. Route to Product Service
       ▼
┌──────────────┐
│   Product    │
│   Service    │──────┐
└──────┬───────┘      │ 3. Check Redis Cache
       │              ▼
       │         ┌─────────┐
       │         │  Redis  │ Cache Hit? Return
       │         └─────────┘
       │              │ Cache Miss
       │              ▼
       │         ┌─────────┐
       │         │ MongoDB │ 4. Fetch from DB
       │         └────┬────┘
       │              │
       │◄─────────────┘ 5. Store in cache
       │
       │ 6. Return products
       ▼
┌────────┐
│ Client │
└────────┘
```

### 3.2 Search Products

```
┌────────┐
│ Client │
└────┬───┘
     │ 1. GET /api/v1/products/search?q=headphones
     ▼
┌──────────────┐
│ API Gateway  │
└──────┬───────┘
       │ 2. Route to Search Service
       ▼
┌──────────────┐
│    Search    │
│   Service    │
└──────┬───────┘
       │ 3. Query Elasticsearch
       ▼
┌──────────────┐
│Elasticsearch │
│    Index     │
└──────┬───────┘
       │ 4. Return results with facets
       ▼
┌──────────────┐
│    Search    │──────► Log query for analytics
│   Service    │
└──────┬───────┘
       │ 5. Return search results
       ▼
┌────────┐
│ Client │
└────────┘
```

### 3.3 Place Order (Saga Pattern)

```
┌────────┐
│ Client │
└────┬───┘
     │ 1. POST /api/v1/orders
     ▼
┌──────────────┐
│ API Gateway  │
└──────┬───────┘
       │ 2. Route to Order Service
       ▼
┌──────────────┐
│    Order     │
│   Service    │
└──────┬───────┘
       │
       │ 3. Begin Saga Transaction
       │
       ├──► Step 1: Reserve Inventory ──┐
       │                                 │
       │         ┌──────────────┐        │
       │         │  Inventory   │        │
       │         │   Service    │        │
       │         └──────┬───────┘        │
       │                │                │
       │◄───────────────┘ Success        │
       │                                 │
       ├──► Step 2: Process Payment ─────┤
       │                                 │
       │         ┌──────────────┐        │
       │         │   Payment    │        │
       │         │   Service    │        │
       │         └──────┬───────┘        │
       │                │                │
       │◄───────────────┘ Success        │
       │                                 │
       ├──► Step 3: Create Order ────────┤
       │         (Save to DB)            │
       │                                 │
       ├──► Step 4: Send Events ─────────┤
       │         (Kafka)                 │
       │                                 │
       │         ┌──────────────┐        │
       │         │    Kafka     │        │
       │         └──────┬───────┘        │
       │                │                │
       │                ├──► Notification Service
       │                ├──► Analytics Service
       │                └──► Email Service
       │
       │ 5. Return order confirmation
       ▼
┌────────┐
│ Client │
└────────┘

If any step fails:
  - Compensating transactions
  - Release inventory reservation
  - Refund payment (if charged)
  - Mark order as failed
```

### 3.4 Real-time Inventory Update

```
┌──────────────┐
│   Admin      │
│   Updates    │
│  Inventory   │
└──────┬───────┘
       │ 1. POST /api/v1/inventory/update
       ▼
┌──────────────┐
│  Inventory   │
│   Service    │
└──────┬───────┘
       │ 2. Update PostgreSQL
       │    (Event Sourcing)
       ▼
┌──────────────┐
│  PostgreSQL  │
│   (Master)   │
└──────┬───────┘
       │ 3. Publish Event
       ▼
┌──────────────┐
│    Kafka     │
│inventory.    │
│  updated     │
└──────┬───────┘
       │
       ├──► 4a. Search Service ────► Update Elasticsearch
       │                              (product availability)
       │
       ├──► 4b. Product Service ───► Update Cache
       │                              (invalidate product cache)
       │
       ├──► 4c. Notification ──────► Send low stock alerts
       │        Service               (if threshold reached)
       │
       └──► 4d. Analytics ─────────► Log inventory event
                Service                (for reporting)
```

---

## 4. Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                      USER INTERACTIONS                              │
└─────────────────────────────────────────────────────────────────────┘
       │           │           │           │           │
       │ Browse    │ Search    │ Add to    │ Place     │ Track
       │ Products  │ Products  │  Cart     │ Order     │ Order
       │           │           │           │           │
       ▼           ▼           ▼           ▼           ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         API GATEWAY                                 │
│                    (Authentication & Routing)                       │
└─────────────────────────────────────────────────────────────────────┘
       │           │           │           │           │
       ▼           ▼           ▼           ▼           ▼
┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐
│ Product  │ │  Search  │ │   Cart   │ │  Order   │ │  Order   │
│ Service  │ │ Service  │ │ Service  │ │ Service  │ │ Service  │
└────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘
     │            │            │            │            │
     │            │            │            │            │
     ▼            ▼            ▼            ▼            ▼
┌─────────┐ ┌──────────┐  ┌─────────┐  ┌──────────┐  ┌──────────┐
│ MongoDB │ │  Elastic │  │  Redis  │  │PostgreSQL│  │PostgreSQL│
│ Products│ │  search  │  │  Cache  │  │  Orders  │  │  Orders  │
│         │ │  Index   │  │         │  │          │  │          │
└─────────┘ └──────────┘  └─────────┘  └──────────┘  └──────────┘
     │                                     │
     │                                     │
     └──────────► Kafka Events ◄───────────┘
                      │
          ┌───────────┼───────────┐
          │           │           │
          ▼           ▼           ▼
    ┌──────────┐ ┌──────────┐ ┌──────────┐
    │Analytics │ │Notification│Search    │
    │ Service  │ │ Service  │ │  Index   │
    │          │ │          │ │  Update  │
    └──────────┘ └──────────┘ └──────────┘
```

---

## 5. Deployment Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         AWS CLOUD (US-EAST-1)                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                   Availability Zone 1                         │  │
│  │                                                               │  │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌───────────────┐  │  │
│  │  │  EKS Worker     │  │  RDS Primary    │  │  ElastiCache  │  │  │
│  │  │  Nodes (5)      │  │  (PostgreSQL)   │  │  (Redis)      │  │  │
│  │  └─────────────────┘  └─────────────────┘  └───────────────┘  │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                   Availability Zone 2                         │  │
│  │                                                               │  │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌───────────────┐  │  │
│  │  │  EKS Worker     │  │  RDS Replica    │  │  ElastiCache  │  │  │
│  │  │  Nodes (5)      │  │  (Read-Only)    │  │  (Redis)      │  │  │
│  │  └─────────────────┘  └─────────────────┘  └───────────────┘  │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                   Availability Zone 3                         │  │
│  │                                                               │  │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌───────────────┐  │  │
│  │  │  EKS Worker     │  │  RDS Replica    │  │  ElastiCache  │  │  │
│  │  │  Nodes (5)      │  │  (Read-Only)    │  │  (Redis)      │  │  │
│  │  └─────────────────┘  └─────────────────┘  └───────────────┘  │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                      Shared Services                          │  │
│  │                                                               │  │
│  │  ┌─────────┐  ┌──────────┐  ┌─────────┐  ┌─────────────────┐  │  │
│  │  │  ALB    │  │  Kafka   │  │  S3     │  │  Elasticsearch  │  │  │
│  │  │         │  │ (MSK)    │  │         │  │     Cluster     │  │  │
│  │  └─────────┘  └──────────┘  └─────────┘  └─────────────────┘  │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              │ (Global CDN)
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         CloudFlare CDN                              │
│                    (150+ Edge Locations)                            │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 6. Security Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                      PERIMETER SECURITY                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐           │
│  │     WAF      │    │     DDoS     │    │  Rate Limit  │           │
│  │ (CloudFlare) │    │  Protection  │    │   (Kong)     │           │
│  └──────────────┘    └──────────────┘    └──────────────┘           │
│                                                                     │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    APPLICATION SECURITY                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐           │
│  │     JWT      │    │    OAuth     │    │     RBAC     │           │
│  │     Auth     │    │  (Social)    │    │ (Roles/Perms)│           │
│  └──────────────┘    └──────────────┘    └──────────────┘           │
│                                                                     │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐           │
│  │   Input      │    │   Output     │    │   CSRF       │           │
│  │ Validation   │    │   Encoding   │    │ Protection   │           │
│  └──────────────┘    └──────────────┘    └──────────────┘           │
│                                                                     │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      NETWORK SECURITY                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐           │
│  │     VPC      │    │   Security   │    │   Private    │           │
│  │   Isolation  │    │    Groups    │    │   Subnets    │           │
│  └──────────────┘    └──────────────┘    └──────────────┘           │
│                                                                     │
│  ┌──────────────┐    ┌──────────────┐                               │
│  │   Service    │    │     mTLS     │                               │
│  │     Mesh     │    │ (Istio/Linkerd)                              │
│  └──────────────┘    └──────────────┘                               │
│                                                                     │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        DATA SECURITY                                │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐           │
│  │  Encryption  │    │  Encryption  │    │ Tokenization │           │
│  │   at Rest    │    │  in Transit  │    │  (Payment)   │           │
│  │  (AES-256)   │    │   (TLS 1.3)  │    │              │           │
│  └──────────────┘    └──────────────┘    └──────────────┘           │
│                                                                     │
│  ┌──────────────┐    ┌──────────────┐                               │
│  │   Secrets    │    │  Data        │                               │
│  │  Management  │    │  Masking     │                               │
│  │   (Vault)    │    │              │                               │
│  └──────────────┘    └──────────────┘                               │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 7. Monitoring & Observability

```
┌─────────────────────────────────────────────────────────────────────┐
│                         APPLICATION LAYER                           │
│                                                                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐               │
│  │   Service 1  │  │   Service 2  │  │   Service N  │               │
│  │              │  │              │  │              │               │
│  │  Metrics ────┼──┼── Logs ──────┼──┼── Traces ───┤                │
│  └──────────────┘  └──────────────┘  └──────────────┘               │
└─────────────────────────────────────────────────────────────────────┘
         │                   │                   │
         │ (Prometheus)      │ (Fluentd)         │ (OpenTelemetry)
         │                   │                   │
         ▼                   ▼                   ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      COLLECTION LAYER                               │
│                                                                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐               │
│  │ Prometheus   │  │  Fluentd     │  │    Jaeger    │               │
│  │   Server     │  │  Aggregator  │  │   Collector  │               │
│  └──────────────┘  └──────────────┘  └──────────────┘               │
└─────────────────────────────────────────────────────────────────────┘
         │                   │                   │
         ▼                   ▼                   ▼
┌─────────────────────────────────────────────────────────────────────┐
│                       STORAGE LAYER                                 │
│                                                                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐               │
│  │ Prometheus   │  │Elasticsearch │  │  Jaeger      │               │
│  │   TSDB       │  │    (ELK)     │  │  Storage     │               │
│  └──────────────┘  └──────────────┘  └──────────────┘               │
└─────────────────────────────────────────────────────────────────────┘
         │                   │                   │
         ▼                   ▼                   ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    VISUALIZATION LAYER                              │
│                                                                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐               │
│  │   Grafana    │  │    Kibana    │  │  Jaeger UI   │               │
│  │ (Dashboards) │  │  (Log Search)│  │   (Traces)   │               │
│  └──────────────┘  └──────────────┘  └──────────────┘               │
│                                                                     │
│  ┌──────────────────────────────────────────────────────┐           │
│  │              AlertManager                            │           │
│  │   - PagerDuty Integration                            │           │
│  │   - Slack Notifications                              │           │
│  │   - Email Alerts                                     │           │
│  └──────────────────────────────────────────────────────┘           │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 8. CI/CD Pipeline

```
┌─────────────┐
│ Developer   │
│ Commits     │
│ Code        │
└──────┬──────┘
       │
       ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         GITHUB ACTIONS                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Stage 1: BUILD                                                     │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐                 │
│  │  Lint   │→ │  Test   │→ │ Build   │→ │ Docker  │                 │
│  │  Code   │  │  (Unit) │  │  App    │  │  Image  │                 │
│  └─────────┘  └─────────┘  └─────────┘  └─────────┘                 │
│                                                                     │
│  Stage 2: SECURITY                                                  │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐                              │
│  │  SAST   │→ │Dependency│→│Container│                              │
│  │ (Snyk)  │  │  Scan   │  │  Scan   │                              │
│  └─────────┘  └─────────┘  └─────────┘                              │
│                                                                     │
│  Stage 3: DEPLOY TO STAGING                                         │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐                              │
│  │  Push   │→ │ ArgoCD  │→ │  E2E    │                              │
│  │  to ECR │  │ Deploy  │  │  Tests  │                              │
│  └─────────┘  └─────────┘  └─────────┘                              │
│                                  │                                  │
│                                  │ (Manual Approval)                │
│                                  ▼                                  │
│  Stage 4: DEPLOY TO PRODUCTION                                      │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐                 │
│  │ Blue/   │→ │ Health  │→ │ Traffic │→ │ Monitor │                 │
│  │ Green   │  │ Check   │  │ Switch  │  │  Metrics│                 │
│  └─────────┘  └─────────┘  └─────────┘  └─────────┘                 │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Summary

These diagrams provide different perspectives of the architecture:

1. **System Context**: High-level view of users and external systems
2. **Container Diagram**: Major components and their technologies
3. **Request Flows**: How different operations work
4. **Data Flow**: Movement of data through the system
5. **Deployment**: Physical infrastructure layout
6. **Security**: Security layers and controls
7. **Monitoring**: Observability stack
8. **CI/CD**: Deployment pipeline

Each diagram helps understand different aspects of the system design and can be used for:

- Onboarding new developers
- Architecture reviews
- Capacity planning
- Security audits
- Disaster recovery planning

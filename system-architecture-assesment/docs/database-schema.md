# Database Schema Design

## Overview

This document details the database schema for the e-commerce platform, following microservices principles where each service owns its data. We use polyglot persistence with different databases optimized for specific use cases.

## Database Distribution

```
┌─────────────────────────────────────────────────────────────────┐
│                    POSTGRESQL (ACID Required)                    │
│  • User Service DB                                              │
│  • Order Service DB                                             │
│  • Payment Service DB                                           │
│  • Inventory Service DB                                         │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    MONGODB (Flexible Schema)                     │
│  • Product Service DB                                           │
│  • Review Service DB                                            │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    REDIS (Fast Access/Cache)                     │
│  • Cart Service                                                 │
│  • Session Storage                                              │
│  • Rate Limiting                                                │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    ELASTICSEARCH (Search)                        │
│  • Product Search Index                                         │
│  • Search Analytics                                             │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    CASSANDRA (Time-Series)                       │
│  • Analytics Events                                             │
│  • User Behavior Tracking                                       │
└─────────────────────────────────────────────────────────────────┘
```

---

## 1. User Service Database (PostgreSQL)

### users
Stores user account information.

```sql
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    phone VARCHAR(20),
    email_verified BOOLEAN DEFAULT FALSE,
    phone_verified BOOLEAN DEFAULT FALSE,
    status VARCHAR(20) DEFAULT 'active', -- active, suspended, deleted
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login_at TIMESTAMP,
    
    CONSTRAINT email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_status ON users(status);
CREATE INDEX idx_users_created_at ON users(created_at);
```

### user_addresses
Stores shipping and billing addresses.

```sql
CREATE TABLE user_addresses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    address_type VARCHAR(20) NOT NULL, -- shipping, billing
    is_default BOOLEAN DEFAULT FALSE,
    full_name VARCHAR(200) NOT NULL,
    phone VARCHAR(20),
    address_line1 VARCHAR(255) NOT NULL,
    address_line2 VARCHAR(255),
    city VARCHAR(100) NOT NULL,
    state VARCHAR(100),
    postal_code VARCHAR(20) NOT NULL,
    country VARCHAR(2) NOT NULL, -- ISO 3166-1 alpha-2
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT valid_address_type CHECK (address_type IN ('shipping', 'billing'))
);

CREATE INDEX idx_user_addresses_user_id ON user_addresses(user_id);
CREATE INDEX idx_user_addresses_default ON user_addresses(user_id, is_default) WHERE is_default = TRUE;
```

### user_roles
Role-based access control.

```sql
CREATE TABLE roles (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL, -- admin, customer, vendor, support
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE user_roles (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role_id INTEGER NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, role_id)
);

CREATE INDEX idx_user_roles_user_id ON user_roles(user_id);
```

### user_sessions
Active user sessions for JWT token management.

```sql
CREATE TABLE user_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL,
    device_info JSONB,
    ip_address INET,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_accessed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_user_sessions_user_id ON user_sessions(user_id);
CREATE INDEX idx_user_sessions_expires_at ON user_sessions(expires_at);
CREATE INDEX idx_user_sessions_token_hash ON user_sessions(token_hash);
```

### oauth_accounts
Social login integration.

```sql
CREATE TABLE oauth_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider VARCHAR(50) NOT NULL, -- google, facebook, apple
    provider_user_id VARCHAR(255) NOT NULL,
    access_token TEXT,
    refresh_token TEXT,
    token_expires_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(provider, provider_user_id)
);

CREATE INDEX idx_oauth_accounts_user_id ON oauth_accounts(user_id);
```

---

## 2. Product Service Database (MongoDB)

### products collection

```javascript
{
  "_id": ObjectId("..."),
  "sku": "PROD-12345",
  "name": "Wireless Bluetooth Headphones",
  "slug": "wireless-bluetooth-headphones",
  "description": "High-quality wireless headphones with noise cancellation",
  "short_description": "Premium wireless headphones",
  
  "category": {
    "id": "cat_123",
    "name": "Electronics",
    "path": ["Electronics", "Audio", "Headphones"]
  },
  
  "brand": {
    "id": "brand_456",
    "name": "TechBrand",
    "logo_url": "https://cdn.example.com/brands/techbrand.png"
  },
  
  "pricing": {
    "base_price": 99.99,
    "sale_price": 79.99,
    "currency": "USD",
    "tax_inclusive": false,
    "discount_percentage": 20
  },
  
  "variants": [
    {
      "variant_id": "var_001",
      "sku": "PROD-12345-BLK",
      "attributes": {
        "color": "Black",
        "size": null
      },
      "price_adjustment": 0,
      "images": [
        "https://cdn.example.com/products/prod-12345-blk-1.jpg",
        "https://cdn.example.com/products/prod-12345-blk-2.jpg"
      ]
    },
    {
      "variant_id": "var_002",
      "sku": "PROD-12345-WHT",
      "attributes": {
        "color": "White",
        "size": null
      },
      "price_adjustment": 5,
      "images": [
        "https://cdn.example.com/products/prod-12345-wht-1.jpg"
      ]
    }
  ],
  
  "attributes": {
    "wireless": true,
    "battery_life": "30 hours",
    "weight": "250g",
    "warranty": "2 years"
  },
  
  "media": {
    "images": [
      {
        "url": "https://cdn.example.com/products/prod-12345-main.jpg",
        "alt": "Wireless headphones main view",
        "position": 1,
        "is_primary": true
      }
    ],
    "videos": [
      {
        "url": "https://cdn.example.com/videos/prod-12345-demo.mp4",
        "thumbnail": "https://cdn.example.com/videos/prod-12345-thumb.jpg",
        "duration": 120
      }
    ]
  },
  
  "seo": {
    "meta_title": "Wireless Bluetooth Headphones | TechBrand",
    "meta_description": "Shop high-quality wireless headphones...",
    "meta_keywords": ["wireless", "bluetooth", "headphones", "audio"]
  },
  
  "shipping": {
    "weight": 500,
    "dimensions": {
      "length": 20,
      "width": 18,
      "height": 8,
      "unit": "cm"
    },
    "free_shipping": true,
    "shipping_class": "standard"
  },
  
  "status": "active", // active, draft, archived, out_of_stock
  "is_featured": true,
  "is_new": false,
  
  "ratings": {
    "average": 4.5,
    "count": 152,
    "distribution": {
      "5": 95,
      "4": 40,
      "3": 10,
      "2": 5,
      "1": 2
    }
  },
  
  "tags": ["wireless", "bluetooth", "noise-cancelling", "premium"],
  
  "created_at": ISODate("2025-01-15T10:00:00Z"),
  "updated_at": ISODate("2025-01-20T14:30:00Z"),
  "created_by": "admin_user_id",
  "updated_by": "admin_user_id"
}
```

**Indexes**:
```javascript
db.products.createIndex({ "sku": 1 }, { unique: true });
db.products.createIndex({ "slug": 1 }, { unique: true });
db.products.createIndex({ "category.id": 1 });
db.products.createIndex({ "brand.id": 1 });
db.products.createIndex({ "status": 1 });
db.products.createIndex({ "tags": 1 });
db.products.createIndex({ "pricing.base_price": 1 });
db.products.createIndex({ "ratings.average": -1 });
db.products.createIndex({ "created_at": -1 });
db.products.createIndex({ 
  "name": "text", 
  "description": "text", 
  "tags": "text" 
}); // Full-text search
```

### categories collection

```javascript
{
  "_id": "cat_123",
  "name": "Electronics",
  "slug": "electronics",
  "description": "Electronic devices and accessories",
  "parent_id": null, // null for top-level categories
  "path": ["Electronics"],
  "level": 1,
  "image_url": "https://cdn.example.com/categories/electronics.jpg",
  "is_active": true,
  "display_order": 1,
  "seo": {
    "meta_title": "Electronics | Shop Online",
    "meta_description": "Browse our electronics collection..."
  },
  "created_at": ISODate("2025-01-01T00:00:00Z"),
  "updated_at": ISODate("2025-01-01T00:00:00Z")
}
```

**Indexes**:
```javascript
db.categories.createIndex({ "slug": 1 }, { unique: true });
db.categories.createIndex({ "parent_id": 1 });
db.categories.createIndex({ "is_active": 1 });
```

---

## 3. Inventory Service Database (PostgreSQL)

### inventory_items
Real-time inventory tracking.

```sql
CREATE TABLE inventory_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id VARCHAR(100) NOT NULL, -- References Product Service
    variant_id VARCHAR(100), -- References specific variant
    warehouse_id UUID NOT NULL REFERENCES warehouses(id),
    quantity_available INTEGER NOT NULL DEFAULT 0,
    quantity_reserved INTEGER NOT NULL DEFAULT 0,
    quantity_sold INTEGER NOT NULL DEFAULT 0,
    reorder_level INTEGER DEFAULT 10,
    reorder_quantity INTEGER DEFAULT 50,
    last_restocked_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT quantity_positive CHECK (quantity_available >= 0),
    CONSTRAINT reserved_valid CHECK (quantity_reserved >= 0),
    UNIQUE(product_id, variant_id, warehouse_id)
);

CREATE INDEX idx_inventory_product_id ON inventory_items(product_id);
CREATE INDEX idx_inventory_warehouse_id ON inventory_items(warehouse_id);
CREATE INDEX idx_inventory_low_stock ON inventory_items(warehouse_id) 
    WHERE quantity_available <= reorder_level;
```

### warehouses

```sql
CREATE TABLE warehouses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(200) NOT NULL,
    code VARCHAR(50) UNIQUE NOT NULL,
    address TEXT,
    city VARCHAR(100),
    state VARCHAR(100),
    country VARCHAR(2),
    postal_code VARCHAR(20),
    is_active BOOLEAN DEFAULT TRUE,
    priority INTEGER DEFAULT 1, -- For fulfillment priority
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_warehouses_code ON warehouses(code);
CREATE INDEX idx_warehouses_active ON warehouses(is_active);
```

### inventory_movements
Event sourcing for audit trail.

```sql
CREATE TABLE inventory_movements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    inventory_item_id UUID NOT NULL REFERENCES inventory_items(id),
    movement_type VARCHAR(50) NOT NULL, -- purchase, sale, return, adjustment, transfer
    quantity INTEGER NOT NULL,
    from_warehouse_id UUID REFERENCES warehouses(id),
    to_warehouse_id UUID REFERENCES warehouses(id),
    reference_type VARCHAR(50), -- order, purchase_order, adjustment
    reference_id VARCHAR(100),
    reason TEXT,
    performed_by UUID, -- User who performed the movement
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT valid_movement_type CHECK (
        movement_type IN ('purchase', 'sale', 'return', 'adjustment', 'transfer', 'reservation', 'release')
    )
);

CREATE INDEX idx_inventory_movements_item_id ON inventory_movements(inventory_item_id);
CREATE INDEX idx_inventory_movements_created_at ON inventory_movements(created_at DESC);
CREATE INDEX idx_inventory_movements_reference ON inventory_movements(reference_type, reference_id);
```

### inventory_reservations
Temporary holds during checkout.

```sql
CREATE TABLE inventory_reservations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    inventory_item_id UUID NOT NULL REFERENCES inventory_items(id),
    order_id UUID, -- NULL until order is created
    session_id VARCHAR(255), -- For guest users
    quantity INTEGER NOT NULL,
    status VARCHAR(20) DEFAULT 'active', -- active, fulfilled, cancelled, expired
    expires_at TIMESTAMP NOT NULL, -- Auto-release after 15 minutes
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT reservation_quantity_positive CHECK (quantity > 0)
);

CREATE INDEX idx_inventory_reservations_item_id ON inventory_reservations(inventory_item_id);
CREATE INDEX idx_inventory_reservations_expires_at ON inventory_reservations(expires_at) 
    WHERE status = 'active';
CREATE INDEX idx_inventory_reservations_order_id ON inventory_reservations(order_id);
```

---

## 4. Order Service Database (PostgreSQL)

### orders

```sql
CREATE TABLE orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_number VARCHAR(50) UNIQUE NOT NULL,
    user_id UUID NOT NULL, -- References User Service
    
    -- Order Status
    status VARCHAR(50) NOT NULL DEFAULT 'pending', 
    -- pending, confirmed, processing, shipped, delivered, cancelled, refunded
    
    -- Pricing
    subtotal DECIMAL(10, 2) NOT NULL,
    tax_amount DECIMAL(10, 2) NOT NULL DEFAULT 0,
    shipping_amount DECIMAL(10, 2) NOT NULL DEFAULT 0,
    discount_amount DECIMAL(10, 2) NOT NULL DEFAULT 0,
    total_amount DECIMAL(10, 2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    
    -- Shipping Information
    shipping_address JSONB NOT NULL,
    billing_address JSONB NOT NULL,
    shipping_method VARCHAR(100),
    estimated_delivery_date DATE,
    
    -- Payment Information
    payment_method VARCHAR(50),
    payment_status VARCHAR(50) DEFAULT 'pending', -- pending, paid, failed, refunded
    
    -- Metadata
    customer_notes TEXT,
    internal_notes TEXT,
    ip_address INET,
    user_agent TEXT,
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    confirmed_at TIMESTAMP,
    shipped_at TIMESTAMP,
    delivered_at TIMESTAMP,
    cancelled_at TIMESTAMP,
    
    CONSTRAINT valid_order_status CHECK (
        status IN ('pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled', 'refunded')
    ),
    CONSTRAINT valid_payment_status CHECK (
        payment_status IN ('pending', 'paid', 'failed', 'refunded', 'partially_refunded')
    ),
    CONSTRAINT total_positive CHECK (total_amount >= 0)
);

CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_orders_order_number ON orders(order_number);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_payment_status ON orders(payment_status);
CREATE INDEX idx_orders_created_at ON orders(created_at DESC);
```

### order_items

```sql
CREATE TABLE order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id VARCHAR(100) NOT NULL, -- References Product Service
    variant_id VARCHAR(100), -- References specific variant
    product_name VARCHAR(255) NOT NULL,
    product_sku VARCHAR(100) NOT NULL,
    quantity INTEGER NOT NULL,
    unit_price DECIMAL(10, 2) NOT NULL,
    subtotal DECIMAL(10, 2) NOT NULL,
    tax_amount DECIMAL(10, 2) DEFAULT 0,
    discount_amount DECIMAL(10, 2) DEFAULT 0,
    total_amount DECIMAL(10, 2) NOT NULL,
    
    -- Snapshot of product details at time of order
    product_snapshot JSONB,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT quantity_positive CHECK (quantity > 0),
    CONSTRAINT price_positive CHECK (unit_price >= 0)
);

CREATE INDEX idx_order_items_order_id ON order_items(order_id);
CREATE INDEX idx_order_items_product_id ON order_items(product_id);
```

### order_status_history
Track order status changes.

```sql
CREATE TABLE order_status_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    previous_status VARCHAR(50),
    new_status VARCHAR(50) NOT NULL,
    comment TEXT,
    changed_by UUID, -- User or system
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_order_status_history_order_id ON order_status_history(order_id);
CREATE INDEX idx_order_status_history_created_at ON order_status_history(created_at DESC);
```

### shipments

```sql
CREATE TABLE shipments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES orders(id),
    tracking_number VARCHAR(100),
    carrier VARCHAR(100), -- UPS, FedEx, DHL, etc.
    shipping_method VARCHAR(100),
    status VARCHAR(50) DEFAULT 'pending', -- pending, in_transit, delivered, failed
    shipped_at TIMESTAMP,
    estimated_delivery_at TIMESTAMP,
    delivered_at TIMESTAMP,
    shipping_address JSONB NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_shipments_order_id ON shipments(order_id);
CREATE INDEX idx_shipments_tracking_number ON shipments(tracking_number);
CREATE INDEX idx_shipments_status ON shipments(status);
```

### refunds

```sql
CREATE TABLE refunds (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES orders(id),
    refund_amount DECIMAL(10, 2) NOT NULL,
    refund_reason VARCHAR(255),
    refund_method VARCHAR(50), -- original_payment, store_credit, manual
    status VARCHAR(50) DEFAULT 'pending', -- pending, approved, processed, rejected
    requested_by UUID,
    approved_by UUID,
    processed_by UUID,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processed_at TIMESTAMP,
    
    CONSTRAINT refund_amount_positive CHECK (refund_amount > 0)
);

CREATE INDEX idx_refunds_order_id ON refunds(order_id);
CREATE INDEX idx_refunds_status ON refunds(status);
```

---

## 5. Payment Service Database (PostgreSQL)

### payments

```sql
CREATE TABLE payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL, -- References Order Service
    payment_gateway VARCHAR(50) NOT NULL, -- stripe, paypal, razorpay
    transaction_id VARCHAR(255), -- Gateway transaction ID
    payment_method_id UUID REFERENCES payment_methods(id),
    
    amount DECIMAL(10, 2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    
    status VARCHAR(50) DEFAULT 'pending', 
    -- pending, processing, succeeded, failed, cancelled, refunded
    
    payment_type VARCHAR(50) NOT NULL, -- credit_card, debit_card, paypal, bank_transfer
    
    -- Security
    fingerprint VARCHAR(255), -- Device fingerprint for fraud detection
    ip_address INET,
    
    -- Gateway Response
    gateway_response JSONB, -- Encrypted gateway response
    error_code VARCHAR(100),
    error_message TEXT,
    
    -- Metadata
    metadata JSONB,
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    succeeded_at TIMESTAMP,
    failed_at TIMESTAMP,
    
    CONSTRAINT valid_payment_status CHECK (
        status IN ('pending', 'processing', 'succeeded', 'failed', 'cancelled', 'refunded', 'partially_refunded')
    ),
    CONSTRAINT amount_positive CHECK (amount > 0)
);

CREATE INDEX idx_payments_order_id ON payments(order_id);
CREATE INDEX idx_payments_transaction_id ON payments(transaction_id);
CREATE INDEX idx_payments_status ON payments(status);
CREATE INDEX idx_payments_created_at ON payments(created_at DESC);
```

### payment_methods
Stored payment methods (tokenized).

```sql
CREATE TABLE payment_methods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL, -- References User Service
    payment_type VARCHAR(50) NOT NULL, -- credit_card, debit_card, paypal
    gateway VARCHAR(50) NOT NULL,
    gateway_customer_id VARCHAR(255), -- Customer ID in gateway
    gateway_payment_method_id VARCHAR(255), -- Payment method token
    
    -- Masked details (for display)
    card_last4 VARCHAR(4),
    card_brand VARCHAR(50),
    card_exp_month INTEGER,
    card_exp_year INTEGER,
    billing_address JSONB,
    
    is_default BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT valid_exp_month CHECK (card_exp_month BETWEEN 1 AND 12),
    CONSTRAINT valid_exp_year CHECK (card_exp_year >= EXTRACT(YEAR FROM CURRENT_DATE))
);

CREATE INDEX idx_payment_methods_user_id ON payment_methods(user_id);
CREATE INDEX idx_payment_methods_default ON payment_methods(user_id, is_default) 
    WHERE is_default = TRUE;
```

### payment_attempts
Track all payment attempts (for fraud detection).

```sql
CREATE TABLE payment_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id UUID REFERENCES payments(id),
    attempt_number INTEGER NOT NULL DEFAULT 1,
    status VARCHAR(50) NOT NULL,
    error_code VARCHAR(100),
    error_message TEXT,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_payment_attempts_payment_id ON payment_attempts(payment_id);
CREATE INDEX idx_payment_attempts_created_at ON payment_attempts(created_at DESC);
```

---

## 6. Review Service Database (MongoDB)

### reviews collection

```javascript
{
  "_id": ObjectId("..."),
  "product_id": "prod_12345",
  "user_id": "user_uuid",
  "order_id": "order_uuid", // Verified purchase
  
  "rating": 5, // 1-5 stars
  "title": "Amazing product!",
  "review_text": "This product exceeded my expectations...",
  
  "verified_purchase": true,
  
  "images": [
    {
      "url": "https://cdn.example.com/reviews/img1.jpg",
      "thumbnail": "https://cdn.example.com/reviews/img1_thumb.jpg"
    }
  ],
  
  "helpful_count": 42,
  "not_helpful_count": 3,
  
  "status": "approved", // pending, approved, rejected, flagged
  "moderation_note": null,
  "moderated_by": null,
  "moderated_at": null,
  
  "seller_response": {
    "text": "Thank you for your feedback!",
    "responded_by": "seller_id",
    "responded_at": ISODate("2025-01-20T10:00:00Z")
  },
  
  "created_at": ISODate("2025-01-15T14:30:00Z"),
  "updated_at": ISODate("2025-01-15T14:30:00Z")
}
```

**Indexes**:
```javascript
db.reviews.createIndex({ "product_id": 1, "status": 1 });
db.reviews.createIndex({ "user_id": 1 });
db.reviews.createIndex({ "order_id": 1 });
db.reviews.createIndex({ "rating": 1 });
db.reviews.createIndex({ "created_at": -1 });
db.reviews.createIndex({ "verified_purchase": 1 });
```

### review_votes collection

```javascript
{
  "_id": ObjectId("..."),
  "review_id": ObjectId("..."),
  "user_id": "user_uuid",
  "vote_type": "helpful", // helpful, not_helpful
  "created_at": ISODate("2025-01-16T10:00:00Z")
}
```

**Indexes**:
```javascript
db.review_votes.createIndex({ "review_id": 1, "user_id": 1 }, { unique: true });
```

---

## 7. Cart Service (Redis)

### Data Structure

```
Key Pattern: cart:{user_id or session_id}
Type: Hash
TTL: 7 days for guest carts, 30 days for authenticated users

Fields:
  - item:{product_id}:{variant_id} → JSON serialized item
  - updated_at → timestamp
  - user_id → UUID (if authenticated)
```

**Example**:
```json
{
  "item:prod_123:var_001": "{\"product_id\":\"prod_123\",\"variant_id\":\"var_001\",\"quantity\":2,\"price\":99.99}",
  "item:prod_456:var_002": "{\"product_id\":\"prod_456\",\"variant_id\":\"var_002\",\"quantity\":1,\"price\":49.99}",
  "updated_at": "2025-01-20T15:30:00Z",
  "user_id": "user_uuid_here"
}
```

---

## 8. Elasticsearch Index Schema

### products index

```json
{
  "mappings": {
    "properties": {
      "product_id": { "type": "keyword" },
      "sku": { "type": "keyword" },
      "name": {
        "type": "text",
        "analyzer": "standard",
        "fields": {
          "keyword": { "type": "keyword" },
          "autocomplete": {
            "type": "text",
            "analyzer": "autocomplete"
          }
        }
      },
      "description": {
        "type": "text",
        "analyzer": "standard"
      },
      "category": {
        "type": "object",
        "properties": {
          "id": { "type": "keyword" },
          "name": { "type": "keyword" },
          "path": { "type": "keyword" }
        }
      },
      "brand": {
        "type": "object",
        "properties": {
          "id": { "type": "keyword" },
          "name": { "type": "keyword" }
        }
      },
      "price": { "type": "float" },
      "sale_price": { "type": "float" },
      "rating": { "type": "float" },
      "rating_count": { "type": "integer" },
      "tags": { "type": "keyword" },
      "attributes": { "type": "object", "enabled": false },
      "in_stock": { "type": "boolean" },
      "is_featured": { "type": "boolean" },
      "created_at": { "type": "date" },
      "updated_at": { "type": "date" }
    }
  }
}
```

---

## 9. Cassandra Schema (Analytics)

### user_events table

```cql
CREATE TABLE IF NOT EXISTS analytics.user_events (
    user_id UUID,
    event_type TEXT,
    event_date DATE,
    event_timestamp TIMESTAMP,
    event_id TIMEUUID,
    product_id TEXT,
    category_id TEXT,
    session_id TEXT,
    device_type TEXT,
    metadata MAP<TEXT, TEXT>,
    PRIMARY KEY ((user_id, event_date), event_timestamp, event_id)
) WITH CLUSTERING ORDER BY (event_timestamp DESC, event_id DESC)
  AND compaction = {'class': 'TimeWindowCompactionStrategy'}
  AND default_time_to_live = 7776000; -- 90 days
```

### product_views table

```cql
CREATE TABLE IF NOT EXISTS analytics.product_views (
    product_id TEXT,
    view_date DATE,
    view_timestamp TIMESTAMP,
    user_id UUID,
    session_id TEXT,
    referrer TEXT,
    PRIMARY KEY ((product_id, view_date), view_timestamp, user_id)
) WITH CLUSTERING ORDER BY (view_timestamp DESC, user_id ASC)
  AND compaction = {'class': 'TimeWindowCompactionStrategy'};
```

---

## Data Relationships & Foreign Keys

### Cross-Service References

Since we're using microservices, we don't have traditional foreign keys across databases. Instead, we use:

1. **Eventual Consistency**: Services publish events when data changes
2. **API Calls**: Services query each other via REST APIs for real-time data
3. **Data Duplication**: Store minimal necessary data from other services
4. **Saga Pattern**: For distributed transactions (e.g., order placement)

### Reference Data Flow Example: Place Order

```
1. User Service: Validate user exists
2. Product Service: Get product details & pricing
3. Inventory Service: Reserve inventory
4. Order Service: Create order (store user_id, product_id references)
5. Payment Service: Process payment (store order_id reference)
6. On Success:
   - Inventory Service: Commit reservation
   - Notification Service: Send confirmation
   - Analytics Service: Log event
7. On Failure:
   - Inventory Service: Release reservation
   - Payment Service: Refund (if charged)
   - Order Service: Mark as failed
```

---

## Data Migration Strategy

### Phase 1: Setup
1. Create databases for each service
2. Apply schemas using migration tools (Flyway, Liquibase, migrate)
3. Set up replication and backups

### Phase 2: Seed Data
1. Create initial users (admin accounts)
2. Import product catalog
3. Set up warehouse locations
4. Configure payment gateways

### Phase 3: Testing
1. Load test with synthetic data
2. Verify referential integrity across services
3. Test disaster recovery procedures

---

## Backup & Disaster Recovery

### Backup Schedule

| Database | Frequency | Retention | Method |
|----------|-----------|-----------|--------|
| PostgreSQL | Continuous WAL + Daily Full | 30 days | pg_basebackup + WAL archiving |
| MongoDB | Hourly | 7 days | mongodump / Atlas backups |
| Redis | Hourly RDB + AOF | 3 days | RDB snapshots + AOF |
| Elasticsearch | Daily | 14 days | Snapshot API to S3 |
| Cassandra | Daily | 30 days | nodetool snapshot |

### Recovery Objectives
- **RTO** (Recovery Time Objective): < 1 hour
- **RPO** (Recovery Point Objective): < 5 minutes

---

## Next Steps

- Review [API Specification](./api-specification.md) for service endpoints
- Study [Scalability & Reliability](./scalability-reliability.md) for production best practices


# API Specification Outline

## Overview

This document outlines the RESTful API specifications for the e-commerce platform. All services expose APIs following consistent patterns and best practices.

## API Design Principles

### 1. RESTful Conventions
- Use nouns for resources (not verbs)
- HTTP methods: GET (read), POST (create), PUT (update), PATCH (partial update), DELETE (remove)
- Plural resource names: `/products`, `/orders`, `/users`

### 2. Versioning
- URL versioning: `/api/v1/products`
- Header versioning (alternative): `Accept: application/vnd.ecommerce.v1+json`

### 3. Response Format
All responses follow a consistent structure:

```json
{
  "success": true,
  "data": { /* response payload */ },
  "meta": {
    "timestamp": "2025-01-20T15:30:00Z",
    "request_id": "req_abc123"
  },
  "error": null
}
```

Error response:
```json
{
  "success": false,
  "data": null,
  "error": {
    "code": "PRODUCT_NOT_FOUND",
    "message": "Product with ID prod_123 not found",
    "details": {}
  },
  "meta": {
    "timestamp": "2025-01-20T15:30:00Z",
    "request_id": "req_abc123"
  }
}
```

### 4. Pagination
For list endpoints:
```
GET /api/v1/products?page=1&limit=20&sort=-created_at
```

Response includes pagination metadata:
```json
{
  "success": true,
  "data": [ /* items */ ],
  "meta": {
    "pagination": {
      "page": 1,
      "limit": 20,
      "total_items": 150,
      "total_pages": 8,
      "has_next": true,
      "has_prev": false
    }
  }
}
```

### 5. Filtering & Sorting
- Filtering: `?category=electronics&price_min=50&price_max=500`
- Sorting: `?sort=price` (ascending), `?sort=-price` (descending)
- Multiple sorts: `?sort=-created_at,name`

### 6. Field Selection (Sparse Fieldsets)
- Request specific fields: `?fields=id,name,price`
- Reduces payload size and improves performance

### 7. Authentication
- JWT Bearer token in Authorization header
- Format: `Authorization: Bearer <token>`

### 8. Rate Limiting
Response headers:
```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1674234567
```

---

## API Gateway

### Base URL
```
Production: https://api.ecommerce.com
Staging: https://api-staging.ecommerce.com
Development: http://localhost:8000
```

### Common Headers

| Header | Required | Description |
|--------|----------|-------------|
| `Authorization` | Yes (except auth endpoints) | Bearer JWT token |
| `Content-Type` | Yes (for POST/PUT/PATCH) | `application/json` |
| `Accept` | No | `application/json` (default) |
| `X-Request-ID` | No | Client-generated request ID for tracing |
| `X-Device-ID` | No | Device identifier for analytics |

---

## 1. User Service API

### Authentication

#### Register User
```http
POST /api/v1/auth/register
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "SecurePass123!",
  "first_name": "John",
  "last_name": "Doe",
  "phone": "+1234567890"
}

Response 201 Created:
{
  "success": true,
  "data": {
    "user": {
      "id": "uuid",
      "email": "user@example.com",
      "first_name": "John",
      "last_name": "Doe",
      "email_verified": false
    },
    "token": "jwt_token_here",
    "refresh_token": "refresh_token_here"
  }
}
```

#### Login
```http
POST /api/v1/auth/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "SecurePass123!"
}

Response 200 OK:
{
  "success": true,
  "data": {
    "user": { /* user object */ },
    "token": "jwt_token_here",
    "refresh_token": "refresh_token_here",
    "expires_in": 3600
  }
}
```

#### Refresh Token
```http
POST /api/v1/auth/refresh
Content-Type: application/json

{
  "refresh_token": "refresh_token_here"
}

Response 200 OK:
{
  "success": true,
  "data": {
    "token": "new_jwt_token",
    "expires_in": 3600
  }
}
```

#### OAuth Login (Google, Facebook)
```http
POST /api/v1/auth/oauth/{provider}
Content-Type: application/json

{
  "access_token": "oauth_access_token_from_provider"
}

Response 200 OK:
{
  "success": true,
  "data": {
    "user": { /* user object */ },
    "token": "jwt_token_here",
    "is_new_user": true
  }
}
```

### User Profile

#### Get Current User
```http
GET /api/v1/users/me
Authorization: Bearer <token>

Response 200 OK:
{
  "success": true,
  "data": {
    "id": "uuid",
    "email": "user@example.com",
    "first_name": "John",
    "last_name": "Doe",
    "phone": "+1234567890",
    "email_verified": true,
    "created_at": "2025-01-15T10:00:00Z"
  }
}
```

#### Update Profile
```http
PATCH /api/v1/users/me
Authorization: Bearer <token>
Content-Type: application/json

{
  "first_name": "Jane",
  "phone": "+0987654321"
}

Response 200 OK:
{
  "success": true,
  "data": { /* updated user object */ }
}
```

### Address Management

#### List Addresses
```http
GET /api/v1/users/me/addresses
Authorization: Bearer <token>

Response 200 OK:
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "address_type": "shipping",
      "is_default": true,
      "full_name": "John Doe",
      "address_line1": "123 Main St",
      "city": "New York",
      "country": "US",
      "postal_code": "10001"
    }
  ]
}
```

#### Add Address
```http
POST /api/v1/users/me/addresses
Authorization: Bearer <token>
Content-Type: application/json

{
  "address_type": "shipping",
  "is_default": true,
  "full_name": "John Doe",
  "phone": "+1234567890",
  "address_line1": "123 Main St",
  "city": "New York",
  "state": "NY",
  "postal_code": "10001",
  "country": "US"
}

Response 201 Created:
{
  "success": true,
  "data": { /* address object */ }
}
```

---

## 2. Product Service API

### Product Catalog

#### List Products
```http
GET /api/v1/products?page=1&limit=20&category=electronics&price_min=50&price_max=500&sort=-created_at
Authorization: Bearer <token> (optional)

Response 200 OK:
{
  "success": true,
  "data": [
    {
      "id": "prod_123",
      "sku": "PROD-12345",
      "name": "Wireless Headphones",
      "slug": "wireless-headphones",
      "description": "High-quality wireless headphones...",
      "price": 99.99,
      "sale_price": 79.99,
      "currency": "USD",
      "category": {
        "id": "cat_123",
        "name": "Electronics",
        "path": ["Electronics", "Audio"]
      },
      "brand": {
        "id": "brand_456",
        "name": "TechBrand"
      },
      "images": [
        "https://cdn.example.com/products/prod-123-1.jpg"
      ],
      "rating": 4.5,
      "rating_count": 152,
      "in_stock": true,
      "is_featured": true
    }
  ],
  "meta": {
    "pagination": { /* pagination info */ }
  }
}
```

#### Get Product Details
```http
GET /api/v1/products/{productId}
Authorization: Bearer <token> (optional)

Response 200 OK:
{
  "success": true,
  "data": {
    "id": "prod_123",
    "sku": "PROD-12345",
    "name": "Wireless Headphones",
    "description": "Detailed product description...",
    "price": 99.99,
    "sale_price": 79.99,
    "variants": [
      {
        "variant_id": "var_001",
        "sku": "PROD-12345-BLK",
        "attributes": {
          "color": "Black"
        },
        "price_adjustment": 0,
        "in_stock": true
      }
    ],
    "attributes": {
      "wireless": true,
      "battery_life": "30 hours"
    },
    "media": {
      "images": [ /* image objects */ ],
      "videos": [ /* video objects */ ]
    },
    "shipping": {
      "weight": 500,
      "free_shipping": true
    },
    "rating": 4.5,
    "rating_count": 152,
    "reviews_summary": {
      "total": 152,
      "distribution": {
        "5": 95,
        "4": 40,
        "3": 10,
        "2": 5,
        "1": 2
      }
    }
  }
}
```

#### Search Products
```http
GET /api/v1/products/search?q=wireless+headphones&category=electronics&page=1&limit=20
Authorization: Bearer <token> (optional)

Response 200 OK:
{
  "success": true,
  "data": {
    "results": [ /* product objects */ ],
    "facets": {
      "categories": [
        { "name": "Electronics", "count": 45 },
        { "name": "Audio", "count": 30 }
      ],
      "brands": [
        { "name": "TechBrand", "count": 15 },
        { "name": "AudioPro", "count": 12 }
      ],
      "price_ranges": [
        { "range": "0-50", "count": 10 },
        { "range": "50-100", "count": 25 }
      ]
    },
    "suggestions": ["wireless headphones", "bluetooth headphones"]
  },
  "meta": {
    "pagination": { /* pagination info */ },
    "search_time": 45 // milliseconds
  }
}
```

#### Get Autocomplete Suggestions
```http
GET /api/v1/products/autocomplete?q=wire

Response 200 OK:
{
  "success": true,
  "data": {
    "suggestions": [
      "wireless headphones",
      "wireless mouse",
      "wireless keyboard"
    ]
  }
}
```

### Categories

#### List Categories
```http
GET /api/v1/categories?parent_id=null

Response 200 OK:
{
  "success": true,
  "data": [
    {
      "id": "cat_123",
      "name": "Electronics",
      "slug": "electronics",
      "parent_id": null,
      "image_url": "https://cdn.example.com/categories/electronics.jpg",
      "product_count": 1250,
      "children_count": 5
    }
  ]
}
```

#### Get Category Tree
```http
GET /api/v1/categories/tree

Response 200 OK:
{
  "success": true,
  "data": [
    {
      "id": "cat_123",
      "name": "Electronics",
      "children": [
        {
          "id": "cat_124",
          "name": "Audio",
          "children": [
            {
              "id": "cat_125",
              "name": "Headphones"
            }
          ]
        }
      ]
    }
  ]
}
```

---

## 3. Inventory Service API

### Inventory Management

#### Check Product Availability
```http
GET /api/v1/inventory/check?product_id=prod_123&variant_id=var_001&quantity=2
Authorization: Bearer <token>

Response 200 OK:
{
  "success": true,
  "data": {
    "product_id": "prod_123",
    "variant_id": "var_001",
    "available": true,
    "quantity_available": 50,
    "warehouse_availability": [
      {
        "warehouse_id": "wh_001",
        "warehouse_name": "Main Warehouse",
        "quantity": 30
      },
      {
        "warehouse_id": "wh_002",
        "warehouse_name": "West Coast",
        "quantity": 20
      }
    ]
  }
}
```

#### Reserve Inventory
```http
POST /api/v1/inventory/reserve
Authorization: Bearer <token>
Content-Type: application/json

{
  "items": [
    {
      "product_id": "prod_123",
      "variant_id": "var_001",
      "quantity": 2
    }
  ],
  "session_id": "session_abc123",
  "expires_in": 900 // seconds (15 minutes)
}

Response 201 Created:
{
  "success": true,
  "data": {
    "reservation_id": "res_xyz789",
    "items": [
      {
        "product_id": "prod_123",
        "variant_id": "var_001",
        "quantity": 2,
        "reserved": true
      }
    ],
    "expires_at": "2025-01-20T16:00:00Z"
  }
}
```

#### Release Reservation
```http
DELETE /api/v1/inventory/reservations/{reservationId}
Authorization: Bearer <token>

Response 204 No Content
```

#### Get Low Stock Alerts (Admin)
```http
GET /api/v1/inventory/low-stock?warehouse_id=wh_001
Authorization: Bearer <admin_token>

Response 200 OK:
{
  "success": true,
  "data": [
    {
      "product_id": "prod_123",
      "variant_id": "var_001",
      "quantity_available": 5,
      "reorder_level": 10,
      "warehouse_id": "wh_001"
    }
  ]
}
```

---

## 4. Cart Service API

### Shopping Cart

#### Get Cart
```http
GET /api/v1/cart
Authorization: Bearer <token>

Response 200 OK:
{
  "success": true,
  "data": {
    "items": [
      {
        "product_id": "prod_123",
        "variant_id": "var_001",
        "product_name": "Wireless Headphones",
        "product_sku": "PROD-12345-BLK",
        "quantity": 2,
        "unit_price": 79.99,
        "subtotal": 159.98,
        "image_url": "https://cdn.example.com/products/prod-123.jpg",
        "in_stock": true
      }
    ],
    "summary": {
      "item_count": 2,
      "subtotal": 159.98,
      "tax": 14.40,
      "shipping": 0,
      "total": 174.38,
      "currency": "USD"
    },
    "updated_at": "2025-01-20T15:30:00Z"
  }
}
```

#### Add to Cart
```http
POST /api/v1/cart/items
Authorization: Bearer <token>
Content-Type: application/json

{
  "product_id": "prod_123",
  "variant_id": "var_001",
  "quantity": 1
}

Response 200 OK:
{
  "success": true,
  "data": { /* updated cart object */ }
}
```

#### Update Cart Item
```http
PATCH /api/v1/cart/items/{productId}
Authorization: Bearer <token>
Content-Type: application/json

{
  "quantity": 3
}

Response 200 OK:
{
  "success": true,
  "data": { /* updated cart object */ }
}
```

#### Remove from Cart
```http
DELETE /api/v1/cart/items/{productId}?variant_id=var_001
Authorization: Bearer <token>

Response 204 No Content
```

#### Clear Cart
```http
DELETE /api/v1/cart
Authorization: Bearer <token>

Response 204 No Content
```

---

## 5. Order Service API

### Order Management

#### Create Order
```http
POST /api/v1/orders
Authorization: Bearer <token>
Content-Type: application/json

{
  "shipping_address_id": "addr_123",
  "billing_address_id": "addr_123",
  "payment_method_id": "pm_456",
  "shipping_method": "standard",
  "customer_notes": "Please leave at door"
}

Response 201 Created:
{
  "success": true,
  "data": {
    "id": "order_uuid",
    "order_number": "ORD-2025-001234",
    "status": "pending",
    "items": [ /* order items */ ],
    "subtotal": 159.98,
    "tax": 14.40,
    "shipping": 0,
    "total": 174.38,
    "currency": "USD",
    "shipping_address": { /* address object */ },
    "created_at": "2025-01-20T15:45:00Z"
  }
}
```

#### Get Order Details
```http
GET /api/v1/orders/{orderId}
Authorization: Bearer <token>

Response 200 OK:
{
  "success": true,
  "data": {
    "id": "order_uuid",
    "order_number": "ORD-2025-001234",
    "status": "shipped",
    "payment_status": "paid",
    "items": [
      {
        "product_id": "prod_123",
        "product_name": "Wireless Headphones",
        "quantity": 2,
        "unit_price": 79.99,
        "total": 159.98
      }
    ],
    "subtotal": 159.98,
    "tax": 14.40,
    "shipping": 0,
    "total": 174.38,
    "shipping_address": { /* address object */ },
    "tracking": {
      "carrier": "UPS",
      "tracking_number": "1Z999AA1234567890",
      "status": "in_transit",
      "estimated_delivery": "2025-01-25"
    },
    "timeline": [
      {
        "status": "pending",
        "timestamp": "2025-01-20T15:45:00Z"
      },
      {
        "status": "confirmed",
        "timestamp": "2025-01-20T15:46:00Z"
      },
      {
        "status": "shipped",
        "timestamp": "2025-01-21T10:00:00Z"
      }
    ],
    "created_at": "2025-01-20T15:45:00Z"
  }
}
```

#### List User Orders
```http
GET /api/v1/orders?status=all&page=1&limit=10&sort=-created_at
Authorization: Bearer <token>

Response 200 OK:
{
  "success": true,
  "data": [
    {
      "id": "order_uuid",
      "order_number": "ORD-2025-001234",
      "status": "delivered",
      "total": 174.38,
      "created_at": "2025-01-20T15:45:00Z"
    }
  ],
  "meta": {
    "pagination": { /* pagination info */ }
  }
}
```

#### Cancel Order
```http
POST /api/v1/orders/{orderId}/cancel
Authorization: Bearer <token>
Content-Type: application/json

{
  "reason": "Changed my mind"
}

Response 200 OK:
{
  "success": true,
  "data": {
    "id": "order_uuid",
    "status": "cancelled",
    "refund_status": "pending"
  }
}
```

#### Track Order
```http
GET /api/v1/orders/{orderId}/tracking
Authorization: Bearer <token>

Response 200 OK:
{
  "success": true,
  "data": {
    "carrier": "UPS",
    "tracking_number": "1Z999AA1234567890",
    "status": "in_transit",
    "estimated_delivery": "2025-01-25",
    "events": [
      {
        "status": "picked_up",
        "location": "New York, NY",
        "timestamp": "2025-01-21T10:00:00Z"
      },
      {
        "status": "in_transit",
        "location": "Philadelphia, PA",
        "timestamp": "2025-01-21T15:30:00Z"
      }
    ]
  }
}
```

---

## 6. Payment Service API

### Payment Processing

#### Process Payment
```http
POST /api/v1/payments
Authorization: Bearer <token>
Content-Type: application/json

{
  "order_id": "order_uuid",
  "payment_method_id": "pm_456",
  "amount": 174.38,
  "currency": "USD",
  "return_url": "https://example.com/checkout/success"
}

Response 201 Created:
{
  "success": true,
  "data": {
    "payment_id": "pay_xyz789",
    "status": "succeeded",
    "transaction_id": "txn_abc123",
    "amount": 174.38,
    "currency": "USD"
  }
}
```

#### Get Payment Status
```http
GET /api/v1/payments/{paymentId}
Authorization: Bearer <token>

Response 200 OK:
{
  "success": true,
  "data": {
    "payment_id": "pay_xyz789",
    "order_id": "order_uuid",
    "status": "succeeded",
    "amount": 174.38,
    "currency": "USD",
    "payment_method": "credit_card",
    "card_last4": "4242",
    "created_at": "2025-01-20T15:46:00Z"
  }
}
```

### Payment Methods

#### List Payment Methods
```http
GET /api/v1/payment-methods
Authorization: Bearer <token>

Response 200 OK:
{
  "success": true,
  "data": [
    {
      "id": "pm_456",
      "type": "credit_card",
      "card_brand": "visa",
      "card_last4": "4242",
      "card_exp_month": 12,
      "card_exp_year": 2026,
      "is_default": true
    }
  ]
}
```

#### Add Payment Method
```http
POST /api/v1/payment-methods
Authorization: Bearer <token>
Content-Type: application/json

{
  "type": "credit_card",
  "gateway": "stripe",
  "token": "tok_visa" // Token from Stripe.js
}

Response 201 Created:
{
  "success": true,
  "data": { /* payment method object */ }
}
```

#### Delete Payment Method
```http
DELETE /api/v1/payment-methods/{paymentMethodId}
Authorization: Bearer <token>

Response 204 No Content
```

---

## 7. Review Service API

### Product Reviews

#### List Product Reviews
```http
GET /api/v1/products/{productId}/reviews?page=1&limit=10&sort=-helpful_count&rating=5
Authorization: Bearer <token> (optional)

Response 200 OK:
{
  "success": true,
  "data": [
    {
      "id": "review_123",
      "user": {
        "id": "user_uuid",
        "name": "John D.",
        "avatar_url": "https://cdn.example.com/avatars/user.jpg"
      },
      "rating": 5,
      "title": "Amazing product!",
      "review_text": "This product exceeded my expectations...",
      "verified_purchase": true,
      "helpful_count": 42,
      "not_helpful_count": 3,
      "images": [
        "https://cdn.example.com/reviews/img1.jpg"
      ],
      "created_at": "2025-01-15T14:30:00Z"
    }
  ],
  "meta": {
    "pagination": { /* pagination info */ },
    "summary": {
      "average_rating": 4.5,
      "total_reviews": 152,
      "rating_distribution": {
        "5": 95,
        "4": 40,
        "3": 10,
        "2": 5,
        "1": 2
      }
    }
  }
}
```

#### Create Review
```http
POST /api/v1/products/{productId}/reviews
Authorization: Bearer <token>
Content-Type: multipart/form-data

rating: 5
title: "Amazing product!"
review_text: "This product exceeded my expectations..."
order_id: "order_uuid"
images: [file1, file2]

Response 201 Created:
{
  "success": true,
  "data": { /* review object */ }
}
```

#### Vote on Review
```http
POST /api/v1/reviews/{reviewId}/vote
Authorization: Bearer <token>
Content-Type: application/json

{
  "vote_type": "helpful" // or "not_helpful"
}

Response 200 OK:
{
  "success": true,
  "data": {
    "helpful_count": 43,
    "not_helpful_count": 3
  }
}
```

---

## 8. Recommendation Service API

### Product Recommendations

#### Get Personalized Recommendations
```http
GET /api/v1/recommendations/personalized?limit=10
Authorization: Bearer <token>

Response 200 OK:
{
  "success": true,
  "data": {
    "recommendations": [
      {
        "product_id": "prod_789",
        "score": 0.95,
        "reason": "Based on your recent purchases"
      }
    ]
  }
}
```

#### Get Similar Products
```http
GET /api/v1/recommendations/similar/{productId}?limit=10
Authorization: Bearer <token> (optional)

Response 200 OK:
{
  "success": true,
  "data": {
    "recommendations": [
      {
        "product_id": "prod_456",
        "similarity_score": 0.89,
        "reason": "Similar category and attributes"
      }
    ]
  }
}
```

#### Get Trending Products
```http
GET /api/v1/recommendations/trending?category=electronics&limit=10

Response 200 OK:
{
  "success": true,
  "data": {
    "products": [ /* product objects */ ]
  }
}
```

---

## 9. Notification Service API

### Notifications

#### List Notifications
```http
GET /api/v1/notifications?status=unread&page=1&limit=20
Authorization: Bearer <token>

Response 200 OK:
{
  "success": true,
  "data": [
    {
      "id": "notif_123",
      "type": "order_shipped",
      "title": "Your order has shipped!",
      "message": "Your order #ORD-2025-001234 is on its way",
      "data": {
        "order_id": "order_uuid"
      },
      "is_read": false,
      "created_at": "2025-01-21T10:00:00Z"
    }
  ],
  "meta": {
    "pagination": { /* pagination info */ },
    "unread_count": 5
  }
}
```

#### Mark as Read
```http
PATCH /api/v1/notifications/{notificationId}
Authorization: Bearer <token>
Content-Type: application/json

{
  "is_read": true
}

Response 200 OK
```

#### Get Notification Preferences
```http
GET /api/v1/notifications/preferences
Authorization: Bearer <token>

Response 200 OK:
{
  "success": true,
  "data": {
    "email": {
      "order_updates": true,
      "promotions": false,
      "newsletter": true
    },
    "sms": {
      "order_updates": true,
      "promotions": false
    },
    "push": {
      "order_updates": true,
      "promotions": true
    }
  }
}
```

---

## Error Codes

### Standard HTTP Status Codes

| Code | Meaning | Usage |
|------|---------|-------|
| 200 | OK | Successful GET, PATCH, PUT |
| 201 | Created | Successful POST |
| 204 | No Content | Successful DELETE |
| 400 | Bad Request | Invalid request format |
| 401 | Unauthorized | Missing or invalid authentication |
| 403 | Forbidden | Insufficient permissions |
| 404 | Not Found | Resource doesn't exist |
| 409 | Conflict | Resource conflict (e.g., duplicate) |
| 422 | Unprocessable Entity | Validation errors |
| 429 | Too Many Requests | Rate limit exceeded |
| 500 | Internal Server Error | Server error |
| 503 | Service Unavailable | Service temporarily down |

### Custom Error Codes

| Code | Description |
|------|-------------|
| `USER_NOT_FOUND` | User doesn't exist |
| `INVALID_CREDENTIALS` | Wrong email/password |
| `EMAIL_ALREADY_EXISTS` | Email already registered |
| `PRODUCT_NOT_FOUND` | Product doesn't exist |
| `PRODUCT_OUT_OF_STOCK` | Product unavailable |
| `INSUFFICIENT_INVENTORY` | Not enough stock |
| `INVALID_CART_ITEM` | Cart item validation failed |
| `ORDER_NOT_FOUND` | Order doesn't exist |
| `ORDER_CANNOT_BE_CANCELLED` | Order status prevents cancellation |
| `PAYMENT_FAILED` | Payment processing failed |
| `INVALID_PAYMENT_METHOD` | Payment method invalid |
| `SHIPPING_ADDRESS_REQUIRED` | Shipping address missing |

---

## Webhooks

For external integrations and async notifications.

### Webhook Events

```http
POST https://your-app.com/webhooks/ecommerce
Content-Type: application/json
X-Webhook-Signature: sha256_signature

{
  "event": "order.created",
  "data": {
    "order_id": "order_uuid",
    "order_number": "ORD-2025-001234",
    "total": 174.38
  },
  "timestamp": "2025-01-20T15:45:00Z"
}
```

### Available Events

- `order.created`
- `order.confirmed`
- `order.shipped`
- `order.delivered`
- `order.cancelled`
- `payment.succeeded`
- `payment.failed`
- `inventory.low_stock`
- `review.submitted`

---

## Rate Limiting

### Limits by Tier

| Tier | Requests per Minute | Burst |
|------|---------------------|-------|
| Guest | 60 | 10 |
| Authenticated | 100 | 20 |
| Premium | 300 | 50 |
| Admin | 1000 | 100 |

### Rate Limit Headers

```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1674234567
Retry-After: 60
```

---

## API Documentation

### Interactive Documentation

- **Swagger UI**: `https://api.ecommerce.com/docs`
- **ReDoc**: `https://api.ecommerce.com/redoc`
- **OpenAPI Spec**: `https://api.ecommerce.com/openapi.json`

### Testing

- **Postman Collection**: Available in repository
- **Sandbox Environment**: `https://api-sandbox.ecommerce.com`
- **Test Cards**: Standard Stripe test cards

---

## Next Steps

- Review [Scalability & Reliability](./scalability-reliability.md) for production considerations
- Implement API versioning strategy
- Set up API monitoring and analytics
- Create client SDKs (JavaScript, Python, Go)


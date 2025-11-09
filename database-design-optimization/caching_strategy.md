# Caching Strategy for Social Media Platform

## Table of Contents
1. [Overview](#overview)
2. [Caching Layers](#caching-layers)
3. [Cache Keys and TTL Strategy](#cache-keys-and-ttl-strategy)
4. [Specific Caching Strategies](#specific-caching-strategies)
5. [Cache Invalidation](#cache-invalidation)
6. [Implementation Guidelines](#implementation-guidelines)

---

## Overview

Social media platforms are read-heavy systems with specific characteristics:
- **Read/Write Ratio**: 95:5 (typical social media ratio)
- **Hot Data**: Recent posts, active users, trending content
- **Cold Data**: Archived posts, inactive users
- **Real-time Requirements**: Notifications, messages, live feeds

### Caching Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Client Layer                          │
│                    (Browser/App Cache)                       │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│                     CDN Layer (CloudFront)                   │
│              (Static Assets, Media Files)                    │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│                   Application Layer                          │
│                                                              │
│  ┌────────────────┐  ┌─────────────────┐  ┌──────────────┐│
│  │  Redis Cache   │  │  Memcached      │  │ Local Cache  ││
│  │  (Hot Data)    │  │  (Session Data) │  │ (In-Memory)  ││
│  └────────────────┘  └─────────────────┘  └──────────────┘│
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│                   Database Layer                             │
│                                                              │
│  ┌────────────────┐  ┌─────────────────┐                   │
│  │  PostgreSQL    │  │  Read Replicas  │                   │
│  │  (Primary)     │  │  (Slaves)       │                   │
│  └────────────────┘  └─────────────────┘                   │
└─────────────────────────────────────────────────────────────┘
```

---

## Caching Layers

### 1. CDN Layer (CloudFront/CloudFlare)

**Purpose**: Cache static assets and media files close to users

**What to Cache**:
- User profile pictures
- Post images and videos
- Thumbnails
- Static assets (CSS, JS, fonts)

**TTL**: 7-30 days

**Configuration**:
```
Cache-Control: public, max-age=2592000, immutable
```

**Invalidation**: Versioned URLs (e.g., `profile-pic-v123.jpg`)

---

### 2. Redis Cache (Primary Application Cache)

**Purpose**: Fast access to frequently accessed data

**Architecture**:
- Master-Slave setup for high availability
- Cluster mode for horizontal scalability
- Eviction Policy: `allkeys-lru` (Least Recently Used)

**Use Cases**:

#### A. User Feed Cache
```
Key Pattern: feed:user:{user_id}:page:{page_num}
TTL: 5 minutes
Data Structure: Sorted Set (ZSET)
```

#### B. User Profile Cache
```
Key Pattern: user:profile:{user_id}
TTL: 15 minutes
Data Structure: Hash
```

#### C. User Stats Cache
```
Key Pattern: user:stats:{user_id}
TTL: 10 minutes
Data Structure: Hash
Fields: followers_count, following_count, posts_count
```

#### D. Post Details Cache
```
Key Pattern: post:{post_id}
TTL: 30 minutes
Data Structure: Hash
```

#### E. Post Stats Cache
```
Key Pattern: post:stats:{post_id}
TTL: 2 minutes (frequently updated)
Data Structure: Hash
Fields: reactions_count, comments_count, shares_count, views_count
```

#### F. Trending Content Cache
```
Key Pattern: trending:posts:{time_window}
TTL: 10 minutes
Data Structure: Sorted Set (ZSET)
Score: engagement_velocity
```

#### G. Hashtag Cache
```
Key Pattern: hashtag:{hashtag_name}:posts
TTL: 15 minutes
Data Structure: Sorted Set (ZSET)
```

#### H. User Relationships Cache
```
Key Pattern: user:following:{user_id}
TTL: 30 minutes
Data Structure: Set
```

```
Key Pattern: user:followers:{user_id}
TTL: 30 minutes
Data Structure: Set
```

#### I. Comment Cache
```
Key Pattern: post:{post_id}:comments:page:{page_num}
TTL: 10 minutes
Data Structure: List or Sorted Set
```

---

### 3. Memcached (Session and Temporary Data)

**Purpose**: Session management and temporary data

**Use Cases**:

#### A. User Sessions
```
Key Pattern: session:{session_token}
TTL: 24 hours (rolling)
Data: User ID, authentication info, preferences
```

#### B. Rate Limiting
```
Key Pattern: ratelimit:{user_id}:{action}
TTL: 1 hour (sliding window)
Data: Request count
```

#### C. One-Time Tokens
```
Key Pattern: token:{token_value}
TTL: 5 minutes
Data: Token purpose and user_id
```

---

### 4. Application-Level Cache (In-Memory)

**Purpose**: Very frequently accessed, rarely changing data

**Use Cases**:

#### A. Reaction Types
```
Scope: Application-wide
Refresh: On application start or configuration change
Data: List of available reactions (like, love, laugh, etc.)
```

#### B. Notification Types
```
Scope: Application-wide
Refresh: On application start
Data: Available notification types and configurations
```

#### C. User Preferences (Current User)
```
Scope: Request/Session
TTL: Duration of user session
Data: Current user's preferences and settings
```

---

## Cache Keys and TTL Strategy

### TTL Guidelines

| Data Type | TTL | Reasoning |
|-----------|-----|-----------|
| User Feed | 5 min | Balance between freshness and load |
| User Profile | 15 min | Changes infrequently |
| Post Content | 30 min | Rarely edited after posting |
| Post Stats | 2 min | Frequently updated (reactions, comments) |
| User Stats | 10 min | Updated periodically |
| Trending Data | 10 min | Needs to be relatively fresh |
| Messages | 1 min | Near real-time requirement |
| Notifications | 30 sec | Real-time requirement |
| Static Content | 7-30 days | Versioned, immutable |
| Session Data | 24 hours | Security consideration |

### Key Naming Conventions

**Pattern**: `{entity}:{identifier}:{sub_entity}:{page/filter}`

**Examples**:
- `user:123:profile`
- `post:456:comments:page:1`
- `feed:user:789:ranked:page:1`
- `hashtag:technology:trending`

**Benefits**:
- Easy to understand
- Pattern-based invalidation
- Namespace organization

---

## Specific Caching Strategies

### 1. Feed Generation (Most Critical)

**Challenge**: Feed is personalized and expensive to compute

**Strategy**: Multi-Level Caching

#### Level 1: Pre-computed Activity Feed (Database)
```sql
-- Materialized feed stored in activity_feed table
-- Updated asynchronously when:
-- - User creates a post
-- - User follows someone
-- - Post gets engagement
```

#### Level 2: Redis Cache (Recent Pages)
```
Key: feed:user:{user_id}:page:{page_num}
Value: JSON array of post IDs with metadata
TTL: 5 minutes

Structure:
[
  {
    "post_id": 123,
    "score": 95.5,
    "created_at": "2025-11-09T10:30:00Z"
  },
  ...
]
```

#### Level 3: Read-Through Cache for Post Details
```
For each post_id in feed:
  1. Check cache: post:{post_id}
  2. If miss, fetch from database
  3. Store in cache with 30-min TTL
```

**Implementation**:
```python
def get_user_feed(user_id, page=1):
    cache_key = f"feed:user:{user_id}:page:{page}"
    
    # Try cache first
    cached_feed = redis.get(cache_key)
    if cached_feed:
        return json.loads(cached_feed)
    
    # Cache miss - fetch from database
    feed = fetch_feed_from_db(user_id, page)
    
    # Store in cache
    redis.setex(cache_key, 300, json.dumps(feed))
    
    return feed
```

---

### 2. User Profile Caching

**Strategy**: Cache-Aside Pattern

```python
def get_user_profile(user_id):
    cache_key = f"user:profile:{user_id}"
    
    # Try cache
    cached_profile = redis.hgetall(cache_key)
    if cached_profile:
        return cached_profile
    
    # Fetch from database
    profile = db.query("""
        SELECT u.*, up.*, us.*
        FROM users u
        JOIN user_profiles up ON u.user_id = up.user_id
        LEFT JOIN user_stats us ON u.user_id = us.user_id
        WHERE u.user_id = %s
    """, user_id)
    
    # Store in cache as hash
    redis.hmset(cache_key, profile)
    redis.expire(cache_key, 900)  # 15 minutes
    
    return profile
```

---

### 3. Post Statistics (Real-time Updates)

**Challenge**: Stats update frequently (reactions, comments)

**Strategy**: Write-Through Cache with Background Sync

**On Reaction/Comment**:
```python
def add_reaction_to_post(post_id, user_id, reaction_type):
    # 1. Write to database
    db.execute("""
        INSERT INTO post_reactions (post_id, user_id, reaction_type_id)
        VALUES (%s, %s, %s)
    """, post_id, user_id, reaction_type)
    
    # 2. Update cache immediately
    cache_key = f"post:stats:{post_id}"
    redis.hincrby(cache_key, "reactions_count", 1)
    redis.expire(cache_key, 120)  # 2 minutes
    
    # 3. Invalidate related caches
    invalidate_feed_cache(user_id)
```

**Background Sync**:
```python
# Periodic job to sync cache with database (every minute)
def sync_post_stats():
    for post_id in get_recently_active_posts():
        stats = db.query("SELECT * FROM post_stats WHERE post_id = %s", post_id)
        cache_key = f"post:stats:{post_id}"
        redis.hmset(cache_key, stats)
        redis.expire(cache_key, 120)
```

---

### 4. Messaging System Caching

**Strategy**: Cache recent conversations, invalidate aggressively

```python
def get_conversation_messages(conversation_id, page=1):
    cache_key = f"conversation:{conversation_id}:messages:page:{page}"
    
    # Only cache first page (most recent messages)
    if page == 1:
        cached = redis.get(cache_key)
        if cached:
            return json.loads(cached)
    
    # Fetch from database
    messages = fetch_messages_from_db(conversation_id, page)
    
    # Cache only first page with short TTL
    if page == 1:
        redis.setex(cache_key, 60, json.dumps(messages))  # 1 minute
    
    return messages

def send_message(conversation_id, sender_id, content):
    # Write to database
    message = db.create_message(conversation_id, sender_id, content)
    
    # Invalidate conversation cache
    cache_key = f"conversation:{conversation_id}:messages:page:1"
    redis.delete(cache_key)
    
    # Update conversation list cache for all participants
    participants = get_conversation_participants(conversation_id)
    for participant_id in participants:
        redis.delete(f"conversations:user:{participant_id}")
    
    return message
```

---

### 5. Notifications Caching

**Strategy**: Aggressive TTL with real-time invalidation

```python
def get_user_notifications(user_id):
    cache_key = f"notifications:user:{user_id}"
    
    cached = redis.get(cache_key)
    if cached:
        return json.loads(cached)
    
    notifications = fetch_notifications_from_db(user_id)
    
    # Short TTL due to real-time nature
    redis.setex(cache_key, 30, json.dumps(notifications))  # 30 seconds
    
    return notifications

def create_notification(user_id, notification_data):
    # Write to database
    db.create_notification(user_id, notification_data)
    
    # Invalidate user's notification cache
    redis.delete(f"notifications:user:{user_id}")
    
    # Optionally push via WebSocket for real-time delivery
    websocket.push(user_id, notification_data)
```

---

### 6. Trending Content Caching

**Strategy**: Pre-computed with scheduled refresh

```python
# Scheduled job (every 10 minutes)
def update_trending_cache():
    # Calculate trending posts
    trending_posts = db.query("""
        SELECT post_id, 
               (reactions_count + comments_count * 2 + shares_count * 3)::DECIMAL / 
               GREATEST(EXTRACT(EPOCH FROM (NOW() - created_at)) / 3600.0, 1) 
               AS velocity
        FROM posts p
        JOIN post_stats ps ON p.post_id = ps.post_id
        WHERE created_at > NOW() - INTERVAL '24 hours'
        ORDER BY velocity DESC
        LIMIT 100
    """)
    
    # Store in sorted set
    cache_key = "trending:posts:24h"
    redis.delete(cache_key)
    
    for post in trending_posts:
        redis.zadd(cache_key, {post.post_id: post.velocity})
    
    redis.expire(cache_key, 600)  # 10 minutes

def get_trending_posts(limit=50):
    cache_key = "trending:posts:24h"
    post_ids = redis.zrevrange(cache_key, 0, limit - 1)
    
    if not post_ids:
        # Cache miss - compute on demand
        update_trending_cache()
        post_ids = redis.zrevrange(cache_key, 0, limit - 1)
    
    # Fetch post details (with their own caching)
    return [get_post_details(post_id) for post_id in post_ids]
```

---

### 7. Search Results Caching

**Strategy**: Cache popular searches, skip caching for unique queries

```python
def search_posts(query, page=1):
    # Normalize query
    normalized_query = normalize_search_query(query)
    cache_key = f"search:posts:{normalized_query}:page:{page}"
    
    # Check query popularity
    query_count = redis.incr(f"search:popularity:{normalized_query}")
    redis.expire(f"search:popularity:{normalized_query}", 3600)
    
    # Only cache if query is popular (searched > 5 times in last hour)
    if query_count > 5:
        cached = redis.get(cache_key)
        if cached:
            return json.loads(cached)
    
    # Execute search
    results = execute_search(query, page)
    
    # Cache popular searches
    if query_count > 5:
        redis.setex(cache_key, 300, json.dumps(results))  # 5 minutes
    
    return results
```

---

## Cache Invalidation

### Strategies

#### 1. Time-Based (TTL)
- Simplest approach
- Suitable for data that changes predictably
- Risk: Serving stale data until expiration

#### 2. Event-Based (Write-Through/Write-Behind)
- Invalidate on data modification
- Most accurate
- Requires careful tracking of dependencies

#### 3. Pattern-Based
- Invalidate groups of related keys
- Use Redis `SCAN` with patterns
- Example: Delete all feed pages when new post is created

### Invalidation Matrix

| Event | Invalidate |
|-------|------------|
| User creates post | `feed:user:{user_id}:*` (own profile)<br>`feed:user:{follower_id}:*` (all followers)<br>`user:stats:{user_id}` |
| User follows someone | `user:following:{user_id}`<br>`user:followers:{followed_id}`<br>`user:stats:{user_id}`<br>`user:stats:{followed_id}`<br>`feed:user:{user_id}:*` |
| User reacts to post | `post:stats:{post_id}`<br>`post:{post_id}` (if includes reaction count) |
| User comments | `post:{post_id}:comments:*`<br>`post:stats:{post_id}` |
| User updates profile | `user:profile:{user_id}` |
| Message sent | `conversation:{conversation_id}:messages:page:1`<br>`conversations:user:{participant_id}` (all) |
| Notification created | `notifications:user:{user_id}` |

### Implementation Pattern

```python
class CacheInvalidator:
    def __init__(self, redis_client):
        self.redis = redis_client
    
    def invalidate_user_feed(self, user_id):
        """Invalidate all pages of user's feed"""
        pattern = f"feed:user:{user_id}:*"
        self.delete_by_pattern(pattern)
    
    def invalidate_follower_feeds(self, user_id):
        """Invalidate feeds of all followers when user posts"""
        follower_ids = self.get_follower_ids(user_id)
        for follower_id in follower_ids:
            self.invalidate_user_feed(follower_id)
    
    def delete_by_pattern(self, pattern):
        """Delete all keys matching pattern"""
        cursor = 0
        while True:
            cursor, keys = self.redis.scan(cursor, match=pattern, count=100)
            if keys:
                self.redis.delete(*keys)
            if cursor == 0:
                break
    
    def on_post_created(self, user_id, post_id):
        """Handle cache invalidation when post is created"""
        # Invalidate author's feed and stats
        self.invalidate_user_feed(user_id)
        self.redis.delete(f"user:stats:{user_id}")
        
        # Invalidate follower feeds (can be async for performance)
        queue_job('invalidate_follower_feeds', user_id)
```

---

## Implementation Guidelines

### 1. Cache Warming

Pre-populate cache with likely-needed data:

```python
def warm_cache_for_user(user_id):
    """Pre-load cache when user logs in"""
    # Load user profile
    get_user_profile(user_id)
    
    # Load first page of feed
    get_user_feed(user_id, page=1)
    
    # Load user stats
    get_user_stats(user_id)
    
    # Load unread notification count
    get_unread_notification_count(user_id)
```

### 2. Cache Stampede Prevention

Prevent multiple simultaneous cache rebuilds:

```python
import time
from threading import Lock

cache_locks = {}

def get_with_lock(cache_key, fetch_func, ttl=300):
    """Prevent cache stampede using distributed lock"""
    
    # Try cache first
    cached = redis.get(cache_key)
    if cached:
        return json.loads(cached)
    
    # Acquire lock
    lock_key = f"lock:{cache_key}"
    lock_acquired = redis.set(lock_key, "1", nx=True, ex=10)
    
    if lock_acquired:
        try:
            # Double-check cache (another thread might have populated it)
            cached = redis.get(cache_key)
            if cached:
                return json.loads(cached)
            
            # Fetch and cache
            data = fetch_func()
            redis.setex(cache_key, ttl, json.dumps(data))
            return data
        finally:
            redis.delete(lock_key)
    else:
        # Wait for other thread to populate cache
        time.sleep(0.1)
        return get_with_lock(cache_key, fetch_func, ttl)
```

### 3. Graceful Degradation

Handle cache failures gracefully:

```python
def get_user_feed_with_fallback(user_id, page=1):
    try:
        return get_user_feed_from_cache(user_id, page)
    except RedisConnectionError:
        logger.warning("Cache unavailable, falling back to database")
        return get_user_feed_from_database(user_id, page)
    except Exception as e:
        logger.error(f"Unexpected cache error: {e}")
        return get_user_feed_from_database(user_id, page)
```

### 4. Monitoring and Metrics

Track cache performance:

```python
class CacheMetrics:
    def __init__(self):
        self.hits = 0
        self.misses = 0
    
    def record_hit(self):
        self.hits += 1
        metrics.increment('cache.hit')
    
    def record_miss(self):
        self.misses += 1
        metrics.increment('cache.miss')
    
    def get_hit_rate(self):
        total = self.hits + self.misses
        return (self.hits / total * 100) if total > 0 else 0

def get_with_metrics(cache_key, fetch_func, metrics):
    cached = redis.get(cache_key)
    
    if cached:
        metrics.record_hit()
        return json.loads(cached)
    
    metrics.record_miss()
    data = fetch_func()
    redis.setex(cache_key, 300, json.dumps(data))
    return data
```

### 5. Cache Configuration

Recommended Redis configuration:

```redis
# Memory Management
maxmemory 4gb
maxmemory-policy allkeys-lru

# Persistence (for non-ephemeral data)
save 900 1
save 300 10
save 60 10000

# Replication (for high availability)
replica-read-only yes
min-replicas-to-write 1
min-replicas-max-lag 10

# Performance
tcp-backlog 511
timeout 0
tcp-keepalive 300
```

---

## Performance Targets

| Metric | Target | With Cache | Without Cache |
|--------|--------|------------|---------------|
| Feed Load Time | < 200ms | 50ms | 800ms |
| Profile Load | < 100ms | 30ms | 300ms |
| Post Details | < 150ms | 40ms | 400ms |
| Search Results | < 300ms | 100ms | 1200ms |
| Cache Hit Rate | > 80% | 85-95% | N/A |
| Cache Miss Penalty | < 3x | 2-3x slower | N/A |

---

## Summary

### Key Principles

1. **Cache Hot Data Aggressively**: Recent posts, active users, trending content
2. **Short TTLs for Real-time Data**: Messages, notifications (30s - 1min)
3. **Longer TTLs for Static Data**: User profiles, post content (15-30min)
4. **Multi-Level Caching**: CDN → Redis → Application → Database
5. **Proactive Invalidation**: Invalidate on writes, don't wait for expiry
6. **Graceful Degradation**: System should work (slower) if cache fails
7. **Monitor Cache Performance**: Track hit rates, response times

### Expected Improvements

- **70-90% reduction** in database load
- **3-5x faster** response times for common queries
- **10x improvement** in feed generation performance
- **Support for 10x more concurrent users** with same infrastructure

This caching strategy provides a solid foundation for building a scalable, high-performance social media platform.


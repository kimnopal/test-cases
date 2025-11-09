# Quick Reference Guide

## Setup Commands

### 1. Create Database
```bash
createdb social_media_db
```

### 2. Enable Extensions
```bash
psql -d social_media_db << EOF
CREATE EXTENSION IF NOT EXISTS pg_trgm;
EOF
```

### 3. Create Schema
```bash
psql -d social_media_db -f schema.sql
psql -d social_media_db -f indexes.sql
psql -d social_media_db -f triggers_and_functions.sql
```

### 4. Load Sample Data
```bash
psql -d social_media_db -f seed_data.sql
```

---

## Common Queries

### Get User Feed
```sql
-- Using pre-computed activity feed (fastest)
SELECT 
    p.post_id,
    p.content,
    u.username,
    ps.reactions_count,
    ps.comments_count
FROM activity_feed af
JOIN posts p ON af.post_id = p.post_id
JOIN users u ON p.user_id = u.user_id
LEFT JOIN post_stats ps ON p.post_id = ps.post_id
WHERE af.user_id = 1  -- User ID
ORDER BY af.score DESC, af.created_at DESC
LIMIT 20;
```

### Get User Profile
```sql
SELECT 
    u.user_id,
    u.username,
    u.email,
    up.full_name,
    up.bio,
    up.profile_picture_url,
    us.followers_count,
    us.following_count,
    us.posts_count
FROM users u
JOIN user_profiles up ON u.user_id = up.user_id
LEFT JOIN user_stats us ON u.user_id = us.user_id
WHERE u.user_id = 1;
```

### Get Post with Details
```sql
SELECT 
    p.*,
    u.username,
    up.full_name,
    ps.reactions_count,
    ps.comments_count,
    -- Media attachments
    json_agg(DISTINCT pm.*) as media,
    -- Hashtags
    array_agg(DISTINCT h.tag_name) as hashtags
FROM posts p
JOIN users u ON p.user_id = u.user_id
JOIN user_profiles up ON u.user_id = up.user_id
LEFT JOIN post_stats ps ON p.post_id = ps.post_id
LEFT JOIN post_media pm ON p.post_id = pm.post_id
LEFT JOIN post_hashtags ph ON p.post_id = ph.post_id
LEFT JOIN hashtags h ON ph.hashtag_id = h.hashtag_id
WHERE p.post_id = 1
GROUP BY p.post_id, u.user_id, up.profile_id, ps.post_id;
```

### Get Comments on Post
```sql
SELECT 
    c.comment_id,
    c.content,
    c.parent_comment_id,
    c.created_at,
    u.username,
    up.profile_picture_url,
    cs.reactions_count
FROM comments c
JOIN users u ON c.user_id = u.user_id
JOIN user_profiles up ON u.user_id = up.user_id
LEFT JOIN comment_stats cs ON c.comment_id = cs.comment_id
WHERE c.post_id = 1
  AND c.is_deleted = FALSE
ORDER BY c.created_at ASC;
```

### Search Posts
```sql
SELECT 
    p.post_id,
    p.content,
    u.username,
    ts_rank(to_tsvector('english', p.content), plainto_tsquery('english', 'technology')) AS relevance
FROM posts p
JOIN users u ON p.user_id = u.user_id
WHERE to_tsvector('english', p.content) @@ plainto_tsquery('english', 'technology')
  AND p.is_deleted = FALSE
ORDER BY relevance DESC
LIMIT 50;
```

### Get Trending Posts
```sql
SELECT 
    p.post_id,
    p.content,
    u.username,
    ps.reactions_count,
    ps.comments_count,
    (ps.reactions_count + ps.comments_count * 2 + ps.shares_count * 3)::DECIMAL / 
    GREATEST(EXTRACT(EPOCH FROM (NOW() - p.created_at)) / 3600.0, 1) AS velocity
FROM posts p
JOIN users u ON p.user_id = u.user_id
JOIN post_stats ps ON p.post_id = ps.post_id
WHERE p.created_at > NOW() - INTERVAL '24 hours'
  AND p.visibility = 'public'
ORDER BY velocity DESC
LIMIT 50;
```

### Get User's Unread Notifications
```sql
SELECT 
    n.notification_id,
    nt.type_name,
    n.content,
    n.created_at,
    u.username as actor_username
FROM notifications n
JOIN notification_types nt ON n.notification_type_id = nt.notification_type_id
LEFT JOIN users u ON n.actor_id = u.user_id
WHERE n.user_id = 1
  AND n.is_read = FALSE
ORDER BY n.created_at DESC;
```

### Get User's Conversations
```sql
SELECT 
    c.conversation_id,
    c.conversation_type,
    c.updated_at,
    -- Last message
    (SELECT m.content FROM messages m 
     WHERE m.conversation_id = c.conversation_id 
     ORDER BY m.created_at DESC LIMIT 1) as last_message,
    -- Unread count
    (SELECT COUNT(*) FROM messages m
     WHERE m.conversation_id = c.conversation_id
       AND m.created_at > cp.last_read_at
       AND m.sender_id != 1) as unread_count
FROM conversations c
JOIN conversation_participants cp ON c.conversation_id = cp.conversation_id
WHERE cp.user_id = 1
  AND cp.left_at IS NULL
ORDER BY c.updated_at DESC;
```

---

## Common Operations

### Create New User
```sql
-- Insert user
INSERT INTO users (username, email, password_hash)
VALUES ('newuser', 'newuser@example.com', '$2a$10$hashed_password')
RETURNING user_id;

-- Create profile
INSERT INTO user_profiles (user_id, full_name)
VALUES (?, 'New User');

-- Initialize stats
INSERT INTO user_stats (user_id)
VALUES (?);
```

### Create New Post
```sql
-- Insert post (triggers will handle stats and feed fan-out)
INSERT INTO posts (user_id, content, post_type, visibility)
VALUES (1, 'Hello World!', 'text', 'public')
RETURNING post_id;
```

### Follow User
```sql
-- Creates relationship (triggers update stats)
INSERT INTO user_relationships (follower_id, following_id, status)
VALUES (1, 2, 'active');
```

### React to Post
```sql
-- Add reaction (triggers update post stats)
INSERT INTO post_reactions (post_id, user_id, reaction_type_id)
VALUES (1, 1, 1)  -- reaction_type_id: 1=like, 2=love, etc.
ON CONFLICT (post_id, user_id) 
DO UPDATE SET reaction_type_id = EXCLUDED.reaction_type_id;
```

### Add Comment
```sql
-- Add comment (triggers update post stats)
INSERT INTO comments (post_id, user_id, content, parent_comment_id)
VALUES (1, 1, 'Great post!', NULL)
RETURNING comment_id;
```

### Mark Notification as Read
```sql
UPDATE notifications
SET is_read = TRUE, read_at = CURRENT_TIMESTAMP
WHERE notification_id = 1;
```

---

## Performance Monitoring

### Check Table Sizes
```sql
SELECT * FROM table_sizes;
```

### Check Index Usage
```sql
SELECT * FROM index_usage
WHERE index_scans < 100
ORDER BY index_scans ASC;
```

### Check Cache Hit Ratio
```sql
SELECT * FROM cache_hit_ratio;
-- Target: > 95%
```

### Analyze Query Performance
```sql
EXPLAIN ANALYZE
SELECT * FROM activity_feed WHERE user_id = 1 LIMIT 20;
```

### Find Slow Queries
```sql
SELECT 
    query,
    calls,
    total_time,
    mean_time,
    max_time
FROM pg_stat_statements
ORDER BY mean_time DESC
LIMIT 10;
```

---

## Maintenance Commands

### Vacuum Database
```sql
VACUUM ANALYZE;
```

### Reindex Database
```sql
REINDEX DATABASE social_media_db;
```

### Update Statistics
```sql
ANALYZE;
```

### Check Database Size
```sql
SELECT pg_size_pretty(pg_database_size('social_media_db'));
```

---

## Testing Queries

### Test Feed Performance
```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM activity_feed WHERE user_id = 1 
ORDER BY score DESC LIMIT 20;
```

### Test Search Performance
```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM posts 
WHERE to_tsvector('english', content) @@ plainto_tsquery('english', 'test')
LIMIT 50;
```

### Generate Test Data
```sql
-- Generate 1000 test users
INSERT INTO users (username, email, password_hash)
SELECT 
    'user_' || generate_series,
    'user_' || generate_series || '@test.com',
    '$2a$10$test'
FROM generate_series(1, 1000);
```

---

## PostgreSQL Configuration

### Recommended Settings

```conf
# Memory
shared_buffers = 4GB
effective_cache_size = 12GB
work_mem = 50MB
maintenance_work_mem = 1GB

# Query Planning
random_page_cost = 1.1  # For SSD
effective_io_concurrency = 200

# WAL
wal_buffers = 16MB
checkpoint_completion_target = 0.9

# Logging
log_min_duration_statement = 1000  # Log slow queries
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d '

# Connections
max_connections = 200
```

### PgBouncer Configuration

```ini
[databases]
social_media_db = host=localhost port=5432 dbname=social_media_db

[pgbouncer]
pool_mode = transaction
max_client_conn = 1000
default_pool_size = 20
reserve_pool_size = 5
```

---

## Redis Cache Examples

### Cache User Profile
```python
import redis
import json

r = redis.Redis()

def get_user_profile(user_id):
    cache_key = f"user:profile:{user_id}"
    cached = r.get(cache_key)
    
    if cached:
        return json.loads(cached)
    
    # Fetch from database
    profile = db.query("SELECT * FROM users WHERE user_id = %s", user_id)
    
    # Cache for 15 minutes
    r.setex(cache_key, 900, json.dumps(profile))
    return profile
```

### Cache User Feed
```python
def get_user_feed(user_id, page=1):
    cache_key = f"feed:user:{user_id}:page:{page}"
    cached = r.get(cache_key)
    
    if cached:
        return json.loads(cached)
    
    # Fetch from database
    feed = db.query("""
        SELECT * FROM activity_feed 
        WHERE user_id = %s 
        ORDER BY score DESC 
        LIMIT 20 OFFSET %s
    """, user_id, (page-1)*20)
    
    # Cache for 5 minutes
    r.setex(cache_key, 300, json.dumps(feed))
    return feed
```

---

## Troubleshooting

### Connection Issues
```bash
# Check PostgreSQL is running
sudo systemctl status postgresql

# Check connections
psql -d social_media_db -c "SELECT count(*) FROM pg_stat_activity;"
```

### Slow Queries
```sql
-- Enable pg_stat_statements
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Find slow queries
SELECT query, mean_time, calls 
FROM pg_stat_statements 
ORDER BY mean_time DESC 
LIMIT 10;
```

### Index Issues
```sql
-- Find unused indexes
SELECT 
    schemaname, 
    tablename, 
    indexname, 
    idx_scan
FROM pg_stat_user_indexes
WHERE idx_scan = 0
  AND indexname NOT LIKE '%_pkey';
```

### Disk Space
```sql
-- Check table sizes
SELECT 
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

---

## Backup & Restore

### Backup Database
```bash
# Full backup
pg_dump social_media_db > backup.sql

# Compressed backup
pg_dump social_media_db | gzip > backup.sql.gz

# Schema only
pg_dump --schema-only social_media_db > schema_backup.sql
```

### Restore Database
```bash
# Restore from backup
psql social_media_db < backup.sql

# Restore from compressed
gunzip -c backup.sql.gz | psql social_media_db
```

---

## Useful Functions

### Check if User Follows Another
```sql
SELECT is_following(1, 2);  -- Returns true/false
```

### Get Unread Notification Count
```sql
SELECT get_unread_notification_count(1);
```

### Mark All Notifications as Read
```sql
SELECT mark_all_notifications_read(1);
```

### Get Mutual Followers
```sql
SELECT get_mutual_followers_count(1, 2);
```

---

## Documentation Links

- **Schema**: `schema.sql` - Complete database schema
- **Indexes**: `indexes.sql` - All index definitions
- **Queries**: `queries.sql` - Complex query examples
- **Caching**: `caching_strategy.md` - Caching architecture
- **Design**: `DESIGN_DECISIONS.md` - Design rationale
- **Triggers**: `triggers_and_functions.sql` - Database functions
- **Seed Data**: `seed_data.sql` - Sample data
- **Assessment**: `ASSESSMENT_SUMMARY.md` - Complete analysis

---

**Last Updated**: November 2025  
**Database Version**: PostgreSQL 14+  
**Status**: Production Ready ✅


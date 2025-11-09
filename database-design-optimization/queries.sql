-- ============================================================================
-- COMPLEX SQL QUERIES FOR SOCIAL MEDIA PLATFORM
-- ============================================================================
-- Focus on: Feed generation, user discovery, content ranking, analytics
-- Optimized for performance with proper index usage
-- ============================================================================

-- ============================================================================
-- 1. FEED GENERATION QUERIES (MOST CRITICAL)
-- ============================================================================

-- ============================================================================
-- 1.1 Personalized Feed - Chronological (Latest posts from followed users)
-- ============================================================================
-- This is the main feed query that shows posts from users you follow
-- Includes post details, author info, and engagement stats

WITH followed_users AS (
    SELECT following_id
    FROM user_relationships
    WHERE follower_id = $1  -- Current user's ID
      AND status = 'active'
)
SELECT 
    p.post_id,
    p.content,
    p.post_type,
    p.visibility,
    p.created_at,
    -- Author information
    u.user_id,
    u.username,
    up.full_name,
    up.profile_picture_url,
    up.is_verified,
    -- Engagement statistics
    ps.views_count,
    ps.comments_count,
    ps.reactions_count,
    ps.shares_count,
    -- Check if current user has reacted
    EXISTS(
        SELECT 1 FROM post_reactions pr 
        WHERE pr.post_id = p.post_id AND pr.user_id = $1
    ) AS has_reacted,
    -- Check if current user has saved this post
    EXISTS(
        SELECT 1 FROM saved_posts sp 
        WHERE sp.post_id = p.post_id AND sp.user_id = $1
    ) AS has_saved,
    -- Media attachments count
    (SELECT COUNT(*) FROM post_media pm WHERE pm.post_id = p.post_id) AS media_count
FROM posts p
JOIN users u ON p.user_id = u.user_id
JOIN user_profiles up ON u.user_id = up.user_id
LEFT JOIN post_stats ps ON p.post_id = ps.post_id
WHERE p.user_id IN (SELECT following_id FROM followed_users)
  AND p.is_deleted = FALSE
  AND p.visibility IN ('public', 'friends_only')
  AND u.is_active = TRUE
ORDER BY p.created_at DESC
LIMIT $2 OFFSET $3;  -- Pagination parameters

-- ============================================================================
-- 1.2 Ranked Feed - Algorithm-based (Using engagement signals)
-- ============================================================================
-- Ranks posts based on recency, engagement, and relationship strength
-- Uses scoring algorithm for personalized ranking

WITH followed_users AS (
    SELECT 
        following_id,
        created_at as follow_date
    FROM user_relationships
    WHERE follower_id = $1
      AND status = 'active'
),
scored_posts AS (
    SELECT 
        p.post_id,
        p.content,
        p.post_type,
        p.created_at,
        u.user_id,
        u.username,
        up.full_name,
        up.profile_picture_url,
        ps.reactions_count,
        ps.comments_count,
        ps.shares_count,
        -- Scoring algorithm
        (
            -- Recency score (decay over time)
            (EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - p.created_at)) / 3600.0)^(-0.5) * 100 +
            -- Engagement score
            (ps.reactions_count * 1.0 + ps.comments_count * 2.0 + ps.shares_count * 3.0) * 0.1 +
            -- Relationship strength (newer follows get slight boost)
            CASE 
                WHEN fu.follow_date > CURRENT_TIMESTAMP - INTERVAL '7 days' THEN 5
                WHEN fu.follow_date > CURRENT_TIMESTAMP - INTERVAL '30 days' THEN 2
                ELSE 0
            END
        ) AS relevance_score
    FROM posts p
    JOIN followed_users fu ON p.user_id = fu.following_id
    JOIN users u ON p.user_id = u.user_id
    JOIN user_profiles up ON u.user_id = up.user_id
    LEFT JOIN post_stats ps ON p.post_id = ps.post_id
    WHERE p.is_deleted = FALSE
      AND p.visibility IN ('public', 'friends_only')
      AND u.is_active = TRUE
      AND p.created_at > CURRENT_TIMESTAMP - INTERVAL '7 days'  -- Recent posts only
)
SELECT *
FROM scored_posts
ORDER BY relevance_score DESC, created_at DESC
LIMIT $2 OFFSET $3;

-- ============================================================================
-- 1.3 Optimized Feed Using Pre-computed Activity Feed Table
-- ============================================================================
-- Fastest approach: Uses pre-computed activity_feed table
-- Feed items are pre-generated when posts are created or engagement happens

SELECT 
    af.feed_id,
    af.activity_type,
    af.score,
    -- Post details
    p.post_id,
    p.content,
    p.post_type,
    p.created_at,
    -- Author information
    u.user_id as author_id,
    u.username,
    up.full_name,
    up.profile_picture_url,
    -- Actor information (person who created the activity)
    actor_u.user_id as actor_id,
    actor_u.username as actor_username,
    actor_up.full_name as actor_full_name,
    -- Engagement stats
    ps.views_count,
    ps.comments_count,
    ps.reactions_count,
    ps.shares_count
FROM activity_feed af
JOIN posts p ON af.post_id = p.post_id
JOIN users u ON p.user_id = u.user_id
JOIN user_profiles up ON u.user_id = up.user_id
JOIN users actor_u ON af.actor_id = actor_u.user_id
JOIN user_profiles actor_up ON actor_u.user_id = actor_up.user_id
LEFT JOIN post_stats ps ON p.post_id = ps.post_id
WHERE af.user_id = $1  -- Current user's feed
  AND p.is_deleted = FALSE
ORDER BY af.score DESC, af.created_at DESC
LIMIT $2 OFFSET $3;

-- ============================================================================
-- 2. DISCOVER/EXPLORE FEED QUERIES
-- ============================================================================

-- ============================================================================
-- 2.1 Trending Posts (Based on recent engagement velocity)
-- ============================================================================
-- Shows posts with high engagement in recent time window

SELECT 
    p.post_id,
    p.content,
    p.post_type,
    p.created_at,
    u.username,
    up.full_name,
    up.profile_picture_url,
    ps.reactions_count,
    ps.comments_count,
    ps.shares_count,
    -- Engagement velocity (engagement per hour since posting)
    (ps.reactions_count + ps.comments_count * 2 + ps.shares_count * 3)::DECIMAL / 
    GREATEST(EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - p.created_at)) / 3600.0, 1) AS engagement_velocity
FROM posts p
JOIN users u ON p.user_id = u.user_id
JOIN user_profiles up ON u.user_id = up.user_id
JOIN post_stats ps ON p.post_id = ps.post_id
WHERE p.is_deleted = FALSE
  AND p.visibility = 'public'
  AND p.created_at > CURRENT_TIMESTAMP - INTERVAL '24 hours'
  AND (ps.reactions_count + ps.comments_count + ps.shares_count) > 10
ORDER BY engagement_velocity DESC, p.created_at DESC
LIMIT 50;

-- ============================================================================
-- 2.2 Top Posts by Hashtag
-- ============================================================================
-- Find most engaged posts for a specific hashtag

SELECT 
    p.post_id,
    p.content,
    p.created_at,
    u.username,
    up.full_name,
    up.profile_picture_url,
    ps.reactions_count,
    ps.comments_count,
    ps.shares_count,
    (ps.reactions_count + ps.comments_count * 2 + ps.shares_count * 3) AS total_engagement
FROM posts p
JOIN post_hashtags ph ON p.post_id = ph.post_id
JOIN hashtags h ON ph.hashtag_id = h.hashtag_id
JOIN users u ON p.user_id = u.user_id
JOIN user_profiles up ON u.user_id = up.user_id
LEFT JOIN post_stats ps ON p.post_id = ps.post_id
WHERE h.tag_name = $1  -- Hashtag to search
  AND p.is_deleted = FALSE
  AND p.visibility = 'public'
  AND p.created_at > CURRENT_TIMESTAMP - INTERVAL '30 days'
ORDER BY total_engagement DESC, p.created_at DESC
LIMIT 50;

-- ============================================================================
-- 2.3 Trending Hashtags
-- ============================================================================
-- Find hashtags with most recent usage

SELECT 
    h.hashtag_id,
    h.tag_name,
    COUNT(ph.post_id) as recent_usage_count,
    h.usage_count as total_usage_count
FROM hashtags h
JOIN post_hashtags ph ON h.hashtag_id = ph.hashtag_id
JOIN posts p ON ph.post_id = p.post_id
WHERE p.created_at > CURRENT_TIMESTAMP - INTERVAL '24 hours'
  AND p.is_deleted = FALSE
  AND p.visibility = 'public'
GROUP BY h.hashtag_id, h.tag_name, h.usage_count
HAVING COUNT(ph.post_id) > 5
ORDER BY recent_usage_count DESC
LIMIT 20;

-- ============================================================================
-- 3. USER DISCOVERY QUERIES
-- ============================================================================

-- ============================================================================
-- 3.1 Suggested Users to Follow
-- ============================================================================
-- Suggests users based on mutual followers (friend-of-friends algorithm)

WITH current_user_following AS (
    SELECT following_id
    FROM user_relationships
    WHERE follower_id = $1 AND status = 'active'
),
mutual_follower_counts AS (
    SELECT 
        ur.following_id as suggested_user_id,
        COUNT(*) as mutual_count
    FROM user_relationships ur
    WHERE ur.follower_id IN (SELECT following_id FROM current_user_following)
      AND ur.status = 'active'
      AND ur.following_id NOT IN (SELECT following_id FROM current_user_following)
      AND ur.following_id != $1  -- Don't suggest self
    GROUP BY ur.following_id
)
SELECT 
    u.user_id,
    u.username,
    up.full_name,
    up.profile_picture_url,
    up.bio,
    us.followers_count,
    us.posts_count,
    mfc.mutual_count
FROM mutual_follower_counts mfc
JOIN users u ON mfc.suggested_user_id = u.user_id
JOIN user_profiles up ON u.user_id = up.user_id
JOIN user_stats us ON u.user_id = us.user_id
WHERE u.is_active = TRUE
ORDER BY mfc.mutual_count DESC, us.followers_count DESC
LIMIT 20;

-- ============================================================================
-- 3.2 Popular/Influential Users
-- ============================================================================
-- Find users with high follower count and engagement

SELECT 
    u.user_id,
    u.username,
    up.full_name,
    up.profile_picture_url,
    up.bio,
    us.followers_count,
    us.following_count,
    us.posts_count,
    -- Calculate engagement rate
    COALESCE(
        (SELECT AVG(reactions_count + comments_count)
         FROM posts p
         JOIN post_stats ps ON p.post_id = ps.post_id
         WHERE p.user_id = u.user_id 
           AND p.created_at > CURRENT_TIMESTAMP - INTERVAL '30 days'
           AND p.is_deleted = FALSE), 0
    ) as avg_engagement
FROM users u
JOIN user_profiles up ON u.user_id = up.user_id
JOIN user_stats us ON u.user_id = us.user_id
WHERE u.is_active = TRUE
  AND u.is_verified = TRUE
  AND us.followers_count > 1000
ORDER BY us.followers_count DESC, avg_engagement DESC
LIMIT 50;

-- ============================================================================
-- 4. SEARCH QUERIES
-- ============================================================================

-- ============================================================================
-- 4.1 Full-Text Search on Posts
-- ============================================================================
-- Search posts by content using PostgreSQL full-text search

SELECT 
    p.post_id,
    p.content,
    p.post_type,
    p.created_at,
    u.username,
    up.full_name,
    up.profile_picture_url,
    ps.reactions_count,
    ps.comments_count,
    -- Relevance ranking
    ts_rank(to_tsvector('english', p.content), plainto_tsquery('english', $1)) AS relevance
FROM posts p
JOIN users u ON p.user_id = u.user_id
JOIN user_profiles up ON u.user_id = up.user_id
LEFT JOIN post_stats ps ON p.post_id = ps.post_id
WHERE p.is_deleted = FALSE
  AND p.visibility = 'public'
  AND to_tsvector('english', p.content) @@ plainto_tsquery('english', $1)
ORDER BY relevance DESC, p.created_at DESC
LIMIT 50;

-- ============================================================================
-- 4.2 User Search with Fuzzy Matching
-- ============================================================================
-- Search users by username or full name with typo tolerance

SELECT 
    u.user_id,
    u.username,
    up.full_name,
    up.profile_picture_url,
    us.followers_count,
    -- Similarity score using trigram matching
    GREATEST(
        similarity(u.username, $1),
        similarity(up.full_name, $1)
    ) AS similarity_score
FROM users u
JOIN user_profiles up ON u.user_id = up.user_id
LEFT JOIN user_stats us ON u.user_id = us.user_id
WHERE u.is_active = TRUE
  AND (
    u.username ILIKE '%' || $1 || '%'
    OR up.full_name ILIKE '%' || $1 || '%'
  )
ORDER BY similarity_score DESC, us.followers_count DESC
LIMIT 20;

-- ============================================================================
-- 5. POST DETAIL QUERIES
-- ============================================================================

-- ============================================================================
-- 5.1 Single Post with Complete Details
-- ============================================================================
-- Get full post details including author, media, and engagement breakdown

SELECT 
    p.post_id,
    p.content,
    p.post_type,
    p.visibility,
    p.created_at,
    p.updated_at,
    -- Author information
    u.user_id,
    u.username,
    up.full_name,
    up.profile_picture_url,
    up.bio,
    -- Statistics
    ps.views_count,
    ps.comments_count,
    ps.reactions_count,
    ps.shares_count,
    -- Media attachments
    (
        SELECT json_agg(
            json_build_object(
                'media_id', pm.media_id,
                'media_type', pm.media_type,
                'media_url', pm.media_url,
                'thumbnail_url', pm.thumbnail_url,
                'width', pm.width,
                'height', pm.height
            ) ORDER BY pm.display_order
        )
        FROM post_media pm
        WHERE pm.post_id = p.post_id
    ) AS media_attachments,
    -- Hashtags
    (
        SELECT json_agg(h.tag_name)
        FROM post_hashtags ph
        JOIN hashtags h ON ph.hashtag_id = h.hashtag_id
        WHERE ph.post_id = p.post_id
    ) AS hashtags,
    -- Reaction breakdown
    (
        SELECT json_object_agg(rt.reaction_name, reaction_counts.count)
        FROM (
            SELECT reaction_type_id, COUNT(*) as count
            FROM post_reactions
            WHERE post_id = p.post_id
            GROUP BY reaction_type_id
        ) reaction_counts
        JOIN reaction_types rt ON reaction_counts.reaction_type_id = rt.reaction_type_id
    ) AS reactions_breakdown
FROM posts p
JOIN users u ON p.user_id = u.user_id
JOIN user_profiles up ON u.user_id = up.user_id
LEFT JOIN post_stats ps ON p.post_id = ps.post_id
WHERE p.post_id = $1
  AND p.is_deleted = FALSE;

-- ============================================================================
-- 5.2 Comments on a Post with Nested Replies
-- ============================================================================
-- Get hierarchical comment structure (top-level comments with replies)

WITH RECURSIVE comment_tree AS (
    -- Top-level comments
    SELECT 
        c.comment_id,
        c.post_id,
        c.user_id,
        c.parent_comment_id,
        c.content,
        c.created_at,
        u.username,
        up.full_name,
        up.profile_picture_url,
        cs.reactions_count,
        cs.replies_count,
        1 AS depth,
        ARRAY[c.comment_id] AS path
    FROM comments c
    JOIN users u ON c.user_id = u.user_id
    JOIN user_profiles up ON u.user_id = up.user_id
    LEFT JOIN comment_stats cs ON c.comment_id = cs.comment_id
    WHERE c.post_id = $1
      AND c.parent_comment_id IS NULL
      AND c.is_deleted = FALSE
    
    UNION ALL
    
    -- Nested replies
    SELECT 
        c.comment_id,
        c.post_id,
        c.user_id,
        c.parent_comment_id,
        c.content,
        c.created_at,
        u.username,
        up.full_name,
        up.profile_picture_url,
        cs.reactions_count,
        cs.replies_count,
        ct.depth + 1,
        ct.path || c.comment_id
    FROM comments c
    JOIN comment_tree ct ON c.parent_comment_id = ct.comment_id
    JOIN users u ON c.user_id = u.user_id
    JOIN user_profiles up ON u.user_id = up.user_id
    LEFT JOIN comment_stats cs ON c.comment_id = cs.comment_id
    WHERE c.is_deleted = FALSE
      AND ct.depth < 5  -- Limit nesting depth
)
SELECT *
FROM comment_tree
ORDER BY path;

-- ============================================================================
-- 6. MESSAGING QUERIES
-- ============================================================================

-- ============================================================================
-- 6.1 User's Conversations List with Unread Count
-- ============================================================================

SELECT 
    c.conversation_id,
    c.conversation_type,
    c.conversation_name,
    c.updated_at,
    -- Last message
    (
        SELECT json_build_object(
            'message_id', m.message_id,
            'content', m.content,
            'sender_id', m.sender_id,
            'sender_username', u.username,
            'created_at', m.created_at
        )
        FROM messages m
        JOIN users u ON m.sender_id = u.user_id
        WHERE m.conversation_id = c.conversation_id
          AND m.is_deleted = FALSE
        ORDER BY m.created_at DESC
        LIMIT 1
    ) AS last_message,
    -- Unread message count
    (
        SELECT COUNT(*)
        FROM messages m
        WHERE m.conversation_id = c.conversation_id
          AND m.created_at > cp.last_read_at
          AND m.sender_id != $1
          AND m.is_deleted = FALSE
    ) AS unread_count,
    -- Participants
    (
        SELECT json_agg(
            json_build_object(
                'user_id', u.user_id,
                'username', u.username,
                'full_name', up.full_name,
                'profile_picture_url', up.profile_picture_url
            )
        )
        FROM conversation_participants cp2
        JOIN users u ON cp2.user_id = u.user_id
        JOIN user_profiles up ON u.user_id = up.user_id
        WHERE cp2.conversation_id = c.conversation_id
          AND cp2.left_at IS NULL
          AND cp2.user_id != $1
    ) AS other_participants
FROM conversations c
JOIN conversation_participants cp ON c.conversation_id = cp.conversation_id
WHERE cp.user_id = $1
  AND cp.left_at IS NULL
ORDER BY c.updated_at DESC
LIMIT 50;

-- ============================================================================
-- 6.2 Messages in a Conversation
-- ============================================================================

SELECT 
    m.message_id,
    m.content,
    m.message_type,
    m.created_at,
    m.updated_at,
    -- Sender information
    u.user_id as sender_id,
    u.username as sender_username,
    up.full_name as sender_full_name,
    up.profile_picture_url as sender_profile_picture,
    -- Media attachments
    (
        SELECT json_agg(
            json_build_object(
                'media_id', mm.media_id,
                'media_type', mm.media_type,
                'media_url', mm.media_url,
                'file_name', mm.file_name
            )
        )
        FROM message_media mm
        WHERE mm.message_id = m.message_id
    ) AS media_attachments,
    -- Read receipts
    (
        SELECT json_agg(
            json_build_object(
                'user_id', mrr.user_id,
                'read_at', mrr.read_at
            )
        )
        FROM message_read_receipts mrr
        WHERE mrr.message_id = m.message_id
    ) AS read_by
FROM messages m
JOIN users u ON m.sender_id = u.user_id
JOIN user_profiles up ON u.user_id = up.user_id
WHERE m.conversation_id = $1
  AND m.is_deleted = FALSE
ORDER BY m.created_at ASC
LIMIT $2 OFFSET $3;

-- ============================================================================
-- 7. NOTIFICATION QUERIES
-- ============================================================================

-- ============================================================================
-- 7.1 User's Recent Notifications
-- ============================================================================

SELECT 
    n.notification_id,
    n.notification_type_id,
    nt.type_name,
    n.entity_type,
    n.entity_id,
    n.content,
    n.is_read,
    n.created_at,
    -- Actor (person who triggered notification)
    u.user_id as actor_id,
    u.username as actor_username,
    up.full_name as actor_full_name,
    up.profile_picture_url as actor_profile_picture
FROM notifications n
JOIN notification_types nt ON n.notification_type_id = nt.notification_type_id
LEFT JOIN users u ON n.actor_id = u.user_id
LEFT JOIN user_profiles up ON u.user_id = up.user_id
WHERE n.user_id = $1
ORDER BY n.created_at DESC
LIMIT 50;

-- ============================================================================
-- 7.2 Unread Notification Count
-- ============================================================================

SELECT COUNT(*) as unread_count
FROM notifications
WHERE user_id = $1
  AND is_read = FALSE;

-- ============================================================================
-- 8. ANALYTICS QUERIES
-- ============================================================================

-- ============================================================================
-- 8.1 User Engagement Statistics
-- ============================================================================

SELECT 
    u.user_id,
    u.username,
    -- Post statistics
    COUNT(DISTINCT p.post_id) as total_posts,
    COALESCE(SUM(ps.reactions_count), 0) as total_reactions_received,
    COALESCE(SUM(ps.comments_count), 0) as total_comments_received,
    COALESCE(AVG(ps.reactions_count), 0) as avg_reactions_per_post,
    -- Activity statistics
    COUNT(DISTINCT pr.reaction_id) as total_reactions_given,
    COUNT(DISTINCT c.comment_id) as total_comments_made
FROM users u
LEFT JOIN posts p ON u.user_id = p.user_id AND p.is_deleted = FALSE
LEFT JOIN post_stats ps ON p.post_id = ps.post_id
LEFT JOIN post_reactions pr ON u.user_id = pr.user_id
LEFT JOIN comments c ON u.user_id = c.user_id AND c.is_deleted = FALSE
WHERE u.user_id = $1
GROUP BY u.user_id, u.username;

-- ============================================================================
-- 8.2 Daily Active Users (DAU)
-- ============================================================================

SELECT 
    DATE(last_activity_at) as activity_date,
    COUNT(DISTINCT user_id) as active_users
FROM user_sessions
WHERE last_activity_at > CURRENT_TIMESTAMP - INTERVAL '30 days'
GROUP BY DATE(last_activity_at)
ORDER BY activity_date DESC;

-- ============================================================================
-- 8.3 Top Posts by Engagement (Past 7 days)
-- ============================================================================

SELECT 
    p.post_id,
    p.content,
    p.created_at,
    u.username,
    ps.reactions_count,
    ps.comments_count,
    ps.shares_count,
    (ps.reactions_count + ps.comments_count * 2 + ps.shares_count * 3) as total_engagement
FROM posts p
JOIN users u ON p.user_id = u.user_id
JOIN post_stats ps ON p.post_id = ps.post_id
WHERE p.created_at > CURRENT_TIMESTAMP - INTERVAL '7 days'
  AND p.is_deleted = FALSE
  AND p.visibility = 'public'
ORDER BY total_engagement DESC
LIMIT 100;


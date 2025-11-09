-- ============================================================================
-- TRIGGERS AND FUNCTIONS FOR DATA CONSISTENCY
-- ============================================================================
-- Automatically maintain denormalized statistics and enforce business rules
-- ============================================================================

-- ============================================================================
-- USER STATISTICS MAINTENANCE
-- ============================================================================

-- Function to increment follower count
CREATE OR REPLACE FUNCTION increment_follower_count()
RETURNS TRIGGER AS $$
BEGIN
    -- Increment follower count for the user being followed
    INSERT INTO user_stats (user_id, followers_count)
    VALUES (NEW.following_id, 1)
    ON CONFLICT (user_id) 
    DO UPDATE SET followers_count = user_stats.followers_count + 1;
    
    -- Increment following count for the follower
    INSERT INTO user_stats (user_id, following_count)
    VALUES (NEW.follower_id, 1)
    ON CONFLICT (user_id) 
    DO UPDATE SET following_count = user_stats.following_count + 1;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to decrement follower count
CREATE OR REPLACE FUNCTION decrement_follower_count()
RETURNS TRIGGER AS $$
BEGIN
    -- Decrement follower count
    UPDATE user_stats 
    SET followers_count = GREATEST(followers_count - 1, 0)
    WHERE user_id = OLD.following_id;
    
    -- Decrement following count
    UPDATE user_stats 
    SET following_count = GREATEST(following_count - 1, 0)
    WHERE user_id = OLD.follower_id;
    
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Triggers for user relationships
CREATE TRIGGER trg_relationship_insert
AFTER INSERT ON user_relationships
FOR EACH ROW
WHEN (NEW.status = 'active')
EXECUTE FUNCTION increment_follower_count();

CREATE TRIGGER trg_relationship_delete
AFTER DELETE ON user_relationships
FOR EACH ROW
WHEN (OLD.status = 'active')
EXECUTE FUNCTION decrement_follower_count();

-- ============================================================================
-- POST STATISTICS MAINTENANCE
-- ============================================================================

-- Function to increment post count
CREATE OR REPLACE FUNCTION increment_post_count()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO user_stats (user_id, posts_count)
    VALUES (NEW.user_id, 1)
    ON CONFLICT (user_id) 
    DO UPDATE SET posts_count = user_stats.posts_count + 1;
    
    -- Initialize post stats
    INSERT INTO post_stats (post_id, views_count, comments_count, reactions_count, shares_count)
    VALUES (NEW.post_id, 0, 0, 0, 0);
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to decrement post count
CREATE OR REPLACE FUNCTION decrement_post_count()
RETURNS TRIGGER AS $$
BEGIN
    -- Only decrement if actually deleted, not soft delete
    IF OLD.is_deleted = FALSE AND NEW.is_deleted = TRUE THEN
        UPDATE user_stats 
        SET posts_count = GREATEST(posts_count - 1, 0)
        WHERE user_id = OLD.user_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for posts
CREATE TRIGGER trg_post_insert
AFTER INSERT ON posts
FOR EACH ROW
WHEN (NEW.is_deleted = FALSE)
EXECUTE FUNCTION increment_post_count();

CREATE TRIGGER trg_post_update
AFTER UPDATE ON posts
FOR EACH ROW
EXECUTE FUNCTION decrement_post_count();

-- ============================================================================
-- POST REACTION STATISTICS
-- ============================================================================

-- Function to update post reaction count
CREATE OR REPLACE FUNCTION update_post_reaction_count()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        UPDATE post_stats 
        SET reactions_count = reactions_count + 1
        WHERE post_id = NEW.post_id;
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        UPDATE post_stats 
        SET reactions_count = GREATEST(reactions_count - 1, 0)
        WHERE post_id = OLD.post_id;
        RETURN OLD;
    ELSIF (TG_OP = 'UPDATE') THEN
        -- If reaction type changed, count remains same
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Trigger for post reactions
CREATE TRIGGER trg_post_reaction_stats
AFTER INSERT OR DELETE OR UPDATE ON post_reactions
FOR EACH ROW
EXECUTE FUNCTION update_post_reaction_count();

-- ============================================================================
-- COMMENT STATISTICS
-- ============================================================================

-- Function to update post comment count
CREATE OR REPLACE FUNCTION update_post_comment_count()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        UPDATE post_stats 
        SET comments_count = comments_count + 1
        WHERE post_id = NEW.post_id;
        
        -- Initialize comment stats
        INSERT INTO comment_stats (comment_id, reactions_count, replies_count)
        VALUES (NEW.comment_id, 0, 0);
        
        -- If this is a reply, increment parent's reply count
        IF NEW.parent_comment_id IS NOT NULL THEN
            INSERT INTO comment_stats (comment_id, replies_count)
            VALUES (NEW.parent_comment_id, 1)
            ON CONFLICT (comment_id)
            DO UPDATE SET replies_count = comment_stats.replies_count + 1;
        END IF;
        
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        -- Only decrement if not soft delete
        IF OLD.is_deleted = FALSE THEN
            UPDATE post_stats 
            SET comments_count = GREATEST(comments_count - 1, 0)
            WHERE post_id = OLD.post_id;
            
            -- Decrement parent's reply count
            IF OLD.parent_comment_id IS NOT NULL THEN
                UPDATE comment_stats
                SET replies_count = GREATEST(replies_count - 1, 0)
                WHERE comment_id = OLD.parent_comment_id;
            END IF;
        END IF;
        RETURN OLD;
    ELSIF (TG_OP = 'UPDATE') THEN
        -- Handle soft delete
        IF OLD.is_deleted = FALSE AND NEW.is_deleted = TRUE THEN
            UPDATE post_stats 
            SET comments_count = GREATEST(comments_count - 1, 0)
            WHERE post_id = OLD.post_id;
        END IF;
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Trigger for comments
CREATE TRIGGER trg_comment_stats
AFTER INSERT OR DELETE OR UPDATE ON comments
FOR EACH ROW
EXECUTE FUNCTION update_post_comment_count();

-- ============================================================================
-- COMMENT REACTION STATISTICS
-- ============================================================================

-- Function to update comment reaction count
CREATE OR REPLACE FUNCTION update_comment_reaction_count()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        INSERT INTO comment_stats (comment_id, reactions_count)
        VALUES (NEW.comment_id, 1)
        ON CONFLICT (comment_id)
        DO UPDATE SET reactions_count = comment_stats.reactions_count + 1;
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        UPDATE comment_stats 
        SET reactions_count = GREATEST(reactions_count - 1, 0)
        WHERE comment_id = OLD.comment_id;
        RETURN OLD;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Trigger for comment reactions
CREATE TRIGGER trg_comment_reaction_stats
AFTER INSERT OR DELETE ON comment_reactions
FOR EACH ROW
EXECUTE FUNCTION update_comment_reaction_count();

-- ============================================================================
-- HASHTAG USAGE COUNT
-- ============================================================================

-- Function to update hashtag usage count
CREATE OR REPLACE FUNCTION update_hashtag_usage()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        UPDATE hashtags 
        SET usage_count = usage_count + 1
        WHERE hashtag_id = NEW.hashtag_id;
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        UPDATE hashtags 
        SET usage_count = GREATEST(usage_count - 1, 0)
        WHERE hashtag_id = OLD.hashtag_id;
        RETURN OLD;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Trigger for post hashtags
CREATE TRIGGER trg_hashtag_usage
AFTER INSERT OR DELETE ON post_hashtags
FOR EACH ROW
EXECUTE FUNCTION update_hashtag_usage();

-- ============================================================================
-- ACTIVITY FEED GENERATION (FAN-OUT ON WRITE)
-- ============================================================================

-- Function to fan-out post to followers' feeds
CREATE OR REPLACE FUNCTION fanout_post_to_followers()
RETURNS TRIGGER AS $$
DECLARE
    follower_record RECORD;
    base_score DECIMAL(10, 4);
BEGIN
    -- Calculate base score (can be enhanced with ML models)
    base_score := 100.0;
    
    -- Insert into activity feed for each follower
    FOR follower_record IN 
        SELECT follower_id 
        FROM user_relationships 
        WHERE following_id = NEW.user_id 
          AND status = 'active'
    LOOP
        INSERT INTO activity_feed (
            user_id, 
            post_id, 
            activity_type, 
            actor_id, 
            score, 
            created_at
        ) VALUES (
            follower_record.follower_id,
            NEW.post_id,
            'post',
            NEW.user_id,
            base_score,
            NEW.created_at
        );
    END LOOP;
    
    -- Also add to author's own feed
    INSERT INTO activity_feed (
        user_id, 
        post_id, 
        activity_type, 
        actor_id, 
        score, 
        created_at
    ) VALUES (
        NEW.user_id,
        NEW.post_id,
        'post',
        NEW.user_id,
        base_score,
        NEW.created_at
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for post fan-out (consider making this async for production)
CREATE TRIGGER trg_post_fanout
AFTER INSERT ON posts
FOR EACH ROW
WHEN (NEW.is_deleted = FALSE AND NEW.visibility IN ('public', 'friends_only'))
EXECUTE FUNCTION fanout_post_to_followers();

-- ============================================================================
-- CONVERSATION UPDATE TIMESTAMP
-- ============================================================================

-- Function to update conversation timestamp
CREATE OR REPLACE FUNCTION update_conversation_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE conversations 
    SET updated_at = NEW.created_at
    WHERE conversation_id = NEW.conversation_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for new messages
CREATE TRIGGER trg_conversation_timestamp
AFTER INSERT ON messages
FOR EACH ROW
WHEN (NEW.is_deleted = FALSE)
EXECUTE FUNCTION update_conversation_timestamp();

-- ============================================================================
-- UPDATED_AT TIMESTAMP AUTOMATION
-- ============================================================================

-- Generic function to update updated_at column
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to relevant tables
CREATE TRIGGER trg_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_posts_updated_at
BEFORE UPDATE ON posts
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_comments_updated_at
BEFORE UPDATE ON comments
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_messages_updated_at
BEFORE UPDATE ON messages
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- NOTIFICATION GENERATION
-- ============================================================================

-- Function to create notification for new follower
CREATE OR REPLACE FUNCTION create_follow_notification()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO notifications (
        user_id,
        notification_type_id,
        actor_id,
        entity_type,
        entity_id,
        content,
        created_at
    )
    SELECT 
        NEW.following_id,
        nt.notification_type_id,
        NEW.follower_id,
        'follow',
        NEW.relationship_id,
        u.username || ' started following you',
        CURRENT_TIMESTAMP
    FROM notification_types nt
    CROSS JOIN users u
    WHERE nt.type_name = 'new_follower'
      AND u.user_id = NEW.follower_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to create notification for reactions
CREATE OR REPLACE FUNCTION create_reaction_notification()
RETURNS TRIGGER AS $$
BEGIN
    -- Only notify if reactor is not the post author
    IF NEW.user_id != (SELECT user_id FROM posts WHERE post_id = NEW.post_id) THEN
        INSERT INTO notifications (
            user_id,
            notification_type_id,
            actor_id,
            entity_type,
            entity_id,
            content,
            created_at
        )
        SELECT 
            p.user_id,
            nt.notification_type_id,
            NEW.user_id,
            'reaction',
            NEW.post_id,
            u.username || ' reacted to your post',
            CURRENT_TIMESTAMP
        FROM posts p
        CROSS JOIN notification_types nt
        CROSS JOIN users u
        WHERE p.post_id = NEW.post_id
          AND nt.type_name = 'reaction'
          AND u.user_id = NEW.user_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to create notification for comments
CREATE OR REPLACE FUNCTION create_comment_notification()
RETURNS TRIGGER AS $$
BEGIN
    -- Notify post author if commenter is different
    IF NEW.user_id != (SELECT user_id FROM posts WHERE post_id = NEW.post_id) THEN
        INSERT INTO notifications (
            user_id,
            notification_type_id,
            actor_id,
            entity_type,
            entity_id,
            content,
            created_at
        )
        SELECT 
            p.user_id,
            nt.notification_type_id,
            NEW.user_id,
            'comment',
            NEW.comment_id,
            u.username || ' commented on your post',
            CURRENT_TIMESTAMP
        FROM posts p
        CROSS JOIN notification_types nt
        CROSS JOIN users u
        WHERE p.post_id = NEW.post_id
          AND nt.type_name = 'comment'
          AND u.user_id = NEW.user_id;
    END IF;
    
    -- If this is a reply, notify parent comment author
    IF NEW.parent_comment_id IS NOT NULL THEN
        INSERT INTO notifications (
            user_id,
            notification_type_id,
            actor_id,
            entity_type,
            entity_id,
            content,
            created_at
        )
        SELECT 
            c.user_id,
            nt.notification_type_id,
            NEW.user_id,
            'comment',
            NEW.comment_id,
            u.username || ' replied to your comment',
            CURRENT_TIMESTAMP
        FROM comments c
        CROSS JOIN notification_types nt
        CROSS JOIN users u
        WHERE c.comment_id = NEW.parent_comment_id
          AND c.user_id != NEW.user_id
          AND nt.type_name = 'reply'
          AND u.user_id = NEW.user_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for notifications (consider making these async for production)
CREATE TRIGGER trg_follow_notification
AFTER INSERT ON user_relationships
FOR EACH ROW
WHEN (NEW.status = 'active')
EXECUTE FUNCTION create_follow_notification();

CREATE TRIGGER trg_reaction_notification
AFTER INSERT ON post_reactions
FOR EACH ROW
EXECUTE FUNCTION create_reaction_notification();

CREATE TRIGGER trg_comment_notification
AFTER INSERT ON comments
FOR EACH ROW
WHEN (NEW.is_deleted = FALSE)
EXECUTE FUNCTION create_comment_notification();

-- ============================================================================
-- DATA VALIDATION FUNCTIONS
-- ============================================================================

-- Function to validate post content length
CREATE OR REPLACE FUNCTION validate_post_content()
RETURNS TRIGGER AS $$
BEGIN
    IF LENGTH(TRIM(NEW.content)) = 0 AND NEW.post_type = 'text' THEN
        RAISE EXCEPTION 'Text posts must have content';
    END IF;
    
    IF LENGTH(NEW.content) > 5000 THEN
        RAISE EXCEPTION 'Post content exceeds maximum length of 5000 characters';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for post validation
CREATE TRIGGER trg_validate_post
BEFORE INSERT OR UPDATE ON posts
FOR EACH ROW
EXECUTE FUNCTION validate_post_content();

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Function to get user's unread notification count
CREATE OR REPLACE FUNCTION get_unread_notification_count(p_user_id BIGINT)
RETURNS INTEGER AS $$
DECLARE
    unread_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO unread_count
    FROM notifications
    WHERE user_id = p_user_id
      AND is_read = FALSE;
    
    RETURN unread_count;
END;
$$ LANGUAGE plpgsql;

-- Function to mark all notifications as read
CREATE OR REPLACE FUNCTION mark_all_notifications_read(p_user_id BIGINT)
RETURNS INTEGER AS $$
DECLARE
    updated_count INTEGER;
BEGIN
    UPDATE notifications
    SET is_read = TRUE,
        read_at = CURRENT_TIMESTAMP
    WHERE user_id = p_user_id
      AND is_read = FALSE;
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RETURN updated_count;
END;
$$ LANGUAGE plpgsql;

-- Function to get user's follower-to-following ratio
CREATE OR REPLACE FUNCTION get_follower_ratio(p_user_id BIGINT)
RETURNS DECIMAL AS $$
DECLARE
    ratio DECIMAL;
BEGIN
    SELECT 
        CASE 
            WHEN following_count = 0 THEN followers_count::DECIMAL
            ELSE followers_count::DECIMAL / following_count::DECIMAL
        END INTO ratio
    FROM user_stats
    WHERE user_id = p_user_id;
    
    RETURN COALESCE(ratio, 0);
END;
$$ LANGUAGE plpgsql;

-- Function to check if user A follows user B
CREATE OR REPLACE FUNCTION is_following(p_follower_id BIGINT, p_following_id BIGINT)
RETURNS BOOLEAN AS $$
DECLARE
    following BOOLEAN;
BEGIN
    SELECT EXISTS(
        SELECT 1 
        FROM user_relationships 
        WHERE follower_id = p_follower_id 
          AND following_id = p_following_id
          AND status = 'active'
    ) INTO following;
    
    RETURN following;
END;
$$ LANGUAGE plpgsql;

-- Function to get mutual followers
CREATE OR REPLACE FUNCTION get_mutual_followers_count(
    p_user_id_1 BIGINT, 
    p_user_id_2 BIGINT
)
RETURNS INTEGER AS $$
DECLARE
    mutual_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO mutual_count
    FROM user_relationships ur1
    INNER JOIN user_relationships ur2 
        ON ur1.follower_id = ur2.follower_id
    WHERE ur1.following_id = p_user_id_1
      AND ur2.following_id = p_user_id_2
      AND ur1.status = 'active'
      AND ur2.status = 'active';
    
    RETURN mutual_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- SEED INITIAL DATA
-- ============================================================================

-- Insert default reaction types
INSERT INTO reaction_types (reaction_name, reaction_emoji, display_order) VALUES
    ('like', '👍', 1),
    ('love', '❤️', 2),
    ('laugh', '😂', 3),
    ('wow', '😮', 4),
    ('sad', '😢', 5),
    ('angry', '😠', 6)
ON CONFLICT (reaction_name) DO NOTHING;

-- Insert default notification types
INSERT INTO notification_types (type_name, type_description, is_active) VALUES
    ('new_follower', 'Someone followed you', TRUE),
    ('reaction', 'Someone reacted to your post', TRUE),
    ('comment', 'Someone commented on your post', TRUE),
    ('reply', 'Someone replied to your comment', TRUE),
    ('mention', 'Someone mentioned you', TRUE),
    ('message', 'New direct message', TRUE),
    ('tag', 'Someone tagged you in a post', TRUE)
ON CONFLICT (type_name) DO NOTHING;

-- ============================================================================
-- PERFORMANCE MONITORING VIEWS
-- ============================================================================

-- View for tracking table sizes
CREATE OR REPLACE VIEW table_sizes AS
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size,
    pg_total_relation_size(schemaname||'.'||tablename) AS size_bytes
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY size_bytes DESC;

-- View for index usage statistics
CREATE OR REPLACE VIEW index_usage AS
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan AS index_scans,
    idx_tup_read AS tuples_read,
    idx_tup_fetch AS tuples_fetched,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC;

-- View for cache hit ratio
CREATE OR REPLACE VIEW cache_hit_ratio AS
SELECT
    'index hit rate' AS metric,
    sum(idx_blks_hit) / NULLIF(sum(idx_blks_hit + idx_blks_read), 0) * 100 AS ratio
FROM pg_statio_user_indexes
UNION ALL
SELECT
    'table hit rate' AS metric,
    sum(heap_blks_hit) / NULLIF(sum(heap_blks_hit + heap_blks_read), 0) * 100 AS ratio
FROM pg_statio_user_tables;

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON FUNCTION increment_follower_count() IS 
'Maintains follower/following counts in user_stats when relationships are created';

COMMENT ON FUNCTION fanout_post_to_followers() IS 
'Fan-out strategy: Pre-computes feed entries when post is created. 
WARNING: Can be expensive for users with many followers. 
Consider async processing for users with >10K followers.';

COMMENT ON TABLE activity_feed IS 
'Pre-computed user feeds for fast retrieval. 
Trade-off: Write amplification (O(followers) per post) for fast reads (O(1) seek)';

COMMENT ON VIEW table_sizes IS 
'Monitor table sizes to identify candidates for partitioning or archival';

COMMENT ON VIEW cache_hit_ratio IS 
'Monitor PostgreSQL cache efficiency. Target: >95% hit ratio';


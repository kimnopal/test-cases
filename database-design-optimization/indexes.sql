-- ============================================================================
-- INDEXES FOR PERFORMANCE OPTIMIZATION
-- ============================================================================
-- Indexes designed for common query patterns in social media platforms
-- Focus on: feed generation, user lookups, timeline queries, messaging, search
-- ============================================================================

-- ============================================================================
-- USER TABLES INDEXES
-- ============================================================================

-- Username and email lookups (authentication)
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_email ON users(email);

-- Active user filtering
CREATE INDEX idx_users_active ON users(is_active) WHERE is_active = TRUE;

-- Last login tracking for analytics
CREATE INDEX idx_users_last_login ON users(last_login_at DESC);

-- Profile lookups
CREATE INDEX idx_user_profiles_user_id ON user_profiles(user_id);

-- Privacy-based queries
CREATE INDEX idx_user_profiles_privacy ON user_profiles(privacy_setting);

-- ============================================================================
-- RELATIONSHIPS INDEXES
-- ============================================================================

-- Critical for feed generation - find who user follows
CREATE INDEX idx_relationships_follower ON user_relationships(follower_id, created_at DESC) 
    WHERE status = 'active';

-- Find followers of a user (profile page)
CREATE INDEX idx_relationships_following ON user_relationships(following_id, created_at DESC) 
    WHERE status = 'active';

-- Check if user A follows user B (single query)
CREATE INDEX idx_relationships_pair ON user_relationships(follower_id, following_id) 
    WHERE status = 'active';

-- Composite index for relationship analytics
CREATE INDEX idx_relationships_status ON user_relationships(status, created_at DESC);

-- ============================================================================
-- POSTS INDEXES
-- ============================================================================

-- User's posts timeline (profile page)
CREATE INDEX idx_posts_user_created ON posts(user_id, created_at DESC) 
    WHERE is_deleted = FALSE;

-- Global posts by creation time (explore/discover feed)
CREATE INDEX idx_posts_created ON posts(created_at DESC) 
    WHERE is_deleted = FALSE AND visibility = 'public';

-- Posts by type for filtering
CREATE INDEX idx_posts_type ON posts(post_type, created_at DESC) 
    WHERE is_deleted = FALSE;

-- Visibility filtering
CREATE INDEX idx_posts_visibility ON posts(visibility, created_at DESC) 
    WHERE is_deleted = FALSE;

-- Composite index for feed queries (most important for feed generation)
CREATE INDEX idx_posts_feed_query ON posts(user_id, visibility, created_at DESC) 
    WHERE is_deleted = FALSE;

-- Post statistics lookup
CREATE INDEX idx_post_stats_reactions ON post_stats(reactions_count DESC);
CREATE INDEX idx_post_stats_comments ON post_stats(comments_count DESC);

-- ============================================================================
-- POST MEDIA INDEXES
-- ============================================================================

-- Media by post lookup
CREATE INDEX idx_post_media_post_id ON post_media(post_id, display_order);

-- Media type filtering
CREATE INDEX idx_post_media_type ON post_media(media_type, created_at DESC);

-- ============================================================================
-- HASHTAGS INDEXES
-- ============================================================================

-- Hashtag search (autocomplete, trending)
CREATE INDEX idx_hashtags_name ON hashtags(tag_name);
CREATE INDEX idx_hashtags_usage ON hashtags(usage_count DESC);

-- Text search on hashtag names (PostgreSQL specific)
CREATE INDEX idx_hashtags_name_trgm ON hashtags USING gin(tag_name gin_trgm_ops);

-- Post hashtag lookups
CREATE INDEX idx_post_hashtags_hashtag ON post_hashtags(hashtag_id);
CREATE INDEX idx_post_hashtags_post ON post_hashtags(post_id);

-- ============================================================================
-- COMMENTS INDEXES
-- ============================================================================

-- Comments on a post (most common query)
CREATE INDEX idx_comments_post_created ON comments(post_id, created_at DESC) 
    WHERE is_deleted = FALSE;

-- User's comment history
CREATE INDEX idx_comments_user ON comments(user_id, created_at DESC) 
    WHERE is_deleted = FALSE;

-- Nested comments (replies to a comment)
CREATE INDEX idx_comments_parent ON comments(parent_comment_id, created_at ASC) 
    WHERE is_deleted = FALSE AND parent_comment_id IS NOT NULL;

-- Top-level comments only
CREATE INDEX idx_comments_top_level ON comments(post_id, created_at DESC) 
    WHERE is_deleted = FALSE AND parent_comment_id IS NULL;

-- ============================================================================
-- REACTIONS INDEXES
-- ============================================================================

-- Post reactions by post
CREATE INDEX idx_post_reactions_post ON post_reactions(post_id, created_at DESC);

-- User's reaction history
CREATE INDEX idx_post_reactions_user ON post_reactions(user_id, created_at DESC);

-- Reaction type analytics
CREATE INDEX idx_post_reactions_type ON post_reactions(reaction_type_id, created_at DESC);

-- Check if user reacted to post
CREATE INDEX idx_post_reactions_user_post ON post_reactions(user_id, post_id);

-- Comment reactions
CREATE INDEX idx_comment_reactions_comment ON comment_reactions(comment_id, created_at DESC);
CREATE INDEX idx_comment_reactions_user ON comment_reactions(user_id, created_at DESC);

-- ============================================================================
-- MESSAGING INDEXES
-- ============================================================================

-- User's conversations list
CREATE INDEX idx_conversations_updated ON conversations(updated_at DESC);

-- Conversation participants lookup
CREATE INDEX idx_conversation_participants_user ON conversation_participants(user_id, last_read_at DESC) 
    WHERE left_at IS NULL;

CREATE INDEX idx_conversation_participants_conversation ON conversation_participants(conversation_id) 
    WHERE left_at IS NULL;

-- Messages in a conversation (chat history)
CREATE INDEX idx_messages_conversation_created ON messages(conversation_id, created_at DESC) 
    WHERE is_deleted = FALSE;

-- Unread messages count
CREATE INDEX idx_messages_conversation_unread ON messages(conversation_id, created_at DESC) 
    WHERE is_deleted = FALSE;

-- User's sent messages
CREATE INDEX idx_messages_sender ON messages(sender_id, created_at DESC) 
    WHERE is_deleted = FALSE;

-- Message media lookup
CREATE INDEX idx_message_media_message_id ON message_media(message_id);

-- Read receipts
CREATE INDEX idx_message_receipts_message ON message_read_receipts(message_id, read_at DESC);
CREATE INDEX idx_message_receipts_user ON message_read_receipts(user_id, read_at DESC);

-- ============================================================================
-- NOTIFICATIONS INDEXES
-- ============================================================================

-- User's notifications (most critical for notification center)
CREATE INDEX idx_notifications_user_created ON notifications(user_id, created_at DESC);

-- Unread notifications count
CREATE INDEX idx_notifications_user_unread ON notifications(user_id, is_read, created_at DESC) 
    WHERE is_read = FALSE;

-- Notifications by type
CREATE INDEX idx_notifications_type ON notifications(notification_type_id, created_at DESC);

-- Actor-based queries (who interacted with user)
CREATE INDEX idx_notifications_actor ON notifications(actor_id, created_at DESC);

-- Entity-based lookups
CREATE INDEX idx_notifications_entity ON notifications(entity_type, entity_id);

-- ============================================================================
-- ACTIVITY FEED INDEXES (CRITICAL FOR PERFORMANCE)
-- ============================================================================

-- User's personalized feed (THE MOST IMPORTANT INDEX)
-- This index is critical for feed generation performance
CREATE INDEX idx_activity_feed_user_score ON activity_feed(user_id, score DESC, created_at DESC);

-- Alternative index for chronological feed
CREATE INDEX idx_activity_feed_user_created ON activity_feed(user_id, created_at DESC);

-- Actor's activities (user profile activity)
CREATE INDEX idx_activity_feed_actor ON activity_feed(actor_id, created_at DESC);

-- Post engagement tracking
CREATE INDEX idx_activity_feed_post ON activity_feed(post_id, activity_type);

-- Composite index for filtered feed queries
CREATE INDEX idx_activity_feed_composite ON activity_feed(user_id, activity_type, created_at DESC);

-- ============================================================================
-- SAVED POSTS INDEXES
-- ============================================================================

-- User's saved posts
CREATE INDEX idx_saved_posts_user ON saved_posts(user_id, saved_at DESC);

-- Collection-based queries
CREATE INDEX idx_saved_posts_collection ON saved_posts(user_id, collection_name, saved_at DESC);

-- Check if post is saved
CREATE INDEX idx_saved_posts_post ON saved_posts(post_id);

-- ============================================================================
-- REPORTS AND MODERATION INDEXES
-- ============================================================================

-- Pending reports for moderation queue
CREATE INDEX idx_reports_status_created ON reports(status, created_at DESC) 
    WHERE status = 'pending';

-- Reports by entity
CREATE INDEX idx_reports_entity ON reports(entity_type, entity_id);

-- Reporter's history
CREATE INDEX idx_reports_reporter ON reports(reporter_id, created_at DESC);

-- ============================================================================
-- ANALYTICS INDEXES
-- ============================================================================

-- Active user sessions
CREATE INDEX idx_sessions_user_active ON user_sessions(user_id, last_activity_at DESC) 
    WHERE ended_at IS NULL;

-- Session token lookup (authentication)
CREATE INDEX idx_sessions_token ON user_sessions(session_token) 
    WHERE ended_at IS NULL;

-- Device type analytics
CREATE INDEX idx_sessions_device ON user_sessions(device_type, started_at DESC);

-- ============================================================================
-- FULL-TEXT SEARCH INDEXES (PostgreSQL)
-- ============================================================================

-- Post content search
CREATE INDEX idx_posts_content_fts ON posts USING gin(to_tsvector('english', content)) 
    WHERE is_deleted = FALSE;

-- User search (username, full name)
CREATE INDEX idx_users_search_fts ON users USING gin(to_tsvector('english', username));

-- Profile search
CREATE INDEX idx_profiles_search_fts ON user_profiles 
    USING gin(to_tsvector('english', coalesce(full_name, '') || ' ' || coalesce(bio, '')));

-- Comment search
CREATE INDEX idx_comments_content_fts ON comments USING gin(to_tsvector('english', content)) 
    WHERE is_deleted = FALSE;

-- ============================================================================
-- TRIGRAM INDEXES FOR FUZZY SEARCH (Requires pg_trgm extension)
-- ============================================================================

-- Enable pg_trgm extension first
-- CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Fuzzy username search (autocomplete, typo tolerance)
CREATE INDEX idx_users_username_trgm ON users USING gin(username gin_trgm_ops);

-- Fuzzy full name search
CREATE INDEX idx_profiles_fullname_trgm ON user_profiles USING gin(full_name gin_trgm_ops);

-- ============================================================================
-- COVERING INDEXES FOR COMMON QUERIES
-- ============================================================================

-- Covering index for feed query with post details
CREATE INDEX idx_posts_feed_covering ON posts(user_id, created_at DESC) 
    INCLUDE (post_id, content, post_type, visibility)
    WHERE is_deleted = FALSE;

-- Covering index for user list with stats
CREATE INDEX idx_users_list_covering ON users(username) 
    INCLUDE (user_id, email, created_at, is_verified)
    WHERE is_active = TRUE;

-- ============================================================================
-- PARTIAL INDEXES FOR EDGE CASES
-- ============================================================================

-- Recently active users (last 30 days)
CREATE INDEX idx_users_recent_active ON users(last_login_at DESC) 
    WHERE last_login_at > CURRENT_TIMESTAMP - INTERVAL '30 days';

-- Verified users only
CREATE INDEX idx_users_verified ON users(username) 
    WHERE is_verified = TRUE;

-- Popular posts (with significant engagement)
CREATE INDEX idx_posts_popular ON posts(created_at DESC) 
    WHERE is_deleted = FALSE 
    AND post_id IN (
        SELECT post_id FROM post_stats 
        WHERE reactions_count + comments_count + shares_count > 100
    );


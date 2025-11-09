-- ============================================================================
-- SOCIAL MEDIA PLATFORM - DATABASE SCHEMA
-- ============================================================================
-- Design follows 3NF normalization principles
-- Optimized for read-heavy workloads typical of social media platforms
-- ============================================================================

-- ============================================================================
-- USERS AND PROFILES
-- ============================================================================

-- Core user accounts table
CREATE TABLE users (
    user_id BIGSERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_login_at TIMESTAMP WITH TIME ZONE,
    is_active BOOLEAN DEFAULT TRUE,
    is_verified BOOLEAN DEFAULT FALSE,
    
    -- Indexes for authentication and lookups
    CONSTRAINT username_length CHECK (LENGTH(username) >= 3),
    CONSTRAINT email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

-- Extended user profile information
CREATE TABLE user_profiles (
    profile_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL UNIQUE,
    full_name VARCHAR(100),
    bio TEXT,
    profile_picture_url VARCHAR(500),
    cover_photo_url VARCHAR(500),
    location VARCHAR(100),
    website VARCHAR(255),
    date_of_birth DATE,
    privacy_setting VARCHAR(20) DEFAULT 'public',
    
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT privacy_values CHECK (privacy_setting IN ('public', 'private', 'friends_only'))
);

-- User statistics (denormalized for performance)
CREATE TABLE user_stats (
    user_id BIGINT PRIMARY KEY,
    followers_count INTEGER DEFAULT 0,
    following_count INTEGER DEFAULT 0,
    posts_count INTEGER DEFAULT 0,
    
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT positive_counts CHECK (
        followers_count >= 0 AND 
        following_count >= 0 AND 
        posts_count >= 0
    )
);

-- ============================================================================
-- RELATIONSHIPS (FOLLOWERS/FOLLOWING)
-- ============================================================================

-- User follows/following relationships
CREATE TABLE user_relationships (
    relationship_id BIGSERIAL PRIMARY KEY,
    follower_id BIGINT NOT NULL,
    following_id BIGINT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) DEFAULT 'active',
    
    FOREIGN KEY (follower_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (following_id) REFERENCES users(user_id) ON DELETE CASCADE,
    
    -- Prevent self-follows and duplicate relationships
    CONSTRAINT no_self_follow CHECK (follower_id != following_id),
    CONSTRAINT unique_relationship UNIQUE (follower_id, following_id),
    CONSTRAINT status_values CHECK (status IN ('active', 'blocked', 'pending'))
);

-- ============================================================================
-- POSTS AND MULTIMEDIA CONTENT
-- ============================================================================

-- Main posts table
CREATE TABLE posts (
    post_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    content TEXT,
    post_type VARCHAR(20) DEFAULT 'text',
    visibility VARCHAR(20) DEFAULT 'public',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMP WITH TIME ZONE,
    
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT post_type_values CHECK (post_type IN ('text', 'image', 'video', 'link', 'poll')),
    CONSTRAINT visibility_values CHECK (visibility IN ('public', 'private', 'friends_only'))
);

-- Post statistics (denormalized for performance)
CREATE TABLE post_stats (
    post_id BIGINT PRIMARY KEY,
    views_count INTEGER DEFAULT 0,
    comments_count INTEGER DEFAULT 0,
    reactions_count INTEGER DEFAULT 0,
    shares_count INTEGER DEFAULT 0,
    
    FOREIGN KEY (post_id) REFERENCES posts(post_id) ON DELETE CASCADE,
    CONSTRAINT positive_stats CHECK (
        views_count >= 0 AND 
        comments_count >= 0 AND 
        reactions_count >= 0 AND 
        shares_count >= 0
    )
);

-- Multimedia attachments for posts
CREATE TABLE post_media (
    media_id BIGSERIAL PRIMARY KEY,
    post_id BIGINT NOT NULL,
    media_type VARCHAR(20) NOT NULL,
    media_url VARCHAR(500) NOT NULL,
    thumbnail_url VARCHAR(500),
    width INTEGER,
    height INTEGER,
    file_size BIGINT,
    duration INTEGER, -- For video/audio in seconds
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (post_id) REFERENCES posts(post_id) ON DELETE CASCADE,
    CONSTRAINT media_type_values CHECK (media_type IN ('image', 'video', 'audio', 'document'))
);

-- Hashtags for content discovery
CREATE TABLE hashtags (
    hashtag_id BIGSERIAL PRIMARY KEY,
    tag_name VARCHAR(100) NOT NULL UNIQUE,
    usage_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Post-hashtag mapping
CREATE TABLE post_hashtags (
    post_id BIGINT NOT NULL,
    hashtag_id BIGINT NOT NULL,
    
    PRIMARY KEY (post_id, hashtag_id),
    FOREIGN KEY (post_id) REFERENCES posts(post_id) ON DELETE CASCADE,
    FOREIGN KEY (hashtag_id) REFERENCES hashtags(hashtag_id) ON DELETE CASCADE
);

-- ============================================================================
-- COMMENTS SYSTEM
-- ============================================================================

-- Comments on posts (supports nested comments)
CREATE TABLE comments (
    comment_id BIGSERIAL PRIMARY KEY,
    post_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    parent_comment_id BIGINT, -- For nested replies
    content TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMP WITH TIME ZONE,
    
    FOREIGN KEY (post_id) REFERENCES posts(post_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (parent_comment_id) REFERENCES comments(comment_id) ON DELETE CASCADE,
    CONSTRAINT content_not_empty CHECK (LENGTH(TRIM(content)) > 0)
);

-- Comment statistics
CREATE TABLE comment_stats (
    comment_id BIGINT PRIMARY KEY,
    reactions_count INTEGER DEFAULT 0,
    replies_count INTEGER DEFAULT 0,
    
    FOREIGN KEY (comment_id) REFERENCES comments(comment_id) ON DELETE CASCADE,
    CONSTRAINT positive_comment_stats CHECK (reactions_count >= 0 AND replies_count >= 0)
);

-- ============================================================================
-- REACTIONS SYSTEM
-- ============================================================================

-- Reaction types (like, love, laugh, etc.)
CREATE TABLE reaction_types (
    reaction_type_id SERIAL PRIMARY KEY,
    reaction_name VARCHAR(50) NOT NULL UNIQUE,
    reaction_emoji VARCHAR(10) NOT NULL,
    display_order INTEGER DEFAULT 0
);

-- Reactions on posts
CREATE TABLE post_reactions (
    reaction_id BIGSERIAL PRIMARY KEY,
    post_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    reaction_type_id INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (post_id) REFERENCES posts(post_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (reaction_type_id) REFERENCES reaction_types(reaction_type_id),
    
    -- One reaction per user per post
    CONSTRAINT unique_post_reaction UNIQUE (post_id, user_id)
);

-- Reactions on comments
CREATE TABLE comment_reactions (
    reaction_id BIGSERIAL PRIMARY KEY,
    comment_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    reaction_type_id INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (comment_id) REFERENCES comments(comment_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (reaction_type_id) REFERENCES reaction_types(reaction_type_id),
    
    -- One reaction per user per comment
    CONSTRAINT unique_comment_reaction UNIQUE (comment_id, user_id)
);

-- ============================================================================
-- PRIVATE MESSAGING SYSTEM
-- ============================================================================

-- Conversation threads
CREATE TABLE conversations (
    conversation_id BIGSERIAL PRIMARY KEY,
    conversation_type VARCHAR(20) DEFAULT 'direct',
    conversation_name VARCHAR(100),
    created_by BIGINT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (created_by) REFERENCES users(user_id),
    CONSTRAINT conversation_type_values CHECK (conversation_type IN ('direct', 'group'))
);

-- Participants in conversations
CREATE TABLE conversation_participants (
    participant_id BIGSERIAL PRIMARY KEY,
    conversation_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    left_at TIMESTAMP WITH TIME ZONE,
    is_admin BOOLEAN DEFAULT FALSE,
    last_read_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    is_muted BOOLEAN DEFAULT FALSE,
    
    FOREIGN KEY (conversation_id) REFERENCES conversations(conversation_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT unique_participant UNIQUE (conversation_id, user_id)
);

-- Messages in conversations
CREATE TABLE messages (
    message_id BIGSERIAL PRIMARY KEY,
    conversation_id BIGINT NOT NULL,
    sender_id BIGINT NOT NULL,
    content TEXT,
    message_type VARCHAR(20) DEFAULT 'text',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMP WITH TIME ZONE,
    
    FOREIGN KEY (conversation_id) REFERENCES conversations(conversation_id) ON DELETE CASCADE,
    FOREIGN KEY (sender_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT message_type_values CHECK (message_type IN ('text', 'image', 'video', 'audio', 'file', 'location'))
);

-- Message media attachments
CREATE TABLE message_media (
    media_id BIGSERIAL PRIMARY KEY,
    message_id BIGINT NOT NULL,
    media_type VARCHAR(20) NOT NULL,
    media_url VARCHAR(500) NOT NULL,
    file_name VARCHAR(255),
    file_size BIGINT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (message_id) REFERENCES messages(message_id) ON DELETE CASCADE,
    CONSTRAINT message_media_type_values CHECK (media_type IN ('image', 'video', 'audio', 'document'))
);

-- Message read receipts
CREATE TABLE message_read_receipts (
    receipt_id BIGSERIAL PRIMARY KEY,
    message_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    read_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (message_id) REFERENCES messages(message_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT unique_read_receipt UNIQUE (message_id, user_id)
);

-- ============================================================================
-- NOTIFICATIONS SYSTEM
-- ============================================================================

-- Notification types
CREATE TABLE notification_types (
    notification_type_id SERIAL PRIMARY KEY,
    type_name VARCHAR(50) NOT NULL UNIQUE,
    type_description TEXT,
    is_active BOOLEAN DEFAULT TRUE
);

-- User notifications
CREATE TABLE notifications (
    notification_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    notification_type_id INTEGER NOT NULL,
    actor_id BIGINT, -- User who triggered the notification
    entity_type VARCHAR(50), -- 'post', 'comment', 'message', etc.
    entity_id BIGINT, -- ID of the related entity
    content TEXT,
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (actor_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (notification_type_id) REFERENCES notification_types(notification_type_id),
    CONSTRAINT entity_type_values CHECK (entity_type IN ('post', 'comment', 'reaction', 'follow', 'message', 'mention', 'tag'))
);

-- User notification preferences
CREATE TABLE notification_preferences (
    preference_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    notification_type_id INTEGER NOT NULL,
    is_enabled BOOLEAN DEFAULT TRUE,
    push_enabled BOOLEAN DEFAULT TRUE,
    email_enabled BOOLEAN DEFAULT FALSE,
    
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (notification_type_id) REFERENCES notification_types(notification_type_id),
    CONSTRAINT unique_user_notification_pref UNIQUE (user_id, notification_type_id)
);

-- ============================================================================
-- ACTIVITY FEEDS
-- ============================================================================

-- User activity feed (pre-computed for performance)
CREATE TABLE activity_feed (
    feed_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    post_id BIGINT NOT NULL,
    activity_type VARCHAR(50) NOT NULL,
    actor_id BIGINT NOT NULL, -- User who created the activity
    score DECIMAL(10, 4) DEFAULT 0, -- For ranking/sorting
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (post_id) REFERENCES posts(post_id) ON DELETE CASCADE,
    FOREIGN KEY (actor_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT activity_type_values CHECK (activity_type IN ('post', 'share', 'comment', 'reaction'))
);

-- ============================================================================
-- SAVED AND BOOKMARKED CONTENT
-- ============================================================================

-- User saved posts
CREATE TABLE saved_posts (
    saved_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    post_id BIGINT NOT NULL,
    collection_name VARCHAR(100),
    saved_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (post_id) REFERENCES posts(post_id) ON DELETE CASCADE,
    CONSTRAINT unique_saved_post UNIQUE (user_id, post_id)
);

-- ============================================================================
-- REPORTING AND MODERATION
-- ============================================================================

-- Content reports
CREATE TABLE reports (
    report_id BIGSERIAL PRIMARY KEY,
    reporter_id BIGINT NOT NULL,
    entity_type VARCHAR(50) NOT NULL,
    entity_id BIGINT NOT NULL,
    reason VARCHAR(100) NOT NULL,
    description TEXT,
    status VARCHAR(20) DEFAULT 'pending',
    reviewed_by BIGINT,
    reviewed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (reporter_id) REFERENCES users(user_id),
    FOREIGN KEY (reviewed_by) REFERENCES users(user_id),
    CONSTRAINT report_entity_type CHECK (entity_type IN ('post', 'comment', 'user', 'message')),
    CONSTRAINT report_status CHECK (status IN ('pending', 'reviewed', 'resolved', 'dismissed'))
);

-- ============================================================================
-- ANALYTICS AND TRACKING
-- ============================================================================

-- User sessions for analytics
CREATE TABLE user_sessions (
    session_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    session_token VARCHAR(255) NOT NULL UNIQUE,
    ip_address INET,
    user_agent TEXT,
    device_type VARCHAR(50),
    started_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_activity_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    ended_at TIMESTAMP WITH TIME ZONE,
    
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);


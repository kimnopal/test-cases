-- ============================================================================
-- SAMPLE DATA FOR TESTING
-- ============================================================================
-- This file generates sample data to test queries and demonstrate the schema
-- ============================================================================

BEGIN;

-- ============================================================================
-- USERS AND PROFILES
-- ============================================================================

-- Insert sample users
INSERT INTO users (username, email, password_hash, is_verified, created_at) VALUES
    ('alice_wonder', 'alice@example.com', '$2a$10$xyzABCDEF1234567890hash', TRUE, CURRENT_TIMESTAMP - INTERVAL '365 days'),
    ('bob_builder', 'bob@example.com', '$2a$10$xyzABCDEF1234567890hash', TRUE, CURRENT_TIMESTAMP - INTERVAL '300 days'),
    ('charlie_brown', 'charlie@example.com', '$2a$10$xyzABCDEF1234567890hash', TRUE, CURRENT_TIMESTAMP - INTERVAL '250 days'),
    ('diana_prince', 'diana@example.com', '$2a$10$xyzABCDEF1234567890hash', TRUE, CURRENT_TIMESTAMP - INTERVAL '200 days'),
    ('eve_online', 'eve@example.com', '$2a$10$xyzABCDEF1234567890hash', FALSE, CURRENT_TIMESTAMP - INTERVAL '150 days'),
    ('frank_ocean', 'frank@example.com', '$2a$10$xyzABCDEF1234567890hash', TRUE, CURRENT_TIMESTAMP - INTERVAL '100 days'),
    ('grace_hopper', 'grace@example.com', '$2a$10$xyzABCDEF1234567890hash', TRUE, CURRENT_TIMESTAMP - INTERVAL '50 days'),
    ('henry_ford', 'henry@example.com', '$2a$10$xyzABCDEF1234567890hash', FALSE, CURRENT_TIMESTAMP - INTERVAL '30 days'),
    ('iris_west', 'iris@example.com', '$2a$10$xyzABCDEF1234567890hash', TRUE, CURRENT_TIMESTAMP - INTERVAL '20 days'),
    ('jack_sparrow', 'jack@example.com', '$2a$10$xyzABCDEF1234567890hash', TRUE, CURRENT_TIMESTAMP - INTERVAL '10 days');

-- Insert user profiles
INSERT INTO user_profiles (user_id, full_name, bio, location, privacy_setting) VALUES
    (1, 'Alice Wonderland', 'Exploring the rabbit hole of technology 🐰', 'San Francisco, CA', 'public'),
    (2, 'Bob Builder', 'Can we fix it? Yes we can! 🔧', 'New York, NY', 'public'),
    (3, 'Charlie Brown', 'Good grief! Life is full of surprises', 'Chicago, IL', 'public'),
    (4, 'Diana Prince', 'Truth and justice advocate 🦸‍♀️', 'Washington, DC', 'public'),
    (5, 'Eve Online', 'Gaming enthusiast and streamer 🎮', 'Austin, TX', 'private'),
    (6, 'Frank Ocean', 'Music producer and artist 🎵', 'Los Angeles, CA', 'public'),
    (7, 'Grace Hopper', 'Computer scientist and mathematician 💻', 'Boston, MA', 'public'),
    (8, 'Henry Ford', 'Entrepreneur and innovator 🚗', 'Detroit, MI', 'friends_only'),
    (9, 'Iris West', 'Journalist chasing the story 📰', 'Central City', 'public'),
    (10, 'Jack Sparrow', 'Captain and treasure hunter ⚓', 'Caribbean', 'public');

-- Initialize user stats (triggers will maintain these)
INSERT INTO user_stats (user_id, followers_count, following_count, posts_count) 
SELECT user_id, 0, 0, 0 FROM users;

-- ============================================================================
-- USER RELATIONSHIPS (FOLLOWERS/FOLLOWING)
-- ============================================================================

-- Create a network of relationships
INSERT INTO user_relationships (follower_id, following_id, status, created_at) VALUES
    -- Alice's network
    (1, 2, 'active', CURRENT_TIMESTAMP - INTERVAL '100 days'),
    (1, 3, 'active', CURRENT_TIMESTAMP - INTERVAL '95 days'),
    (1, 4, 'active', CURRENT_TIMESTAMP - INTERVAL '90 days'),
    (1, 6, 'active', CURRENT_TIMESTAMP - INTERVAL '85 days'),
    (1, 7, 'active', CURRENT_TIMESTAMP - INTERVAL '80 days'),
    
    -- Bob's network
    (2, 1, 'active', CURRENT_TIMESTAMP - INTERVAL '98 days'),
    (2, 3, 'active', CURRENT_TIMESTAMP - INTERVAL '93 days'),
    (2, 5, 'active', CURRENT_TIMESTAMP - INTERVAL '88 days'),
    (2, 7, 'active', CURRENT_TIMESTAMP - INTERVAL '83 days'),
    
    -- Charlie's network
    (3, 1, 'active', CURRENT_TIMESTAMP - INTERVAL '96 days'),
    (3, 2, 'active', CURRENT_TIMESTAMP - INTERVAL '91 days'),
    (3, 4, 'active', CURRENT_TIMESTAMP - INTERVAL '86 days'),
    
    -- Diana's network
    (4, 1, 'active', CURRENT_TIMESTAMP - INTERVAL '89 days'),
    (4, 7, 'active', CURRENT_TIMESTAMP - INTERVAL '84 days'),
    (4, 9, 'active', CURRENT_TIMESTAMP - INTERVAL '79 days'),
    
    -- Other relationships
    (5, 2, 'active', CURRENT_TIMESTAMP - INTERVAL '75 days'),
    (6, 1, 'active', CURRENT_TIMESTAMP - INTERVAL '70 days'),
    (7, 1, 'active', CURRENT_TIMESTAMP - INTERVAL '65 days'),
    (7, 4, 'active', CURRENT_TIMESTAMP - INTERVAL '60 days'),
    (8, 2, 'active', CURRENT_TIMESTAMP - INTERVAL '55 days'),
    (9, 4, 'active', CURRENT_TIMESTAMP - INTERVAL '50 days'),
    (10, 1, 'active', CURRENT_TIMESTAMP - INTERVAL '45 days'),
    (10, 6, 'active', CURRENT_TIMESTAMP - INTERVAL '40 days');

-- ============================================================================
-- HASHTAGS
-- ============================================================================

INSERT INTO hashtags (tag_name, usage_count) VALUES
    ('technology', 0),
    ('programming', 0),
    ('socialmedia', 0),
    ('ai', 0),
    ('machinelearning', 0),
    ('travel', 0),
    ('food', 0),
    ('photography', 0),
    ('music', 0),
    ('gaming', 0),
    ('fitness', 0),
    ('motivation', 0);

-- ============================================================================
-- POSTS
-- ============================================================================

-- Alice's posts
INSERT INTO posts (user_id, content, post_type, visibility, created_at) VALUES
    (1, 'Just launched my new project! Check it out 🚀 #technology #programming', 'text', 'public', CURRENT_TIMESTAMP - INTERVAL '5 days'),
    (1, 'Beautiful sunset at the Golden Gate Bridge #photography #travel', 'image', 'public', CURRENT_TIMESTAMP - INTERVAL '3 days'),
    (1, 'Excited about the future of AI and machine learning! #ai #machinelearning', 'text', 'public', CURRENT_TIMESTAMP - INTERVAL '1 day'),
    
-- Bob's posts
    (2, 'Working on a new construction project. Progress update! #work', 'image', 'public', CURRENT_TIMESTAMP - INTERVAL '6 days'),
    (2, 'Best pizza in New York! 🍕 #food', 'image', 'public', CURRENT_TIMESTAMP - INTERVAL '4 days'),
    (2, 'Team collaboration makes everything better #motivation', 'text', 'public', CURRENT_TIMESTAMP - INTERVAL '2 days'),
    
-- Charlie's posts
    (3, 'Sometimes life throws you a curveball. Keep swinging! #motivation', 'text', 'public', CURRENT_TIMESTAMP - INTERVAL '7 days'),
    (3, 'Chicago deep dish > New York pizza. Fight me. 🍕 #food', 'text', 'public', CURRENT_TIMESTAMP - INTERVAL '4 days'),
    
-- Diana's posts
    (4, 'Truth and justice matter now more than ever #motivation', 'text', 'public', CURRENT_TIMESTAMP - INTERVAL '8 days'),
    (4, 'Visiting the monuments at sunset #photography #travel', 'image', 'public', CURRENT_TIMESTAMP - INTERVAL '5 days'),
    (4, 'Supporting local community initiatives today ❤️', 'text', 'public', CURRENT_TIMESTAMP - INTERVAL '1 day'),
    
-- Frank's posts
    (6, 'New track dropping this Friday! Stay tuned 🎵 #music', 'text', 'public', CURRENT_TIMESTAMP - INTERVAL '6 days'),
    (6, 'Studio vibes tonight #music', 'image', 'public', CURRENT_TIMESTAMP - INTERVAL '3 days'),
    
-- Grace's posts
    (7, 'Debugging is like being a detective in a crime movie where you are also the murderer. #programming', 'text', 'public', CURRENT_TIMESTAMP - INTERVAL '4 days'),
    (7, 'The best thing about a boolean is even if you are wrong, you are only off by a bit. #programming', 'text', 'public', CURRENT_TIMESTAMP - INTERVAL '2 days'),
    
-- Iris's posts
    (9, 'Breaking: Major tech announcement coming soon! #technology', 'text', 'public', CURRENT_TIMESTAMP - INTERVAL '3 days'),
    (9, 'Journalism keeps democracy alive 📰 #motivation', 'text', 'public', CURRENT_TIMESTAMP - INTERVAL '1 day'),
    
-- Jack's posts
    (10, 'The problem is not the problem. The problem is your attitude about the problem. #motivation', 'text', 'public', CURRENT_TIMESTAMP - INTERVAL '5 days'),
    (10, 'Caribbean adventures continue! ⚓ #travel #photography', 'image', 'public', CURRENT_TIMESTAMP - INTERVAL '2 days');

-- Link hashtags to posts
INSERT INTO post_hashtags (post_id, hashtag_id) VALUES
    -- Post 1: Alice's project
    (1, 1), (1, 2),
    -- Post 3: Alice's AI post
    (3, 4), (3, 5),
    -- Post 2: Alice's sunset
    (2, 6), (2, 8),
    -- Post 5: Bob's pizza
    (5, 7),
    -- Post 6: Bob's motivation
    (6, 12),
    -- Post 7: Charlie's motivation
    (7, 12),
    -- Post 8: Charlie's pizza
    (8, 7),
    -- Post 9: Diana's motivation
    (9, 12),
    -- Post 10: Diana's photo
    (10, 6), (10, 8),
    -- Post 12: Frank's track
    (12, 9),
    -- Post 13: Frank's studio
    (13, 9),
    -- Post 14: Grace's debugging
    (14, 2),
    -- Post 15: Grace's boolean
    (15, 2),
    -- Post 16: Iris's tech news
    (16, 1),
    -- Post 17: Iris's journalism
    (17, 12),
    -- Post 18: Jack's motivation
    (18, 12),
    -- Post 19: Jack's adventures
    (19, 6), (19, 8);

-- ============================================================================
-- POST REACTIONS
-- ============================================================================

-- Reactions on Alice's first post
INSERT INTO post_reactions (post_id, user_id, reaction_type_id, created_at) VALUES
    (1, 2, 1, CURRENT_TIMESTAMP - INTERVAL '4 days 22 hours'),  -- Bob likes
    (1, 3, 2, CURRENT_TIMESTAMP - INTERVAL '4 days 20 hours'),  -- Charlie loves
    (1, 4, 1, CURRENT_TIMESTAMP - INTERVAL '4 days 18 hours'),  -- Diana likes
    (1, 7, 1, CURRENT_TIMESTAMP - INTERVAL '4 days 15 hours'),  -- Grace likes
    (1, 10, 3, CURRENT_TIMESTAMP - INTERVAL '4 days 12 hours'), -- Jack laughs
    
-- Reactions on various posts
    (2, 2, 2, CURRENT_TIMESTAMP - INTERVAL '2 days 22 hours'),
    (2, 6, 2, CURRENT_TIMESTAMP - INTERVAL '2 days 20 hours'),
    (3, 4, 1, CURRENT_TIMESTAMP - INTERVAL '23 hours'),
    (3, 7, 1, CURRENT_TIMESTAMP - INTERVAL '22 hours'),
    (5, 1, 3, CURRENT_TIMESTAMP - INTERVAL '3 days 20 hours'),
    (5, 3, 3, CURRENT_TIMESTAMP - INTERVAL '3 days 18 hours'),
    (7, 1, 1, CURRENT_TIMESTAMP - INTERVAL '6 days 20 hours'),
    (7, 2, 1, CURRENT_TIMESTAMP - INTERVAL '6 days 18 hours'),
    (8, 2, 3, CURRENT_TIMESTAMP - INTERVAL '3 days 22 hours'),
    (8, 5, 3, CURRENT_TIMESTAMP - INTERVAL '3 days 20 hours'),
    (10, 1, 2, CURRENT_TIMESTAMP - INTERVAL '4 days 22 hours'),
    (12, 1, 2, CURRENT_TIMESTAMP - INTERVAL '5 days 20 hours'),
    (14, 1, 3, CURRENT_TIMESTAMP - INTERVAL '3 days 20 hours'),
    (14, 2, 3, CURRENT_TIMESTAMP - INTERVAL '3 days 19 hours'),
    (14, 4, 3, CURRENT_TIMESTAMP - INTERVAL '3 days 18 hours'),
    (15, 1, 3, CURRENT_TIMESTAMP - INTERVAL '1 day 22 hours'),
    (15, 2, 3, CURRENT_TIMESTAMP - INTERVAL '1 day 20 hours');

-- ============================================================================
-- COMMENTS
-- ============================================================================

-- Comments on Alice's project post (post_id: 1)
INSERT INTO comments (post_id, user_id, content, created_at) VALUES
    (1, 2, 'This looks amazing! Great work! 🎉', CURRENT_TIMESTAMP - INTERVAL '4 days 20 hours'),
    (1, 7, 'Very impressive technical implementation. Did you use React or Vue?', CURRENT_TIMESTAMP - INTERVAL '4 days 18 hours'),
    (1, 3, 'Can''t wait to try it out!', CURRENT_TIMESTAMP - INTERVAL '4 days 15 hours');

-- Reply to Grace's question
INSERT INTO comments (post_id, user_id, parent_comment_id, content, created_at) VALUES
    (1, 1, 2, 'Thanks! I used React with TypeScript 🚀', CURRENT_TIMESTAMP - INTERVAL '4 days 17 hours');

-- Comments on other posts
INSERT INTO comments (post_id, user_id, content, created_at) VALUES
    (2, 6, 'Stunning photo! The colors are incredible', CURRENT_TIMESTAMP - INTERVAL '2 days 20 hours'),
    (5, 1, 'I need to visit! Recommendations?', CURRENT_TIMESTAMP - INTERVAL '3 days 18 hours'),
    (8, 2, 'Chicago pizza is great but I stand by NY pizza 😄', CURRENT_TIMESTAMP - INTERVAL '3 days 20 hours'),
    (14, 2, 'This is gold! 😂', CURRENT_TIMESTAMP - INTERVAL '3 days 19 hours'),
    (14, 4, 'Every developer can relate to this', CURRENT_TIMESTAMP - INTERVAL '3 days 18 hours'),
    (15, 1, 'Grace, your programming jokes are the best!', CURRENT_TIMESTAMP - INTERVAL '1 day 20 hours');

-- ============================================================================
-- COMMENT REACTIONS
-- ============================================================================

INSERT INTO comment_reactions (comment_id, user_id, reaction_type_id, created_at) VALUES
    (1, 1, 2, CURRENT_TIMESTAMP - INTERVAL '4 days 19 hours'),  -- Alice loves Bob's comment
    (2, 1, 1, CURRENT_TIMESTAMP - INTERVAL '4 days 17 hours'),  -- Alice likes Grace's question
    (4, 7, 1, CURRENT_TIMESTAMP - INTERVAL '4 days 16 hours'),  -- Grace likes Alice's reply
    (8, 1, 3, CURRENT_TIMESTAMP - INTERVAL '3 days 18 hours'),  -- Alice laughs at Bob's comment
    (9, 7, 1, CURRENT_TIMESTAMP - INTERVAL '3 days 17 hours');  -- Grace likes Diana's comment

-- ============================================================================
-- CONVERSATIONS AND MESSAGES
-- ============================================================================

-- Direct conversation: Alice and Bob
INSERT INTO conversations (conversation_type, created_by, created_at) VALUES
    ('direct', 1, CURRENT_TIMESTAMP - INTERVAL '10 days');

INSERT INTO conversation_participants (conversation_id, user_id, joined_at) VALUES
    (1, 1, CURRENT_TIMESTAMP - INTERVAL '10 days'),
    (1, 2, CURRENT_TIMESTAMP - INTERVAL '10 days');

INSERT INTO messages (conversation_id, sender_id, content, created_at) VALUES
    (1, 1, 'Hey Bob! How''s the construction project going?', CURRENT_TIMESTAMP - INTERVAL '10 days'),
    (1, 2, 'Going great! Should be done next week.', CURRENT_TIMESTAMP - INTERVAL '9 days 23 hours'),
    (1, 1, 'That''s awesome! Let me know when you''re free for lunch', CURRENT_TIMESTAMP - INTERVAL '9 days 22 hours'),
    (1, 2, 'Will do! How about next Friday?', CURRENT_TIMESTAMP - INTERVAL '9 days 20 hours'),
    (1, 1, 'Perfect! See you then 👍', CURRENT_TIMESTAMP - INTERVAL '9 days 19 hours');

-- Group conversation: Tech Talk
INSERT INTO conversations (conversation_type, conversation_name, created_by, created_at) VALUES
    ('group', 'Tech Talk', 1, CURRENT_TIMESTAMP - INTERVAL '15 days');

INSERT INTO conversation_participants (conversation_id, user_id, is_admin, joined_at) VALUES
    (2, 1, TRUE, CURRENT_TIMESTAMP - INTERVAL '15 days'),
    (2, 7, FALSE, CURRENT_TIMESTAMP - INTERVAL '15 days'),
    (2, 9, FALSE, CURRENT_TIMESTAMP - INTERVAL '15 days');

INSERT INTO messages (conversation_id, sender_id, content, created_at) VALUES
    (2, 1, 'Welcome to Tech Talk! Let''s discuss the latest in tech', CURRENT_TIMESTAMP - INTERVAL '15 days'),
    (2, 7, 'Excited to be here! What''s everyone working on?', CURRENT_TIMESTAMP - INTERVAL '14 days 22 hours'),
    (2, 9, 'Currently researching AI applications in journalism', CURRENT_TIMESTAMP - INTERVAL '14 days 20 hours'),
    (2, 1, 'That sounds fascinating! Would love to hear more', CURRENT_TIMESTAMP - INTERVAL '14 days 18 hours');

-- ============================================================================
-- MESSAGE READ RECEIPTS
-- ============================================================================

-- Mark messages as read
INSERT INTO message_read_receipts (message_id, user_id, read_at) VALUES
    (1, 2, CURRENT_TIMESTAMP - INTERVAL '9 days 23 hours'),
    (2, 1, CURRENT_TIMESTAMP - INTERVAL '9 days 23 hours'),
    (3, 2, CURRENT_TIMESTAMP - INTERVAL '9 days 22 hours'),
    (4, 1, CURRENT_TIMESTAMP - INTERVAL '9 days 20 hours'),
    (5, 2, CURRENT_TIMESTAMP - INTERVAL '9 days 19 hours'),
    (6, 7, CURRENT_TIMESTAMP - INTERVAL '14 days 22 hours'),
    (6, 9, CURRENT_TIMESTAMP - INTERVAL '14 days 21 hours'),
    (7, 1, CURRENT_TIMESTAMP - INTERVAL '14 days 22 hours'),
    (7, 9, CURRENT_TIMESTAMP - INTERVAL '14 days 21 hours');

-- ============================================================================
-- SAVED POSTS
-- ============================================================================

INSERT INTO saved_posts (user_id, post_id, collection_name, saved_at) VALUES
    (1, 14, 'Funny', CURRENT_TIMESTAMP - INTERVAL '3 days 18 hours'),
    (1, 15, 'Funny', CURRENT_TIMESTAMP - INTERVAL '1 day 19 hours'),
    (2, 1, 'Inspiration', CURRENT_TIMESTAMP - INTERVAL '4 days 21 hours'),
    (4, 14, 'Tech Humor', CURRENT_TIMESTAMP - INTERVAL '3 days 17 hours');

-- ============================================================================
-- NOTIFICATIONS
-- ============================================================================

-- Note: Many notifications are created automatically by triggers
-- Here we can add a few manual ones for testing

INSERT INTO notifications (user_id, notification_type_id, actor_id, entity_type, entity_id, content, is_read, created_at) VALUES
    -- Alice's notifications (some unread)
    (1, 1, 10, 'follow', 23, 'jack_sparrow started following you', FALSE, CURRENT_TIMESTAMP - INTERVAL '2 days'),
    (1, 2, 2, 'reaction', 1, 'bob_builder reacted to your post', TRUE, CURRENT_TIMESTAMP - INTERVAL '4 days'),
    (1, 3, 7, 'comment', 2, 'grace_hopper commented on your post', TRUE, CURRENT_TIMESTAMP - INTERVAL '4 days'),
    
    -- Bob's notifications
    (2, 1, 1, 'follow', 1, 'alice_wonder started following you', TRUE, CURRENT_TIMESTAMP - INTERVAL '5 days'),
    (2, 3, 1, 'comment', 5, 'alice_wonder commented on your post', FALSE, CURRENT_TIMESTAMP - INTERVAL '3 days');

-- ============================================================================
-- USER SESSIONS
-- ============================================================================

INSERT INTO user_sessions (user_id, session_token, ip_address, device_type, started_at, last_activity_at) VALUES
    (1, 'session_token_alice_123', '192.168.1.100', 'desktop', CURRENT_TIMESTAMP - INTERVAL '2 hours', CURRENT_TIMESTAMP - INTERVAL '5 minutes'),
    (2, 'session_token_bob_456', '192.168.1.101', 'mobile', CURRENT_TIMESTAMP - INTERVAL '1 hour', CURRENT_TIMESTAMP - INTERVAL '10 minutes'),
    (7, 'session_token_grace_789', '192.168.1.102', 'desktop', CURRENT_TIMESTAMP - INTERVAL '30 minutes', CURRENT_TIMESTAMP - INTERVAL '2 minutes');

COMMIT;

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Verify data was inserted correctly
SELECT 'Users created:' as metric, COUNT(*) as count FROM users
UNION ALL
SELECT 'Relationships created:', COUNT(*) FROM user_relationships
UNION ALL
SELECT 'Posts created:', COUNT(*) FROM posts
UNION ALL
SELECT 'Comments created:', COUNT(*) FROM comments
UNION ALL
SELECT 'Reactions created:', COUNT(*) FROM post_reactions
UNION ALL
SELECT 'Messages created:', COUNT(*) FROM messages
UNION ALL
SELECT 'Notifications created:', COUNT(*) FROM notifications;

-- Show sample feed for Alice
SELECT 
    'Alice''s Feed Preview' as description,
    p.post_id,
    u.username,
    LEFT(p.content, 50) || '...' as content_preview,
    ps.reactions_count,
    ps.comments_count
FROM posts p
JOIN user_relationships ur ON p.user_id = ur.following_id
JOIN users u ON p.user_id = u.user_id
LEFT JOIN post_stats ps ON p.post_id = ps.post_id
WHERE ur.follower_id = 1
  AND p.is_deleted = FALSE
ORDER BY p.created_at DESC
LIMIT 5;

-- Show user statistics
SELECT 
    u.username,
    us.followers_count,
    us.following_count,
    us.posts_count
FROM users u
JOIN user_stats us ON u.user_id = us.user_id
ORDER BY us.followers_count DESC
LIMIT 10;


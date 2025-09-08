-- Give all existing users 1000 tokens
-- This migration ensures all users have the initial token allocation

-- Update existing users to have 1000 tokens if they don't already have tokens
INSERT INTO user_tokens (user_id, photo_tokens, video_tokens, premium_tokens)
SELECT 
    u.id,
    1000 as photo_tokens,
    1000 as video_tokens,
    0 as premium_tokens
FROM users u
WHERE u.id NOT IN (SELECT user_id FROM user_tokens)
ON CONFLICT (user_id) DO NOTHING;

-- Update existing token records to ensure minimum 1000 tokens
UPDATE user_tokens 
SET 
    photo_tokens = GREATEST(photo_tokens, 1000),
    video_tokens = GREATEST(video_tokens, 1000),
    updated_at = NOW()
WHERE photo_tokens < 1000 OR video_tokens < 1000;

-- Create a function to give bonus tokens to all users
CREATE OR REPLACE FUNCTION give_bonus_tokens_to_all_users(bonus_amount INTEGER DEFAULT 1000)
RETURNS TABLE(users_updated INTEGER) AS $$
DECLARE
    updated_count INTEGER;
BEGIN
    UPDATE user_tokens 
    SET 
        photo_tokens = photo_tokens + bonus_amount,
        video_tokens = video_tokens + bonus_amount,
        updated_at = NOW();
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    
    RETURN QUERY SELECT updated_count;
END;
$$ LANGUAGE plpgsql;

-- Create a function to reset all users to 1000 tokens (admin use only)
CREATE OR REPLACE FUNCTION reset_all_users_to_1000_tokens()
RETURNS TABLE(users_updated INTEGER) AS $$
DECLARE
    updated_count INTEGER;
BEGIN
    UPDATE user_tokens 
    SET 
        photo_tokens = 1000,
        video_tokens = 1000,
        updated_at = NOW();
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    
    RETURN QUERY SELECT updated_count;
END;
$$ LANGUAGE plpgsql;

-- Create a function to get token statistics
CREATE OR REPLACE FUNCTION get_token_statistics()
RETURNS TABLE(
    total_users INTEGER,
    avg_photo_tokens NUMERIC,
    avg_video_tokens NUMERIC,
    total_photo_tokens BIGINT,
    total_video_tokens BIGINT,
    users_with_zero_tokens INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::INTEGER as total_users,
        AVG(ut.photo_tokens)::NUMERIC as avg_photo_tokens,
        AVG(ut.video_tokens)::NUMERIC as avg_video_tokens,
        SUM(ut.photo_tokens)::BIGINT as total_photo_tokens,
        SUM(ut.video_tokens)::BIGINT as total_video_tokens,
        COUNT(CASE WHEN ut.photo_tokens = 0 AND ut.video_tokens = 0 THEN 1 END)::INTEGER as users_with_zero_tokens
    FROM user_tokens ut;
END;
$$ LANGUAGE plpgsql;

COMMIT;
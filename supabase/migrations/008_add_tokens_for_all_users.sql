-- Add 1000 tokens for all existing users
-- First disable RLS temporarily
ALTER TABLE public.user_tokens DISABLE ROW LEVEL SECURITY;

-- Update all existing token records to 1000
UPDATE public.user_tokens SET
    photo_tokens = 1000,
    video_tokens = 1000,
    premium_tokens = 0,
    updated_at = NOW();

-- Insert tokens for users who don't have token records yet
INSERT INTO public.user_tokens (user_id, photo_tokens, video_tokens, premium_tokens)
SELECT 
    u.id,
    1000 as photo_tokens,
    1000 as video_tokens,
    0 as premium_tokens
FROM public.users u
WHERE u.id NOT IN (SELECT user_id FROM public.user_tokens WHERE user_id IS NOT NULL);

-- Re-enable RLS
ALTER TABLE public.user_tokens ENABLE ROW LEVEL SECURITY;

-- Ensure proper policies exist
DROP POLICY IF EXISTS "Allow public read access" ON public.user_tokens;
DROP POLICY IF EXISTS "Allow public insert access" ON public.user_tokens;
DROP POLICY IF EXISTS "Allow public update access" ON public.user_tokens;
DROP POLICY IF EXISTS "Allow public delete access" ON public.user_tokens;

CREATE POLICY "Allow public read access" ON public.user_tokens
  FOR SELECT USING (true);

CREATE POLICY "Allow public insert access" ON public.user_tokens
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Allow public update access" ON public.user_tokens
  FOR UPDATE USING (true);

CREATE POLICY "Allow public delete access" ON public.user_tokens
  FOR DELETE USING (true);
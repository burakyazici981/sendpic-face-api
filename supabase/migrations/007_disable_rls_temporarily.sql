-- Temporarily disable RLS for user_tokens table to insert data
ALTER TABLE public.user_tokens DISABLE ROW LEVEL SECURITY;

-- Insert token record for existing user
INSERT INTO public.user_tokens (user_id, photo_tokens, video_tokens, premium_tokens) 
VALUES ('ee3c66ac-737c-45e2-afe1-eb6491c1f6cc', 1000, 1000, 0);

-- Re-enable RLS
ALTER TABLE public.user_tokens ENABLE ROW LEVEL SECURITY;

-- Create new policies
CREATE POLICY "Allow public read access" ON public.user_tokens
  FOR SELECT USING (true);

CREATE POLICY "Allow public insert access" ON public.user_tokens
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Allow public update access" ON public.user_tokens
  FOR UPDATE USING (true);

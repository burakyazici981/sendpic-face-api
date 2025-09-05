-- Drop existing policies
DROP POLICY IF EXISTS "Users can view own tokens" ON public.user_tokens;
DROP POLICY IF EXISTS "Users can insert own tokens" ON public.user_tokens;
DROP POLICY IF EXISTS "Users can update own tokens" ON public.user_tokens;
DROP POLICY IF EXISTS "Service role can manage all tokens" ON public.user_tokens;

-- Allow public access for user_tokens table (temporary for setup)
DROP POLICY IF EXISTS "Allow public read access" ON public.user_tokens;

-- Create new policies
CREATE POLICY "Allow public read access" ON public.user_tokens
  FOR SELECT USING (true);

CREATE POLICY "Allow public insert access" ON public.user_tokens
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Allow public update access" ON public.user_tokens
  FOR UPDATE USING (true);

-- Also allow public access to users table for token management
DROP POLICY IF EXISTS "Users can view own profile" ON public.users;
DROP POLICY IF EXISTS "Users can update own profile" ON public.users;

CREATE POLICY "Allow public read access" ON public.users
  FOR SELECT USING (true);

CREATE POLICY "Allow public insert access" ON public.users
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Allow public update access" ON public.users
  FOR UPDATE USING (true);

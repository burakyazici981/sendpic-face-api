-- Fix user_tokens RLS policy
DROP POLICY IF EXISTS "Users can view own tokens" ON public.user_tokens;
DROP POLICY IF EXISTS "Users can insert own tokens" ON public.user_tokens;
DROP POLICY IF EXISTS "Users can update own tokens" ON public.user_tokens;

-- Allow authenticated users to manage their own tokens
CREATE POLICY "Users can view own tokens" ON public.user_tokens
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own tokens" ON public.user_tokens
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own tokens" ON public.user_tokens
  FOR UPDATE USING (auth.uid() = user_id);

-- Allow service role to manage all tokens (for admin operations)
CREATE POLICY "Service role can manage all tokens" ON public.user_tokens
  FOR ALL USING (auth.role() = 'service_role');

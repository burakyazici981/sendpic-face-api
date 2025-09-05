-- Version check table for app updates
CREATE TABLE public.version_check (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  platform TEXT NOT NULL CHECK (platform IN ('android', 'ios')),
  latest_version TEXT NOT NULL,
  min_required_version TEXT NOT NULL,
  android_url TEXT,
  ios_url TEXT,
  release_notes TEXT,
  is_forced BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Insert initial version data
INSERT INTO public.version_check (platform, latest_version, min_required_version, android_url, ios_url, release_notes, is_forced) VALUES
('android', '1.0.0', '1.0.0', 'https://play.google.com/store/apps/details?id=com.sendpic.app', 'https://apps.apple.com/app/sendpic/id123456789', 'İlk sürüm', false),
('ios', '1.0.0', '1.0.0', 'https://play.google.com/store/apps/details?id=com.sendpic.app', 'https://apps.apple.com/app/sendpic/id123456789', 'İlk sürüm', false);

-- Enable RLS
ALTER TABLE public.version_check ENABLE ROW LEVEL SECURITY;

-- Allow public read access
CREATE POLICY "Allow public read access" ON public.version_check
  FOR SELECT USING (true);

-- Add birth_date column to users table
ALTER TABLE public.users ADD COLUMN birth_date DATE;

-- Update existing users with a default birth date (18 years ago)
UPDATE public.users 
SET birth_date = CURRENT_DATE - INTERVAL '18 years' 
WHERE birth_date IS NULL;

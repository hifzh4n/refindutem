-- Create lost_items table
CREATE TABLE IF NOT EXISTS lost_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title VARCHAR(255) NOT NULL,
  category VARCHAR(100),
  location_lost VARCHAR(255),
  date_lost TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  description TEXT,
  image_urls TEXT[] DEFAULT '{}',
  status VARCHAR(50) DEFAULT 'open',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create found_items table
CREATE TABLE IF NOT EXISTS found_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title VARCHAR(255) NOT NULL,
  category VARCHAR(100),
  location_found VARCHAR(255),
  date_found TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  description TEXT,
  image_urls TEXT[] DEFAULT '{}',
  status VARCHAR(50) DEFAULT 'open',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create notifications table
CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type VARCHAR(50),
  message TEXT NOT NULL,
  is_read BOOLEAN DEFAULT FALSE,
  related_item_id UUID,
  related_item_type VARCHAR(50),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create profiles table for public contact information
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name VARCHAR(255),
  matric_number VARCHAR(100),
  avatar_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create chat_messages table for realtime chat conversations
CREATE TABLE IF NOT EXISTS chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id TEXT NOT NULL,
  sender_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  receiver_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Backfill profiles for existing auth users and keep them synced.
INSERT INTO profiles (id, full_name, matric_number, avatar_url, created_at, updated_at)
SELECT
  u.id,
  COALESCE(NULLIF(u.raw_user_meta_data->>'full_name', ''), UPPER(SPLIT_PART(u.email, '@', 1))),
  COALESCE(NULLIF(u.raw_user_meta_data->>'matric_number', ''), UPPER(SPLIT_PART(u.email, '@', 1))),
  NULLIF(u.raw_user_meta_data->>'avatar_url', ''),
  COALESCE(u.created_at, NOW()),
  NOW()
FROM auth.users u
ON CONFLICT (id) DO UPDATE
SET
  full_name = COALESCE(EXCLUDED.full_name, profiles.full_name),
  matric_number = COALESCE(EXCLUDED.matric_number, profiles.matric_number),
  avatar_url = COALESCE(EXCLUDED.avatar_url, profiles.avatar_url),
  updated_at = NOW();

CREATE OR REPLACE FUNCTION public.sync_profile_from_auth_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, matric_number, avatar_url, created_at, updated_at)
  VALUES (
    NEW.id,
    COALESCE(NULLIF(NEW.raw_user_meta_data->>'full_name', ''), UPPER(SPLIT_PART(NEW.email, '@', 1))),
    COALESCE(NULLIF(NEW.raw_user_meta_data->>'matric_number', ''), UPPER(SPLIT_PART(NEW.email, '@', 1))),
    NULLIF(NEW.raw_user_meta_data->>'avatar_url', ''),
    COALESCE(NEW.created_at, NOW()),
    NOW()
  )
  ON CONFLICT (id) DO UPDATE
  SET
    full_name = COALESCE(EXCLUDED.full_name, public.profiles.full_name),
    matric_number = COALESCE(EXCLUDED.matric_number, public.profiles.matric_number),
    avatar_url = COALESCE(EXCLUDED.avatar_url, public.profiles.avatar_url),
    updated_at = NOW();

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_profile_sync ON auth.users;
CREATE TRIGGER on_auth_user_profile_sync
AFTER INSERT OR UPDATE OF email, raw_user_meta_data
ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.sync_profile_from_auth_user();

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_lost_items_user_id ON lost_items(user_id);
CREATE INDEX IF NOT EXISTS idx_lost_items_created_at ON lost_items(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_found_items_user_id ON found_items(user_id);
CREATE INDEX IF NOT EXISTS idx_found_items_created_at ON found_items(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_profiles_matric_number ON profiles(matric_number);
CREATE INDEX IF NOT EXISTS idx_chat_messages_conversation_created ON chat_messages(conversation_id, created_at);
CREATE INDEX IF NOT EXISTS idx_chat_messages_sender_id ON chat_messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_receiver_id ON chat_messages(receiver_id);

DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE chat_messages;
  EXCEPTION
    WHEN duplicate_object THEN
      NULL;
  END;
END $$;

-- Enable RLS (Row Level Security) on lost_items
ALTER TABLE IF EXISTS lost_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own lost items" ON lost_items;
DROP POLICY IF EXISTS "Authenticated users can view all lost items" ON lost_items;
CREATE POLICY "Authenticated users can view all lost items" ON lost_items
  FOR SELECT USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Users can insert their own lost items" ON lost_items;
CREATE POLICY "Users can insert their own lost items" ON lost_items
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own lost items" ON lost_items;
CREATE POLICY "Users can update their own lost items" ON lost_items
  FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own lost items" ON lost_items;
CREATE POLICY "Users can delete their own lost items" ON lost_items
  FOR DELETE USING (auth.uid() = user_id);

-- Enable RLS on found_items
ALTER TABLE IF EXISTS found_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own found items" ON found_items;
DROP POLICY IF EXISTS "Authenticated users can view all found items" ON found_items;
CREATE POLICY "Authenticated users can view all found items" ON found_items
  FOR SELECT USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Users can insert their own found items" ON found_items;
CREATE POLICY "Users can insert their own found items" ON found_items
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own found items" ON found_items;
CREATE POLICY "Users can update their own found items" ON found_items
  FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own found items" ON found_items;
CREATE POLICY "Users can delete their own found items" ON found_items
  FOR DELETE USING (auth.uid() = user_id);

-- Enable RLS on notifications
ALTER TABLE IF EXISTS notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own notifications" ON notifications;
CREATE POLICY "Users can view their own notifications" ON notifications
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own notifications" ON notifications;
CREATE POLICY "Users can insert their own notifications" ON notifications
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own notifications" ON notifications;
CREATE POLICY "Users can update their own notifications" ON notifications
  FOR UPDATE USING (auth.uid() = user_id);

-- Enable RLS on chat_messages
ALTER TABLE IF EXISTS chat_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own chat messages" ON chat_messages;
CREATE POLICY "Users can view their own chat messages" ON chat_messages
  FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

DROP POLICY IF EXISTS "Users can insert chat messages as sender" ON chat_messages;
CREATE POLICY "Users can insert chat messages as sender" ON chat_messages
  FOR INSERT WITH CHECK (auth.uid() = sender_id);

DROP POLICY IF EXISTS "Users can delete their own sent chat messages" ON chat_messages;
CREATE POLICY "Users can delete their own sent chat messages" ON chat_messages
  FOR DELETE USING (auth.uid() = sender_id);

-- Enable RLS on profiles
ALTER TABLE IF EXISTS profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can view all profiles" ON profiles;
CREATE POLICY "Authenticated users can view all profiles" ON profiles
  FOR SELECT USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Users can insert their own profile" ON profiles;
CREATE POLICY "Users can insert their own profile" ON profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update their own profile" ON profiles;
CREATE POLICY "Users can update their own profile" ON profiles
  FOR UPDATE USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Create storage bucket for report photos (run once)
INSERT INTO storage.buckets (id, name, public)
VALUES ('report-images', 'report-images', true)
ON CONFLICT (id) DO NOTHING;

-- Allow authenticated users to upload report photos to their own folder
DROP POLICY IF EXISTS "Authenticated users can upload report images" ON storage.objects;
CREATE POLICY "Authenticated users can upload report images" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'report-images'
    AND auth.uid() IS NOT NULL
    AND name LIKE auth.uid()::text || '/%'
  );

-- Allow public read access to report photos
DROP POLICY IF EXISTS "Public can view report images" ON storage.objects;
CREATE POLICY "Public can view report images" ON storage.objects
  FOR SELECT TO public
  USING (bucket_id = 'report-images');

-- Allow owners to update and delete their uploaded report photos
DROP POLICY IF EXISTS "Users can update their own report images" ON storage.objects;
CREATE POLICY "Users can update their own report images" ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'report-images'
    AND owner = auth.uid()
  )
  WITH CHECK (
    bucket_id = 'report-images'
    AND owner = auth.uid()
  );

DROP POLICY IF EXISTS "Users can delete their own report images" ON storage.objects;
CREATE POLICY "Users can delete their own report images" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'report-images'
    AND owner = auth.uid()
  );

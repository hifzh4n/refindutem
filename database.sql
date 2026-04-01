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

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_lost_items_user_id ON lost_items(user_id);
CREATE INDEX IF NOT EXISTS idx_lost_items_created_at ON lost_items(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_found_items_user_id ON found_items(user_id);
CREATE INDEX IF NOT EXISTS idx_found_items_created_at ON found_items(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at DESC);

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

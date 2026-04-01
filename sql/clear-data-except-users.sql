-- Clear all application data while keeping auth.users intact
-- Run in Supabase SQL Editor as a privileged role (e.g., postgres)

BEGIN;

DO $$
BEGIN
  IF to_regclass('public.notifications') IS NOT NULL THEN
    EXECUTE 'TRUNCATE TABLE public.notifications RESTART IDENTITY CASCADE';
  END IF;

  IF to_regclass('public.lost_items') IS NOT NULL THEN
    EXECUTE 'TRUNCATE TABLE public.lost_items RESTART IDENTITY CASCADE';
  END IF;

  IF to_regclass('public.found_items') IS NOT NULL THEN
    EXECUTE 'TRUNCATE TABLE public.found_items RESTART IDENTITY CASCADE';
  END IF;

  IF to_regprocedure('storage.empty_bucket(text)') IS NOT NULL THEN
    PERFORM storage.empty_bucket('report-images');
  END IF;
END $$;

COMMIT;

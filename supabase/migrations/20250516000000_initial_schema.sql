-- =============================================================================
-- Migration: Initial Schema for ReFindUTeM
-- Description: Campus lost-and-found app for verified UTeM students and staff
-- Tables: lost_item_reports, found_item_reports
-- Storage: profiles, lost-item-images, found-item-images
-- Functions: update_my_phone
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. TABLES
-- -----------------------------------------------------------------------------

-- Lost Item Reports
create table if not exists public.lost_item_reports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  item_name text not null,
  category text not null,
  lost_date date not null,
  location text not null,
  description text not null,
  contact_method text not null,
  contact_detail text not null,
  image_path text,
  status text not null default 'open',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint lost_item_reports_status_check
    check (status in ('open', 'matched', 'closed')),
  constraint lost_item_reports_category_check
    check (category in (
      'Student card', 'Keys', 'Wallet', 'Electronics',
      'Bag', 'Bottle', 'Book', 'Other'
    )),
  constraint lost_item_reports_contact_method_check
    check (contact_method in ('Phone', 'Email'))
);

-- Found Item Reports
create table if not exists public.found_item_reports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  item_name text not null,
  category text not null,
  found_date date not null,
  location text not null,
  description text not null,
  handover_status text not null,
  contact_method text not null,
  contact_detail text not null,
  image_path text,
  status text not null default 'open',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint found_item_reports_status_check
    check (status in ('open', 'claimed', 'closed')),
  constraint found_item_reports_category_check
    check (category in (
      'Student card', 'Keys', 'Wallet', 'Electronics',
      'Bag', 'Bottle', 'Book', 'Other'
    )),
  constraint found_item_reports_handover_status_check
    check (handover_status in (
      'Keeping safely',
      'Submitted to security',
      'Submitted to faculty office',
      'Submitted to library counter'
    )),
  constraint found_item_reports_contact_method_check
    check (contact_method in ('Phone', 'Email'))
);

-- -----------------------------------------------------------------------------
-- 2. ROW LEVEL SECURITY
-- -----------------------------------------------------------------------------

-- Enable RLS
alter table public.lost_item_reports enable row level security;
alter table public.found_item_reports enable row level security;

-- Lost Item Reports policies
create policy "lost_item_reports_select_own"
  on public.lost_item_reports for select to authenticated
  using ((select auth.uid()) = user_id);

create policy "lost_item_reports_select_open"
  on public.lost_item_reports for select to authenticated
  using (status = 'open');

create policy "lost_item_reports_insert_own"
  on public.lost_item_reports for insert to authenticated
  with check ((select auth.uid()) = user_id);

create policy "lost_item_reports_update_own"
  on public.lost_item_reports for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- Found Item Reports policies
create policy "found_item_reports_select_own"
  on public.found_item_reports for select to authenticated
  using ((select auth.uid()) = user_id);

create policy "found_item_reports_select_open"
  on public.found_item_reports for select to authenticated
  using (status = 'open');

create policy "found_item_reports_insert_own"
  on public.found_item_reports for insert to authenticated
  with check ((select auth.uid()) = user_id);

create policy "found_item_reports_update_own"
  on public.found_item_reports for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- -----------------------------------------------------------------------------
-- 3. GRANTS
-- -----------------------------------------------------------------------------

grant select, insert, update on public.lost_item_reports to authenticated;
grant select, insert, update on public.found_item_reports to authenticated;

-- -----------------------------------------------------------------------------
-- 4. STORAGE BUCKETS
-- -----------------------------------------------------------------------------

-- Profiles bucket (avatars)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'profiles', 'profiles', false, 5242880,
  array['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Lost item images bucket
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'lost-item-images', 'lost-item-images', false, 5242880,
  array['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Found item images bucket
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'found-item-images', 'found-item-images', false, 5242880,
  array['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- -----------------------------------------------------------------------------
-- 5. STORAGE POLICIES
-- -----------------------------------------------------------------------------

-- Profile avatars: user can manage their own avatar
create policy "profiles_authenticated_select_own_avatar"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'profiles'
    and (storage.foldername(name))[1] = 'avatars'
    and (storage.foldername(name))[2] = (select auth.uid())::text
  );

create policy "profiles_authenticated_insert_own_avatar"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'profiles'
    and (storage.foldername(name))[1] = 'avatars'
    and (storage.foldername(name))[2] = (select auth.uid())::text
  );

create policy "profiles_authenticated_update_own_avatar"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'profiles'
    and (storage.foldername(name))[1] = 'avatars'
    and (storage.foldername(name))[2] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'profiles'
    and (storage.foldername(name))[1] = 'avatars'
    and (storage.foldername(name))[2] = (select auth.uid())::text
  );

create policy "profiles_authenticated_delete_own_avatar"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'profiles'
    and (storage.foldername(name))[1] = 'avatars'
    and (storage.foldername(name))[2] = (select auth.uid())::text
  );

-- Lost item images: anyone authenticated can view, owner can manage
create policy "lost_item_images_authenticated_select"
  on storage.objects for select to authenticated
  using (bucket_id = 'lost-item-images');

create policy "lost_item_images_authenticated_insert_own"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'lost-item-images'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "lost_item_images_authenticated_update_own"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'lost-item-images'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'lost-item-images'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "lost_item_images_authenticated_delete_own"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'lost-item-images'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- Found item images: anyone authenticated can view, owner can manage
create policy "found_item_images_authenticated_select"
  on storage.objects for select to authenticated
  using (bucket_id = 'found-item-images');

create policy "found_item_images_authenticated_insert_own"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'found-item-images'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "found_item_images_authenticated_update_own"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'found-item-images'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'found-item-images'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "found_item_images_authenticated_delete_own"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'found-item-images'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- -----------------------------------------------------------------------------
-- 6. FUNCTIONS
-- -----------------------------------------------------------------------------

-- Update phone number with Malaysian format validation
create or replace function public.update_my_phone(phone_number text)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  normalized_phone text;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  normalized_phone := regexp_replace(coalesce(phone_number, ''), '[^0-9+]', '', 'g');

  if normalized_phone = '' then
    update auth.users
    set
      phone = null,
      phone_confirmed_at = null,
      raw_user_meta_data = jsonb_set(
        coalesce(raw_user_meta_data, '{}'::jsonb),
        '{phone}',
        'null'::jsonb,
        true
      ),
      updated_at = now()
    where id = auth.uid();
    return;
  end if;

  if normalized_phone !~ '^\+601[0-9]{8,9}$' then
    raise exception 'Enter a valid Malaysia phone number.';
  end if;

  update auth.users
  set
    phone = normalized_phone,
    phone_confirmed_at = coalesce(phone_confirmed_at, now()),
    raw_user_meta_data = jsonb_set(
      coalesce(raw_user_meta_data, '{}'::jsonb),
      '{phone}',
      to_jsonb(normalized_phone),
      true
    ),
    updated_at = now()
  where id = auth.uid();
end;
$$;

revoke all on function public.update_my_phone(text) from public;
grant execute on function public.update_my_phone(text) to authenticated;

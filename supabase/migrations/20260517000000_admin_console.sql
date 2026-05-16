-- =============================================================================
-- Migration: Admin console support
-- Description: Admin roles, report-wide CRUD policies, and user management RPCs
-- =============================================================================

create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null
);

alter table public.admin_users enable row level security;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select exists (
    select 1
    from public.admin_users
    where user_id = auth.uid()
  );
$$;

revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;

drop policy if exists "admin_users_select_admins" on public.admin_users;
create policy "admin_users_select_admins"
  on public.admin_users for select to authenticated
  using (public.is_admin());

grant select on public.admin_users to authenticated;

drop policy if exists "profiles_admin_select_avatars" on storage.objects;
create policy "profiles_admin_select_avatars"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'profiles'
    and public.is_admin()
  );

drop policy if exists "lost_item_reports_admin_all" on public.lost_item_reports;
create policy "lost_item_reports_admin_all"
  on public.lost_item_reports for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists "found_item_reports_admin_all" on public.found_item_reports;
create policy "found_item_reports_admin_all"
  on public.found_item_reports for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

grant delete on public.lost_item_reports to authenticated;
grant delete on public.found_item_reports to authenticated;

create or replace function public.admin_dashboard_stats()
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  result jsonb;
begin
  if not public.is_admin() then
    raise exception 'Admin access required';
  end if;

  select jsonb_build_object(
    'users', (select count(*) from auth.users),
    'admins', (select count(*) from public.admin_users),
    'lost_open', (select count(*) from public.lost_item_reports where status = 'open'),
    'lost_total', (select count(*) from public.lost_item_reports),
    'found_open', (select count(*) from public.found_item_reports where status = 'open'),
    'found_total', (select count(*) from public.found_item_reports)
  )
  into result;

  return result;
end;
$$;

revoke all on function public.admin_dashboard_stats() from public;
grant execute on function public.admin_dashboard_stats() to authenticated;

drop function if exists public.admin_list_users();

create or replace function public.admin_list_users()
returns table (
  id uuid,
  email text,
  phone text,
  first_name text,
  last_name text,
  avatar_path text,
  is_admin boolean,
  created_at timestamptz,
  last_sign_in_at timestamptz
)
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if not public.is_admin() then
    raise exception 'Admin access required';
  end if;

  return query
  select
    users.id,
    users.email::text,
    users.phone::text,
    coalesce(users.raw_user_meta_data->>'first_name', '')::text,
    coalesce(users.raw_user_meta_data->>'last_name', '')::text,
    coalesce(users.raw_user_meta_data->>'avatar_path', '')::text,
    exists (
      select 1
      from public.admin_users admins
      where admins.user_id = users.id
    ),
    users.created_at,
    users.last_sign_in_at
  from auth.users users
  order by users.created_at desc;
end;
$$;

revoke all on function public.admin_list_users() from public;
grant execute on function public.admin_list_users() to authenticated;

create or replace function public.admin_update_user(
  target_user_id uuid,
  first_name text,
  last_name text,
  make_admin boolean
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if not public.is_admin() then
    raise exception 'Admin access required';
  end if;

  if target_user_id = auth.uid() and make_admin is false then
    raise exception 'You cannot remove your own admin access.';
  end if;

  update auth.users
  set
    raw_user_meta_data =
      jsonb_set(
        jsonb_set(
          coalesce(raw_user_meta_data, '{}'::jsonb),
          '{first_name}',
          to_jsonb(trim(coalesce(first_name, ''))),
          true
        ),
        '{last_name}',
        to_jsonb(trim(coalesce(last_name, ''))),
        true
      ),
    updated_at = now()
  where id = target_user_id;

  if make_admin then
    insert into public.admin_users (user_id, created_by)
    values (target_user_id, auth.uid())
    on conflict (user_id) do nothing;
  else
    delete from public.admin_users where user_id = target_user_id;
  end if;
end;
$$;

revoke all on function public.admin_update_user(uuid, text, text, boolean) from public;
grant execute on function public.admin_update_user(uuid, text, text, boolean) to authenticated;

create or replace function public.admin_delete_user(target_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if not public.is_admin() then
    raise exception 'Admin access required';
  end if;

  if target_user_id = auth.uid() then
    raise exception 'You cannot delete your own account.';
  end if;

  delete from auth.users where id = target_user_id;
end;
$$;

revoke all on function public.admin_delete_user(uuid) from public;
grant execute on function public.admin_delete_user(uuid) to authenticated;

insert into public.admin_users (user_id)
select id
from auth.users
where email = 'admin@utem.edu.my'
on conflict (user_id) do nothing;

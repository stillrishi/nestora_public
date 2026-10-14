-- Nestora shared portfolio: invite/owner approval is required for data access.
-- Run this in Supabase SQL Editor before using the mobile app.

create table if not exists public.portfolio_memberships (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  role text not null check (role in ('owner', 'editor', 'viewer')),
  created_at timestamptz not null default now()
);

create table if not exists public.portfolio_access_requests (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  requested_at timestamptz not null default now()
);

create table if not exists public.portfolio_state (
  id text primary key check (id = 'shared'),
  payload jsonb not null default '{"properties":[],"tenancies":[],"rents":[],"expenses":[],"documents":[],"settings":{"currency":"INR"}}'::jsonb,
  revision integer not null default 0,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id)
);

insert into public.portfolio_state (id) values ('shared') on conflict (id) do nothing;

create or replace function public.nestora_is_member()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.portfolio_memberships m where m.user_id = (select auth.uid()))
$$;

create or replace function public.nestora_is_owner()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.portfolio_memberships m where m.user_id = (select auth.uid()) and m.role = 'owner')
$$;

create or replace function public.nestora_can_edit()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.portfolio_memberships m where m.user_id = (select auth.uid()) and m.role in ('owner', 'editor'))
$$;

revoke all on function public.nestora_is_member() from public;
revoke all on function public.nestora_is_owner() from public;
revoke all on function public.nestora_can_edit() from public;
grant execute on function public.nestora_is_member() to authenticated;
grant execute on function public.nestora_is_owner() to authenticated;
grant execute on function public.nestora_can_edit() to authenticated;

alter table public.portfolio_memberships enable row level security;
alter table public.portfolio_access_requests enable row level security;
alter table public.portfolio_state enable row level security;

revoke all on table public.portfolio_memberships from public, anon;
revoke all on table public.portfolio_access_requests from public, anon;
revoke all on table public.portfolio_state from public, anon;
grant select, insert, update, delete on public.portfolio_memberships to authenticated;
grant select, insert, update, delete on public.portfolio_access_requests to authenticated;
grant select, update on public.portfolio_state to authenticated;
grant usage on schema public to authenticated;

drop policy if exists "Members can see their membership; owners see all" on public.portfolio_memberships;
create policy "Members can see their membership; owners see all" on public.portfolio_memberships for select to authenticated
  using (user_id = (select auth.uid()) or public.nestora_is_owner());
drop policy if exists "Owners manage memberships" on public.portfolio_memberships;
create policy "Owners manage memberships" on public.portfolio_memberships for all to authenticated
  using (public.nestora_is_owner()) with check (public.nestora_is_owner());

drop policy if exists "Users create their own access request" on public.portfolio_access_requests;
create policy "Users create their own access request" on public.portfolio_access_requests for insert to authenticated
  with check (user_id = (select auth.uid()));
drop policy if exists "Users see own request and owners see all" on public.portfolio_access_requests;
create policy "Users see own request and owners see all" on public.portfolio_access_requests for select to authenticated
  using (user_id = (select auth.uid()) or public.nestora_is_owner());
drop policy if exists "Owners remove access requests" on public.portfolio_access_requests;
create policy "Owners remove access requests" on public.portfolio_access_requests for delete to authenticated
  using (public.nestora_is_owner());

drop policy if exists "Members read shared portfolio" on public.portfolio_state;
create policy "Members read shared portfolio" on public.portfolio_state for select to authenticated
  using (public.nestora_is_member());
drop policy if exists "Editors update shared portfolio" on public.portfolio_state;
create policy "Editors update shared portfolio" on public.portfolio_state for update to authenticated
  using (public.nestora_can_edit()) with check (public.nestora_can_edit());

create or replace function public.save_nestora_portfolio(p_payload jsonb, p_expected_revision integer)
returns integer language plpgsql security invoker set search_path = '' as $$
declare next_revision integer;
begin
  update public.portfolio_state
    set payload = p_payload, revision = revision + 1, updated_at = now(), updated_by = (select auth.uid())
    where id = 'shared' and revision = p_expected_revision
    returning revision into next_revision;
  if next_revision is null then
    raise exception 'Portfolio changed on another device. Reload the latest data before saving.' using errcode = '40001';
  end if;
  return next_revision;
end;
$$;
revoke all on function public.save_nestora_portfolio(jsonb, integer) from public, anon;
grant execute on function public.save_nestora_portfolio(jsonb, integer) to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('nestora-documents', 'nestora-documents', false, 26214400,
  array['application/pdf','image/jpeg','image/png','image/webp','image/heic','application/msword','application/vnd.openxmlformats-officedocument.wordprocessingml.document'])
on conflict (id) do update set public = false, file_size_limit = 26214400;

drop policy if exists "Members read Nestora files" on storage.objects;
create policy "Members read Nestora files" on storage.objects for select to authenticated
  using (bucket_id = 'nestora-documents' and (storage.foldername(name))[1] = 'shared' and public.nestora_is_member());
drop policy if exists "Editors upload Nestora files" on storage.objects;
create policy "Editors upload Nestora files" on storage.objects for insert to authenticated
  with check (bucket_id = 'nestora-documents' and (storage.foldername(name))[1] = 'shared' and public.nestora_can_edit());
drop policy if exists "Editors update Nestora files" on storage.objects;
create policy "Editors update Nestora files" on storage.objects for update to authenticated
  using (bucket_id = 'nestora-documents' and (storage.foldername(name))[1] = 'shared' and public.nestora_can_edit())
  with check (bucket_id = 'nestora-documents' and (storage.foldername(name))[1] = 'shared' and public.nestora_can_edit());
drop policy if exists "Editors delete Nestora files" on storage.objects;
create policy "Editors delete Nestora files" on storage.objects for delete to authenticated
  using (bucket_id = 'nestora-documents' and (storage.foldername(name))[1] = 'shared' and public.nestora_can_edit());

-- Durable profile storage for TokenBar public identity links.
-- Run this in Supabase SQL editor, then set SUPABASE_URL and
-- SUPABASE_SERVICE_ROLE_KEY in Vercel Project Settings.

create table if not exists public.tokenbar_profiles (
  token text primary key,
  profile jsonb not null,
  owner_id text,
  primary_archetype text,
  npc_class text,
  specificity_score integer,
  uploaded_at_epoch bigint not null default extract(epoch from now())::bigint,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.tokenbar_profiles
  add column if not exists owner_id text;

create index if not exists tokenbar_profiles_primary_archetype_idx
  on public.tokenbar_profiles (primary_archetype);

create index if not exists tokenbar_profiles_npc_class_idx
  on public.tokenbar_profiles (npc_class);

create index if not exists tokenbar_profiles_uploaded_at_idx
  on public.tokenbar_profiles (uploaded_at_epoch desc);

create index if not exists tokenbar_profiles_owner_id_idx
  on public.tokenbar_profiles (owner_id);

create or replace function public.set_tokenbar_profiles_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists tokenbar_profiles_updated_at on public.tokenbar_profiles;
create trigger tokenbar_profiles_updated_at
before update on public.tokenbar_profiles
for each row execute function public.set_tokenbar_profiles_updated_at();

alter table public.tokenbar_profiles enable row level security;

-- Public profile reads are okay because uploaded identity JSON is explicitly opt-in.
drop policy if exists "public can read tokenbar profiles" on public.tokenbar_profiles;
create policy "public can read tokenbar profiles"
on public.tokenbar_profiles
for select
using (true);

-- Do not allow browser/client writes with anon keys. The Vercel API should write
-- server-side with SUPABASE_SERVICE_ROLE_KEY.
drop policy if exists "no public writes to tokenbar profiles" on public.tokenbar_profiles;
create policy "no public writes to tokenbar profiles"
on public.tokenbar_profiles
for insert
with check (false);

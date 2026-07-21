-- TokenBar Builder Identity proof-action storage.
-- Run this in Supabase SQL editor, then set:
--   TOKENBAR_ACTION_STORE=supabase
--   SUPABASE_URL=...
--   SUPABASE_SERVICE_ROLE_KEY=...
--
-- Stored rows contain generated proof cards and action-stage metadata only.
-- They must not contain raw prompts, transcripts, source code, diffs, .env files, or secrets.

create table if not exists public.tokenbar_action_runs (
  run_id text primary key,
  token text not null,
  action text not null default 'builder_identity.proof_card.v1',
  status text not null default 'complete',
  run jsonb not null,
  proof jsonb not null,
  created_at_epoch bigint not null,
  inserted_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists tokenbar_action_runs_token_idx
  on public.tokenbar_action_runs (token);

create index if not exists tokenbar_action_runs_created_at_idx
  on public.tokenbar_action_runs (created_at_epoch desc);

create index if not exists tokenbar_action_runs_action_idx
  on public.tokenbar_action_runs (action);

create or replace function public.set_tokenbar_action_runs_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists tokenbar_action_runs_updated_at on public.tokenbar_action_runs;
create trigger tokenbar_action_runs_updated_at
before update on public.tokenbar_action_runs
for each row execute function public.set_tokenbar_action_runs_updated_at();

alter table public.tokenbar_action_runs enable row level security;

drop policy if exists "public can read tokenbar proof actions" on public.tokenbar_action_runs;
create policy "public can read tokenbar proof actions"
on public.tokenbar_action_runs
for select
to anon, authenticated
using (true);

drop policy if exists "no public writes to tokenbar proof actions" on public.tokenbar_action_runs;
create policy "no public writes to tokenbar proof actions"
on public.tokenbar_action_runs
for all
to anon, authenticated
using (false)
with check (false);

-- Safe to run more than once. Supabase Dashboard -> SQL Editor -> New query -> paste -> Run.

create table if not exists public.user_backups (
  user_id uuid primary key references auth.users(id) on delete cascade
);

alter table public.user_backups add column if not exists email text;
alter table public.user_backups add column if not exists user_name text;
alter table public.user_backups add column if not exists course text;
alter table public.user_backups add column if not exists year text;
alter table public.user_backups add column if not exists state text;
alter table public.user_backups add column if not exists holiday_names text;
alter table public.user_backups add column if not exists hidden_hols jsonb;
alter table public.user_backups add column if not exists timetable_file_name text;
alter table public.user_backups add column if not exists subjects jsonb;
alter table public.user_backups add column if not exists holidays jsonb;
alter table public.user_backups add column if not exists history_logs jsonb;
alter table public.user_backups add column if not exists updated_at timestamptz default now();

alter table public.user_backups enable row level security;

drop policy if exists "Users can view own backup" on public.user_backups;
drop policy if exists "Users can insert own backup" on public.user_backups;
drop policy if exists "Users can update own backup" on public.user_backups;
drop policy if exists "Users can delete own backup" on public.user_backups;

create policy "Users can view own backup" on public.user_backups
  for select using (auth.uid() = user_id);
create policy "Users can insert own backup" on public.user_backups
  for insert with check (auth.uid() = user_id);
create policy "Users can update own backup" on public.user_backups
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "Users can delete own backup" on public.user_backups
  for delete using (auth.uid() = user_id);

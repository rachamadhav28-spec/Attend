-- Run this in your Supabase Dashboard -> SQL Editor -> New Query:

create table if not exists public.user_backups (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text,
  user_name text,
  course text,
  year text,
  state text,
  holiday_names text,
  hidden_hols jsonb,
  timetable_file_name text,
  subjects jsonb,
  holidays jsonb,
  history_logs jsonb,
  updated_at timestamptz default now()
);

alter table public.user_backups enable row level security;

create policy "Users can view own backup"
  on public.user_backups for select
  using (auth.uid() = user_id);

create policy "Users can insert own backup"
  on public.user_backups for insert
  with check (auth.uid() = user_id);

create policy "Users can update own backup"
  on public.user_backups for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users can delete own backup"
  on public.user_backups for delete
  using (auth.uid() = user_id);

-- If you already ran the old script, run only these two:
-- drop policy if exists "Users can update own backup" on public.user_backups;
-- create policy "Users can update own backup" on public.user_backups for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
-- create policy "Users can delete own backup" on public.user_backups for delete using (auth.uid() = user_id);

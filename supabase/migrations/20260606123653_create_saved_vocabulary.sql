-- Saved vocabulary: per-user dictionary of words captured from learning content.
create table public.saved_vocabulary (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  word text not null,
  normalized_word text not null,
  source_context text,
  meaning text,
  pronunciation text,
  example_sentence text,
  real_life_usage text,
  created_at timestamptz not null default now(),
  unique (user_id, normalized_word)
);

-- Speeds up the per-user dictionary listing.
create index saved_vocabulary_user_id_created_at_idx
  on public.saved_vocabulary (user_id, created_at desc);

alter table public.saved_vocabulary enable row level security;

create policy "select own vocab" on public.saved_vocabulary
  for select using (auth.uid() = user_id);

create policy "insert own vocab" on public.saved_vocabulary
  for insert with check (auth.uid() = user_id);

create policy "update own vocab" on public.saved_vocabulary
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "delete own vocab" on public.saved_vocabulary
  for delete using (auth.uid() = user_id);

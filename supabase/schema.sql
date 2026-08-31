-- BasirahAI — Supabase schema
-- Paste this into your Supabase project's SQL Editor (Dashboard → SQL Editor → New query) and run it.
-- Matches docs/DATASET.md / plan.md's data model.

create table if not exists patients (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  date_of_birth date,
  gender text,
  cnic text,          -- optional; MVP-level storage only, see docs/DATASET.md privacy notes
  phone text,
  created_at timestamptz not null default now()
);

create table if not exists screenings (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references patients(id) on delete cascade,
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  referable boolean not null,
  confidence double precision not null,
  raw_grade integer not null,
  raw_grade_label text not null,
  created_at timestamptz not null default now()
);

alter table patients enable row level security;
alter table screenings enable row level security;

-- RLS policies control WHICH rows a role can touch, but the role still needs
-- base table-level privileges to touch the table at all. Without these
-- grants, every request fails with "permission denied for table patients"
-- (Postgres error 42501) even though the RLS policies below are correct.
grant select, insert, update, delete on patients to authenticated;
grant select, insert, update, delete on screenings to authenticated;

-- A user can only see/modify their own patients.
create policy "Users manage their own patients"
  on patients for all
  using (owner_user_id = auth.uid())
  with check (owner_user_id = auth.uid());

-- A user can only see/modify their own screenings.
create policy "Users manage their own screenings"
  on screenings for all
  using (owner_user_id = auth.uid())
  with check (owner_user_id = auth.uid());

create index if not exists idx_patients_owner on patients(owner_user_id);
create index if not exists idx_screenings_patient on screenings(patient_id);
create index if not exists idx_screenings_owner on screenings(owner_user_id);

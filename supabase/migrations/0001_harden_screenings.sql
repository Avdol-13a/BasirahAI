-- BasirahAI — hardening migration (2026-09-02)
--
-- NOT applied automatically by anything in this repo. Review, then paste
-- into the live Supabase project's SQL Editor (Dashboard → SQL Editor →
-- New query) and run it yourself, the same way supabase/schema.sql was
-- originally applied (see dev/HANDOFF.md §7/§10).
--
-- Idempotent / rerunnable: every statement below either uses IF NOT EXISTS,
-- IF EXISTS, or a pg_catalog existence check in a DO block first, so running
-- this file twice (or against a project it was already applied to) is safe
-- and a no-op the second time.
--
-- Existing-row risk: the two CHECK constraints below will FAIL TO APPLY
-- (the whole ALTER TABLE statement errors, nothing is partially applied)
-- if any row already violates them. Given the app's own insert paths, this
-- should not happen in practice (confidence always comes from the model's
-- own softmax output — a probability, and raw_grade is always one of the
-- five class indices the model was built to emit), but if this migration
-- errors on ADD CONSTRAINT, inspect existing rows for the violation before
-- retrying rather than weakening the constraint to make it pass.

-- 1. confidence must be a valid probability.
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'screenings_confidence_range') then
    alter table screenings
      add constraint screenings_confidence_range
      check (confidence >= 0 and confidence <= 1);
  end if;
end $$;

-- 2. raw_grade must be one of the model's 5 real class indices.
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'screenings_raw_grade_range') then
    alter table screenings
      add constraint screenings_raw_grade_range
      check (raw_grade >= 0 and raw_grade <= 4);
  end if;
end $$;

-- 3. gender, if set, must be one of the three values the app's own dropdown
-- offers (patient_form_screen.dart) — nullable, since the field is optional.
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'patients_gender_allowed_values') then
    alter table patients
      add constraint patients_gender_allowed_values
      check (gender is null or gender in ('Female', 'Male', 'Other'));
  end if;
end $$;

-- 4. Cross-user authorization gap: the existing RLS policy on `screenings`
-- only checks that owner_user_id = auth.uid() on the screenings row itself
-- -- it does NOT check that the patient_id it references is *also* owned by
-- that same user. As written, an authenticated user could INSERT a
-- screening row with their own owner_user_id but a patient_id belonging to
-- a DIFFERENT user's patient (e.g. a guessed or leaked UUID) — a real data-
-- integrity/authorization violation, even though the app's own UI never
-- does this today (it only ever supplies a patient_id it just loaded for
-- the current user). Fixed by adding an ownership check via an EXISTS
-- subquery against `patients` to the policy's WITH CHECK clause.
--
-- drop-then-create is the standard idempotent pattern for policies
-- (CREATE POLICY has no IF NOT EXISTS); this does not touch existing rows
-- or RLS being enabled, only which future INSERT/UPDATE are allowed.
drop policy if exists "Users manage their own screenings" on screenings;
create policy "Users manage their own screenings"
  on screenings for all
  using (owner_user_id = auth.uid())
  with check (
    owner_user_id = auth.uid()
    and exists (
      select 1 from patients p
      where p.id = screenings.patient_id
        and p.owner_user_id = auth.uid()
    )
  );

-- Note: screenings.id is already the primary key (schema.sql), which
-- already guarantees the uniqueness the client-generated screening UUID
-- (see app/lib/utils/uuid.dart) relies on for its upsert-based idempotent
-- save/retry — no separate uniqueness constraint needed here.

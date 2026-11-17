-- Learn Hub starter schema for Supabase PostgreSQL.
-- Run in Supabase SQL Editor. Review and test RLS policies before production.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  role text not null default 'student' check (role in ('student','teacher','admin')),
  class_level text,
  session text default '2026/2027',
  subjects text[] not null default '{}',
  created_at timestamptz not null default now()
);

create table if not exists public.subjects (
  id uuid primary key default gen_random_uuid(),
  class_level text not null,
  name text not null,
  curriculum_version text not null default 'to-be-verified',
  is_active boolean not null default true,
  unique(class_level,name,curriculum_version)
);
create table if not exists public.topics (
  id uuid primary key default gen_random_uuid(),
  subject_id uuid not null references public.subjects(id) on delete cascade,
  term smallint not null check(term between 1 and 3),
  sequence_no integer not null,
  title text not null,
  learning_objectives jsonb not null default '[]',
  lesson_content jsonb not null default '{}',
  unique(subject_id,term,sequence_no)
);
create table if not exists public.questions (
  id uuid primary key default gen_random_uuid(),
  topic_id uuid not null references public.topics(id) on delete cascade,
  question_text text not null,
  options jsonb not null,
  correct_answer integer not null,
  explanation text not null,
  source_reference text,
  reviewed boolean not null default false
);
create table if not exists public.assessments (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  class_level text not null,
  subject_id uuid references public.subjects(id),
  assessment_type text not null check(assessment_type in ('topic_quiz','three_topic_test','term_exam','mock','external_cbt')),
  term smallint check(term between 1 and 3),
  pass_mark numeric not null default 65 check(pass_mark between 0 and 100),
  question_count integer not null default 40,
  is_published boolean not null default false
);
create table if not exists public.assessment_attempts (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.profiles(id) on delete cascade,
  assessment_id uuid not null references public.assessments(id),
  score numeric not null check(score between 0 and 100),
  passed boolean generated always as (score >= 65) stored,
  answers jsonb not null default '{}',
  completed_at timestamptz not null default now()
);
create table if not exists public.lesson_progress (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.profiles(id) on delete cascade,
  topic_id uuid not null references public.topics(id) on delete cascade,
  completed boolean not null default false,
  updated_at timestamptz not null default now(),
  unique(student_id,topic_id)
);
create table if not exists public.teacher_assignments (
  id uuid primary key default gen_random_uuid(),
  teacher_id uuid not null references public.profiles(id) on delete cascade,
  class_level text not null,
  subject_id uuid references public.subjects(id),
  created_at timestamptz not null default now()
);
create table if not exists public.promotion_records (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.profiles(id) on delete cascade,
  from_class text not null,
  to_class text not null,
  academic_session text not null,
  approved_by uuid references public.profiles(id),
  decision text not null check(decision in ('eligible','promoted','repeat','pending_review')),
  notes text,
  created_at timestamptz not null default now()
);

-- Assign default student profile when a new auth user signs up.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into public.profiles(id,full_name,role)
  values(new.id,coalesce(new.raw_user_meta_data->>'full_name',''),'student')
  on conflict(id) do nothing;
  return new;
end; $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.handle_new_user();

-- Role helper. Role changes must only be performed by trusted administrators.
create or replace function public.current_user_role()
returns text language sql stable security definer set search_path=public as $$
  select role from public.profiles where id=auth.uid()
$$;
create or replace function public.is_staff()
returns boolean language sql stable security definer set search_path=public as $$
  select coalesce(public.current_user_role() in ('teacher','admin'),false)
$$;
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path=public as $$
  select coalesce(public.current_user_role()='admin',false)
$$;

alter table public.profiles enable row level security;
alter table public.subjects enable row level security;
alter table public.topics enable row level security;
alter table public.questions enable row level security;
alter table public.assessments enable row level security;
alter table public.assessment_attempts enable row level security;
alter table public.lesson_progress enable row level security;
alter table public.teacher_assignments enable row level security;
alter table public.promotion_records enable row level security;

-- Profiles: users see/update their own non-role fields; admin can manage all.
create policy "profile read own or admin" on public.profiles for select
using (id=auth.uid() or public.is_admin());
create policy "profile update own safe fields" on public.profiles for update
using (id=auth.uid()) with check (id=auth.uid() and role=(select p.role from public.profiles p where p.id=auth.uid()));
create policy "admin manages profiles" on public.profiles for all
using (public.is_admin()) with check (public.is_admin());

-- Published curriculum visible to signed-in users; admin writes curriculum.
create policy "signed in read subjects" on public.subjects for select to authenticated using (true);
create policy "admin manages subjects" on public.subjects for all using(public.is_admin()) with check(public.is_admin());
create policy "signed in read topics" on public.topics for select to authenticated using (true);
create policy "admin manages topics" on public.topics for all using(public.is_admin()) with check(public.is_admin());
create policy "signed in read reviewed questions" on public.questions for select to authenticated using (reviewed=true);
create policy "admin manages questions" on public.questions for all using(public.is_admin()) with check(public.is_admin());
create policy "signed in read published assessments" on public.assessments for select to authenticated using (is_published=true or public.is_admin());
create policy "admin manages assessments" on public.assessments for all using(public.is_admin()) with check(public.is_admin());

-- Students access their own attempts/progress. Staff may review class work in later
-- deployment after class/assignment scope is implemented and audited.
create policy "student reads own attempts" on public.assessment_attempts for select to authenticated using(student_id=auth.uid() or public.is_admin());
create policy "student inserts own attempts" on public.assessment_attempts for insert to authenticated with check(student_id=auth.uid());
create policy "student reads own progress" on public.lesson_progress for select to authenticated using(student_id=auth.uid() or public.is_admin());
create policy "student manages own progress" on public.lesson_progress for all to authenticated using(student_id=auth.uid()) with check(student_id=auth.uid());
create policy "admin manages assignments" on public.teacher_assignments for all using(public.is_admin()) with check(public.is_admin());
create policy "teacher reads own assignments" on public.teacher_assignments for select to authenticated using(teacher_id=auth.uid() or public.is_admin());
create policy "student reads own promotion" on public.promotion_records for select to authenticated using(student_id=auth.uid() or public.is_admin());
create policy "admin manages promotion" on public.promotion_records for all using(public.is_admin()) with check(public.is_admin());

-- IMPORTANT:
-- 1. Do not expose service_role key in browser code.
-- 2. Provision the first admin securely (trusted server/admin SQL), never via public signup.
-- 3. Add audited server-side functions for teacher creation, role changes, marking,
--    promotion approvals and class-scoped teacher access before production.
-- 4. Review and test every policy with separate student/teacher/admin accounts.

-- Learn Hub 2.0 school-management modules.
create table if not exists public.school_classes (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  class_level text not null,
  academic_session text not null default '2026/2027',
  class_teacher_id uuid references public.profiles(id),
  created_at timestamptz not null default now()
);
create table if not exists public.class_memberships (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.school_classes(id) on delete cascade,
  student_id uuid not null references public.profiles(id) on delete cascade,
  unique(class_id,student_id)
);
create table if not exists public.school_announcements (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null,
  audience text not null default 'all' check(audience in ('all','students','teachers','class')),
  class_id uuid references public.school_classes(id) on delete cascade,
  author_id uuid not null references public.profiles(id),
  published_at timestamptz not null default now()
);
create table if not exists public.assignments (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  instructions text not null default '',
  class_id uuid not null references public.school_classes(id) on delete cascade,
  subject_id uuid references public.subjects(id),
  teacher_id uuid not null references public.profiles(id),
  due_at timestamptz,
  created_at timestamptz not null default now()
);
create table if not exists public.assignment_submissions (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null references public.assignments(id) on delete cascade,
  student_id uuid not null references public.profiles(id) on delete cascade,
  submission_text text,
  file_path text,
  score numeric check(score between 0 and 100),
  feedback text,
  submitted_at timestamptz not null default now(),
  unique(assignment_id,student_id)
);
create table if not exists public.attendance_records (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.profiles(id) on delete cascade,
  class_id uuid not null references public.school_classes(id) on delete cascade,
  attendance_date date not null,
  status text not null check(status in ('present','absent','late','excused')),
  recorded_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  unique(student_id,class_id,attendance_date)
);
create table if not exists public.timetable_periods (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.school_classes(id) on delete cascade,
  subject_id uuid references public.subjects(id),
  teacher_id uuid references public.profiles(id),
  day_of_week smallint not null check(day_of_week between 1 and 5),
  starts_at time not null,
  ends_at time not null,
  room text,
  check(ends_at>starts_at)
);
create table if not exists public.fee_records (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.profiles(id) on delete cascade,
  description text not null,
  amount_kobo bigint not null check(amount_kobo>=0),
  payment_status text not null default 'pending' check(payment_status in ('pending','paid','waived')),
  provider_reference text,
  verified_at timestamptz,
  created_at timestamptz not null default now()
);
create table if not exists public.report_cards (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.profiles(id) on delete cascade,
  class_id uuid not null references public.school_classes(id),
  academic_session text not null,
  term smallint not null check(term between 1 and 3),
  subject_scores jsonb not null default '{}',
  teacher_comment text,
  principal_comment text,
  approved_by uuid references public.profiles(id),
  published_at timestamptz,
  created_at timestamptz not null default now(),
  unique(student_id,academic_session,term)
);

alter table public.school_classes enable row level security;
alter table public.class_memberships enable row level security;
alter table public.school_announcements enable row level security;
alter table public.assignments enable row level security;
alter table public.assignment_submissions enable row level security;
alter table public.attendance_records enable row level security;
alter table public.timetable_periods enable row level security;
alter table public.fee_records enable row level security;
alter table public.report_cards enable row level security;

-- Conservative baseline: administrators manage school records. Students can
-- read their own membership/submission/attendance/fee/report rows. Expand staff
-- access only with audited class-assignment checks before production.
create policy "admin manages school classes" on public.school_classes for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "signed in reads classes" on public.school_classes for select to authenticated using(true);
create policy "admin manages class memberships" on public.class_memberships for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "student reads own memberships" on public.class_memberships for select to authenticated using(student_id=auth.uid() or public.is_admin());
create policy "signed in reads announcements" on public.school_announcements for select to authenticated using(true);
create policy "staff creates announcements" on public.school_announcements for insert to authenticated with check(public.is_staff() and author_id=auth.uid());
create policy "admin manages announcements" on public.school_announcements for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "signed in reads assignments" on public.assignments for select to authenticated using(true);
create policy "teacher creates assignments" on public.assignments for insert to authenticated with check(public.current_user_role()='teacher' and teacher_id=auth.uid());
create policy "teacher manages own assignments" on public.assignments for update to authenticated using(teacher_id=auth.uid() or public.is_admin()) with check(teacher_id=auth.uid() or public.is_admin());
create policy "student reads own submissions" on public.assignment_submissions for select to authenticated using(student_id=auth.uid() or public.is_admin());
create policy "student submits own work" on public.assignment_submissions for insert to authenticated with check(student_id=auth.uid());
create policy "student updates own submission" on public.assignment_submissions for update to authenticated using(student_id=auth.uid()) with check(student_id=auth.uid());
create policy "admin manages submissions" on public.assignment_submissions for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "student reads own attendance" on public.attendance_records for select to authenticated using(student_id=auth.uid() or public.is_admin());
create policy "staff records attendance" on public.attendance_records for insert to authenticated with check(public.is_staff() and recorded_by=auth.uid());
create policy "admin manages attendance" on public.attendance_records for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "signed in reads timetable" on public.timetable_periods for select to authenticated using(true);
create policy "admin manages timetable" on public.timetable_periods for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "student reads own fee records" on public.fee_records for select to authenticated using(student_id=auth.uid() or public.is_admin());
create policy "admin manages fee records" on public.fee_records for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "student reads own published reports" on public.report_cards for select to authenticated using((student_id=auth.uid() and published_at is not null) or public.is_admin());
create policy "admin manages report cards" on public.report_cards for all to authenticated using(public.is_admin()) with check(public.is_admin());

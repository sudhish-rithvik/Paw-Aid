-- PAW-AID Supabase Schema
-- Run this in Supabase SQL Editor: https://supabase.com/dashboard/project/_/sql

-- ============================================================
-- EXTENSIONS
-- ============================================================
create extension if not exists "uuid-ossp";

-- ============================================================
-- PROFILES (extends auth.users)
-- ============================================================
create table public.profiles (
  id uuid references auth.users on delete cascade primary key,
  role text not null default 'citizen'
    check (role in ('citizen', 'ngo_staff', 'admin')),
  display_name text,
  phone text,
  fcm_token text,
  is_suspended boolean default false,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Auto-create profile on signup
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, new.raw_user_meta_data->>'display_name');
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ============================================================
-- NGOS
-- ============================================================
create table public.ngos (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  registration_number text unique,
  email text unique not null,
  phone text,
  city text,
  state text,
  address text,
  website text,
  pan text,
  gst text,
  animal_welfare_license text,
  specializations text[] default '{}',
  operating_hours text,
  num_vehicles int default 0,
  num_volunteers int default 0,
  service_radius_km float default 25,
  lat float,
  lng float,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected', 'suspended')),
  rejection_reason text,
  fcm_token text,
  avg_response_sec int default 0,
  rescue_success_rate float default 0,
  active_cases_count int default 0,
  total_rescued int default 0,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ============================================================
-- NGO DOCUMENTS
-- ============================================================
create table public.ngo_documents (
  id uuid primary key default uuid_generate_v4(),
  ngo_id uuid references public.ngos on delete cascade not null,
  doc_type text not null,
  -- doc_type values: registration_cert | animal_welfare_license | pan | gst | id_proof | address_proof | awb_registration
  storage_path text not null,
  file_name text,
  verified_by uuid references public.profiles,
  created_at timestamptz default now()
);

-- ============================================================
-- VOLUNTEERS
-- ============================================================
create table public.volunteers (
  id uuid primary key default uuid_generate_v4(),
  profile_id uuid references public.profiles on delete set null,
  ngo_id uuid references public.ngos on delete cascade,
  name text not null,
  phone text,
  fcm_token text,
  is_available boolean default true,
  lat float,
  lng float,
  last_location_at timestamptz,
  created_at timestamptz default now()
);

-- ============================================================
-- RESCUE CASES
-- ============================================================
create table public.rescue_cases (
  id uuid primary key default uuid_generate_v4(),
  reporter_id uuid references public.profiles on delete set null,  -- NULL for guest
  lat float not null,
  lng float not null,
  address text,
  notes text,
  image_path text,  -- Supabase Storage path
  status text not null default 'pending'
    check (status in (
      'pending', 'accepted', 'dispatched',
      'animal_picked', 'vet_treatment', 'recovery',
      'completed', 'closed'
    )),
  priority_level text check (priority_level in ('critical', 'high', 'medium', 'low')),
  assigned_ngo_id uuid references public.ngos on delete set null,
  assigned_volunteer_id uuid references public.volunteers on delete set null,
  is_duplicate boolean default false,
  original_case_id uuid references public.rescue_cases on delete set null,
  created_at timestamptz default now(),
  resolved_at timestamptz,
  updated_at timestamptz default now()
);

-- Index for geospatial queries
create index idx_rescue_cases_location on public.rescue_cases (lat, lng);
create index idx_rescue_cases_status on public.rescue_cases (status);
create index idx_rescue_cases_priority on public.rescue_cases (priority_level);
create index idx_rescue_cases_created on public.rescue_cases (created_at desc);

-- ============================================================
-- AI ANALYSES
-- ============================================================
create table public.ai_analyses (
  id uuid primary key default uuid_generate_v4(),
  case_id uuid references public.rescue_cases on delete cascade unique not null,
  animal text,
  visible_injuries text[] default '{}',
  mobility text,
  pain_level text,
  severity text check (severity in ('Low', 'Medium', 'High', 'Critical')),
  confidence float,
  recommended_action text,
  reason text,
  raw_response jsonb,
  is_demo boolean default false,
  analyzed_at timestamptz default now()
);

-- ============================================================
-- RESCUE EVENTS (audit trail per case)
-- ============================================================
create table public.rescue_events (
  id uuid primary key default uuid_generate_v4(),
  case_id uuid references public.rescue_cases on delete cascade not null,
  event_type text not null,
  -- event_type values: status_change | ngo_assigned | photo_uploaded | ai_completed | duplicate_detected | ngo_rejected
  actor_id uuid references public.profiles on delete set null,
  old_status text,
  new_status text,
  metadata jsonb,
  image_path text,  -- stage photo
  created_at timestamptz default now()
);

create index idx_rescue_events_case on public.rescue_events (case_id, created_at desc);

-- ============================================================
-- NGO ANALYTICS SNAPSHOTS
-- ============================================================
create table public.ngo_analytics (
  id uuid primary key default uuid_generate_v4(),
  ngo_id uuid references public.ngos on delete cascade,
  period_date date not null,
  completed_count int default 0,
  avg_response_sec int default 0,
  active_count int default 0,
  critical_handled int default 0,
  high_handled int default 0,
  created_at timestamptz default now(),
  unique(ngo_id, period_date)
);

-- ============================================================
-- STORAGE BUCKETS (run these separately or via Supabase dashboard)
-- ============================================================
-- Bucket: animal-images (public read)
-- Bucket: ngo-documents (private)
-- Bucket: rescue-stages (public read)

-- ============================================================
-- RLS POLICIES
-- ============================================================

-- Enable RLS on all tables
alter table public.profiles enable row level security;
alter table public.ngos enable row level security;
alter table public.ngo_documents enable row level security;
alter table public.volunteers enable row level security;
alter table public.rescue_cases enable row level security;
alter table public.ai_analyses enable row level security;
alter table public.rescue_events enable row level security;
alter table public.ngo_analytics enable row level security;

-- Profiles: users can read/update their own
create policy "Users can view own profile" on public.profiles
  for select using (auth.uid() = id);
create policy "Users can update own profile" on public.profiles
  for update using (auth.uid() = id);

-- Rescue cases: anyone can read, authenticated can create
create policy "Anyone can view rescue cases" on public.rescue_cases
  for select using (true);
create policy "Anyone can create rescue case" on public.rescue_cases
  for insert with check (true);

-- AI analyses: public read
create policy "Anyone can view AI analyses" on public.ai_analyses
  for select using (true);

-- NGOs: public read for approved
create policy "Anyone can view approved NGOs" on public.ngos
  for select using (status = 'approved');

-- NOTE: Backend uses service_key which bypasses RLS for admin operations

-- ============================================================
-- HELPFUL VIEWS
-- ============================================================

create or replace view public.cases_with_analysis as
select
  rc.*,
  aa.animal,
  aa.visible_injuries,
  aa.mobility,
  aa.pain_level,
  aa.severity,
  aa.confidence,
  aa.recommended_action,
  aa.reason,
  aa.is_demo,
  n.name as ngo_name,
  n.phone as ngo_phone,
  n.fcm_token as ngo_fcm_token
from public.rescue_cases rc
left join public.ai_analyses aa on aa.case_id = rc.id
left join public.ngos n on n.id = rc.assigned_ngo_id;

-- ============================================================
-- SEED: Admin account placeholder
-- (Create admin user via Supabase Auth dashboard, then run:)
-- UPDATE public.profiles SET role = 'admin' WHERE id = '<admin-user-id>';
-- ============================================================

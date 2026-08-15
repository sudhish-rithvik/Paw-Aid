-- Enable pgcrypto for password hashing
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. Insert an Admin User
INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
VALUES
('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'admin@pawaid.com', crypt('password123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"display_name": "Admin User"}', now(), now());

-- The trigger handle_new_user() automatically creates a profile. Let's update its role.
UPDATE public.profiles SET role = 'admin', phone = '9000000001' WHERE id = '00000000-0000-0000-0000-000000000001';


-- 2. Insert an NGO Staff User
INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
VALUES
('00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'ngo@pawaid.com', crypt('password123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"display_name": "NGO Worker"}', now(), now());

UPDATE public.profiles SET role = 'ngo_staff', phone = '9000000002' WHERE id = '00000000-0000-0000-0000-000000000002';


-- 3. Insert a Citizen User
INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
VALUES
('00000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'citizen@pawaid.com', crypt('password123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"display_name": "Helpful Citizen"}', now(), now());

UPDATE public.profiles SET role = 'citizen', phone = '9000000003' WHERE id = '00000000-0000-0000-0000-000000000003';


-- 4. Create an Approved NGO
INSERT INTO public.ngos (id, name, registration_number, email, phone, city, state, address, specializations, status, lat, lng)
VALUES
('10000000-0000-0000-0000-000000000001', 'Chennai Animal Rescue Foundation', 'TN/NGO/2024/001', 'contact@carf.org', '9999999999', 'Chennai', 'Tamil Nadu', '123 Marina Beach Road', '{"Dog", "Cat", "Cow"}', 'approved', 13.0827, 80.2707);


-- 5. Link the NGO Staff User to the NGO as a Volunteer
INSERT INTO public.volunteers (id, profile_id, ngo_id, name, phone, is_available)
VALUES
(uuid_generate_v4(), '00000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', 'NGO Worker', '9000000002', true);


-- 6. Create a Dummy Rescue Case reported by the Citizen
INSERT INTO public.rescue_cases (id, reporter_id, lat, lng, address, notes, status, priority_level)
VALUES
('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000003', 13.0850, 80.2700, 'Near Chennai Central Station', 'Found a dog limping heavily on the street.', 'pending', 'high');


-- 7. Create a Dummy AI Analysis for the Case
INSERT INTO public.ai_analyses (case_id, animal, visible_injuries, mobility, severity, confidence, recommended_action)
VALUES
('20000000-0000-0000-0000-000000000001', 'Dog', '{"broken leg"}', 'Limping', 'High', 0.92, 'Dispatch rescue team immediately.');

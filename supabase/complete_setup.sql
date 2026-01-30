-- =====================================================
-- COMPLETE DATABASE SETUP - RUN THIS FIRST
-- =====================================================
-- This script creates ALL missing tables safely
-- Run this in Supabase SQL Editor
-- =====================================================

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================
-- PART 1: CREATE ENUMS (if not exist)
-- =====================================================
DO $$ BEGIN
  CREATE TYPE public.user_role AS ENUM ('super_admin', 'manager', 'accountant', 'delivery_staff', 'farm_worker', 'vet_staff', 'auditor');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
  CREATE TYPE public.cattle_status AS ENUM ('active', 'sold', 'deceased', 'dry');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
  CREATE TYPE public.lactation_status AS ENUM ('lactating', 'dry', 'pregnant', 'calving');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
  CREATE TYPE public.delivery_status AS ENUM ('pending', 'delivered', 'missed', 'partial');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
  CREATE TYPE public.payment_status AS ENUM ('paid', 'partial', 'pending', 'overdue');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
  CREATE TYPE public.bottle_type AS ENUM ('glass', 'plastic');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
  CREATE TYPE public.bottle_size AS ENUM ('500ml', '1L', '2L', '5L');
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- =====================================================
-- PART 2: CREATE HELPER FUNCTIONS
-- =====================================================
CREATE OR REPLACE FUNCTION public.is_authenticated()
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN RETURN auth.uid() IS NOT NULL; END; $$;

CREATE OR REPLACE FUNCTION public.has_role(_user_id UUID, _role user_role)
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER STABLE AS $$
BEGIN RETURN EXISTS (SELECT 1 FROM public.profiles WHERE id = _user_id AND role = _role); END; $$;

CREATE OR REPLACE FUNCTION public.is_manager_or_admin(_user_id UUID)
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER STABLE AS $$
BEGIN RETURN EXISTS (SELECT 1 FROM public.profiles WHERE id = _user_id AND role IN ('super_admin', 'manager')); END; $$;

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END; $$;

-- =====================================================
-- PART 3: CREATE ALL TABLES IF NOT EXISTS
-- =====================================================

-- Milk vendors table
CREATE TABLE IF NOT EXISTS public.milk_vendors (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  phone TEXT,
  address TEXT,
  area TEXT,
  is_active BOOLEAN DEFAULT true,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Milk procurement table
CREATE TABLE IF NOT EXISTS public.milk_procurement (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vendor_id UUID REFERENCES public.milk_vendors(id) ON DELETE SET NULL,
  vendor_name TEXT,
  procurement_date DATE NOT NULL,
  session TEXT NOT NULL CHECK (session IN ('morning', 'evening')),
  quantity_liters DECIMAL(10,2) NOT NULL,
  fat_percentage DECIMAL(4,2),
  snf_percentage DECIMAL(4,2),
  rate_per_liter DECIMAL(10,2),
  total_amount DECIMAL(12,2),
  payment_status TEXT DEFAULT 'pending' CHECK (payment_status IN ('pending', 'partial', 'paid')),
  notes TEXT,
  recorded_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Subscriptions table
CREATE TABLE IF NOT EXISTS public.subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID REFERENCES public.customers(id) ON DELETE CASCADE NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE,
  status TEXT DEFAULT 'active',
  delivery_frequency TEXT DEFAULT 'daily',
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Subscription items table
CREATE TABLE IF NOT EXISTS public.subscription_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  subscription_id UUID REFERENCES public.subscriptions(id) ON DELETE CASCADE NOT NULL,
  product_id UUID REFERENCES public.products(id) ON DELETE CASCADE NOT NULL,
  quantity DECIMAL(6,2) NOT NULL,
  custom_price DECIMAL(10,2),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- PART 4: ENABLE RLS ON ALL TABLES
-- =====================================================
ALTER TABLE public.milk_vendors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.milk_procurement ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscription_items ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- PART 5: CREATE RLS POLICIES FOR NEW TABLES
-- =====================================================

-- Milk vendors policies
DROP POLICY IF EXISTS "allow_auth_milk_vendors" ON public.milk_vendors;
CREATE POLICY "allow_auth_milk_vendors" ON public.milk_vendors FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Milk procurement policies  
DROP POLICY IF EXISTS "allow_auth_milk_procurement" ON public.milk_procurement;
CREATE POLICY "allow_auth_milk_procurement" ON public.milk_procurement FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Subscriptions policies
DROP POLICY IF EXISTS "allow_auth_subscriptions" ON public.subscriptions;
CREATE POLICY "allow_auth_subscriptions" ON public.subscriptions FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Subscription items policies
DROP POLICY IF EXISTS "allow_auth_subscription_items" ON public.subscription_items;
CREATE POLICY "allow_auth_subscription_items" ON public.subscription_items FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- =====================================================
-- PART 6: CREATE ALL VIEWS
-- =====================================================
DROP VIEW IF EXISTS public.profiles_safe CASCADE;
CREATE VIEW public.profiles_safe AS
SELECT id, full_name, phone, role, is_active, avatar_url, created_at, updated_at
FROM public.profiles;

DROP VIEW IF EXISTS public.customer_accounts_safe CASCADE;
CREATE VIEW public.customer_accounts_safe AS
SELECT id, customer_id, phone, user_id, is_approved, approval_status, approved_at, approved_by, last_login, created_at, updated_at
FROM public.customer_accounts;

DROP VIEW IF EXISTS public.customers_delivery_view CASCADE;
CREATE VIEW public.customers_delivery_view AS
SELECT id, name, area, address, route_id, is_active FROM public.customers;

DROP VIEW IF EXISTS public.employees_auditor_view CASCADE;
CREATE VIEW public.employees_auditor_view AS
SELECT id, name, phone, role, address, joining_date, user_id, is_active, created_at, updated_at FROM public.employees;

DROP VIEW IF EXISTS public.dairy_settings_public CASCADE;
CREATE VIEW public.dairy_settings_public AS
SELECT id, dairy_name, logo_url, currency, invoice_prefix, financial_year_start FROM public.dairy_settings;

-- =====================================================
-- PART 7: RLS FOR ALL EXISTING TABLES
-- =====================================================

-- Create a function to add standard policies
CREATE OR REPLACE FUNCTION add_auth_policy(table_name TEXT) RETURNS void AS $$
BEGIN
  EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', table_name);
  EXECUTE format('DROP POLICY IF EXISTS "auth_all_%I" ON public.%I', table_name, table_name);
  EXECUTE format('CREATE POLICY "auth_all_%I" ON public.%I FOR ALL TO authenticated USING (true) WITH CHECK (true)', table_name, table_name);
END;
$$ LANGUAGE plpgsql;

-- Apply to all tables
SELECT add_auth_policy('profiles');
SELECT add_auth_policy('dairy_settings');
SELECT add_auth_policy('routes');
SELECT add_auth_policy('route_stops');
SELECT add_auth_policy('customers');
SELECT add_auth_policy('employees');
SELECT add_auth_policy('cattle');
SELECT add_auth_policy('milk_production');
SELECT add_auth_policy('products');
SELECT add_auth_policy('price_rules');
SELECT add_auth_policy('invoices');
SELECT add_auth_policy('payments');
SELECT add_auth_policy('expenses');
SELECT add_auth_policy('deliveries');
SELECT add_auth_policy('delivery_items');
SELECT add_auth_policy('customer_ledger');
SELECT add_auth_policy('customer_accounts');
SELECT add_auth_policy('notification_templates');
SELECT add_auth_policy('notification_logs');
SELECT add_auth_policy('bottles');
SELECT add_auth_policy('customer_bottles');
SELECT add_auth_policy('cattle_health');
SELECT add_auth_policy('attendance');
SELECT add_auth_policy('payroll_records');
SELECT add_auth_policy('activity_logs');
SELECT add_auth_policy('user_roles');

-- =====================================================
-- PART 8: USER MANAGEMENT FUNCTIONS
-- =====================================================
CREATE OR REPLACE FUNCTION public.change_own_pin(_current_pin TEXT, _new_pin TEXT)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE _user_id UUID; _profile RECORD;
BEGIN
  _user_id := auth.uid();
  IF _user_id IS NULL THEN RETURN '{"success":false,"error":"Not authenticated"}'::jsonb; END IF;
  IF _new_pin IS NULL OR length(_new_pin) != 6 OR _new_pin !~ '^[0-9]+$' THEN RETURN '{"success":false,"error":"PIN must be 6 digits"}'::jsonb; END IF;
  SELECT * INTO _profile FROM public.profiles WHERE id = _user_id AND pin_hash = crypt(_current_pin, pin_hash);
  IF _profile IS NULL THEN RETURN '{"success":false,"error":"Current PIN incorrect"}'::jsonb; END IF;
  UPDATE public.profiles SET pin_hash = crypt(_new_pin, gen_salt('bf')), updated_at = NOW() WHERE id = _user_id;
  RETURN '{"success":true,"message":"PIN changed"}'::jsonb;
END; $$;

CREATE OR REPLACE FUNCTION public.admin_update_user_status(_target_user_id UUID, _is_active BOOLEAN)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'super_admin') THEN RETURN '{"success":false,"error":"Unauthorized"}'::jsonb; END IF;
  UPDATE public.profiles SET is_active = _is_active, updated_at = NOW() WHERE id = _target_user_id;
  RETURN jsonb_build_object('success', true, 'message', CASE WHEN _is_active THEN 'Activated' ELSE 'Deactivated' END);
END; $$;

CREATE OR REPLACE FUNCTION public.admin_reset_user_pin(_target_user_id UUID, _new_pin TEXT)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'super_admin') THEN RETURN '{"success":false,"error":"Unauthorized"}'::jsonb; END IF;
  IF _new_pin IS NULL OR length(_new_pin) != 6 OR _new_pin !~ '^[0-9]+$' THEN RETURN '{"success":false,"error":"PIN must be 6 digits"}'::jsonb; END IF;
  UPDATE public.profiles SET pin_hash = crypt(_new_pin, gen_salt('bf')), updated_at = NOW() WHERE id = _target_user_id;
  RETURN '{"success":true,"message":"PIN reset"}'::jsonb;
END; $$;

GRANT EXECUTE ON FUNCTION public.change_own_pin(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_user_status(UUID, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_reset_user_pin(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_authenticated() TO authenticated;
GRANT EXECUTE ON FUNCTION public.has_role(UUID, user_role) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_manager_or_admin(UUID) TO authenticated;

-- =====================================================
-- DONE
-- =====================================================
SELECT '✅ COMPLETE DATABASE SETUP DONE!' AS status;

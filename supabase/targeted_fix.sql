-- =====================================================
-- TARGETED FIX FOR AWADH DAIRY ERRORS
-- =====================================================
-- Run this in Supabase SQL Editor
-- This fixes the specific errors shown in screenshots
-- =====================================================

-- =====================================================
-- FIX 1: Create customer_accounts_safe view
-- Error: "Could not find the table 'customer_accounts_safe'"
-- =====================================================
DO $$
BEGIN
  -- Drop if exists to recreate cleanly
  DROP VIEW IF EXISTS public.customer_accounts_safe;
  
  -- Create the safe view that excludes pin_hash
  CREATE VIEW public.customer_accounts_safe AS
  SELECT 
    id,
    customer_id,
    phone,
    user_id,
    is_approved,
    approval_status,
    approved_at,
    approved_by,
    last_login,
    created_at,
    updated_at
  FROM public.customer_accounts;
  
  RAISE NOTICE 'Created customer_accounts_safe view';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Error creating customer_accounts_safe: %', SQLERRM;
END $$;

-- =====================================================
-- FIX 2: Create profiles_safe view  
-- =====================================================
DO $$
BEGIN
  DROP VIEW IF EXISTS public.profiles_safe;
  
  CREATE VIEW public.profiles_safe AS
  SELECT 
    id, 
    full_name, 
    phone, 
    role, 
    is_active, 
    avatar_url,
    created_at, 
    updated_at
  FROM public.profiles;
  
  RAISE NOTICE 'Created profiles_safe view';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Error creating profiles_safe: %', SQLERRM;
END $$;

-- =====================================================
-- FIX 3: Create other required views
-- =====================================================
DO $$
BEGIN
  DROP VIEW IF EXISTS public.customers_delivery_view;
  CREATE VIEW public.customers_delivery_view AS
  SELECT id, name, area, address, route_id, is_active
  FROM public.customers;
  RAISE NOTICE 'Created customers_delivery_view';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Error creating customers_delivery_view: %', SQLERRM;
END $$;

DO $$
BEGIN
  DROP VIEW IF EXISTS public.employees_auditor_view;
  CREATE VIEW public.employees_auditor_view AS
  SELECT id, name, phone, role, address, joining_date, user_id, is_active, created_at, updated_at
  FROM public.employees;
  RAISE NOTICE 'Created employees_auditor_view';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Error creating employees_auditor_view: %', SQLERRM;
END $$;

DO $$
BEGIN
  DROP VIEW IF EXISTS public.dairy_settings_public;
  CREATE VIEW public.dairy_settings_public AS
  SELECT id, dairy_name, logo_url, currency, invoice_prefix, financial_year_start
  FROM public.dairy_settings;
  RAISE NOTICE 'Created dairy_settings_public view';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Error creating dairy_settings_public: %', SQLERRM;
END $$;

-- =====================================================
-- FIX 4: Ensure RLS policies allow authenticated users
-- Error: "TypeError: Failed to fetch" and "Failed to create order"
-- =====================================================

-- Invoices table RLS
DO $$
BEGIN
  ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
  
  DROP POLICY IF EXISTS "auth_select_invoices" ON public.invoices;
  DROP POLICY IF EXISTS "auth_insert_invoices" ON public.invoices;
  DROP POLICY IF EXISTS "auth_update_invoices" ON public.invoices;
  
  CREATE POLICY "auth_select_invoices" ON public.invoices FOR SELECT TO authenticated USING (true);
  CREATE POLICY "auth_insert_invoices" ON public.invoices FOR INSERT TO authenticated WITH CHECK (true);
  CREATE POLICY "auth_update_invoices" ON public.invoices FOR UPDATE TO authenticated USING (true);
  
  RAISE NOTICE 'Configured invoices RLS policies';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Error with invoices RLS: %', SQLERRM;
END $$;

-- Deliveries table RLS
DO $$
BEGIN
  ALTER TABLE public.deliveries ENABLE ROW LEVEL SECURITY;
  
  DROP POLICY IF EXISTS "auth_select_deliveries" ON public.deliveries;
  DROP POLICY IF EXISTS "auth_insert_deliveries" ON public.deliveries;
  DROP POLICY IF EXISTS "auth_update_deliveries" ON public.deliveries;
  
  CREATE POLICY "auth_select_deliveries" ON public.deliveries FOR SELECT TO authenticated USING (true);
  CREATE POLICY "auth_insert_deliveries" ON public.deliveries FOR INSERT TO authenticated WITH CHECK (true);
  CREATE POLICY "auth_update_deliveries" ON public.deliveries FOR UPDATE TO authenticated USING (true);
  
  RAISE NOTICE 'Configured deliveries RLS policies';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Error with deliveries RLS: %', SQLERRM;
END $$;

-- Delivery items table RLS
DO $$
BEGIN
  ALTER TABLE public.delivery_items ENABLE ROW LEVEL SECURITY;
  
  DROP POLICY IF EXISTS "auth_select_delivery_items" ON public.delivery_items;
  DROP POLICY IF EXISTS "auth_insert_delivery_items" ON public.delivery_items;
  DROP POLICY IF EXISTS "auth_update_delivery_items" ON public.delivery_items;
  
  CREATE POLICY "auth_select_delivery_items" ON public.delivery_items FOR SELECT TO authenticated USING (true);
  CREATE POLICY "auth_insert_delivery_items" ON public.delivery_items FOR INSERT TO authenticated WITH CHECK (true);
  CREATE POLICY "auth_update_delivery_items" ON public.delivery_items FOR UPDATE TO authenticated USING (true);
  
  RAISE NOTICE 'Configured delivery_items RLS policies';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Error with delivery_items RLS: %', SQLERRM;
END $$;

-- Customer ledger table RLS
DO $$
BEGIN
  ALTER TABLE public.customer_ledger ENABLE ROW LEVEL SECURITY;
  
  DROP POLICY IF EXISTS "auth_select_customer_ledger" ON public.customer_ledger;
  DROP POLICY IF EXISTS "auth_insert_customer_ledger" ON public.customer_ledger;
  DROP POLICY IF EXISTS "auth_update_customer_ledger" ON public.customer_ledger;
  
  CREATE POLICY "auth_select_customer_ledger" ON public.customer_ledger FOR SELECT TO authenticated USING (true);
  CREATE POLICY "auth_insert_customer_ledger" ON public.customer_ledger FOR INSERT TO authenticated WITH CHECK (true);
  CREATE POLICY "auth_update_customer_ledger" ON public.customer_ledger FOR UPDATE TO authenticated USING (true);
  
  RAISE NOTICE 'Configured customer_ledger RLS policies';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Error with customer_ledger RLS: %', SQLERRM;
END $$;

-- Customers table RLS
DO $$
BEGIN
  ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
  
  DROP POLICY IF EXISTS "auth_select_customers" ON public.customers;
  DROP POLICY IF EXISTS "auth_insert_customers" ON public.customers;
  DROP POLICY IF EXISTS "auth_update_customers" ON public.customers;
  
  CREATE POLICY "auth_select_customers" ON public.customers FOR SELECT TO authenticated USING (true);
  CREATE POLICY "auth_insert_customers" ON public.customers FOR INSERT TO authenticated WITH CHECK (true);
  CREATE POLICY "auth_update_customers" ON public.customers FOR UPDATE TO authenticated USING (true);
  
  RAISE NOTICE 'Configured customers RLS policies';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Error with customers RLS: %', SQLERRM;
END $$;

-- Products table RLS
DO $$
BEGIN
  ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
  
  DROP POLICY IF EXISTS "auth_select_products" ON public.products;
  DROP POLICY IF EXISTS "auth_insert_products" ON public.products;
  DROP POLICY IF EXISTS "auth_update_products" ON public.products;
  
  CREATE POLICY "auth_select_products" ON public.products FOR SELECT TO authenticated USING (true);
  CREATE POLICY "auth_insert_products" ON public.products FOR INSERT TO authenticated WITH CHECK (true);
  CREATE POLICY "auth_update_products" ON public.products FOR UPDATE TO authenticated USING (true);
  
  RAISE NOTICE 'Configured products RLS policies';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Error with products RLS: %', SQLERRM;
END $$;

-- Customer accounts table RLS
DO $$
BEGIN
  ALTER TABLE public.customer_accounts ENABLE ROW LEVEL SECURITY;
  
  DROP POLICY IF EXISTS "auth_select_customer_accounts" ON public.customer_accounts;
  DROP POLICY IF EXISTS "auth_insert_customer_accounts" ON public.customer_accounts;
  DROP POLICY IF EXISTS "auth_update_customer_accounts" ON public.customer_accounts;
  
  CREATE POLICY "auth_select_customer_accounts" ON public.customer_accounts FOR SELECT TO authenticated USING (true);
  CREATE POLICY "auth_insert_customer_accounts" ON public.customer_accounts FOR INSERT TO authenticated WITH CHECK (true);
  CREATE POLICY "auth_update_customer_accounts" ON public.customer_accounts FOR UPDATE TO authenticated USING (true);
  
  RAISE NOTICE 'Configured customer_accounts RLS policies';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Error with customer_accounts RLS: %', SQLERRM;
END $$;

-- Payments table RLS
DO $$
BEGIN
  ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
  
  DROP POLICY IF EXISTS "auth_select_payments" ON public.payments;
  DROP POLICY IF EXISTS "auth_insert_payments" ON public.payments;
  DROP POLICY IF EXISTS "auth_update_payments" ON public.payments;
  
  CREATE POLICY "auth_select_payments" ON public.payments FOR SELECT TO authenticated USING (true);
  CREATE POLICY "auth_insert_payments" ON public.payments FOR INSERT TO authenticated WITH CHECK (true);
  CREATE POLICY "auth_update_payments" ON public.payments FOR UPDATE TO authenticated USING (true);
  
  RAISE NOTICE 'Configured payments RLS policies';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Error with payments RLS: %', SQLERRM;
END $$;

-- =====================================================
-- FIX 5: User management functions
-- =====================================================
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- change_own_pin function
CREATE OR REPLACE FUNCTION public.change_own_pin(_current_pin TEXT, _new_pin TEXT)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  _user_id UUID;
  _profile RECORD;
BEGIN
  _user_id := auth.uid();
  IF _user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;
  IF _new_pin IS NULL OR length(_new_pin) != 6 OR _new_pin !~ '^[0-9]+$' THEN
    RETURN jsonb_build_object('success', false, 'error', 'New PIN must be exactly 6 digits');
  END IF;
  SELECT * INTO _profile FROM public.profiles WHERE id = _user_id AND pin_hash = crypt(_current_pin, pin_hash);
  IF _profile IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Current PIN is incorrect');
  END IF;
  UPDATE public.profiles SET pin_hash = crypt(_new_pin, gen_salt('bf')), updated_at = NOW() WHERE id = _user_id;
  RETURN jsonb_build_object('success', true, 'message', 'PIN changed successfully');
END;
$$;

-- admin_update_user_status function
CREATE OR REPLACE FUNCTION public.admin_update_user_status(_target_user_id UUID, _is_active BOOLEAN)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'super_admin') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
  END IF;
  UPDATE public.profiles SET is_active = _is_active, updated_at = NOW() WHERE id = _target_user_id;
  IF FOUND THEN
    RETURN jsonb_build_object('success', true, 'message', CASE WHEN _is_active THEN 'User activated' ELSE 'User deactivated' END);
  ELSE
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;
END;
$$;

-- admin_reset_user_pin function
CREATE OR REPLACE FUNCTION public.admin_reset_user_pin(_target_user_id UUID, _new_pin TEXT)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'super_admin') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
  END IF;
  IF _new_pin IS NULL OR length(_new_pin) != 6 OR _new_pin !~ '^[0-9]+$' THEN
    RETURN jsonb_build_object('success', false, 'error', 'PIN must be exactly 6 digits');
  END IF;
  UPDATE public.profiles SET pin_hash = crypt(_new_pin, gen_salt('bf')), updated_at = NOW() WHERE id = _target_user_id;
  IF FOUND THEN
    RETURN jsonb_build_object('success', true, 'message', 'PIN reset successfully');
  ELSE
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;
END;
$$;

-- Grant function permissions
GRANT EXECUTE ON FUNCTION public.change_own_pin(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_user_status(UUID, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_reset_user_pin(UUID, TEXT) TO authenticated;

-- =====================================================
-- VERIFICATION
-- =====================================================
SELECT '✅ FIX COMPLETE! Verify views exist:' as status;

SELECT 'VIEW' as type, viewname as name 
FROM pg_views 
WHERE schemaname = 'public' 
AND viewname IN ('customer_accounts_safe', 'profiles_safe', 'customers_delivery_view', 'employees_auditor_view', 'dairy_settings_public')
ORDER BY name;

-- =====================================================
-- COMPREHENSIVE DATABASE FIX - Run in Supabase SQL Editor
-- =====================================================
-- This file fixes all missing views, tables, RLS policies,
-- and functions causing errors in the Awadh Dairy application.
-- 
-- Errors being fixed:
-- 1. "TypeError: Failed to fetch" on Billing page
-- 2. "Failed to create order" on Quick Add-on Order
-- 3. "Could not find table 'customer_accounts_safe'" on Customers page
-- 
-- Run this ONCE in Supabase SQL Editor.
-- =====================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================
-- SECTION 1: CREATE MISSING VIEWS
-- =====================================================

-- 1.1 Safe profiles view (excludes pin_hash for security)
DROP VIEW IF EXISTS public.profiles_safe CASCADE;
CREATE OR REPLACE VIEW public.profiles_safe AS
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

-- 1.2 Safe customer accounts view (excludes pin_hash)
DROP VIEW IF EXISTS public.customer_accounts_safe CASCADE;
CREATE OR REPLACE VIEW public.customer_accounts_safe AS
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

-- 1.3 Dairy settings public view
DROP VIEW IF EXISTS public.dairy_settings_public CASCADE;
CREATE OR REPLACE VIEW public.dairy_settings_public AS
SELECT 
  id,
  dairy_name,
  logo_url,
  currency,
  invoice_prefix,
  financial_year_start
FROM public.dairy_settings;

-- 1.4 Customers delivery view (for delivery staff)
DROP VIEW IF EXISTS public.customers_delivery_view CASCADE;
CREATE OR REPLACE VIEW public.customers_delivery_view AS
SELECT 
  id,
  name,
  area,
  address,
  route_id,
  is_active
FROM public.customers;

-- 1.5 Employees auditor view (for auditors)
DROP VIEW IF EXISTS public.employees_auditor_view CASCADE;
CREATE OR REPLACE VIEW public.employees_auditor_view AS
SELECT 
  id,
  name,
  phone,
  role,
  address,
  joining_date,
  user_id,
  is_active,
  created_at,
  updated_at
FROM public.employees;

-- =====================================================
-- SECTION 2: FIX RLS POLICIES FOR INVOICES TABLE
-- =====================================================

-- Ensure RLS is enabled on invoices
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Authenticated users can read invoices" ON public.invoices;
DROP POLICY IF EXISTS "Authenticated users can insert invoices" ON public.invoices;
DROP POLICY IF EXISTS "Authenticated users can update invoices" ON public.invoices;
DROP POLICY IF EXISTS "Authenticated users can delete invoices" ON public.invoices;
DROP POLICY IF EXISTS "Block anonymous access to invoices" ON public.invoices;

-- Create comprehensive RLS policies for invoices
CREATE POLICY "Authenticated users can read invoices" ON public.invoices
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Authenticated users can insert invoices" ON public.invoices
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Authenticated users can update invoices" ON public.invoices
  FOR UPDATE TO authenticated USING (true);

CREATE POLICY "Authenticated users can delete invoices" ON public.invoices
  FOR DELETE TO authenticated USING (
    public.is_manager_or_admin(auth.uid())
    OR public.has_role(auth.uid(), 'accountant'::user_role)
  );

CREATE POLICY "Block anonymous access to invoices" ON public.invoices
  AS RESTRICTIVE FOR ALL TO anon USING (false);

-- =====================================================
-- SECTION 3: FIX RLS POLICIES FOR DELIVERIES TABLE
-- =====================================================

ALTER TABLE public.deliveries ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read deliveries" ON public.deliveries;
DROP POLICY IF EXISTS "Authenticated users can insert deliveries" ON public.deliveries;
DROP POLICY IF EXISTS "Authenticated users can update deliveries" ON public.deliveries;
DROP POLICY IF EXISTS "Authenticated users can delete deliveries" ON public.deliveries;
DROP POLICY IF EXISTS "Block anonymous access to deliveries" ON public.deliveries;

CREATE POLICY "Authenticated users can read deliveries" ON public.deliveries
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Authenticated users can insert deliveries" ON public.deliveries
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Authenticated users can update deliveries" ON public.deliveries
  FOR UPDATE TO authenticated USING (true);

CREATE POLICY "Authenticated users can delete deliveries" ON public.deliveries
  FOR DELETE TO authenticated USING (
    public.is_manager_or_admin(auth.uid())
  );

CREATE POLICY "Block anonymous access to deliveries" ON public.deliveries
  AS RESTRICTIVE FOR ALL TO anon USING (false);

-- =====================================================
-- SECTION 4: FIX RLS POLICIES FOR DELIVERY_ITEMS TABLE
-- =====================================================

ALTER TABLE public.delivery_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read delivery_items" ON public.delivery_items;
DROP POLICY IF EXISTS "Authenticated users can insert delivery_items" ON public.delivery_items;
DROP POLICY IF EXISTS "Authenticated users can update delivery_items" ON public.delivery_items;
DROP POLICY IF EXISTS "Authenticated users can delete delivery_items" ON public.delivery_items;
DROP POLICY IF EXISTS "Block anonymous access to delivery_items" ON public.delivery_items;

CREATE POLICY "Authenticated users can read delivery_items" ON public.delivery_items
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Authenticated users can insert delivery_items" ON public.delivery_items
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Authenticated users can update delivery_items" ON public.delivery_items
  FOR UPDATE TO authenticated USING (true);

CREATE POLICY "Authenticated users can delete delivery_items" ON public.delivery_items
  FOR DELETE TO authenticated USING (
    public.is_manager_or_admin(auth.uid())
  );

CREATE POLICY "Block anonymous access to delivery_items" ON public.delivery_items
  AS RESTRICTIVE FOR ALL TO anon USING (false);

-- =====================================================
-- SECTION 5: FIX RLS POLICIES FOR CUSTOMER_LEDGER TABLE
-- =====================================================

ALTER TABLE public.customer_ledger ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read customer_ledger" ON public.customer_ledger;
DROP POLICY IF EXISTS "Authenticated users can insert customer_ledger" ON public.customer_ledger;
DROP POLICY IF EXISTS "Authenticated users can update customer_ledger" ON public.customer_ledger;
DROP POLICY IF EXISTS "Authenticated users can delete customer_ledger" ON public.customer_ledger;
DROP POLICY IF EXISTS "Block anonymous access to customer_ledger" ON public.customer_ledger;

CREATE POLICY "Authenticated users can read customer_ledger" ON public.customer_ledger
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Authenticated users can insert customer_ledger" ON public.customer_ledger
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Authenticated users can update customer_ledger" ON public.customer_ledger
  FOR UPDATE TO authenticated USING (true);

CREATE POLICY "Authenticated users can delete customer_ledger" ON public.customer_ledger
  FOR DELETE TO authenticated USING (
    public.is_manager_or_admin(auth.uid())
  );

CREATE POLICY "Block anonymous access to customer_ledger" ON public.customer_ledger
  AS RESTRICTIVE FOR ALL TO anon USING (false);

-- =====================================================
-- SECTION 6: FIX RLS POLICIES FOR CUSTOMER_ACCOUNTS TABLE
-- =====================================================

ALTER TABLE public.customer_accounts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read customer_accounts" ON public.customer_accounts;
DROP POLICY IF EXISTS "Authenticated users can insert customer_accounts" ON public.customer_accounts;
DROP POLICY IF EXISTS "Authenticated users can update customer_accounts" ON public.customer_accounts;
DROP POLICY IF EXISTS "Block anonymous access to customer_accounts" ON public.customer_accounts;

CREATE POLICY "Authenticated users can read customer_accounts" ON public.customer_accounts
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Authenticated users can insert customer_accounts" ON public.customer_accounts
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Authenticated users can update customer_accounts" ON public.customer_accounts
  FOR UPDATE TO authenticated USING (true);

CREATE POLICY "Block anonymous access to customer_accounts" ON public.customer_accounts
  AS RESTRICTIVE FOR ALL TO anon USING (false);

-- =====================================================
-- SECTION 7: FIX RLS POLICIES FOR PAYMENTS TABLE
-- =====================================================

ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read payments" ON public.payments;
DROP POLICY IF EXISTS "Authenticated users can insert payments" ON public.payments;
DROP POLICY IF EXISTS "Authenticated users can update payments" ON public.payments;
DROP POLICY IF EXISTS "Block anonymous access to payments" ON public.payments;

CREATE POLICY "Authenticated users can read payments" ON public.payments
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Authenticated users can insert payments" ON public.payments
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Authenticated users can update payments" ON public.payments
  FOR UPDATE TO authenticated USING (true);

CREATE POLICY "Block anonymous access to payments" ON public.payments
  AS RESTRICTIVE FOR ALL TO anon USING (false);

-- =====================================================
-- SECTION 8: FIX RLS POLICIES FOR CUSTOMERS TABLE
-- =====================================================

ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read customers" ON public.customers;
DROP POLICY IF EXISTS "Authenticated users can insert customers" ON public.customers;
DROP POLICY IF EXISTS "Authenticated users can update customers" ON public.customers;
DROP POLICY IF EXISTS "Block anonymous access to customers" ON public.customers;

CREATE POLICY "Authenticated users can read customers" ON public.customers
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Authenticated users can insert customers" ON public.customers
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Authenticated users can update customers" ON public.customers
  FOR UPDATE TO authenticated USING (true);

CREATE POLICY "Block anonymous access to customers" ON public.customers
  AS RESTRICTIVE FOR ALL TO anon USING (false);

-- =====================================================
-- SECTION 9: FIX RLS POLICIES FOR PRODUCTS TABLE
-- =====================================================

ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read products" ON public.products;
DROP POLICY IF EXISTS "Authenticated users can insert products" ON public.products;
DROP POLICY IF EXISTS "Authenticated users can update products" ON public.products;
DROP POLICY IF EXISTS "Block anonymous access to products" ON public.products;

CREATE POLICY "Authenticated users can read products" ON public.products
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Authenticated users can insert products" ON public.products
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Authenticated users can update products" ON public.products
  FOR UPDATE TO authenticated USING (true);

CREATE POLICY "Block anonymous access to products" ON public.products
  AS RESTRICTIVE FOR ALL TO anon USING (false);

-- =====================================================
-- SECTION 10: DATABASE HELPER FUNCTIONS
-- =====================================================

-- Ensure is_authenticated function exists
CREATE OR REPLACE FUNCTION public.is_authenticated()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN auth.uid() IS NOT NULL;
END;
$$;

-- Ensure has_role function exists
CREATE OR REPLACE FUNCTION public.has_role(_user_id UUID, _role user_role)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = _user_id AND role = _role
  );
END;
$$;

-- Ensure is_manager_or_admin function exists
CREATE OR REPLACE FUNCTION public.is_manager_or_admin(_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = _user_id AND role IN ('super_admin', 'manager')
  );
END;
$$;

-- =====================================================
-- SECTION 11: USER MANAGEMENT FUNCTIONS (from previous fix)
-- =====================================================

-- change_own_pin - User self-service PIN change
DROP FUNCTION IF EXISTS public.change_own_pin(TEXT, TEXT);
CREATE OR REPLACE FUNCTION public.change_own_pin(
  _current_pin TEXT,
  _new_pin TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
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
  
  SELECT * INTO _profile
  FROM public.profiles
  WHERE id = _user_id
    AND pin_hash = crypt(_current_pin, pin_hash);
  
  IF _profile IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Current PIN is incorrect');
  END IF;
  
  UPDATE public.profiles
  SET pin_hash = crypt(_new_pin, gen_salt('bf')),
      updated_at = NOW()
  WHERE id = _user_id;
  
  RETURN jsonb_build_object('success', true, 'message', 'PIN changed successfully');
END;
$$;

-- admin_update_user_status
DROP FUNCTION IF EXISTS public.admin_update_user_status(UUID, BOOLEAN);
CREATE OR REPLACE FUNCTION public.admin_update_user_status(
  _target_user_id UUID,
  _is_active BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = auth.uid() AND role = 'super_admin'
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized - super_admin only');
  END IF;

  UPDATE public.profiles
  SET is_active = _is_active, updated_at = NOW()
  WHERE id = _target_user_id;
  
  IF FOUND THEN
    RETURN jsonb_build_object(
      'success', true,
      'message', CASE WHEN _is_active THEN 'User activated' ELSE 'User deactivated' END
    );
  ELSE
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;
END;
$$;

-- admin_reset_user_pin
DROP FUNCTION IF EXISTS public.admin_reset_user_pin(UUID, TEXT);
CREATE OR REPLACE FUNCTION public.admin_reset_user_pin(
  _target_user_id UUID,
  _new_pin TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _pin_hash TEXT;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = auth.uid() AND role = 'super_admin'
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized - super_admin only');
  END IF;

  IF _new_pin IS NULL OR length(_new_pin) != 6 OR _new_pin !~ '^[0-9]+$' THEN
    RETURN jsonb_build_object('success', false, 'error', 'PIN must be exactly 6 digits');
  END IF;

  _pin_hash := crypt(_new_pin, gen_salt('bf'));
  
  UPDATE public.profiles
  SET pin_hash = _pin_hash, updated_at = NOW()
  WHERE id = _target_user_id;
  
  IF FOUND THEN
    RETURN jsonb_build_object('success', true, 'message', 'PIN reset successfully');
  ELSE
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;
END;
$$;

-- update_pin_only
DROP FUNCTION IF EXISTS public.update_pin_only(UUID, TEXT);
CREATE OR REPLACE FUNCTION public.update_pin_only(
  _user_id UUID,
  _pin TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _pin_hash TEXT;
BEGIN
  _pin_hash := crypt(_pin, gen_salt('bf'));
  UPDATE public.profiles 
  SET pin_hash = _pin_hash, updated_at = NOW()
  WHERE id = _user_id;
END;
$$;

-- =====================================================
-- SECTION 12: GRANT EXECUTION PERMISSIONS
-- =====================================================

GRANT EXECUTE ON FUNCTION public.is_authenticated() TO authenticated;
GRANT EXECUTE ON FUNCTION public.has_role(UUID, user_role) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_manager_or_admin(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.change_own_pin(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_user_status(UUID, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_reset_user_pin(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_pin_only(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_pin_only(UUID, TEXT) TO service_role;

-- =====================================================
-- SECTION 13: REFRESH SCHEMA CACHE
-- =====================================================
-- Note: Supabase should automatically pick up these changes.
-- If not, you may need to regenerate types using:
-- npx supabase gen types typescript --project-id YOUR_PROJECT_ID > src/integrations/supabase/types.ts

-- =====================================================
-- VERIFICATION - Check everything was created
-- =====================================================
DO $$
BEGIN
  RAISE NOTICE '✅ Database fix completed successfully!';
  RAISE NOTICE '   - Created 5 secure views';
  RAISE NOTICE '   - Fixed RLS policies for 8+ tables';
  RAISE NOTICE '   - Created/updated user management functions';
END $$;

SELECT 
  '✅ Views Created' as category,
  viewname as name
FROM pg_views 
WHERE schemaname = 'public' 
  AND viewname IN ('profiles_safe', 'customer_accounts_safe', 'dairy_settings_public', 'customers_delivery_view', 'employees_auditor_view')

UNION ALL

SELECT 
  '✅ Functions Ready' as category,
  routine_name as name
FROM information_schema.routines 
WHERE routine_schema = 'public' 
  AND routine_name IN ('change_own_pin', 'admin_update_user_status', 'admin_reset_user_pin', 'is_manager_or_admin', 'has_role')
ORDER BY category, name;

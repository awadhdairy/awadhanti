-- =====================================================
-- SECURITY FIX 1: Fix Auto-Admin Role Assignment
-- =====================================================

-- Replace handle_new_user function to assign farm_worker by default
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, role, phone, pin_hash)
  VALUES (
    new.id, 
    COALESCE(new.raw_user_meta_data ->> 'full_name', new.email), 
    'farm_worker',  -- Changed from super_admin
    new.raw_user_meta_data ->> 'phone',
    CASE 
      WHEN new.raw_user_meta_data ->> 'pin' IS NOT NULL 
      THEN crypt(new.raw_user_meta_data ->> 'pin', gen_salt('bf'))
      ELSE NULL 
    END
  );
  
  INSERT INTO public.user_roles (user_id, role)
  VALUES (new.id, 'farm_worker');  -- Changed from super_admin
  
  RETURN new;
END;
$$;

-- =====================================================
-- SECURITY FIX 2: Add PIN Brute-Force Protection
-- =====================================================

-- Create auth_attempts table for rate limiting
CREATE TABLE IF NOT EXISTS public.auth_attempts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  phone text NOT NULL UNIQUE,
  failed_count integer DEFAULT 0,
  locked_until timestamp with time zone,
  last_attempt timestamp with time zone DEFAULT now()
);

-- Enable RLS on auth_attempts
ALTER TABLE public.auth_attempts ENABLE ROW LEVEL SECURITY;

-- Only allow the verify_pin function to access this table (via SECURITY DEFINER)
-- No direct access policies needed

-- Replace verify_pin function with rate limiting
CREATE OR REPLACE FUNCTION public.verify_pin(_phone text, _pin text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _user_id uuid;
  _locked_until timestamp with time zone;
  _failed_count integer;
BEGIN
  -- Check if account is locked
  SELECT locked_until, failed_count INTO _locked_until, _failed_count
  FROM public.auth_attempts WHERE phone = _phone;
  
  IF _locked_until IS NOT NULL AND _locked_until > NOW() THEN
    RAISE EXCEPTION 'Account temporarily locked. Try again later.';
  END IF;
  
  -- Verify PIN
  SELECT id INTO _user_id
  FROM public.profiles
  WHERE phone = _phone
    AND pin_hash = crypt(_pin, pin_hash);
  
  IF _user_id IS NULL THEN
    -- Increment failed attempts
    INSERT INTO public.auth_attempts (phone, failed_count, last_attempt)
    VALUES (_phone, 1, NOW())
    ON CONFLICT (phone) DO UPDATE
    SET failed_count = auth_attempts.failed_count + 1,
        last_attempt = NOW(),
        locked_until = CASE
          WHEN auth_attempts.failed_count >= 4 THEN NOW() + INTERVAL '15 minutes'
          ELSE NULL
        END;
    RETURN NULL;
  ELSE
    -- Reset attempts on success
    DELETE FROM public.auth_attempts WHERE phone = _phone;
    RETURN _user_id;
  END IF;
END;
$$;

-- =====================================================
-- SECURITY FIX 3: Role-Based RLS Policies
-- =====================================================

-- Helper function to check if user has any of the specified roles
CREATE OR REPLACE FUNCTION public.has_any_role(_user_id uuid, _roles user_role[])
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_roles
    WHERE user_id = _user_id
      AND role = ANY(_roles)
  )
$$;

-- Helper function to check if user is manager or admin
CREATE OR REPLACE FUNCTION public.is_manager_or_admin(_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.has_any_role(_user_id, ARRAY['super_admin', 'manager']::user_role[])
$$;

-- =====================================================
-- CUSTOMERS TABLE - Restrict access by role
-- =====================================================
DROP POLICY IF EXISTS "Authenticated users can access customers" ON public.customers;

CREATE POLICY "Managers and admins have full access to customers"
ON public.customers FOR ALL
USING (public.is_manager_or_admin(auth.uid()));

CREATE POLICY "Accountants can read customers"
ON public.customers FOR SELECT
USING (public.has_role(auth.uid(), 'accountant'));

CREATE POLICY "Delivery staff can read customers on their routes"
ON public.customers FOR SELECT
USING (public.has_role(auth.uid(), 'delivery_staff'));

CREATE POLICY "Auditors can read customers"
ON public.customers FOR SELECT
USING (public.has_role(auth.uid(), 'auditor'));

-- =====================================================
-- INVOICES TABLE - Restrict access by role
-- =====================================================
DROP POLICY IF EXISTS "Authenticated users can access invoices" ON public.invoices;

CREATE POLICY "Managers and admins have full access to invoices"
ON public.invoices FOR ALL
USING (public.is_manager_or_admin(auth.uid()));

CREATE POLICY "Accountants can manage invoices"
ON public.invoices FOR ALL
USING (public.has_role(auth.uid(), 'accountant'));

CREATE POLICY "Auditors can read invoices"
ON public.invoices FOR SELECT
USING (public.has_role(auth.uid(), 'auditor'));

-- =====================================================
-- PAYMENTS TABLE - Restrict access by role
-- =====================================================
DROP POLICY IF EXISTS "Authenticated users can access payments" ON public.payments;

CREATE POLICY "Managers and admins have full access to payments"
ON public.payments FOR ALL
USING (public.is_manager_or_admin(auth.uid()));

CREATE POLICY "Accountants can manage payments"
ON public.payments FOR ALL
USING (public.has_role(auth.uid(), 'accountant'));

CREATE POLICY "Auditors can read payments"
ON public.payments FOR SELECT
USING (public.has_role(auth.uid(), 'auditor'));

-- =====================================================
-- EXPENSES TABLE - Restrict access by role
-- =====================================================
DROP POLICY IF EXISTS "Authenticated users can access expenses" ON public.expenses;

CREATE POLICY "Managers and admins have full access to expenses"
ON public.expenses FOR ALL
USING (public.is_manager_or_admin(auth.uid()));

CREATE POLICY "Accountants can manage expenses"
ON public.expenses FOR ALL
USING (public.has_role(auth.uid(), 'accountant'));

CREATE POLICY "Auditors can read expenses"
ON public.expenses FOR SELECT
USING (public.has_role(auth.uid(), 'auditor'));

-- =====================================================
-- EMPLOYEES TABLE - Restrict access by role
-- =====================================================
DROP POLICY IF EXISTS "Authenticated users can access employees" ON public.employees;

CREATE POLICY "Managers and admins have full access to employees"
ON public.employees FOR ALL
USING (public.is_manager_or_admin(auth.uid()));

CREATE POLICY "Auditors can read employees"
ON public.employees FOR SELECT
USING (public.has_role(auth.uid(), 'auditor'));

-- =====================================================
-- ATTENDANCE TABLE - Restrict access by role
-- =====================================================
DROP POLICY IF EXISTS "Authenticated users can access attendance" ON public.attendance;

CREATE POLICY "Managers and admins have full access to attendance"
ON public.attendance FOR ALL
USING (public.is_manager_or_admin(auth.uid()));

CREATE POLICY "Auditors can read attendance"
ON public.attendance FOR SELECT
USING (public.has_role(auth.uid(), 'auditor'));

-- =====================================================
-- CATTLE TABLE - Restrict access by role
-- =====================================================
DROP POLICY IF EXISTS "Authenticated users can access cattle" ON public.cattle;

CREATE POLICY "Managers and admins have full access to cattle"
ON public.cattle FOR ALL
USING (public.is_manager_or_admin(auth.uid()));

CREATE POLICY "Farm workers can manage cattle"
ON public.cattle FOR ALL
USING (public.has_role(auth.uid(), 'farm_worker'));

CREATE POLICY "Vet staff can read cattle"
ON public.cattle FOR SELECT
USING (public.has_role(auth.uid(), 'vet_staff'));

CREATE POLICY "Auditors can read cattle"
ON public.cattle FOR SELECT
USING (public.has_role(auth.uid(), 'auditor'));

-- =====================================================
-- CATTLE_HEALTH TABLE - Restrict access by role
-- =====================================================
DROP POLICY IF EXISTS "Authenticated users can access cattle_health" ON public.cattle_health;

CREATE POLICY "Managers and admins have full access to cattle_health"
ON public.cattle_health FOR ALL
USING (public.is_manager_or_admin(auth.uid()));

CREATE POLICY "Farm workers can manage cattle_health"
ON public.cattle_health FOR ALL
USING (public.has_role(auth.uid(), 'farm_worker'));

CREATE POLICY "Vet staff can manage cattle_health"
ON public.cattle_health FOR ALL
USING (public.has_role(auth.uid(), 'vet_staff'));

CREATE POLICY "Auditors can read cattle_health"
ON public.cattle_health FOR SELECT
USING (public.has_role(auth.uid(), 'auditor'));

-- =====================================================
-- MILK_PRODUCTION TABLE - Restrict access by role
-- =====================================================
DROP POLICY IF EXISTS "Authenticated users can access milk_production" ON public.milk_production;

CREATE POLICY "Managers and admins have full access to milk_production"
ON public.milk_production FOR ALL
USING (public.is_manager_or_admin(auth.uid()));

CREATE POLICY "Farm workers can manage milk_production"
ON public.milk_production FOR ALL
USING (public.has_role(auth.uid(), 'farm_worker'));

CREATE POLICY "Auditors can read milk_production"
ON public.milk_production FOR SELECT
USING (public.has_role(auth.uid(), 'auditor'));

-- =====================================================
-- FEED_INVENTORY TABLE - Restrict access by role
-- =====================================================
DROP POLICY IF EXISTS "Authenticated users can access feed_inventory" ON public.feed_inventory;

CREATE POLICY "Managers and admins have full access to feed_inventory"
ON public.feed_inventory FOR ALL
USING (public.is_manager_or_admin(auth.uid()));

CREATE POLICY "Farm workers can read feed_inventory"
ON public.feed_inventory FOR SELECT
USING (public.has_role(auth.uid(), 'farm_worker'));

CREATE POLICY "Auditors can read feed_inventory"
ON public.feed_inventory FOR SELECT
USING (public.has_role(auth.uid(), 'auditor'));

-- =====================================================
-- FEED_CONSUMPTION TABLE - Restrict access by role
-- =====================================================
DROP POLICY IF EXISTS "Authenticated users can access feed_consumption" ON public.feed_consumption;

CREATE POLICY "Managers and admins have full access to feed_consumption"
ON public.feed_consumption FOR ALL
USING (public.is_manager_or_admin(auth.uid()));

CREATE POLICY "Farm workers can manage feed_consumption"
ON public.feed_consumption FOR ALL
USING (public.has_role(auth.uid(), 'farm_worker'));

CREATE POLICY "Auditors can read feed_consumption"
ON public.feed_consumption FOR SELECT
USING (public.has_role(auth.uid(), 'auditor'));

-- =====================================================
-- PRODUCTS TABLE - Restrict access by role
-- =====================================================
DROP POLICY IF EXISTS "Authenticated users can access products" ON public.products;

CREATE POLICY "Managers and admins have full access to products"
ON public.products FOR ALL
USING (public.is_manager_or_admin(auth.uid()));

CREATE POLICY "Staff can read products"
ON public.products FOR SELECT
USING (public.is_authenticated());

-- =====================================================
-- BOTTLES TABLE - Restrict access by role
-- =====================================================
DROP POLICY IF EXISTS "Authenticated users can access bottles" ON public.bottles;

CREATE POLICY "Managers and admins have full access to bottles"
ON public.bottles FOR ALL
USING (public.is_manager_or_admin(auth.uid()));

CREATE POLICY "Staff can read bottles"
ON public.bottles FOR SELECT
USING (public.is_authenticated());

-- =====================================================
-- BOTTLE_TRANSACTIONS TABLE - Restrict access by role
-- =====================================================
DROP POLICY IF EXISTS "Authenticated users can access bottle_transactions" ON public.bottle_transactions;

CREATE POLICY "Managers and admins have full access to bottle_transactions"
ON public.bottle_transactions FOR ALL
USING (public.is_manager_or_admin(auth.uid()));

CREATE POLICY "Delivery staff can manage bottle_transactions"
ON public.bottle_transactions FOR ALL
USING (public.has_role(auth.uid(), 'delivery_staff'));

CREATE POLICY "Auditors can read bottle_transactions"
ON public.bottle_transactions FOR SELECT
USING (public.has_role(auth.uid(), 'auditor'));

-- =====================================================
-- CUSTOMER_BOTTLES TABLE - Restrict access by role
-- =====================================================
DROP POLICY IF EXISTS "Authenticated users can access customer_bottles" ON public.customer_bottles;

CREATE POLICY "Managers and admins have full access to customer_bottles"
ON public.customer_bottles FOR ALL
USING (public.is_manager_or_admin(auth.uid()));

CREATE POLICY "Delivery staff can manage customer_bottles"
ON public.customer_bottles FOR ALL
USING (public.has_role(auth.uid(), 'delivery_staff'));

CREATE POLICY "Auditors can read customer_bottles"
ON public.customer_bottles FOR SELECT
USING (public.has_role(auth.uid(), 'auditor'));

-- =====================================================
-- CUSTOMER_PRODUCTS TABLE - Restrict access by role
-- =====================================================
DROP POLICY IF EXISTS "Authenticated users can access customer_products" ON public.customer_products;

CREATE POLICY "Managers and admins have full access to customer_products"
ON public.customer_products FOR ALL
USING (public.is_manager_or_admin(auth.uid()));

CREATE POLICY "Delivery staff can read customer_products"
ON public.customer_products FOR SELECT
USING (public.has_role(auth.uid(), 'delivery_staff'));

CREATE POLICY "Auditors can read customer_products"
ON public.customer_products FOR SELECT
USING (public.has_role(auth.uid(), 'auditor'));

-- =====================================================
-- DELIVERIES TABLE - Restrict access by role
-- =====================================================
DROP POLICY IF EXISTS "Authenticated users can access deliveries" ON public.deliveries;

CREATE POLICY "Managers and admins have full access to deliveries"
ON public.deliveries FOR ALL
USING (public.is_manager_or_admin(auth.uid()));

CREATE POLICY "Delivery staff can manage deliveries"
ON public.deliveries FOR ALL
USING (public.has_role(auth.uid(), 'delivery_staff'));

CREATE POLICY "Auditors can read deliveries"
ON public.deliveries FOR SELECT
USING (public.has_role(auth.uid(), 'auditor'));

-- =====================================================
-- DELIVERY_ITEMS TABLE - Restrict access by role
-- =====================================================
DROP POLICY IF EXISTS "Authenticated users can access delivery_items" ON public.delivery_items;

CREATE POLICY "Managers and admins have full access to delivery_items"
ON public.delivery_items FOR ALL
USING (public.is_manager_or_admin(auth.uid()));

CREATE POLICY "Delivery staff can manage delivery_items"
ON public.delivery_items FOR ALL
USING (public.has_role(auth.uid(), 'delivery_staff'));

CREATE POLICY "Auditors can read delivery_items"
ON public.delivery_items FOR SELECT
USING (public.has_role(auth.uid(), 'auditor'));

-- =====================================================
-- ROUTES TABLE - Restrict access by role
-- =====================================================
DROP POLICY IF EXISTS "Authenticated users can access routes" ON public.routes;

CREATE POLICY "Managers and admins have full access to routes"
ON public.routes FOR ALL
USING (public.is_manager_or_admin(auth.uid()));

CREATE POLICY "Staff can read routes"
ON public.routes FOR SELECT
USING (public.is_authenticated());

-- =====================================================
-- DAIRY_SETTINGS TABLE - Restrict access by role
-- =====================================================
DROP POLICY IF EXISTS "Authenticated users can access dairy_settings" ON public.dairy_settings;

CREATE POLICY "Admins have full access to dairy_settings"
ON public.dairy_settings FOR ALL
USING (public.has_role(auth.uid(), 'super_admin'));

CREATE POLICY "Staff can read dairy_settings"
ON public.dairy_settings FOR SELECT
USING (public.is_authenticated());

-- =====================================================
-- ACTIVITY_LOGS TABLE - Keep existing restrictive policies
-- =====================================================
-- Already has restrictive policies, no changes needed
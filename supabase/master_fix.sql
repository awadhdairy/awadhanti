-- =====================================================
-- MASTER DATABASE FIX - AWADH DAIRY
-- =====================================================
-- This script ensures ALL required tables have proper RLS
-- Run this in Supabase SQL Editor
-- =====================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================
-- PART 1: CREATE ALL REQUIRED VIEWS
-- =====================================================

-- profiles_safe view (excludes pin_hash)
DROP VIEW IF EXISTS public.profiles_safe CASCADE;
CREATE VIEW public.profiles_safe AS
SELECT id, full_name, phone, role, is_active, avatar_url, created_at, updated_at
FROM public.profiles;

-- customer_accounts_safe view (excludes pin_hash)
DROP VIEW IF EXISTS public.customer_accounts_safe CASCADE;
CREATE VIEW public.customer_accounts_safe AS
SELECT id, customer_id, phone, user_id, is_approved, approval_status, approved_at, approved_by, last_login, created_at, updated_at
FROM public.customer_accounts;

-- customers_delivery_view for delivery staff
DROP VIEW IF EXISTS public.customers_delivery_view CASCADE;
CREATE VIEW public.customers_delivery_view AS
SELECT id, name, area, address, route_id, is_active
FROM public.customers;

-- employees_auditor_view for auditors
DROP VIEW IF EXISTS public.employees_auditor_view CASCADE;
CREATE VIEW public.employees_auditor_view AS
SELECT id, name, phone, role, address, joining_date, user_id, is_active, created_at, updated_at
FROM public.employees;

-- dairy_settings_public view
DROP VIEW IF EXISTS public.dairy_settings_public CASCADE;
CREATE VIEW public.dairy_settings_public AS
SELECT id, dairy_name, logo_url, currency, invoice_prefix, financial_year_start
FROM public.dairy_settings;

-- =====================================================
-- PART 2: RLS POLICIES FOR ALL TABLES
-- =====================================================

-- Helper to enable RLS and create standard policies
-- We'll create policies that allow authenticated users full access

-- PROFILES
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "allow_authenticated_select_profiles" ON public.profiles;
DROP POLICY IF EXISTS "allow_authenticated_insert_profiles" ON public.profiles;
DROP POLICY IF EXISTS "allow_authenticated_update_profiles" ON public.profiles;
CREATE POLICY "allow_authenticated_select_profiles" ON public.profiles FOR SELECT TO authenticated USING (true);
CREATE POLICY "allow_authenticated_insert_profiles" ON public.profiles FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "allow_authenticated_update_profiles" ON public.profiles FOR UPDATE TO authenticated USING (true);

-- DAIRY_SETTINGS
ALTER TABLE public.dairy_settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "allow_authenticated_select_dairy_settings" ON public.dairy_settings;
DROP POLICY IF EXISTS "allow_authenticated_insert_dairy_settings" ON public.dairy_settings;
DROP POLICY IF EXISTS "allow_authenticated_update_dairy_settings" ON public.dairy_settings;
CREATE POLICY "allow_authenticated_select_dairy_settings" ON public.dairy_settings FOR SELECT TO authenticated USING (true);
CREATE POLICY "allow_authenticated_insert_dairy_settings" ON public.dairy_settings FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "allow_authenticated_update_dairy_settings" ON public.dairy_settings FOR UPDATE TO authenticated USING (true);

-- ROUTES
ALTER TABLE public.routes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "allow_authenticated_select_routes" ON public.routes;
DROP POLICY IF EXISTS "allow_authenticated_insert_routes" ON public.routes;
DROP POLICY IF EXISTS "allow_authenticated_update_routes" ON public.routes;
DROP POLICY IF EXISTS "allow_authenticated_delete_routes" ON public.routes;
CREATE POLICY "allow_authenticated_select_routes" ON public.routes FOR SELECT TO authenticated USING (true);
CREATE POLICY "allow_authenticated_insert_routes" ON public.routes FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "allow_authenticated_update_routes" ON public.routes FOR UPDATE TO authenticated USING (true);
CREATE POLICY "allow_authenticated_delete_routes" ON public.routes FOR DELETE TO authenticated USING (true);

-- ROUTE_STOPS
ALTER TABLE public.route_stops ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "allow_authenticated_select_route_stops" ON public.route_stops;
DROP POLICY IF EXISTS "allow_authenticated_insert_route_stops" ON public.route_stops;
DROP POLICY IF EXISTS "allow_authenticated_update_route_stops" ON public.route_stops;
DROP POLICY IF EXISTS "allow_authenticated_delete_route_stops" ON public.route_stops;
CREATE POLICY "allow_authenticated_select_route_stops" ON public.route_stops FOR SELECT TO authenticated USING (true);
CREATE POLICY "allow_authenticated_insert_route_stops" ON public.route_stops FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "allow_authenticated_update_route_stops" ON public.route_stops FOR UPDATE TO authenticated USING (true);
CREATE POLICY "allow_authenticated_delete_route_stops" ON public.route_stops FOR DELETE TO authenticated USING (true);

-- CUSTOMERS
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "allow_authenticated_select_customers" ON public.customers;
DROP POLICY IF EXISTS "allow_authenticated_insert_customers" ON public.customers;
DROP POLICY IF EXISTS "allow_authenticated_update_customers" ON public.customers;
DROP POLICY IF EXISTS "allow_authenticated_delete_customers" ON public.customers;
CREATE POLICY "allow_authenticated_select_customers" ON public.customers FOR SELECT TO authenticated USING (true);
CREATE POLICY "allow_authenticated_insert_customers" ON public.customers FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "allow_authenticated_update_customers" ON public.customers FOR UPDATE TO authenticated USING (true);
CREATE POLICY "allow_authenticated_delete_customers" ON public.customers FOR DELETE TO authenticated USING (true);

-- EMPLOYEES
ALTER TABLE public.employees ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "allow_authenticated_select_employees" ON public.employees;
DROP POLICY IF EXISTS "allow_authenticated_insert_employees" ON public.employees;
DROP POLICY IF EXISTS "allow_authenticated_update_employees" ON public.employees;
DROP POLICY IF EXISTS "allow_authenticated_delete_employees" ON public.employees;
CREATE POLICY "allow_authenticated_select_employees" ON public.employees FOR SELECT TO authenticated USING (true);
CREATE POLICY "allow_authenticated_insert_employees" ON public.employees FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "allow_authenticated_update_employees" ON public.employees FOR UPDATE TO authenticated USING (true);
CREATE POLICY "allow_authenticated_delete_employees" ON public.employees FOR DELETE TO authenticated USING (true);

-- CATTLE
ALTER TABLE public.cattle ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "allow_authenticated_select_cattle" ON public.cattle;
DROP POLICY IF EXISTS "allow_authenticated_insert_cattle" ON public.cattle;
DROP POLICY IF EXISTS "allow_authenticated_update_cattle" ON public.cattle;
DROP POLICY IF EXISTS "allow_authenticated_delete_cattle" ON public.cattle;
CREATE POLICY "allow_authenticated_select_cattle" ON public.cattle FOR SELECT TO authenticated USING (true);
CREATE POLICY "allow_authenticated_insert_cattle" ON public.cattle FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "allow_authenticated_update_cattle" ON public.cattle FOR UPDATE TO authenticated USING (true);
CREATE POLICY "allow_authenticated_delete_cattle" ON public.cattle FOR DELETE TO authenticated USING (true);

-- MILK_PRODUCTION
ALTER TABLE public.milk_production ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "allow_authenticated_select_milk_production" ON public.milk_production;
DROP POLICY IF EXISTS "allow_authenticated_insert_milk_production" ON public.milk_production;
DROP POLICY IF EXISTS "allow_authenticated_update_milk_production" ON public.milk_production;
DROP POLICY IF EXISTS "allow_authenticated_delete_milk_production" ON public.milk_production;
CREATE POLICY "allow_authenticated_select_milk_production" ON public.milk_production FOR SELECT TO authenticated USING (true);
CREATE POLICY "allow_authenticated_insert_milk_production" ON public.milk_production FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "allow_authenticated_update_milk_production" ON public.milk_production FOR UPDATE TO authenticated USING (true);
CREATE POLICY "allow_authenticated_delete_milk_production" ON public.milk_production FOR DELETE TO authenticated USING (true);

-- PRODUCTS
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "allow_authenticated_select_products" ON public.products;
DROP POLICY IF EXISTS "allow_authenticated_insert_products" ON public.products;
DROP POLICY IF EXISTS "allow_authenticated_update_products" ON public.products;
DROP POLICY IF EXISTS "allow_authenticated_delete_products" ON public.products;
CREATE POLICY "allow_authenticated_select_products" ON public.products FOR SELECT TO authenticated USING (true);
CREATE POLICY "allow_authenticated_insert_products" ON public.products FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "allow_authenticated_update_products" ON public.products FOR UPDATE TO authenticated USING (true);
CREATE POLICY "allow_authenticated_delete_products" ON public.products FOR DELETE TO authenticated USING (true);

-- PRICE_RULES
ALTER TABLE public.price_rules ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "allow_authenticated_select_price_rules" ON public.price_rules;
DROP POLICY IF EXISTS "allow_authenticated_insert_price_rules" ON public.price_rules;
DROP POLICY IF EXISTS "allow_authenticated_update_price_rules" ON public.price_rules;
DROP POLICY IF EXISTS "allow_authenticated_delete_price_rules" ON public.price_rules;
CREATE POLICY "allow_authenticated_select_price_rules" ON public.price_rules FOR SELECT TO authenticated USING (true);
CREATE POLICY "allow_authenticated_insert_price_rules" ON public.price_rules FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "allow_authenticated_update_price_rules" ON public.price_rules FOR UPDATE TO authenticated USING (true);
CREATE POLICY "allow_authenticated_delete_price_rules" ON public.price_rules FOR DELETE TO authenticated USING (true);

-- INVOICES
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "allow_authenticated_select_invoices" ON public.invoices;
DROP POLICY IF EXISTS "allow_authenticated_insert_invoices" ON public.invoices;
DROP POLICY IF EXISTS "allow_authenticated_update_invoices" ON public.invoices;
DROP POLICY IF EXISTS "allow_authenticated_delete_invoices" ON public.invoices;
CREATE POLICY "allow_authenticated_select_invoices" ON public.invoices FOR SELECT TO authenticated USING (true);
CREATE POLICY "allow_authenticated_insert_invoices" ON public.invoices FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "allow_authenticated_update_invoices" ON public.invoices FOR UPDATE TO authenticated USING (true);
CREATE POLICY "allow_authenticated_delete_invoices" ON public.invoices FOR DELETE TO authenticated USING (true);

-- PAYMENTS
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "allow_authenticated_select_payments" ON public.payments;
DROP POLICY IF EXISTS "allow_authenticated_insert_payments" ON public.payments;
DROP POLICY IF EXISTS "allow_authenticated_update_payments" ON public.payments;
DROP POLICY IF EXISTS "allow_authenticated_delete_payments" ON public.payments;
CREATE POLICY "allow_authenticated_select_payments" ON public.payments FOR SELECT TO authenticated USING (true);
CREATE POLICY "allow_authenticated_insert_payments" ON public.payments FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "allow_authenticated_update_payments" ON public.payments FOR UPDATE TO authenticated USING (true);
CREATE POLICY "allow_authenticated_delete_payments" ON public.payments FOR DELETE TO authenticated USING (true);

-- EXPENSES
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "allow_authenticated_select_expenses" ON public.expenses;
DROP POLICY IF EXISTS "allow_authenticated_insert_expenses" ON public.expenses;
DROP POLICY IF EXISTS "allow_authenticated_update_expenses" ON public.expenses;
DROP POLICY IF EXISTS "allow_authenticated_delete_expenses" ON public.expenses;
CREATE POLICY "allow_authenticated_select_expenses" ON public.expenses FOR SELECT TO authenticated USING (true);
CREATE POLICY "allow_authenticated_insert_expenses" ON public.expenses FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "allow_authenticated_update_expenses" ON public.expenses FOR UPDATE TO authenticated USING (true);
CREATE POLICY "allow_authenticated_delete_expenses" ON public.expenses FOR DELETE TO authenticated USING (true);

-- DELIVERIES
ALTER TABLE public.deliveries ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "allow_authenticated_select_deliveries" ON public.deliveries;
DROP POLICY IF EXISTS "allow_authenticated_insert_deliveries" ON public.deliveries;
DROP POLICY IF EXISTS "allow_authenticated_update_deliveries" ON public.deliveries;
DROP POLICY IF EXISTS "allow_authenticated_delete_deliveries" ON public.deliveries;
CREATE POLICY "allow_authenticated_select_deliveries" ON public.deliveries FOR SELECT TO authenticated USING (true);
CREATE POLICY "allow_authenticated_insert_deliveries" ON public.deliveries FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "allow_authenticated_update_deliveries" ON public.deliveries FOR UPDATE TO authenticated USING (true);
CREATE POLICY "allow_authenticated_delete_deliveries" ON public.deliveries FOR DELETE TO authenticated USING (true);

-- DELIVERY_ITEMS
ALTER TABLE public.delivery_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "allow_authenticated_select_delivery_items" ON public.delivery_items;
DROP POLICY IF EXISTS "allow_authenticated_insert_delivery_items" ON public.delivery_items;
DROP POLICY IF EXISTS "allow_authenticated_update_delivery_items" ON public.delivery_items;
DROP POLICY IF EXISTS "allow_authenticated_delete_delivery_items" ON public.delivery_items;
CREATE POLICY "allow_authenticated_select_delivery_items" ON public.delivery_items FOR SELECT TO authenticated USING (true);
CREATE POLICY "allow_authenticated_insert_delivery_items" ON public.delivery_items FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "allow_authenticated_update_delivery_items" ON public.delivery_items FOR UPDATE TO authenticated USING (true);
CREATE POLICY "allow_authenticated_delete_delivery_items" ON public.delivery_items FOR DELETE TO authenticated USING (true);

-- CUSTOMER_LEDGER
ALTER TABLE public.customer_ledger ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "allow_authenticated_select_customer_ledger" ON public.customer_ledger;
DROP POLICY IF EXISTS "allow_authenticated_insert_customer_ledger" ON public.customer_ledger;
DROP POLICY IF EXISTS "allow_authenticated_update_customer_ledger" ON public.customer_ledger;
DROP POLICY IF EXISTS "allow_authenticated_delete_customer_ledger" ON public.customer_ledger;
CREATE POLICY "allow_authenticated_select_customer_ledger" ON public.customer_ledger FOR SELECT TO authenticated USING (true);
CREATE POLICY "allow_authenticated_insert_customer_ledger" ON public.customer_ledger FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "allow_authenticated_update_customer_ledger" ON public.customer_ledger FOR UPDATE TO authenticated USING (true);
CREATE POLICY "allow_authenticated_delete_customer_ledger" ON public.customer_ledger FOR DELETE TO authenticated USING (true);

-- CUSTOMER_ACCOUNTS
ALTER TABLE public.customer_accounts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "allow_authenticated_select_customer_accounts" ON public.customer_accounts;
DROP POLICY IF EXISTS "allow_authenticated_insert_customer_accounts" ON public.customer_accounts;
DROP POLICY IF EXISTS "allow_authenticated_update_customer_accounts" ON public.customer_accounts;
DROP POLICY IF EXISTS "allow_authenticated_delete_customer_accounts" ON public.customer_accounts;
CREATE POLICY "allow_authenticated_select_customer_accounts" ON public.customer_accounts FOR SELECT TO authenticated USING (true);
CREATE POLICY "allow_authenticated_insert_customer_accounts" ON public.customer_accounts FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "allow_authenticated_update_customer_accounts" ON public.customer_accounts FOR UPDATE TO authenticated USING (true);
CREATE POLICY "allow_authenticated_delete_customer_accounts" ON public.customer_accounts FOR DELETE TO authenticated USING (true);

-- NOTIFICATION_TEMPLATES
ALTER TABLE public.notification_templates ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "allow_authenticated_select_notification_templates" ON public.notification_templates;
DROP POLICY IF EXISTS "allow_authenticated_insert_notification_templates" ON public.notification_templates;
DROP POLICY IF EXISTS "allow_authenticated_update_notification_templates" ON public.notification_templates;
DROP POLICY IF EXISTS "allow_authenticated_delete_notification_templates" ON public.notification_templates;
CREATE POLICY "allow_authenticated_select_notification_templates" ON public.notification_templates FOR SELECT TO authenticated USING (true);
CREATE POLICY "allow_authenticated_insert_notification_templates" ON public.notification_templates FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "allow_authenticated_update_notification_templates" ON public.notification_templates FOR UPDATE TO authenticated USING (true);
CREATE POLICY "allow_authenticated_delete_notification_templates" ON public.notification_templates FOR DELETE TO authenticated USING (true);

-- NOTIFICATION_LOGS
ALTER TABLE public.notification_logs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "allow_authenticated_select_notification_logs" ON public.notification_logs;
DROP POLICY IF EXISTS "allow_authenticated_insert_notification_logs" ON public.notification_logs;
DROP POLICY IF EXISTS "allow_authenticated_update_notification_logs" ON public.notification_logs;
CREATE POLICY "allow_authenticated_select_notification_logs" ON public.notification_logs FOR SELECT TO authenticated USING (true);
CREATE POLICY "allow_authenticated_insert_notification_logs" ON public.notification_logs FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "allow_authenticated_update_notification_logs" ON public.notification_logs FOR UPDATE TO authenticated USING (true);

-- MILK_VENDORS
ALTER TABLE public.milk_vendors ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "allow_authenticated_select_milk_vendors" ON public.milk_vendors;
DROP POLICY IF EXISTS "allow_authenticated_insert_milk_vendors" ON public.milk_vendors;
DROP POLICY IF EXISTS "allow_authenticated_update_milk_vendors" ON public.milk_vendors;
DROP POLICY IF EXISTS "allow_authenticated_delete_milk_vendors" ON public.milk_vendors;
CREATE POLICY "allow_authenticated_select_milk_vendors" ON public.milk_vendors FOR SELECT TO authenticated USING (true);
CREATE POLICY "allow_authenticated_insert_milk_vendors" ON public.milk_vendors FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "allow_authenticated_update_milk_vendors" ON public.milk_vendors FOR UPDATE TO authenticated USING (true);
CREATE POLICY "allow_authenticated_delete_milk_vendors" ON public.milk_vendors FOR DELETE TO authenticated USING (true);

-- MILK_PROCUREMENT
ALTER TABLE public.milk_procurement ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "allow_authenticated_select_milk_procurement" ON public.milk_procurement;
DROP POLICY IF EXISTS "allow_authenticated_insert_milk_procurement" ON public.milk_procurement;
DROP POLICY IF EXISTS "allow_authenticated_update_milk_procurement" ON public.milk_procurement;
DROP POLICY IF EXISTS "allow_authenticated_delete_milk_procurement" ON public.milk_procurement;
CREATE POLICY "allow_authenticated_select_milk_procurement" ON public.milk_procurement FOR SELECT TO authenticated USING (true);
CREATE POLICY "allow_authenticated_insert_milk_procurement" ON public.milk_procurement FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "allow_authenticated_update_milk_procurement" ON public.milk_procurement FOR UPDATE TO authenticated USING (true);
CREATE POLICY "allow_authenticated_delete_milk_procurement" ON public.milk_procurement FOR DELETE TO authenticated USING (true);

-- SUBSCRIPTIONS
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "allow_authenticated_select_subscriptions" ON public.subscriptions;
DROP POLICY IF EXISTS "allow_authenticated_insert_subscriptions" ON public.subscriptions;
DROP POLICY IF EXISTS "allow_authenticated_update_subscriptions" ON public.subscriptions;
DROP POLICY IF EXISTS "allow_authenticated_delete_subscriptions" ON public.subscriptions;
CREATE POLICY "allow_authenticated_select_subscriptions" ON public.subscriptions FOR SELECT TO authenticated USING (true);
CREATE POLICY "allow_authenticated_insert_subscriptions" ON public.subscriptions FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "allow_authenticated_update_subscriptions" ON public.subscriptions FOR UPDATE TO authenticated USING (true);
CREATE POLICY "allow_authenticated_delete_subscriptions" ON public.subscriptions FOR DELETE TO authenticated USING (true);

-- SUBSCRIPTION_ITEMS
ALTER TABLE public.subscription_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "allow_authenticated_select_subscription_items" ON public.subscription_items;
DROP POLICY IF EXISTS "allow_authenticated_insert_subscription_items" ON public.subscription_items;
DROP POLICY IF EXISTS "allow_authenticated_update_subscription_items" ON public.subscription_items;
DROP POLICY IF EXISTS "allow_authenticated_delete_subscription_items" ON public.subscription_items;
CREATE POLICY "allow_authenticated_select_subscription_items" ON public.subscription_items FOR SELECT TO authenticated USING (true);
CREATE POLICY "allow_authenticated_insert_subscription_items" ON public.subscription_items FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "allow_authenticated_update_subscription_items" ON public.subscription_items FOR UPDATE TO authenticated USING (true);
CREATE POLICY "allow_authenticated_delete_subscription_items" ON public.subscription_items FOR DELETE TO authenticated USING (true);

-- CATTLE_HEALTH
ALTER TABLE public.cattle_health ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "allow_authenticated_select_cattle_health" ON public.cattle_health;
DROP POLICY IF EXISTS "allow_authenticated_insert_cattle_health" ON public.cattle_health;
DROP POLICY IF EXISTS "allow_authenticated_update_cattle_health" ON public.cattle_health;
DROP POLICY IF EXISTS "allow_authenticated_delete_cattle_health" ON public.cattle_health;
CREATE POLICY "allow_authenticated_select_cattle_health" ON public.cattle_health FOR SELECT TO authenticated USING (true);
CREATE POLICY "allow_authenticated_insert_cattle_health" ON public.cattle_health FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "allow_authenticated_update_cattle_health" ON public.cattle_health FOR UPDATE TO authenticated USING (true);
CREATE POLICY "allow_authenticated_delete_cattle_health" ON public.cattle_health FOR DELETE TO authenticated USING (true);

-- BOTTLES
ALTER TABLE public.bottles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "allow_authenticated_select_bottles" ON public.bottles;
DROP POLICY IF EXISTS "allow_authenticated_insert_bottles" ON public.bottles;
DROP POLICY IF EXISTS "allow_authenticated_update_bottles" ON public.bottles;
DROP POLICY IF EXISTS "allow_authenticated_delete_bottles" ON public.bottles;
CREATE POLICY "allow_authenticated_select_bottles" ON public.bottles FOR SELECT TO authenticated USING (true);
CREATE POLICY "allow_authenticated_insert_bottles" ON public.bottles FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "allow_authenticated_update_bottles" ON public.bottles FOR UPDATE TO authenticated USING (true);
CREATE POLICY "allow_authenticated_delete_bottles" ON public.bottles FOR DELETE TO authenticated USING (true);

-- CUSTOMER_BOTTLES
ALTER TABLE public.customer_bottles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "allow_authenticated_select_customer_bottles" ON public.customer_bottles;
DROP POLICY IF EXISTS "allow_authenticated_insert_customer_bottles" ON public.customer_bottles;
DROP POLICY IF EXISTS "allow_authenticated_update_customer_bottles" ON public.customer_bottles;
DROP POLICY IF EXISTS "allow_authenticated_delete_customer_bottles" ON public.customer_bottles;
CREATE POLICY "allow_authenticated_select_customer_bottles" ON public.customer_bottles FOR SELECT TO authenticated USING (true);
CREATE POLICY "allow_authenticated_insert_customer_bottles" ON public.customer_bottles FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "allow_authenticated_update_customer_bottles" ON public.customer_bottles FOR UPDATE TO authenticated USING (true);
CREATE POLICY "allow_authenticated_delete_customer_bottles" ON public.customer_bottles FOR DELETE TO authenticated USING (true);

-- ATTENDANCE
ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "allow_authenticated_select_attendance" ON public.attendance;
DROP POLICY IF EXISTS "allow_authenticated_insert_attendance" ON public.attendance;
DROP POLICY IF EXISTS "allow_authenticated_update_attendance" ON public.attendance;
CREATE POLICY "allow_authenticated_select_attendance" ON public.attendance FOR SELECT TO authenticated USING (true);
CREATE POLICY "allow_authenticated_insert_attendance" ON public.attendance FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "allow_authenticated_update_attendance" ON public.attendance FOR UPDATE TO authenticated USING (true);

-- PAYROLL_RECORDS
ALTER TABLE public.payroll_records ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "allow_authenticated_select_payroll_records" ON public.payroll_records;
DROP POLICY IF EXISTS "allow_authenticated_insert_payroll_records" ON public.payroll_records;
DROP POLICY IF EXISTS "allow_authenticated_update_payroll_records" ON public.payroll_records;
CREATE POLICY "allow_authenticated_select_payroll_records" ON public.payroll_records FOR SELECT TO authenticated USING (true);
CREATE POLICY "allow_authenticated_insert_payroll_records" ON public.payroll_records FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "allow_authenticated_update_payroll_records" ON public.payroll_records FOR UPDATE TO authenticated USING (true);

-- ACTIVITY_LOGS
ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "allow_authenticated_select_activity_logs" ON public.activity_logs;
DROP POLICY IF EXISTS "allow_authenticated_insert_activity_logs" ON public.activity_logs;
CREATE POLICY "allow_authenticated_select_activity_logs" ON public.activity_logs FOR SELECT TO authenticated USING (true);
CREATE POLICY "allow_authenticated_insert_activity_logs" ON public.activity_logs FOR INSERT TO authenticated WITH CHECK (true);

-- USER_ROLES
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "allow_authenticated_select_user_roles" ON public.user_roles;
DROP POLICY IF EXISTS "allow_authenticated_insert_user_roles" ON public.user_roles;
DROP POLICY IF EXISTS "allow_authenticated_update_user_roles" ON public.user_roles;
CREATE POLICY "allow_authenticated_select_user_roles" ON public.user_roles FOR SELECT TO authenticated USING (true);
CREATE POLICY "allow_authenticated_insert_user_roles" ON public.user_roles FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "allow_authenticated_update_user_roles" ON public.user_roles FOR UPDATE TO authenticated USING (true);

-- =====================================================
-- PART 3: CRITICAL FUNCTIONS
-- =====================================================

-- change_own_pin
CREATE OR REPLACE FUNCTION public.change_own_pin(_current_pin TEXT, _new_pin TEXT)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE _user_id UUID; _profile RECORD;
BEGIN
  _user_id := auth.uid();
  IF _user_id IS NULL THEN RETURN '{"success":false,"error":"Not authenticated"}'::jsonb; END IF;
  IF _new_pin IS NULL OR length(_new_pin) != 6 OR _new_pin !~ '^[0-9]+$' THEN
    RETURN '{"success":false,"error":"PIN must be 6 digits"}'::jsonb;
  END IF;
  SELECT * INTO _profile FROM public.profiles WHERE id = _user_id AND pin_hash = crypt(_current_pin, pin_hash);
  IF _profile IS NULL THEN RETURN '{"success":false,"error":"Current PIN incorrect"}'::jsonb; END IF;
  UPDATE public.profiles SET pin_hash = crypt(_new_pin, gen_salt('bf')), updated_at = NOW() WHERE id = _user_id;
  RETURN '{"success":true,"message":"PIN changed"}'::jsonb;
END; $$;

-- admin_update_user_status
CREATE OR REPLACE FUNCTION public.admin_update_user_status(_target_user_id UUID, _is_active BOOLEAN)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'super_admin') THEN
    RETURN '{"success":false,"error":"Unauthorized"}'::jsonb;
  END IF;
  UPDATE public.profiles SET is_active = _is_active, updated_at = NOW() WHERE id = _target_user_id;
  RETURN jsonb_build_object('success', true, 'message', CASE WHEN _is_active THEN 'Activated' ELSE 'Deactivated' END);
END; $$;

-- admin_reset_user_pin
CREATE OR REPLACE FUNCTION public.admin_reset_user_pin(_target_user_id UUID, _new_pin TEXT)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'super_admin') THEN
    RETURN '{"success":false,"error":"Unauthorized"}'::jsonb;
  END IF;
  IF _new_pin IS NULL OR length(_new_pin) != 6 OR _new_pin !~ '^[0-9]+$' THEN
    RETURN '{"success":false,"error":"PIN must be 6 digits"}'::jsonb;
  END IF;
  UPDATE public.profiles SET pin_hash = crypt(_new_pin, gen_salt('bf')), updated_at = NOW() WHERE id = _target_user_id;
  RETURN '{"success":true,"message":"PIN reset"}'::jsonb;
END; $$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION public.change_own_pin(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_user_status(UUID, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_reset_user_pin(UUID, TEXT) TO authenticated;

-- =====================================================
-- VERIFICATION
-- =====================================================
SELECT '✅ MASTER FIX COMPLETE!' AS status;

SELECT 'VIEWS' AS category, viewname AS name FROM pg_views WHERE schemaname = 'public' 
AND viewname IN ('profiles_safe', 'customer_accounts_safe', 'customers_delivery_view', 'employees_auditor_view', 'dairy_settings_public')
ORDER BY name;

-- =====================================================
-- AWADH DAIRY - CONSOLIDATED DATABASE SCHEMA
-- =====================================================
-- Run this in your Supabase SQL Editor to set up the complete database
-- Execute in order from top to bottom
-- =====================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =====================================================
-- PART 1: ENUMS
-- =====================================================

-- User roles
CREATE TYPE public.user_role AS ENUM (
  'super_admin', 'manager', 'accountant', 
  'delivery_staff', 'farm_worker', 'vet_staff', 'auditor'
);

-- Cattle status
CREATE TYPE public.cattle_status AS ENUM ('active', 'sold', 'deceased', 'dry');

-- Lactation status
CREATE TYPE public.lactation_status AS ENUM ('lactating', 'dry', 'pregnant', 'calving');

-- Delivery status
CREATE TYPE public.delivery_status AS ENUM ('pending', 'delivered', 'missed', 'partial');

-- Payment status
CREATE TYPE public.payment_status AS ENUM ('paid', 'partial', 'pending', 'overdue');

-- Bottle type
CREATE TYPE public.bottle_type AS ENUM ('glass', 'plastic');

-- Bottle size
CREATE TYPE public.bottle_size AS ENUM ('500ml', '1L', '2L', '5L');

-- =====================================================
-- PART 2: CORE TABLES
-- =====================================================

-- Profiles table for user management
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  phone TEXT UNIQUE,
  pin_hash TEXT,
  role user_role NOT NULL DEFAULT 'farm_worker',
  avatar_url TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- User roles table for role-based access
CREATE TABLE public.user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL UNIQUE,
  role user_role NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Delivery routes (create before customers due to FK)
CREATE TABLE public.routes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  area_covered TEXT,
  assigned_staff UUID REFERENCES auth.users(id),
  sequence_order INTEGER,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Cattle table for animal management
CREATE TABLE public.cattle (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tag_number TEXT NOT NULL UNIQUE,
  name TEXT,
  breed TEXT NOT NULL,
  cattle_type TEXT NOT NULL DEFAULT 'cow',
  date_of_birth DATE,
  purchase_date DATE,
  purchase_cost DECIMAL(10,2),
  weight DECIMAL(6,2),
  status cattle_status DEFAULT 'active',
  lactation_status lactation_status DEFAULT 'dry',
  lactation_number INTEGER DEFAULT 0,
  last_calving_date DATE,
  expected_calving_date DATE,
  notes TEXT,
  image_url TEXT,
  created_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Milk production records
CREATE TABLE public.milk_production (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cattle_id UUID REFERENCES public.cattle(id) ON DELETE CASCADE NOT NULL,
  production_date DATE NOT NULL,
  session TEXT NOT NULL CHECK (session IN ('morning', 'evening')),
  quantity_liters DECIMAL(6,2) NOT NULL,
  fat_percentage DECIMAL(4,2),
  snf_percentage DECIMAL(4,2),
  quality_notes TEXT,
  recorded_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(cattle_id, production_date, session)
);

-- Products table
CREATE TABLE public.products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  category TEXT NOT NULL,
  unit TEXT NOT NULL DEFAULT 'liter',
  base_price DECIMAL(10,2) NOT NULL,
  tax_percentage DECIMAL(4,2) DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  description TEXT,
  image_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Customers table
CREATE TABLE public.customers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  phone TEXT,
  email TEXT,
  address TEXT,
  area TEXT,
  route_id UUID REFERENCES public.routes(id) ON DELETE SET NULL,
  subscription_type TEXT DEFAULT 'daily',
  billing_cycle TEXT DEFAULT 'monthly',
  credit_balance DECIMAL(10,2) DEFAULT 0,
  advance_balance DECIMAL(10,2) DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Customer product preferences (subscriptions)
CREATE TABLE public.customer_products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID REFERENCES public.customers(id) ON DELETE CASCADE NOT NULL,
  product_id UUID REFERENCES public.products(id) ON DELETE CASCADE NOT NULL,
  quantity DECIMAL(6,2) NOT NULL,
  custom_price DECIMAL(10,2),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(customer_id, product_id)
);

-- Customer accounts for customer app authentication
CREATE TABLE public.customer_accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL UNIQUE REFERENCES public.customers(id) ON DELETE CASCADE,
  user_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  phone TEXT NOT NULL UNIQUE,
  pin_hash TEXT,
  is_approved BOOLEAN DEFAULT false,
  approval_status TEXT DEFAULT 'pending' CHECK (approval_status IN ('pending', 'approved', 'rejected')),
  approved_by UUID REFERENCES auth.users(id),
  approved_at TIMESTAMP WITH TIME ZONE,
  last_login TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Customer vacations (delivery pause periods)
CREATE TABLE public.customer_vacations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  reason TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  created_by UUID REFERENCES auth.users(id),
  CONSTRAINT valid_date_range CHECK (end_date >= start_date)
);

-- Customer ledger (transaction history)
CREATE TABLE public.customer_ledger (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
  transaction_date DATE NOT NULL DEFAULT CURRENT_DATE,
  transaction_type TEXT NOT NULL,
  reference_id UUID,
  description TEXT NOT NULL,
  debit_amount DECIMAL(10,2) DEFAULT 0,
  credit_amount DECIMAL(10,2) DEFAULT 0,
  running_balance DECIMAL(10,2) DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  created_by UUID REFERENCES auth.users(id)
);

-- Route stops
CREATE TABLE public.route_stops (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  route_id UUID NOT NULL REFERENCES public.routes(id) ON DELETE CASCADE,
  customer_id UUID NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
  stop_order INTEGER NOT NULL,
  estimated_arrival_time TIME,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Deliveries table
CREATE TABLE public.deliveries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID REFERENCES public.customers(id) ON DELETE CASCADE NOT NULL,
  delivery_date DATE NOT NULL,
  status delivery_status DEFAULT 'pending',
  delivered_by UUID REFERENCES auth.users(id),
  delivery_time TIMESTAMP WITH TIME ZONE,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(customer_id, delivery_date)
);

-- Delivery items
CREATE TABLE public.delivery_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  delivery_id UUID REFERENCES public.deliveries(id) ON DELETE CASCADE NOT NULL,
  product_id UUID REFERENCES public.products(id) NOT NULL,
  quantity DECIMAL(6,2) NOT NULL,
  unit_price DECIMAL(10,2) NOT NULL,
  total_amount DECIMAL(10,2) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Invoices table
CREATE TABLE public.invoices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_number TEXT NOT NULL UNIQUE,
  customer_id UUID REFERENCES public.customers(id) ON DELETE CASCADE NOT NULL,
  billing_period_start DATE NOT NULL,
  billing_period_end DATE NOT NULL,
  total_amount DECIMAL(10,2) NOT NULL,
  tax_amount DECIMAL(10,2) DEFAULT 0,
  discount_amount DECIMAL(10,2) DEFAULT 0,
  final_amount DECIMAL(10,2) NOT NULL,
  payment_status payment_status DEFAULT 'pending',
  due_date DATE,
  paid_amount DECIMAL(10,2) DEFAULT 0,
  payment_date DATE,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Payments table
CREATE TABLE public.payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_id UUID REFERENCES public.invoices(id) ON DELETE CASCADE,
  customer_id UUID REFERENCES public.customers(id) ON DELETE CASCADE NOT NULL,
  amount DECIMAL(10,2) NOT NULL,
  payment_mode TEXT NOT NULL,
  payment_date DATE NOT NULL,
  reference_number TEXT,
  notes TEXT,
  recorded_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Bottle inventory
CREATE TABLE public.bottles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bottle_type bottle_type NOT NULL,
  size bottle_size NOT NULL,
  total_quantity INTEGER NOT NULL DEFAULT 0,
  available_quantity INTEGER NOT NULL DEFAULT 0,
  deposit_amount DECIMAL(6,2) DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(bottle_type, size)
);

-- Customer bottle balance
CREATE TABLE public.customer_bottles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID REFERENCES public.customers(id) ON DELETE CASCADE NOT NULL,
  bottle_id UUID REFERENCES public.bottles(id) ON DELETE CASCADE NOT NULL,
  quantity_pending INTEGER DEFAULT 0,
  last_issued_date DATE,
  last_returned_date DATE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(customer_id, bottle_id)
);

-- Bottle transactions
CREATE TABLE public.bottle_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bottle_id UUID REFERENCES public.bottles(id) ON DELETE CASCADE NOT NULL,
  customer_id UUID REFERENCES public.customers(id) ON DELETE CASCADE,
  staff_id UUID REFERENCES auth.users(id),
  transaction_type TEXT NOT NULL,
  quantity INTEGER NOT NULL,
  transaction_date DATE NOT NULL,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Cattle health records
CREATE TABLE public.cattle_health (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cattle_id UUID REFERENCES public.cattle(id) ON DELETE CASCADE NOT NULL,
  record_date DATE NOT NULL,
  record_type TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  vet_name TEXT,
  cost DECIMAL(10,2),
  next_due_date DATE,
  recorded_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Breeding records
CREATE TABLE public.breeding_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cattle_id UUID NOT NULL REFERENCES public.cattle(id) ON DELETE CASCADE,
  record_type TEXT NOT NULL,
  record_date DATE NOT NULL,
  heat_cycle_day INTEGER,
  insemination_bull TEXT,
  insemination_technician TEXT,
  pregnancy_confirmed BOOLEAN,
  expected_calving_date DATE,
  actual_calving_date DATE,
  calf_details JSONB,
  notes TEXT,
  recorded_by UUID,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Feed/Fodder inventory
CREATE TABLE public.feed_inventory (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  category TEXT NOT NULL,
  unit TEXT NOT NULL DEFAULT 'kg',
  current_stock DECIMAL(10,2) DEFAULT 0,
  min_stock_level DECIMAL(10,2) DEFAULT 0,
  cost_per_unit DECIMAL(10,2),
  supplier TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Feed consumption records
CREATE TABLE public.feed_consumption (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  feed_id UUID REFERENCES public.feed_inventory(id) ON DELETE CASCADE NOT NULL,
  cattle_id UUID REFERENCES public.cattle(id) ON DELETE SET NULL,
  consumption_date DATE NOT NULL,
  quantity DECIMAL(10,2) NOT NULL,
  recorded_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Employees table
CREATE TABLE public.employees (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  phone TEXT,
  address TEXT,
  role user_role NOT NULL,
  salary DECIMAL(10,2),
  joining_date DATE,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Shifts table
CREATE TABLE public.shifts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Employee shifts assignment
CREATE TABLE public.employee_shifts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id UUID NOT NULL REFERENCES public.employees(id) ON DELETE CASCADE,
  shift_id UUID NOT NULL REFERENCES public.shifts(id) ON DELETE CASCADE,
  effective_from DATE NOT NULL,
  effective_to DATE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Employee attendance
CREATE TABLE public.attendance (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id UUID REFERENCES public.employees(id) ON DELETE CASCADE NOT NULL,
  attendance_date DATE NOT NULL,
  check_in TIME,
  check_out TIME,
  status TEXT DEFAULT 'present',
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(employee_id, attendance_date)
);

-- Payroll records
CREATE TABLE public.payroll_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id UUID NOT NULL REFERENCES public.employees(id) ON DELETE CASCADE,
  pay_period_start DATE NOT NULL,
  pay_period_end DATE NOT NULL,
  base_salary DECIMAL(10,2) NOT NULL DEFAULT 0,
  overtime_hours DECIMAL(6,2) DEFAULT 0,
  overtime_rate DECIMAL(10,2) DEFAULT 0,
  bonus DECIMAL(10,2) DEFAULT 0,
  deductions DECIMAL(10,2) DEFAULT 0,
  net_salary DECIMAL(10,2) NOT NULL DEFAULT 0,
  payment_status TEXT DEFAULT 'pending',
  payment_date DATE,
  payment_mode TEXT,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  created_by UUID
);

-- Equipment table
CREATE TABLE public.equipment (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  category TEXT NOT NULL,
  model TEXT,
  serial_number TEXT,
  purchase_date DATE,
  purchase_cost DECIMAL(10,2),
  warranty_expiry DATE,
  status TEXT DEFAULT 'active',
  location TEXT,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Maintenance records
CREATE TABLE public.maintenance_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id UUID NOT NULL REFERENCES public.equipment(id) ON DELETE CASCADE,
  maintenance_type TEXT NOT NULL,
  maintenance_date DATE NOT NULL,
  description TEXT,
  cost DECIMAL(10,2) DEFAULT 0,
  performed_by TEXT,
  next_maintenance_date DATE,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Expenses table
CREATE TABLE public.expenses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category TEXT NOT NULL,
  title TEXT NOT NULL,
  amount DECIMAL(10,2) NOT NULL,
  expense_date DATE NOT NULL,
  cattle_id UUID REFERENCES public.cattle(id) ON DELETE SET NULL,
  notes TEXT,
  receipt_url TEXT,
  recorded_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Price rules table (Quality-based pricing)
CREATE TABLE public.price_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  product_id UUID REFERENCES public.products(id) ON DELETE CASCADE,
  min_fat_percentage DECIMAL(4,2),
  max_fat_percentage DECIMAL(4,2),
  min_snf_percentage DECIMAL(4,2),
  max_snf_percentage DECIMAL(4,2),
  price_adjustment DECIMAL(10,2) NOT NULL DEFAULT 0,
  adjustment_type TEXT DEFAULT 'fixed',
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Dairy settings
CREATE TABLE public.dairy_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  dairy_name TEXT NOT NULL DEFAULT 'Awadh Dairy',
  logo_url TEXT,
  address TEXT,
  phone TEXT,
  email TEXT,
  currency TEXT DEFAULT 'INR',
  financial_year_start INTEGER DEFAULT 4,
  invoice_prefix TEXT DEFAULT 'INV',
  settings JSONB DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Notification templates
CREATE TABLE public.notification_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  template_type TEXT NOT NULL,
  channel TEXT NOT NULL,
  subject TEXT,
  body TEXT NOT NULL,
  variables JSONB DEFAULT '[]',
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Notification logs
CREATE TABLE public.notification_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id UUID REFERENCES public.notification_templates(id),
  recipient_type TEXT NOT NULL,
  recipient_id UUID NOT NULL,
  recipient_contact TEXT,
  channel TEXT NOT NULL,
  subject TEXT,
  body TEXT NOT NULL,
  status TEXT DEFAULT 'pending',
  sent_at TIMESTAMP WITH TIME ZONE,
  error_message TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Activity logs for audit
CREATE TABLE public.activity_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id),
  action TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id TEXT,
  details JSONB,
  ip_address TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Auth attempts for staff rate limiting
CREATE TABLE public.auth_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phone TEXT NOT NULL UNIQUE,
  failed_count INTEGER DEFAULT 0,
  locked_until TIMESTAMP WITH TIME ZONE,
  last_attempt TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Customer auth attempts for rate limiting
CREATE TABLE public.customer_auth_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phone TEXT NOT NULL UNIQUE,
  failed_count INTEGER DEFAULT 0,
  last_attempt TIMESTAMP WITH TIME ZONE DEFAULT now(),
  locked_until TIMESTAMP WITH TIME ZONE
);

-- =====================================================
-- PART 3: INDEXES
-- =====================================================

CREATE INDEX idx_customer_ledger_customer ON public.customer_ledger(customer_id);
CREATE INDEX idx_customer_ledger_date ON public.customer_ledger(transaction_date);
CREATE INDEX idx_customer_vacations_dates ON public.customer_vacations(start_date, end_date);
CREATE INDEX idx_customer_vacations_customer ON public.customer_vacations(customer_id);
CREATE INDEX idx_customer_accounts_phone ON public.customer_accounts(phone);
CREATE INDEX idx_customer_accounts_customer_id ON public.customer_accounts(customer_id);
CREATE INDEX idx_customer_accounts_user_id ON public.customer_accounts(user_id);
CREATE INDEX idx_deliveries_date ON public.deliveries(delivery_date);
CREATE INDEX idx_milk_production_date ON public.milk_production(production_date);
CREATE INDEX idx_activity_logs_created ON public.activity_logs(created_at);
-- =====================================================
-- PART 3.5: VIEWS
-- =====================================================

-- Safe view of profiles (excludes sensitive data like pin_hash)
CREATE OR REPLACE VIEW public.profiles_safe AS
SELECT id, full_name, phone, role, avatar_url, is_active, created_at, updated_at
FROM public.profiles;

GRANT SELECT ON public.profiles_safe TO authenticated;
GRANT SELECT ON public.profiles_safe TO anon;

-- =====================================================
-- PART 4: ENABLE RLS ON ALL TABLES
-- =====================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cattle ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.milk_production ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_vacations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.routes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.route_stops ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.deliveries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.delivery_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bottles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_bottles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bottle_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cattle_health ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.breeding_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.feed_inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.feed_consumption ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.employee_shifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payroll_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.equipment ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maintenance_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dairy_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.auth_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_auth_attempts ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- PART 5: HELPER FUNCTIONS
-- =====================================================

-- Check if user is authenticated
CREATE OR REPLACE FUNCTION public.is_authenticated()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT auth.uid() IS NOT NULL
$$;

-- Check if user has specific role
CREATE OR REPLACE FUNCTION public.has_role(_user_id uuid, _role user_role)
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
      AND role = _role
  )
$$;

-- Check if user has any of the specified roles
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

-- Check if user is manager or admin
CREATE OR REPLACE FUNCTION public.is_manager_or_admin(_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.has_any_role(_user_id, ARRAY['super_admin', 'manager']::user_role[])
$$;

-- Check if customer is on vacation
CREATE OR REPLACE FUNCTION public.is_customer_on_vacation(
  _customer_id UUID,
  _check_date DATE DEFAULT CURRENT_DATE
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.customer_vacations
    WHERE customer_id = _customer_id
      AND is_active = true
      AND _check_date BETWEEN start_date AND end_date
  )
$$;

-- =====================================================
-- PART 6: AUTHENTICATION FUNCTIONS
-- =====================================================

-- Update PIN only (for staff)
CREATE OR REPLACE FUNCTION public.update_pin_only(_user_id UUID, _pin TEXT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.profiles
  SET pin_hash = crypt(_pin, gen_salt('bf')),
      updated_at = NOW()
  WHERE id = _user_id;
END;
$$;

-- Update user profile with PIN
CREATE OR REPLACE FUNCTION public.update_user_profile_with_pin(
  _user_id UUID,
  _full_name TEXT,
  _phone TEXT,
  _role user_role,
  _pin TEXT
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, phone, role, pin_hash, is_active)
  VALUES (_user_id, _full_name, _phone, _role, crypt(_pin, gen_salt('bf')), true)
  ON CONFLICT (id) DO UPDATE
  SET full_name = _full_name,
      phone = _phone,
      role = _role,
      pin_hash = crypt(_pin, gen_salt('bf')),
      updated_at = NOW();
END;
$$;

-- Verify staff PIN with brute-force protection
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

-- Verify customer PIN
CREATE OR REPLACE FUNCTION public.verify_customer_pin(_phone TEXT, _pin TEXT)
RETURNS TABLE(customer_id UUID, user_id UUID, is_approved BOOLEAN)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _locked_until TIMESTAMP WITH TIME ZONE;
  _failed_count INTEGER;
  _account RECORD;
BEGIN
  -- Check if account is locked
  SELECT ca.locked_until, ca.failed_count INTO _locked_until, _failed_count
  FROM public.customer_auth_attempts ca WHERE ca.phone = _phone;
  
  IF _locked_until IS NOT NULL AND _locked_until > NOW() THEN
    RAISE EXCEPTION 'Account temporarily locked. Try again later.';
  END IF;
  
  -- Verify PIN
  SELECT cust.customer_id AS customer_id, cust.user_id, cust.is_approved 
  INTO _account
  FROM public.customer_accounts cust
  WHERE cust.phone = _phone
    AND cust.pin_hash = crypt(_pin, cust.pin_hash);
  
  IF _account IS NULL THEN
    -- Increment failed attempts
    INSERT INTO public.customer_auth_attempts (phone, failed_count, last_attempt)
    VALUES (_phone, 1, NOW())
    ON CONFLICT (phone) DO UPDATE
    SET failed_count = customer_auth_attempts.failed_count + 1,
        last_attempt = NOW(),
        locked_until = CASE
          WHEN customer_auth_attempts.failed_count >= 4 THEN NOW() + INTERVAL '15 minutes'
          ELSE NULL
        END;
    RETURN;
  ELSE
    -- Reset attempts on success
    DELETE FROM public.customer_auth_attempts WHERE phone = _phone;
    
    -- Update last login
    UPDATE public.customer_accounts SET last_login = NOW() WHERE phone = _phone;
    
    RETURN QUERY SELECT _account.customer_id, _account.user_id, _account.is_approved;
  END IF;
END;
$$;

-- Register customer account
CREATE OR REPLACE FUNCTION public.register_customer_account(_phone TEXT, _pin TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _customer RECORD;
  _existing_account RECORD;
BEGIN
  -- Check if account already exists
  SELECT * INTO _existing_account FROM public.customer_accounts WHERE phone = _phone;
  IF _existing_account IS NOT NULL THEN
    RETURN json_build_object('success', false, 'error', 'Account already exists for this phone number');
  END IF;
  
  -- Check if customer exists in customers table
  SELECT * INTO _customer FROM public.customers WHERE phone = _phone AND is_active = true;
  
  IF _customer IS NOT NULL THEN
    -- Auto-approve for existing customers
    INSERT INTO public.customer_accounts (customer_id, phone, pin_hash, is_approved, approval_status)
    VALUES (_customer.id, _phone, crypt(_pin, gen_salt('bf')), true, 'approved');
    
    RETURN json_build_object(
      'success', true, 
      'approved', true, 
      'message', 'Account created and auto-approved',
      'customer_id', _customer.id
    );
  ELSE
    -- New customer - needs manual approval
    INSERT INTO public.customers (name, phone, is_active)
    VALUES ('Pending Registration', _phone, false)
    RETURNING * INTO _customer;
    
    INSERT INTO public.customer_accounts (customer_id, phone, pin_hash, is_approved, approval_status)
    VALUES (_customer.id, _phone, crypt(_pin, gen_salt('bf')), false, 'pending');
    
    RETURN json_build_object(
      'success', true, 
      'approved', false, 
      'message', 'Account created, pending approval',
      'customer_id', _customer.id
    );
  END IF;
END;
$$;

-- Update customer PIN
CREATE OR REPLACE FUNCTION public.update_customer_pin(_customer_id UUID, _current_pin TEXT, _new_pin TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _account RECORD;
BEGIN
  -- Verify current PIN
  SELECT * INTO _account 
  FROM public.customer_accounts 
  WHERE customer_id = _customer_id 
    AND pin_hash = crypt(_current_pin, pin_hash);
  
  IF _account IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Current PIN is incorrect');
  END IF;
  
  -- Update PIN
  UPDATE public.customer_accounts 
  SET pin_hash = crypt(_new_pin, gen_salt('bf')), updated_at = NOW()
  WHERE customer_id = _customer_id;
  
  RETURN json_build_object('success', true, 'message', 'PIN updated successfully');
END;
$$;

-- =====================================================
-- PART 7: TRIGGER FUNCTIONS
-- =====================================================

-- Handle new user creation
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
    'farm_worker',
    new.raw_user_meta_data ->> 'phone',
    CASE 
      WHEN new.raw_user_meta_data ->> 'pin' IS NOT NULL 
      THEN crypt(new.raw_user_meta_data ->> 'pin', gen_salt('bf'))
      ELSE NULL 
    END
  );
  
  INSERT INTO public.user_roles (user_id, role)
  VALUES (new.id, 'farm_worker');
  
  RETURN new;
END;
$$;

-- Trigger for new user
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Update timestamp function
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for updated_at
CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_cattle_updated_at BEFORE UPDATE ON public.cattle FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_products_updated_at BEFORE UPDATE ON public.products FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_customers_updated_at BEFORE UPDATE ON public.customers FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_invoices_updated_at BEFORE UPDATE ON public.invoices FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_bottles_updated_at BEFORE UPDATE ON public.bottles FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_customer_bottles_updated_at BEFORE UPDATE ON public.customer_bottles FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_feed_inventory_updated_at BEFORE UPDATE ON public.feed_inventory FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_employees_updated_at BEFORE UPDATE ON public.employees FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_dairy_settings_updated_at BEFORE UPDATE ON public.dairy_settings FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_equipment_updated_at BEFORE UPDATE ON public.equipment FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_price_rules_updated_at BEFORE UPDATE ON public.price_rules FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_customer_accounts_updated_at BEFORE UPDATE ON public.customer_accounts FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- =====================================================
-- PART 8: RLS POLICIES
-- =====================================================

-- Profiles policies
CREATE POLICY "Users can view their own profile" ON public.profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update their own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Authenticated users can view all profiles" ON public.profiles FOR SELECT USING (public.is_authenticated());

-- User roles policies
CREATE POLICY "Users can view their own roles" ON public.user_roles FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Admins can manage roles" ON public.user_roles FOR ALL USING (public.has_role(auth.uid(), 'super_admin'));

-- Cattle policies
CREATE POLICY "Managers and admins have full access to cattle" ON public.cattle FOR ALL USING (public.is_manager_or_admin(auth.uid()));
CREATE POLICY "Farm workers can manage cattle" ON public.cattle FOR ALL USING (public.has_role(auth.uid(), 'farm_worker'));
CREATE POLICY "Vet staff can read cattle" ON public.cattle FOR SELECT USING (public.has_role(auth.uid(), 'vet_staff'));
CREATE POLICY "Auditors can read cattle" ON public.cattle FOR SELECT USING (public.has_role(auth.uid(), 'auditor'));

-- Milk production policies
CREATE POLICY "Managers and admins have full access to milk_production" ON public.milk_production FOR ALL USING (public.is_manager_or_admin(auth.uid()));
CREATE POLICY "Farm workers can manage milk_production" ON public.milk_production FOR ALL USING (public.has_role(auth.uid(), 'farm_worker'));
CREATE POLICY "Auditors can read milk_production" ON public.milk_production FOR SELECT USING (public.has_role(auth.uid(), 'auditor'));

-- Products policies
CREATE POLICY "Managers and admins have full access to products" ON public.products FOR ALL USING (public.is_manager_or_admin(auth.uid()));
CREATE POLICY "Staff can read products" ON public.products FOR SELECT USING (public.is_authenticated());

-- Customers policies
CREATE POLICY "Managers and admins have full access to customers" ON public.customers FOR ALL USING (public.is_manager_or_admin(auth.uid()));
CREATE POLICY "Accountants can read customers" ON public.customers FOR SELECT USING (public.has_role(auth.uid(), 'accountant'));
CREATE POLICY "Delivery staff can read customers" ON public.customers FOR SELECT USING (public.has_role(auth.uid(), 'delivery_staff'));
CREATE POLICY "Auditors can read customers" ON public.customers FOR SELECT USING (public.has_role(auth.uid(), 'auditor'));
CREATE POLICY "Customers can read own customer data" ON public.customers FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.customer_accounts ca 
    WHERE ca.customer_id = customers.id 
    AND ca.user_id = auth.uid()
  )
);
CREATE POLICY "Customers can update own customer data" ON public.customers FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM public.customer_accounts ca 
    WHERE ca.customer_id = customers.id 
    AND ca.user_id = auth.uid()
  )
);

-- Customer accounts policies
CREATE POLICY "Managers and admins have full access to customer_accounts" ON public.customer_accounts FOR ALL USING (is_manager_or_admin(auth.uid()));
CREATE POLICY "Customers can view own account" ON public.customer_accounts FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Customers can update own account" ON public.customer_accounts FOR UPDATE USING (user_id = auth.uid());

-- Customer products policies
CREATE POLICY "Managers and admins have full access to customer_products" ON public.customer_products FOR ALL USING (public.is_manager_or_admin(auth.uid()));
CREATE POLICY "Delivery staff can read customer_products" ON public.customer_products FOR SELECT USING (public.has_role(auth.uid(), 'delivery_staff'));
CREATE POLICY "Auditors can read customer_products" ON public.customer_products FOR SELECT USING (public.has_role(auth.uid(), 'auditor'));
CREATE POLICY "Customers can read own products" ON public.customer_products FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.customer_accounts ca WHERE ca.customer_id = customer_products.customer_id AND ca.user_id = auth.uid())
);
CREATE POLICY "Customers can manage own subscriptions" ON public.customer_products FOR ALL USING (
  EXISTS (SELECT 1 FROM public.customer_accounts ca WHERE ca.customer_id = customer_products.customer_id AND ca.user_id = auth.uid())
);

-- Customer vacations policies
CREATE POLICY "Managers and admins have full access to customer_vacations" ON public.customer_vacations FOR ALL USING (is_manager_or_admin(auth.uid()));
CREATE POLICY "Delivery staff can read customer_vacations" ON public.customer_vacations FOR SELECT USING (has_role(auth.uid(), 'delivery_staff'::user_role));
CREATE POLICY "Auditors can read customer_vacations" ON public.customer_vacations FOR SELECT USING (has_role(auth.uid(), 'auditor'::user_role));
CREATE POLICY "Customers can read own vacations" ON public.customer_vacations FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.customer_accounts ca WHERE ca.customer_id = customer_vacations.customer_id AND ca.user_id = auth.uid())
);
CREATE POLICY "Customers can manage own vacations" ON public.customer_vacations FOR ALL USING (
  EXISTS (SELECT 1 FROM public.customer_accounts ca WHERE ca.customer_id = customer_vacations.customer_id AND ca.user_id = auth.uid())
);

-- Customer ledger policies
CREATE POLICY "Managers and admins have full access to customer_ledger" ON public.customer_ledger FOR ALL USING (is_manager_or_admin(auth.uid()));
CREATE POLICY "Accountants can manage customer_ledger" ON public.customer_ledger FOR ALL USING (has_role(auth.uid(), 'accountant'::user_role));
CREATE POLICY "Delivery staff can read customer_ledger" ON public.customer_ledger FOR SELECT USING (has_role(auth.uid(), 'delivery_staff'::user_role));
CREATE POLICY "Auditors can read customer_ledger" ON public.customer_ledger FOR SELECT USING (has_role(auth.uid(), 'auditor'::user_role));
CREATE POLICY "Customers can read own ledger" ON public.customer_ledger FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.customer_accounts ca WHERE ca.customer_id = customer_ledger.customer_id AND ca.user_id = auth.uid())
);

-- Routes policies
CREATE POLICY "Managers and admins have full access to routes" ON public.routes FOR ALL USING (public.is_manager_or_admin(auth.uid()));
CREATE POLICY "Staff can read routes" ON public.routes FOR SELECT USING (public.is_authenticated());

-- Route stops policies
CREATE POLICY "Managers and admins have full access to route_stops" ON public.route_stops FOR ALL USING (is_manager_or_admin(auth.uid()));
CREATE POLICY "Delivery staff can read route_stops" ON public.route_stops FOR SELECT USING (has_role(auth.uid(), 'delivery_staff'));

-- Deliveries policies
CREATE POLICY "Managers and admins have full access to deliveries" ON public.deliveries FOR ALL USING (public.is_manager_or_admin(auth.uid()));
CREATE POLICY "Delivery staff can manage deliveries" ON public.deliveries FOR ALL USING (public.has_role(auth.uid(), 'delivery_staff'));
CREATE POLICY "Auditors can read deliveries" ON public.deliveries FOR SELECT USING (public.has_role(auth.uid(), 'auditor'));
CREATE POLICY "Customers can read own deliveries" ON public.deliveries FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.customer_accounts ca WHERE ca.customer_id = deliveries.customer_id AND ca.user_id = auth.uid())
);

-- Delivery items policies
CREATE POLICY "Managers and admins have full access to delivery_items" ON public.delivery_items FOR ALL USING (public.is_manager_or_admin(auth.uid()));
CREATE POLICY "Delivery staff can manage delivery_items" ON public.delivery_items FOR ALL USING (public.has_role(auth.uid(), 'delivery_staff'));
CREATE POLICY "Auditors can read delivery_items" ON public.delivery_items FOR SELECT USING (public.has_role(auth.uid(), 'auditor'));
CREATE POLICY "Customers can read own delivery_items" ON public.delivery_items FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.deliveries d
    JOIN public.customer_accounts ca ON ca.customer_id = d.customer_id
    WHERE d.id = delivery_items.delivery_id AND ca.user_id = auth.uid()
  )
);

-- Invoices policies
CREATE POLICY "Managers and admins have full access to invoices" ON public.invoices FOR ALL USING (public.is_manager_or_admin(auth.uid()));
CREATE POLICY "Accountants can manage invoices" ON public.invoices FOR ALL USING (public.has_role(auth.uid(), 'accountant'));
CREATE POLICY "Auditors can read invoices" ON public.invoices FOR SELECT USING (public.has_role(auth.uid(), 'auditor'));
CREATE POLICY "Customers can read own invoices" ON public.invoices FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.customer_accounts ca WHERE ca.customer_id = invoices.customer_id AND ca.user_id = auth.uid())
);

-- Payments policies
CREATE POLICY "Managers and admins have full access to payments" ON public.payments FOR ALL USING (public.is_manager_or_admin(auth.uid()));
CREATE POLICY "Accountants can manage payments" ON public.payments FOR ALL USING (public.has_role(auth.uid(), 'accountant'));
CREATE POLICY "Auditors can read payments" ON public.payments FOR SELECT USING (public.has_role(auth.uid(), 'auditor'));
CREATE POLICY "Customers can read own payments" ON public.payments FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.customer_accounts ca WHERE ca.customer_id = payments.customer_id AND ca.user_id = auth.uid())
);

-- Bottles policies
CREATE POLICY "Managers and admins have full access to bottles" ON public.bottles FOR ALL USING (public.is_manager_or_admin(auth.uid()));
CREATE POLICY "Staff can read bottles" ON public.bottles FOR SELECT USING (public.is_authenticated());

-- Customer bottles policies
CREATE POLICY "Managers and admins have full access to customer_bottles" ON public.customer_bottles FOR ALL USING (public.is_manager_or_admin(auth.uid()));
CREATE POLICY "Delivery staff can manage customer_bottles" ON public.customer_bottles FOR ALL USING (public.has_role(auth.uid(), 'delivery_staff'));
CREATE POLICY "Auditors can read customer_bottles" ON public.customer_bottles FOR SELECT USING (public.has_role(auth.uid(), 'auditor'));
CREATE POLICY "Customers can read own bottles" ON public.customer_bottles FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.customer_accounts ca WHERE ca.customer_id = customer_bottles.customer_id AND ca.user_id = auth.uid())
);

-- Bottle transactions policies
CREATE POLICY "Managers and admins have full access to bottle_transactions" ON public.bottle_transactions FOR ALL USING (public.is_manager_or_admin(auth.uid()));
CREATE POLICY "Delivery staff can manage bottle_transactions" ON public.bottle_transactions FOR ALL USING (public.has_role(auth.uid(), 'delivery_staff'));
CREATE POLICY "Auditors can read bottle_transactions" ON public.bottle_transactions FOR SELECT USING (public.has_role(auth.uid(), 'auditor'));

-- Cattle health policies
CREATE POLICY "Managers and admins have full access to cattle_health" ON public.cattle_health FOR ALL USING (public.is_manager_or_admin(auth.uid()));
CREATE POLICY "Farm workers can manage cattle_health" ON public.cattle_health FOR ALL USING (public.has_role(auth.uid(), 'farm_worker'));
CREATE POLICY "Vet staff can manage cattle_health" ON public.cattle_health FOR ALL USING (public.has_role(auth.uid(), 'vet_staff'));
CREATE POLICY "Auditors can read cattle_health" ON public.cattle_health FOR SELECT USING (public.has_role(auth.uid(), 'auditor'));

-- Breeding records policies
CREATE POLICY "Managers and admins have full access to breeding_records" ON public.breeding_records FOR ALL USING (is_manager_or_admin(auth.uid()));
CREATE POLICY "Farm workers can manage breeding_records" ON public.breeding_records FOR ALL USING (has_role(auth.uid(), 'farm_worker'));
CREATE POLICY "Vet staff can manage breeding_records" ON public.breeding_records FOR ALL USING (has_role(auth.uid(), 'vet_staff'));
CREATE POLICY "Auditors can read breeding_records" ON public.breeding_records FOR SELECT USING (has_role(auth.uid(), 'auditor'));

-- Feed inventory policies
CREATE POLICY "Managers and admins have full access to feed_inventory" ON public.feed_inventory FOR ALL USING (public.is_manager_or_admin(auth.uid()));
CREATE POLICY "Farm workers can read feed_inventory" ON public.feed_inventory FOR SELECT USING (public.has_role(auth.uid(), 'farm_worker'));
CREATE POLICY "Auditors can read feed_inventory" ON public.feed_inventory FOR SELECT USING (public.has_role(auth.uid(), 'auditor'));

-- Feed consumption policies
CREATE POLICY "Managers and admins have full access to feed_consumption" ON public.feed_consumption FOR ALL USING (public.is_manager_or_admin(auth.uid()));
CREATE POLICY "Farm workers can manage feed_consumption" ON public.feed_consumption FOR ALL USING (public.has_role(auth.uid(), 'farm_worker'));
CREATE POLICY "Auditors can read feed_consumption" ON public.feed_consumption FOR SELECT USING (public.has_role(auth.uid(), 'auditor'));

-- Employees policies
CREATE POLICY "Managers and admins have full access to employees" ON public.employees FOR ALL USING (public.is_manager_or_admin(auth.uid()));
CREATE POLICY "Auditors can read employees" ON public.employees FOR SELECT USING (public.has_role(auth.uid(), 'auditor'));

-- Shifts policies
CREATE POLICY "Managers and admins have full access to shifts" ON public.shifts FOR ALL USING (is_manager_or_admin(auth.uid()));
CREATE POLICY "Staff can read shifts" ON public.shifts FOR SELECT USING (is_authenticated());

-- Employee shifts policies
CREATE POLICY "Managers and admins have full access to employee_shifts" ON public.employee_shifts FOR ALL USING (is_manager_or_admin(auth.uid()));
CREATE POLICY "Staff can read employee_shifts" ON public.employee_shifts FOR SELECT USING (is_authenticated());

-- Attendance policies
CREATE POLICY "Managers and admins have full access to attendance" ON public.attendance FOR ALL USING (public.is_manager_or_admin(auth.uid()));
CREATE POLICY "Auditors can read attendance" ON public.attendance FOR SELECT USING (public.has_role(auth.uid(), 'auditor'));

-- Payroll policies
CREATE POLICY "Managers and admins have full access to payroll_records" ON public.payroll_records FOR ALL USING (is_manager_or_admin(auth.uid()));
CREATE POLICY "Accountants can manage payroll_records" ON public.payroll_records FOR ALL USING (has_role(auth.uid(), 'accountant'));
CREATE POLICY "Auditors can read payroll_records" ON public.payroll_records FOR SELECT USING (has_role(auth.uid(), 'auditor'));

-- Equipment policies
CREATE POLICY "Managers and admins have full access to equipment" ON public.equipment FOR ALL USING (is_manager_or_admin(auth.uid()));
CREATE POLICY "Staff can read equipment" ON public.equipment FOR SELECT USING (is_authenticated());

-- Maintenance records policies
CREATE POLICY "Managers and admins have full access to maintenance_records" ON public.maintenance_records FOR ALL USING (is_manager_or_admin(auth.uid()));
CREATE POLICY "Farm workers can manage maintenance_records" ON public.maintenance_records FOR ALL USING (has_role(auth.uid(), 'farm_worker'));
CREATE POLICY "Auditors can read maintenance_records" ON public.maintenance_records FOR SELECT USING (has_role(auth.uid(), 'auditor'));

-- Expenses policies
CREATE POLICY "Managers and admins have full access to expenses" ON public.expenses FOR ALL USING (public.is_manager_or_admin(auth.uid()));
CREATE POLICY "Accountants can manage expenses" ON public.expenses FOR ALL USING (public.has_role(auth.uid(), 'accountant'));
CREATE POLICY "Auditors can read expenses" ON public.expenses FOR SELECT USING (public.has_role(auth.uid(), 'auditor'));

-- Price rules policies
CREATE POLICY "Managers and admins have full access to price_rules" ON public.price_rules FOR ALL USING (is_manager_or_admin(auth.uid()));
CREATE POLICY "Staff can read price_rules" ON public.price_rules FOR SELECT USING (is_authenticated());

-- Dairy settings policies
CREATE POLICY "Admins have full access to dairy_settings" ON public.dairy_settings FOR ALL USING (public.has_role(auth.uid(), 'super_admin'));
CREATE POLICY "Staff can read dairy_settings" ON public.dairy_settings FOR SELECT USING (public.is_authenticated());

-- Notification templates policies
CREATE POLICY "Managers and admins have full access to notification_templates" ON public.notification_templates FOR ALL USING (is_manager_or_admin(auth.uid()));
CREATE POLICY "Staff can read notification_templates" ON public.notification_templates FOR SELECT USING (is_authenticated());

-- Notification logs policies
CREATE POLICY "Managers and admins have full access to notification_logs" ON public.notification_logs FOR ALL USING (is_manager_or_admin(auth.uid()));
CREATE POLICY "Staff can read notification_logs" ON public.notification_logs FOR SELECT USING (is_authenticated());

-- Activity logs policies
CREATE POLICY "Authenticated users can view activity_logs" ON public.activity_logs FOR SELECT USING (public.is_authenticated());
CREATE POLICY "Authenticated users can insert activity_logs" ON public.activity_logs FOR INSERT WITH CHECK (public.is_authenticated());

-- Auth attempts - no direct access (only via security definer functions)
CREATE POLICY "No direct access to auth_attempts" ON public.auth_attempts FOR ALL USING (false);
CREATE POLICY "No direct access to customer_auth_attempts" ON public.customer_auth_attempts FOR ALL USING (false);

-- =====================================================
-- PART 9: DEFAULT DATA
-- =====================================================

-- Insert default dairy settings
INSERT INTO public.dairy_settings (dairy_name, currency, invoice_prefix) 
VALUES ('Awadh Dairy', 'INR', 'INV');

-- Insert default shifts
INSERT INTO public.shifts (name, start_time, end_time) VALUES 
  ('Morning Shift', '05:00', '13:00'),
  ('Evening Shift', '13:00', '21:00'),
  ('Night Shift', '21:00', '05:00');

-- Insert default notification templates
INSERT INTO public.notification_templates (name, template_type, channel, subject, body, variables) VALUES 
  ('Payment Reminder', 'payment_reminder', 'sms', NULL, 'Dear {{customer_name}}, your payment of ₹{{amount}} is due on {{due_date}}. Please pay to avoid service interruption.', '["customer_name", "amount", "due_date"]'),
  ('Delivery Confirmation', 'delivery_alert', 'whatsapp', NULL, 'Hi {{customer_name}}, your {{product_name}} ({{quantity}}) has been delivered. Thank you!', '["customer_name", "product_name", "quantity"]'),
  ('Health Alert', 'health_alert', 'sms', NULL, 'Alert: Cattle {{tag_number}} - {{health_issue}}. Next checkup: {{next_date}}.', '["tag_number", "health_issue", "next_date"]'),
  ('Low Stock Alert', 'inventory_alert', 'sms', NULL, 'Stock Alert: {{item_name}} is running low. Current stock: {{current_stock}} {{unit}}. Minimum: {{min_stock}} {{unit}}.', '["item_name", "current_stock", "min_stock", "unit"]');

-- =====================================================
-- SETUP COMPLETE!
-- =====================================================
-- Next steps:
-- 1. Go to your Supabase dashboard
-- 2. Navigate to SQL Editor
-- 3. Paste this entire file and run it
-- 4. Then start your app with npm run dev
-- =====================================================

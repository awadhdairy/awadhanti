-- =====================================================
-- COMPLETE DATABASE FIX + DUMMY DATA FOR AWADH DAIRY
-- =====================================================
-- Run this ONCE in Supabase SQL Editor
-- Safe to run multiple times
-- =====================================================

-- =====================================================
-- PART 1: ADD MISSING COLUMNS
-- =====================================================

-- Add sire_id column to cattle (father reference)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_schema = 'public' 
                 AND table_name = 'cattle' 
                 AND column_name = 'sire_id') THEN
    ALTER TABLE public.cattle ADD COLUMN sire_id UUID REFERENCES public.cattle(id);
  END IF;
END $$;

-- Add dam_id column to cattle (mother reference)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_schema = 'public' 
                 AND table_name = 'cattle' 
                 AND column_name = 'dam_id') THEN
    ALTER TABLE public.cattle ADD COLUMN dam_id UUID REFERENCES public.cattle(id);
  END IF;
END $$;

-- =====================================================
-- PART 2: CREATE/RECREATE PROFILES_SAFE VIEW
-- =====================================================

DROP VIEW IF EXISTS public.profiles_safe;

CREATE VIEW public.profiles_safe AS
SELECT 
  id, 
  full_name, 
  phone, 
  role, 
  avatar_url, 
  is_active, 
  created_at, 
  updated_at
FROM public.profiles;

GRANT SELECT ON public.profiles_safe TO authenticated;
GRANT SELECT ON public.profiles_safe TO anon;

-- =====================================================
-- PART 3: DROP AND CREATE ALL RLS POLICIES
-- =====================================================

-- Drop all existing policies first
DO $$
DECLARE
  tbl TEXT;
  pol RECORD;
BEGIN
  FOR pol IN (SELECT policyname, tablename FROM pg_policies WHERE schemaname = 'public') LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', pol.policyname, pol.tablename);
  END LOOP;
END $$;

-- Create permissive policies for all tables
DO $$
DECLARE
  tbl TEXT;
  tables TEXT[] := ARRAY[
    'profiles', 'user_roles', 'cattle', 'milk_production', 'products', 'customers',
    'customer_products', 'customer_accounts', 'customer_vacations', 'customer_ledger',
    'routes', 'route_stops', 'deliveries', 'delivery_items', 'invoices', 'payments',
    'bottles', 'customer_bottles', 'bottle_transactions', 'cattle_health', 'breeding_records',
    'feed_inventory', 'feed_consumption', 'employees', 'shifts', 'employee_shifts',
    'attendance', 'payroll_records', 'equipment', 'maintenance_records', 'expenses',
    'price_rules', 'dairy_settings', 'notification_templates', 'notification_logs',
    'activity_logs', 'auth_attempts', 'customer_auth_attempts'
  ];
BEGIN
  FOREACH tbl IN ARRAY tables LOOP
    BEGIN
      EXECUTE format('CREATE POLICY "Enable all for %s" ON public.%I FOR ALL USING (true) WITH CHECK (true)', tbl, tbl);
    EXCEPTION WHEN OTHERS THEN
      -- Policy might already exist or table doesn't exist
      NULL;
    END;
  END LOOP;
END $$;

-- =====================================================
-- PART 4: INSERT DUMMY DATA FOR ALL SEGMENTS
-- =====================================================

-- 4.1: ROUTES (must come before customers)
INSERT INTO public.routes (id, name, description, distance_km, is_active)
VALUES 
  ('11111111-1111-1111-1111-111111111111', 'Route A - City Center', 'Main city center delivery route', 15.5, true),
  ('22222222-2222-2222-2222-222222222222', 'Route B - Industrial Area', 'Industrial zone delivery', 22.0, true),
  ('33333333-3333-3333-3333-333333333333', 'Route C - Residential', 'Residential area delivery', 18.5, true)
ON CONFLICT DO NOTHING;

-- 4.2: PRODUCTS
INSERT INTO public.products (id, name, category, unit, base_price, tax_percentage, is_active)
VALUES 
  ('aaaa1111-1111-1111-1111-111111111111', 'Full Cream Milk', 'milk', 'liter', 60.00, 0, true),
  ('aaaa2222-2222-2222-2222-222222222222', 'Toned Milk', 'milk', 'liter', 50.00, 0, true),
  ('aaaa3333-3333-3333-3333-333333333333', 'Curd', 'dairy', 'kg', 70.00, 0, true),
  ('aaaa4444-4444-4444-4444-444444444444', 'Paneer', 'dairy', 'kg', 350.00, 5, true),
  ('aaaa5555-5555-5555-5555-555555555555', 'Ghee', 'dairy', 'liter', 600.00, 5, true),
  ('aaaa6666-6666-6666-6666-666666666666', 'Butter', 'dairy', 'kg', 500.00, 5, true)
ON CONFLICT DO NOTHING;

-- 4.3: CATTLE
INSERT INTO public.cattle (id, tag_number, name, breed, cattle_type, date_of_birth, weight, status, lactation_status, lactation_number)
VALUES 
  ('bbbb1111-1111-1111-1111-111111111111', 'CAT-001', 'Lakshmi', 'Gir', 'cow', '2020-03-15', 450.5, 'active', 'lactating', 3),
  ('bbbb2222-2222-2222-2222-222222222222', 'CAT-002', 'Gauri', 'Sahiwal', 'cow', '2019-08-20', 420.0, 'active', 'lactating', 4),
  ('bbbb3333-3333-3333-3333-333333333333', 'CAT-003', 'Kamdhenu', 'Jersey', 'cow', '2021-01-10', 380.0, 'active', 'dry', 2),
  ('bbbb4444-4444-4444-4444-444444444444', 'CAT-004', 'Nandini', 'HF', 'cow', '2018-05-25', 520.0, 'active', 'pregnant', 5),
  ('bbbb5555-5555-5555-5555-555555555555', 'CAT-005', 'Raja', 'Gir', 'bull', '2017-11-12', 650.0, 'active', 'dry', 0),
  ('bbbb6666-6666-6666-6666-666666666666', 'CAT-006', 'Heera', 'Sahiwal', 'heifer', '2023-02-28', 180.0, 'active', 'dry', 0)
ON CONFLICT (tag_number) DO NOTHING;

-- 4.4: MILK PRODUCTION
INSERT INTO public.milk_production (cattle_id, production_date, session, quantity_liters, fat_percentage, snf_percentage)
VALUES 
  ('bbbb1111-1111-1111-1111-111111111111', CURRENT_DATE, 'morning', 12.5, 4.2, 8.5),
  ('bbbb1111-1111-1111-1111-111111111111', CURRENT_DATE, 'evening', 10.0, 4.0, 8.3),
  ('bbbb2222-2222-2222-2222-222222222222', CURRENT_DATE, 'morning', 15.0, 4.5, 8.7),
  ('bbbb2222-2222-2222-2222-222222222222', CURRENT_DATE, 'evening', 12.0, 4.3, 8.5),
  ('bbbb1111-1111-1111-1111-111111111111', CURRENT_DATE - 1, 'morning', 11.5, 4.1, 8.4),
  ('bbbb1111-1111-1111-1111-111111111111', CURRENT_DATE - 1, 'evening', 9.5, 4.0, 8.2),
  ('bbbb2222-2222-2222-2222-222222222222', CURRENT_DATE - 1, 'morning', 14.0, 4.4, 8.6),
  ('bbbb2222-2222-2222-2222-222222222222', CURRENT_DATE - 1, 'evening', 11.0, 4.2, 8.4)
ON CONFLICT (cattle_id, production_date, session) DO NOTHING;

-- 4.5: CUSTOMERS
INSERT INTO public.customers (id, name, phone, email, address, area, route_id, subscription_type, is_active)
VALUES 
  ('cccc1111-1111-1111-1111-111111111111', 'Rajesh Kumar', '9876543210', 'rajesh@email.com', '123 Main Street, Block A', 'City Center', '11111111-1111-1111-1111-111111111111', 'daily', true),
  ('cccc2222-2222-2222-2222-222222222222', 'Priya Sharma', '9876543211', 'priya@email.com', '45 Park Avenue', 'City Center', '11111111-1111-1111-1111-111111111111', 'daily', true),
  ('cccc3333-3333-3333-3333-333333333333', 'Hotel Grand Palace', '9876543212', 'hotel@email.com', 'Industrial Road 5', 'Industrial Area', '22222222-2222-2222-2222-222222222222', 'daily', true),
  ('cccc4444-4444-4444-4444-444444444444', 'Anita Verma', '9876543213', 'anita@email.com', '78 Rose Colony', 'Residential', '33333333-3333-3333-3333-333333333333', 'alternate', true),
  ('cccc5555-5555-5555-5555-555555555555', 'Sweet Shop Mithai', '9876543214', 'sweets@email.com', 'Market Road 12', 'City Center', '11111111-1111-1111-1111-111111111111', 'daily', true)
ON CONFLICT DO NOTHING;

-- 4.6: CUSTOMER PRODUCT SUBSCRIPTIONS
INSERT INTO public.customer_products (customer_id, product_id, quantity, is_active)
VALUES 
  ('cccc1111-1111-1111-1111-111111111111', 'aaaa1111-1111-1111-1111-111111111111', 2.0, true),
  ('cccc1111-1111-1111-1111-111111111111', 'aaaa3333-3333-3333-3333-333333333333', 0.5, true),
  ('cccc2222-2222-2222-2222-222222222222', 'aaaa2222-2222-2222-2222-222222222222', 1.5, true),
  ('cccc3333-3333-3333-3333-333333333333', 'aaaa1111-1111-1111-1111-111111111111', 20.0, true),
  ('cccc3333-3333-3333-3333-333333333333', 'aaaa4444-4444-4444-4444-444444444444', 2.0, true),
  ('cccc4444-4444-4444-4444-444444444444', 'aaaa1111-1111-1111-1111-111111111111', 1.0, true),
  ('cccc5555-5555-5555-5555-555555555555', 'aaaa1111-1111-1111-1111-111111111111', 15.0, true),
  ('cccc5555-5555-5555-5555-555555555555', 'aaaa5555-5555-5555-5555-555555555555', 1.0, true)
ON CONFLICT (customer_id, product_id) DO NOTHING;

-- 4.7: DELIVERIES
INSERT INTO public.deliveries (id, customer_id, delivery_date, status)
VALUES 
  ('dddd1111-1111-1111-1111-111111111111', 'cccc1111-1111-1111-1111-111111111111', CURRENT_DATE, 'delivered'),
  ('dddd2222-2222-2222-2222-222222222222', 'cccc2222-2222-2222-2222-222222222222', CURRENT_DATE, 'delivered'),
  ('dddd3333-3333-3333-3333-333333333333', 'cccc3333-3333-3333-3333-333333333333', CURRENT_DATE, 'pending'),
  ('dddd4444-4444-4444-4444-444444444444', 'cccc4444-4444-4444-4444-444444444444', CURRENT_DATE, 'pending')
ON CONFLICT (customer_id, delivery_date) DO NOTHING;

-- 4.8: DELIVERY ITEMS
INSERT INTO public.delivery_items (delivery_id, product_id, quantity, unit_price, total_amount)
VALUES 
  ('dddd1111-1111-1111-1111-111111111111', 'aaaa1111-1111-1111-1111-111111111111', 2.0, 60.00, 120.00),
  ('dddd1111-1111-1111-1111-111111111111', 'aaaa3333-3333-3333-3333-333333333333', 0.5, 70.00, 35.00),
  ('dddd2222-2222-2222-2222-222222222222', 'aaaa2222-2222-2222-2222-222222222222', 1.5, 50.00, 75.00),
  ('dddd3333-3333-3333-3333-333333333333', 'aaaa1111-1111-1111-1111-111111111111', 20.0, 60.00, 1200.00)
ON CONFLICT DO NOTHING;

-- 4.9: INVOICES
INSERT INTO public.invoices (id, invoice_number, customer_id, billing_period_start, billing_period_end, total_amount, final_amount, paid_amount, payment_status)
VALUES 
  ('eeee1111-1111-1111-1111-111111111111', 'INV-2026-001', 'cccc1111-1111-1111-1111-111111111111', CURRENT_DATE - 30, CURRENT_DATE - 1, 4650.00, 4650.00, 4650.00, 'paid'),
  ('eeee2222-2222-2222-2222-222222222222', 'INV-2026-002', 'cccc2222-2222-2222-2222-222222222222', CURRENT_DATE - 30, CURRENT_DATE - 1, 2250.00, 2250.00, 1500.00, 'partial'),
  ('eeee3333-3333-3333-3333-333333333333', 'INV-2026-003', 'cccc3333-3333-3333-3333-333333333333', CURRENT_DATE - 30, CURRENT_DATE - 1, 45000.00, 45000.00, 0, 'pending')
ON CONFLICT (invoice_number) DO NOTHING;

-- 4.10: PAYMENTS
INSERT INTO public.payments (customer_id, invoice_id, amount, payment_mode, payment_date)
VALUES 
  ('cccc1111-1111-1111-1111-111111111111', 'eeee1111-1111-1111-1111-111111111111', 4650.00, 'upi', CURRENT_DATE - 5),
  ('cccc2222-2222-2222-2222-222222222222', 'eeee2222-2222-2222-2222-222222222222', 1500.00, 'cash', CURRENT_DATE - 3)
ON CONFLICT DO NOTHING;

-- 4.11: BOTTLES
INSERT INTO public.bottles (id, bottle_type, size, total_quantity, available_quantity, deposit_amount)
VALUES 
  ('ffff1111-1111-1111-1111-111111111111', 'glass', '500ml', 200, 150, 20.00),
  ('ffff2222-2222-2222-2222-222222222222', 'glass', '1liter', 300, 220, 30.00),
  ('ffff3333-3333-3333-3333-333333333333', 'plastic', '500ml', 500, 450, 10.00),
  ('ffff4444-4444-4444-4444-444444444444', 'plastic', '1liter', 400, 350, 15.00)
ON CONFLICT (bottle_type, size) DO NOTHING;

-- 4.12: CUSTOMER BOTTLES
INSERT INTO public.customer_bottles (customer_id, bottle_id, quantity_pending)
VALUES 
  ('cccc1111-1111-1111-1111-111111111111', 'ffff2222-2222-2222-2222-222222222222', 5),
  ('cccc2222-2222-2222-2222-222222222222', 'ffff2222-2222-2222-2222-222222222222', 3),
  ('cccc3333-3333-3333-3333-333333333333', 'ffff4444-4444-4444-4444-444444444444', 25)
ON CONFLICT (customer_id, bottle_id) DO NOTHING;

-- 4.13: CATTLE HEALTH RECORDS
INSERT INTO public.cattle_health (cattle_id, record_date, record_type, title, description, vet_name, cost, next_due_date)
VALUES 
  ('bbbb1111-1111-1111-1111-111111111111', CURRENT_DATE - 30, 'vaccination', 'FMD Vaccination', 'Foot and Mouth Disease vaccination completed', 'Dr. Ramesh', 250.00, CURRENT_DATE + 150),
  ('bbbb2222-2222-2222-2222-222222222222', CURRENT_DATE - 45, 'vaccination', 'Brucellosis Vaccine', 'Annual brucellosis vaccination', 'Dr. Ramesh', 300.00, CURRENT_DATE + 320),
  ('bbbb3333-3333-3333-3333-333333333333', CURRENT_DATE - 10, 'checkup', 'Regular Health Checkup', 'General health checkup - all normal', 'Dr. Suresh', 500.00, CURRENT_DATE + 80),
  ('bbbb4444-4444-4444-4444-444444444444', CURRENT_DATE - 7, 'treatment', 'Mastitis Treatment', 'Treatment for mild mastitis - recovered', 'Dr. Ramesh', 1500.00, NULL),
  ('bbbb1111-1111-1111-1111-111111111111', CURRENT_DATE - 60, 'deworming', 'Deworming', 'Quarterly deworming completed', 'Dr. Suresh', 150.00, CURRENT_DATE + 30)
ON CONFLICT DO NOTHING;

-- 4.14: BREEDING RECORDS
INSERT INTO public.breeding_records (cattle_id, record_type, record_date, heat_cycle_day, insemination_bull, pregnancy_confirmed, expected_calving_date, notes)
VALUES 
  ('bbbb1111-1111-1111-1111-111111111111', 'heat_detection', CURRENT_DATE - 60, 1, NULL, NULL, NULL, 'Strong heat signs observed'),
  ('bbbb1111-1111-1111-1111-111111111111', 'artificial_insemination', CURRENT_DATE - 59, NULL, 'Gir Bull G-101', NULL, CURRENT_DATE + 224, 'AI performed successfully'),
  ('bbbb1111-1111-1111-1111-111111111111', 'pregnancy_check', CURRENT_DATE - 20, NULL, NULL, true, CURRENT_DATE + 224, 'Pregnancy confirmed by ultrasound'),
  ('bbbb4444-4444-4444-4444-444444444444', 'heat_detection', CURRENT_DATE - 120, 1, NULL, NULL, NULL, 'Heat detected'),
  ('bbbb4444-4444-4444-4444-444444444444', 'artificial_insemination', CURRENT_DATE - 119, NULL, 'HF Bull H-205', NULL, CURRENT_DATE + 164, 'AI performed'),
  ('bbbb4444-4444-4444-4444-444444444444', 'pregnancy_check', CURRENT_DATE - 60, NULL, NULL, true, CURRENT_DATE + 164, 'Confirmed pregnant')
ON CONFLICT DO NOTHING;

-- 4.15: FEED INVENTORY
INSERT INTO public.feed_inventory (id, name, category, unit, current_stock, min_stock_level, cost_per_unit, supplier)
VALUES 
  ('gggg1111-1111-1111-1111-111111111111', 'Green Fodder', 'fodder', 'kg', 2500.00, 500.00, 5.00, 'Local Farm'),
  ('gggg2222-2222-2222-2222-222222222222', 'Dry Hay', 'fodder', 'kg', 1800.00, 300.00, 8.00, 'Agri Suppliers'),
  ('gggg3333-3333-3333-3333-333333333333', 'Cattle Feed Mix', 'concentrate', 'kg', 500.00, 100.00, 35.00, 'Amul Feeds'),
  ('gggg4444-4444-4444-4444-444444444444', 'Mineral Mix', 'supplement', 'kg', 50.00, 10.00, 120.00, 'Vet Pharma'),
  ('gggg5555-5555-5555-5555-555555555555', 'Oil Cake', 'concentrate', 'kg', 300.00, 50.00, 45.00, 'Oil Mills'),
  ('gggg6666-6666-6666-6666-666666666666', 'Salt Lick', 'supplement', 'piece', 20.00, 5.00, 80.00, 'Vet Pharma')
ON CONFLICT DO NOTHING;

-- 4.16: FEED CONSUMPTION
INSERT INTO public.feed_consumption (feed_id, cattle_id, consumption_date, quantity)
VALUES 
  ('gggg1111-1111-1111-1111-111111111111', 'bbbb1111-1111-1111-1111-111111111111', CURRENT_DATE, 25.0),
  ('gggg2222-2222-2222-2222-222222222222', 'bbbb1111-1111-1111-1111-111111111111', CURRENT_DATE, 5.0),
  ('gggg3333-3333-3333-3333-333333333333', 'bbbb1111-1111-1111-1111-111111111111', CURRENT_DATE, 3.0),
  ('gggg1111-1111-1111-1111-111111111111', 'bbbb2222-2222-2222-2222-222222222222', CURRENT_DATE, 25.0),
  ('gggg3333-3333-3333-3333-333333333333', 'bbbb2222-2222-2222-2222-222222222222', CURRENT_DATE, 4.0)
ON CONFLICT DO NOTHING;

-- 4.17: EMPLOYEES
INSERT INTO public.employees (id, name, phone, address, role, salary, joining_date, is_active)
VALUES 
  ('hhhh1111-1111-1111-1111-111111111111', 'Ramesh Singh', '9988776655', 'Village Bharatpur', 'farm_worker', 15000.00, '2022-01-15', true),
  ('hhhh2222-2222-2222-2222-222222222222', 'Sunil Kumar', '9988776656', 'Village Jhunjhunu', 'delivery_staff', 12000.00, '2021-06-01', true),
  ('hhhh3333-3333-3333-3333-333333333333', 'Meena Devi', '9988776657', 'City Area', 'accountant', 20000.00, '2020-03-10', true),
  ('hhhh4444-4444-4444-4444-444444444444', 'Gopal Sharma', '9988776658', 'Village Sikar', 'farm_worker', 14000.00, '2023-02-20', true)
ON CONFLICT DO NOTHING;

-- 4.18: SHIFTS
INSERT INTO public.shifts (id, name, start_time, end_time, is_active)
VALUES 
  ('iiii1111-1111-1111-1111-111111111111', 'Morning Shift', '05:00:00', '13:00:00', true),
  ('iiii2222-2222-2222-2222-222222222222', 'Evening Shift', '13:00:00', '21:00:00', true),
  ('iiii3333-3333-3333-3333-333333333333', 'Night Shift', '21:00:00', '05:00:00', true)
ON CONFLICT DO NOTHING;

-- 4.19: EMPLOYEE SHIFTS
INSERT INTO public.employee_shifts (employee_id, shift_id, effective_from)
VALUES 
  ('hhhh1111-1111-1111-1111-111111111111', 'iiii1111-1111-1111-1111-111111111111', '2024-01-01'),
  ('hhhh2222-2222-2222-2222-222222222222', 'iiii1111-1111-1111-1111-111111111111', '2024-01-01'),
  ('hhhh4444-4444-4444-4444-444444444444', 'iiii2222-2222-2222-2222-222222222222', '2024-01-01')
ON CONFLICT DO NOTHING;

-- 4.20: ATTENDANCE
INSERT INTO public.attendance (employee_id, attendance_date, check_in, check_out, status)
VALUES 
  ('hhhh1111-1111-1111-1111-111111111111', CURRENT_DATE, '05:15:00', '13:10:00', 'present'),
  ('hhhh2222-2222-2222-2222-222222222222', CURRENT_DATE, '05:30:00', NULL, 'present'),
  ('hhhh3333-3333-3333-3333-333333333333', CURRENT_DATE, '09:00:00', '18:00:00', 'present'),
  ('hhhh4444-4444-4444-4444-444444444444', CURRENT_DATE, '13:05:00', NULL, 'present'),
  ('hhhh1111-1111-1111-1111-111111111111', CURRENT_DATE - 1, '05:10:00', '13:05:00', 'present'),
  ('hhhh2222-2222-2222-2222-222222222222', CURRENT_DATE - 1, '05:20:00', '13:30:00', 'present')
ON CONFLICT (employee_id, attendance_date) DO NOTHING;

-- 4.21: EQUIPMENT
INSERT INTO public.equipment (id, name, category, model, purchase_date, purchase_cost, status, location)
VALUES 
  ('jjjj1111-1111-1111-1111-111111111111', 'Milking Machine', 'milking', 'DeLaval VMS', '2022-05-15', 250000.00, 'active', 'Milking Parlor'),
  ('jjjj2222-2222-2222-2222-222222222222', 'Bulk Milk Cooler', 'storage', 'BMC-500L', '2021-08-20', 180000.00, 'active', 'Milk Storage'),
  ('jjjj3333-3333-3333-3333-333333333333', 'Fodder Cutter', 'feeding', 'Chaff Cutter Pro', '2023-01-10', 45000.00, 'active', 'Feed Storage'),
  ('jjjj4444-4444-4444-4444-444444444444', 'Generator', 'power', 'Mahindra 25kVA', '2020-03-25', 150000.00, 'maintenance', 'Power Room'),
  ('jjjj5555-5555-5555-5555-555555555555', 'Delivery Van', 'transport', 'Tata Ace', '2022-11-01', 450000.00, 'active', 'Vehicle Shed')
ON CONFLICT DO NOTHING;

-- 4.22: MAINTENANCE RECORDS
INSERT INTO public.maintenance_records (equipment_id, maintenance_type, maintenance_date, description, cost, performed_by, next_maintenance_date)
VALUES 
  ('jjjj1111-1111-1111-1111-111111111111', 'preventive', CURRENT_DATE - 30, 'Regular servicing and cleaning', 5000.00, 'DeLaval Service', CURRENT_DATE + 60),
  ('jjjj2222-2222-2222-2222-222222222222', 'preventive', CURRENT_DATE - 45, 'Compressor check and gas refill', 8000.00, 'Cooling Experts', CURRENT_DATE + 45),
  ('jjjj4444-4444-4444-4444-444444444444', 'repair', CURRENT_DATE - 5, 'Engine oil change and filter replacement', 3500.00, 'Local Mechanic', CURRENT_DATE + 85),
  ('jjjj5555-5555-5555-5555-555555555555', 'preventive', CURRENT_DATE - 15, 'Full vehicle service', 7500.00, 'Tata Service Center', CURRENT_DATE + 75)
ON CONFLICT DO NOTHING;

-- 4.23: EXPENSES
INSERT INTO public.expenses (category, title, amount, expense_date, notes)
VALUES 
  ('feed', 'Monthly Cattle Feed Purchase', 25000.00, CURRENT_DATE - 5, 'Bulk feed purchase from Amul Feeds'),
  ('veterinary', 'Vaccination Camp', 5000.00, CURRENT_DATE - 10, 'FMD vaccination for all cattle'),
  ('maintenance', 'Milking Machine Service', 5000.00, CURRENT_DATE - 30, 'Regular maintenance'),
  ('fuel', 'Diesel for Generator', 3500.00, CURRENT_DATE - 3, 'Monthly diesel purchase'),
  ('utilities', 'Electricity Bill', 12000.00, CURRENT_DATE - 15, 'Monthly electricity'),
  ('salary', 'Staff Salary - January', 61000.00, CURRENT_DATE - 2, 'Monthly salaries'),
  ('transport', 'Vehicle Fuel', 8000.00, CURRENT_DATE - 7, 'Weekly fuel for delivery van'),
  ('supplies', 'Cleaning Supplies', 2500.00, CURRENT_DATE - 12, 'Detergents and brushes')
ON CONFLICT DO NOTHING;

-- 4.24: ROUTE STOPS
INSERT INTO public.route_stops (route_id, customer_id, stop_order, estimated_arrival_time)
VALUES 
  ('11111111-1111-1111-1111-111111111111', 'cccc1111-1111-1111-1111-111111111111', 1, '06:00:00'),
  ('11111111-1111-1111-1111-111111111111', 'cccc2222-2222-2222-2222-222222222222', 2, '06:15:00'),
  ('11111111-1111-1111-1111-111111111111', 'cccc5555-5555-5555-5555-555555555555', 3, '06:30:00'),
  ('22222222-2222-2222-2222-222222222222', 'cccc3333-3333-3333-3333-333333333333', 1, '06:00:00'),
  ('33333333-3333-3333-3333-333333333333', 'cccc4444-4444-4444-4444-444444444444', 1, '06:30:00')
ON CONFLICT DO NOTHING;

-- 4.25: PRICE RULES
INSERT INTO public.price_rules (name, product_id, min_fat_percentage, max_fat_percentage, price_adjustment, adjustment_type, is_active)
VALUES 
  ('High Fat Premium', 'aaaa1111-1111-1111-1111-111111111111', 4.5, 6.0, 5.00, 'fixed', true),
  ('Low Fat Discount', 'aaaa1111-1111-1111-1111-111111111111', 3.0, 3.5, -3.00, 'fixed', true),
  ('Premium SNF Bonus', 'aaaa1111-1111-1111-1111-111111111111', NULL, NULL, 2.00, 'fixed', true)
ON CONFLICT DO NOTHING;

-- 4.26: DAIRY SETTINGS
INSERT INTO public.dairy_settings (key, value, description)
VALUES 
  ('dairy_name', 'Awadh Dairy', 'Name of the dairy'),
  ('dairy_address', 'Village Khairabad, District Ayodhya, UP', 'Dairy address'),
  ('dairy_phone', '+91 9876543210', 'Contact number'),
  ('default_milk_rate', '60', 'Default rate per liter'),
  ('gst_number', 'GSTIN09AAACW1234L1ZD', 'GST registration number'),
  ('invoice_prefix', 'INV', 'Prefix for invoice numbers'),
  ('delivery_start_time', '05:00', 'Default delivery start time'),
  ('milk_collection_sessions', '["morning", "evening"]', 'Available milk collection sessions')
ON CONFLICT (key) DO NOTHING;

-- =====================================================
-- PART 5: VERIFY DATA
-- =====================================================

SELECT 'DATA SUMMARY' as section, '' as details
UNION ALL SELECT 'Cattle', (SELECT COUNT(*)::TEXT FROM public.cattle)
UNION ALL SELECT 'Milk Production', (SELECT COUNT(*)::TEXT FROM public.milk_production)
UNION ALL SELECT 'Customers', (SELECT COUNT(*)::TEXT FROM public.customers)
UNION ALL SELECT 'Products', (SELECT COUNT(*)::TEXT FROM public.products)
UNION ALL SELECT 'Routes', (SELECT COUNT(*)::TEXT FROM public.routes)
UNION ALL SELECT 'Deliveries', (SELECT COUNT(*)::TEXT FROM public.deliveries)
UNION ALL SELECT 'Invoices', (SELECT COUNT(*)::TEXT FROM public.invoices)
UNION ALL SELECT 'Employees', (SELECT COUNT(*)::TEXT FROM public.employees)
UNION ALL SELECT 'Feed Items', (SELECT COUNT(*)::TEXT FROM public.feed_inventory)
UNION ALL SELECT 'Equipment', (SELECT COUNT(*)::TEXT FROM public.equipment)
UNION ALL SELECT 'Cattle Health', (SELECT COUNT(*)::TEXT FROM public.cattle_health)
UNION ALL SELECT 'Breeding Records', (SELECT COUNT(*)::TEXT FROM public.breeding_records)
UNION ALL SELECT 'Expenses', (SELECT COUNT(*)::TEXT FROM public.expenses)
UNION ALL SELECT '✅ ALL DONE!', 'Refresh your app now';

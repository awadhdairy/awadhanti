-- =====================================================
-- RLS POLICIES - Run this in Supabase SQL Editor
-- This adds the missing RLS policies for all tables
-- =====================================================

-- Profiles policies
CREATE POLICY "Service role full access to profiles" ON public.profiles
  FOR ALL USING (true) WITH CHECK (true);

CREATE POLICY "Users can read own profile" ON public.profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON public.profiles
  FOR UPDATE USING (auth.uid() = id);

-- User roles policies  
CREATE POLICY "Service role full access to user_roles" ON public.user_roles
  FOR ALL USING (true) WITH CHECK (true);

CREATE POLICY "Users can read own role" ON public.user_roles
  FOR SELECT USING (auth.uid() = user_id);

-- Cattle policies
CREATE POLICY "Authenticated users can read cattle" ON public.cattle
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can insert cattle" ON public.cattle
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can update cattle" ON public.cattle
  FOR UPDATE USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can delete cattle" ON public.cattle
  FOR DELETE USING (auth.uid() IS NOT NULL);

-- Customers policies
CREATE POLICY "Authenticated users can read customers" ON public.customers
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can insert customers" ON public.customers
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can update customers" ON public.customers
  FOR UPDATE USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can delete customers" ON public.customers
  FOR DELETE USING (auth.uid() IS NOT NULL);

-- Products policies
CREATE POLICY "Authenticated users can read products" ON public.products
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can insert products" ON public.products
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can update products" ON public.products
  FOR UPDATE USING (auth.uid() IS NOT NULL);

-- Deliveries policies
CREATE POLICY "Authenticated users can read deliveries" ON public.deliveries
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can insert deliveries" ON public.deliveries
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can update deliveries" ON public.deliveries
  FOR UPDATE USING (auth.uid() IS NOT NULL);

-- Delivery items policies
CREATE POLICY "Authenticated users can read delivery_items" ON public.delivery_items
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can insert delivery_items" ON public.delivery_items
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- Milk production policies
CREATE POLICY "Authenticated users can read milk_production" ON public.milk_production
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can insert milk_production" ON public.milk_production
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can update milk_production" ON public.milk_production
  FOR UPDATE USING (auth.uid() IS NOT NULL);

-- Routes policies
CREATE POLICY "Authenticated users can read routes" ON public.routes
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can manage routes" ON public.routes
  FOR ALL USING (auth.uid() IS NOT NULL);

-- Route stops policies
CREATE POLICY "Authenticated users can read route_stops" ON public.route_stops
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can manage route_stops" ON public.route_stops
  FOR ALL USING (auth.uid() IS NOT NULL);

-- Invoices policies
CREATE POLICY "Authenticated users can read invoices" ON public.invoices
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can manage invoices" ON public.invoices
  FOR ALL USING (auth.uid() IS NOT NULL);

-- Payments policies
CREATE POLICY "Authenticated users can read payments" ON public.payments
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can manage payments" ON public.payments
  FOR ALL USING (auth.uid() IS NOT NULL);

-- Employees policies
CREATE POLICY "Authenticated users can read employees" ON public.employees
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can manage employees" ON public.employees
  FOR ALL USING (auth.uid() IS NOT NULL);

-- Attendance policies
CREATE POLICY "Authenticated users can read attendance" ON public.attendance
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can manage attendance" ON public.attendance
  FOR ALL USING (auth.uid() IS NOT NULL);

-- Cattle health policies
CREATE POLICY "Authenticated users can read cattle_health" ON public.cattle_health
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can manage cattle_health" ON public.cattle_health
  FOR ALL USING (auth.uid() IS NOT NULL);

-- Expenses policies
CREATE POLICY "Authenticated users can read expenses" ON public.expenses
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can manage expenses" ON public.expenses
  FOR ALL USING (auth.uid() IS NOT NULL);

-- Bottles policies
CREATE POLICY "Authenticated users can read bottles" ON public.bottles
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can manage bottles" ON public.bottles
  FOR ALL USING (auth.uid() IS NOT NULL);

-- Customer bottles policies
CREATE POLICY "Authenticated users can read customer_bottles" ON public.customer_bottles
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can manage customer_bottles" ON public.customer_bottles
  FOR ALL USING (auth.uid() IS NOT NULL);

-- Bottle transactions policies
CREATE POLICY "Authenticated users can read bottle_transactions" ON public.bottle_transactions
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can manage bottle_transactions" ON public.bottle_transactions
  FOR ALL USING (auth.uid() IS NOT NULL);

-- Customer products policies
CREATE POLICY "Authenticated users can read customer_products" ON public.customer_products
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can manage customer_products" ON public.customer_products
  FOR ALL USING (auth.uid() IS NOT NULL);

-- Customer accounts policies
CREATE POLICY "Authenticated users can read customer_accounts" ON public.customer_accounts
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can manage customer_accounts" ON public.customer_accounts
  FOR ALL USING (auth.uid() IS NOT NULL);

-- Customer vacations policies
CREATE POLICY "Authenticated users can read customer_vacations" ON public.customer_vacations
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can manage customer_vacations" ON public.customer_vacations
  FOR ALL USING (auth.uid() IS NOT NULL);

-- Customer ledger policies
CREATE POLICY "Authenticated users can read customer_ledger" ON public.customer_ledger
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can manage customer_ledger" ON public.customer_ledger
  FOR ALL USING (auth.uid() IS NOT NULL);

-- Feed inventory policies
CREATE POLICY "Authenticated users can read feed_inventory" ON public.feed_inventory
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can manage feed_inventory" ON public.feed_inventory
  FOR ALL USING (auth.uid() IS NOT NULL);

-- Feed consumption policies
CREATE POLICY "Authenticated users can read feed_consumption" ON public.feed_consumption
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can manage feed_consumption" ON public.feed_consumption
  FOR ALL USING (auth.uid() IS NOT NULL);

-- Breeding records policies
CREATE POLICY "Authenticated users can read breeding_records" ON public.breeding_records
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can manage breeding_records" ON public.breeding_records
  FOR ALL USING (auth.uid() IS NOT NULL);

-- Shifts policies
CREATE POLICY "Authenticated users can read shifts" ON public.shifts
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can manage shifts" ON public.shifts
  FOR ALL USING (auth.uid() IS NOT NULL);

-- Employee shifts policies
CREATE POLICY "Authenticated users can read employee_shifts" ON public.employee_shifts
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can manage employee_shifts" ON public.employee_shifts
  FOR ALL USING (auth.uid() IS NOT NULL);

-- Payroll records policies
CREATE POLICY "Authenticated users can read payroll_records" ON public.payroll_records
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can manage payroll_records" ON public.payroll_records
  FOR ALL USING (auth.uid() IS NOT NULL);

-- Equipment policies
CREATE POLICY "Authenticated users can read equipment" ON public.equipment
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can manage equipment" ON public.equipment
  FOR ALL USING (auth.uid() IS NOT NULL);

-- Maintenance records policies
CREATE POLICY "Authenticated users can read maintenance_records" ON public.maintenance_records
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can manage maintenance_records" ON public.maintenance_records
  FOR ALL USING (auth.uid() IS NOT NULL);

-- Price rules policies
CREATE POLICY "Authenticated users can read price_rules" ON public.price_rules
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can manage price_rules" ON public.price_rules
  FOR ALL USING (auth.uid() IS NOT NULL);

-- Dairy settings policies
CREATE POLICY "Authenticated users can read dairy_settings" ON public.dairy_settings
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can manage dairy_settings" ON public.dairy_settings
  FOR ALL USING (auth.uid() IS NOT NULL);

-- Notification templates policies
CREATE POLICY "Authenticated users can read notification_templates" ON public.notification_templates
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can manage notification_templates" ON public.notification_templates
  FOR ALL USING (auth.uid() IS NOT NULL);

-- Notification logs policies
CREATE POLICY "Authenticated users can read notification_logs" ON public.notification_logs
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can manage notification_logs" ON public.notification_logs
  FOR ALL USING (auth.uid() IS NOT NULL);

-- Activity logs policies
CREATE POLICY "Authenticated users can read activity_logs" ON public.activity_logs
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can insert activity_logs" ON public.activity_logs
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- Auth attempts policies (public access for rate limiting)
CREATE POLICY "Anyone can read auth_attempts" ON public.auth_attempts
  FOR SELECT USING (true);

CREATE POLICY "Anyone can manage auth_attempts" ON public.auth_attempts
  FOR ALL USING (true);

-- Customer auth attempts policies
CREATE POLICY "Anyone can read customer_auth_attempts" ON public.customer_auth_attempts
  FOR SELECT USING (true);

CREATE POLICY "Anyone can manage customer_auth_attempts" ON public.customer_auth_attempts
  FOR ALL USING (true);

-- Success message
SELECT 'RLS policies created successfully!' as message;

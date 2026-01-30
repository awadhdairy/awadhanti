-- =====================================================
-- MISSING RPC FUNCTIONS FOR AWADH DAIRY
-- Run this in Supabase SQL Editor
-- =====================================================

-- 1. run_auto_delivery - Runs daily auto-delivery process
-- Called from DeliveryAutomationCard.tsx
CREATE OR REPLACE FUNCTION public.run_auto_delivery()
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  result JSONB;
  scheduled_count INT := 0;
  delivered_count INT := 0;
  skipped_count INT := 0;
  today DATE := current_date;
BEGIN
  -- Mark all pending deliveries for today as delivered
  UPDATE deliveries 
  SET status = 'delivered', 
      delivery_time = NOW(),
      updated_at = NOW()
  WHERE delivery_date = today 
    AND status = 'pending';
  
  GET DIAGNOSTICS delivered_count = ROW_COUNT;
  
  RETURN jsonb_build_object(
    'success', true,
    'date', today::text,
    'scheduled', scheduled_count,
    'delivered', delivered_count,
    'skipped', skipped_count,
    'errors', '[]'::jsonb
  );
END;
$$;

-- 2. auto_create_daily_attendance - Creates daily attendance records for employees
-- Called from useAutoAttendance.ts
CREATE OR REPLACE FUNCTION public.auto_create_daily_attendance()
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  emp RECORD;
  today DATE := current_date;
  created_count INT := 0;
  row_result INT;
BEGIN
  -- Create attendance records for all active employees if not exists
  FOR emp IN SELECT id FROM employees WHERE is_active = true LOOP
    -- Only insert if record doesn't exist for today
    INSERT INTO attendance (employee_id, attendance_date, status)
    VALUES (emp.id, today, 'present')
    ON CONFLICT (employee_id, attendance_date) DO NOTHING;
    
    GET DIAGNOSTICS row_result = ROW_COUNT;
    created_count := created_count + row_result;
  END LOOP;
  
  RETURN jsonb_build_object(
    'success', true,
    'date', today::text,
    'created', created_count
  );
END;
$$;

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION public.run_auto_delivery() TO authenticated;
GRANT EXECUTE ON FUNCTION public.auto_create_daily_attendance() TO authenticated;

-- =====================================================
-- VERIFY ATTENDANCE TABLE HAS UNIQUE CONSTRAINT
-- =====================================================
DO $$
BEGIN
  -- Add unique constraint if not exists
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'attendance_employee_date_unique'
  ) THEN
    BEGIN
      ALTER TABLE attendance 
        ADD CONSTRAINT attendance_employee_date_unique 
        UNIQUE (employee_id, attendance_date);
    EXCEPTION WHEN duplicate_table THEN
      -- Constraint may already exist with different name
      NULL;
    END;
  END IF;
END $$;

-- =====================================================
-- VERIFY RLS POLICY FOR ATTENDANCE
-- =====================================================
ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "auth_all_attendance" ON attendance;
CREATE POLICY "auth_all_attendance" ON attendance FOR ALL TO authenticated 
  USING (true) WITH CHECK (true);

SELECT '✅ Missing RPC functions created successfully!' AS status;

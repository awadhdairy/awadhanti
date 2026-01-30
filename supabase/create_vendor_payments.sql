-- ==============================================
-- Create vendor_payments table for Milk Procurement
-- Run this in Supabase SQL Editor
-- ==============================================

-- Create vendor_payments table
CREATE TABLE IF NOT EXISTS public.vendor_payments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  vendor_id UUID NOT NULL REFERENCES public.milk_vendors(id) ON DELETE CASCADE,
  payment_date DATE NOT NULL DEFAULT CURRENT_DATE,
  amount NUMERIC(12, 2) NOT NULL,
  payment_mode TEXT DEFAULT 'cash' CHECK (payment_mode IN ('cash', 'bank_transfer', 'upi', 'cheque')),
  reference_number TEXT,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by UUID REFERENCES auth.users(id)
);

-- Add index for faster lookups
CREATE INDEX IF NOT EXISTS idx_vendor_payments_vendor_id ON public.vendor_payments(vendor_id);
CREATE INDEX IF NOT EXISTS idx_vendor_payments_date ON public.vendor_payments(payment_date DESC);

-- Enable RLS
ALTER TABLE public.vendor_payments ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for authenticated users
CREATE POLICY "Allow authenticated users to read vendor_payments"
ON public.vendor_payments FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Allow authenticated users to insert vendor_payments"
ON public.vendor_payments FOR INSERT
TO authenticated
WITH CHECK (true);

CREATE POLICY "Allow authenticated users to update vendor_payments"
ON public.vendor_payments FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

CREATE POLICY "Allow authenticated users to delete vendor_payments"
ON public.vendor_payments FOR DELETE
TO authenticated
USING (true);

-- Grant permissions
GRANT ALL ON public.vendor_payments TO authenticated;
GRANT ALL ON public.vendor_payments TO service_role;

-- Add a trigger to update vendor's current_balance when payment is recorded
CREATE OR REPLACE FUNCTION update_vendor_balance_on_payment()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Decrease vendor balance when payment is made
    UPDATE public.milk_vendors
    SET current_balance = COALESCE(current_balance, 0) - NEW.amount
    WHERE id = NEW.vendor_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    -- Increase vendor balance when payment is deleted (reverse)
    UPDATE public.milk_vendors
    SET current_balance = COALESCE(current_balance, 0) + OLD.amount
    WHERE id = OLD.vendor_id;
    RETURN OLD;
  ELSIF TG_OP = 'UPDATE' THEN
    -- Adjust balance for amount difference
    UPDATE public.milk_vendors
    SET current_balance = COALESCE(current_balance, 0) + OLD.amount - NEW.amount
    WHERE id = NEW.vendor_id;
    RETURN NEW;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop trigger if exists and recreate
DROP TRIGGER IF EXISTS trigger_update_vendor_balance ON public.vendor_payments;
CREATE TRIGGER trigger_update_vendor_balance
AFTER INSERT OR UPDATE OR DELETE ON public.vendor_payments
FOR EACH ROW EXECUTE FUNCTION update_vendor_balance_on_payment();

-- Verification
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'vendor_payments') THEN
    RAISE NOTICE '✅ vendor_payments table created successfully!';
  ELSE
    RAISE NOTICE '❌ vendor_payments table creation failed!';
  END IF;
END $$;

-- =====================================================
-- CUSTOMER AUTH FUNCTIONS
-- Run this if customer login/register is not working
-- =====================================================

-- Enable pgcrypto extension for password hashing
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. verify_customer_pin - Verify customer login
CREATE OR REPLACE FUNCTION public.verify_customer_pin(_phone TEXT, _pin TEXT)
RETURNS TABLE(customer_id UUID, is_approved BOOLEAN, customer_name TEXT)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ca.customer_id,
    ca.is_approved,
    c.name AS customer_name
  FROM customer_accounts ca
  JOIN customers c ON c.id = ca.customer_id
  WHERE ca.phone = _phone 
    AND ca.pin_hash = crypt(_pin, ca.pin_hash);
END;
$$;

-- 2. register_customer_account - Register new customer account
CREATE OR REPLACE FUNCTION public.register_customer_account(_phone TEXT, _pin TEXT)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  _customer RECORD;
  _account_id UUID;
BEGIN
  -- Validate PIN format
  IF _pin IS NULL OR length(_pin) != 6 OR _pin !~ '^[0-9]+$' THEN
    RETURN jsonb_build_object('success', false, 'error', 'PIN must be 6 digits');
  END IF;

  -- Check if account already exists
  IF EXISTS (SELECT 1 FROM customer_accounts WHERE phone = _phone) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Account already exists');
  END IF;

  -- Find customer by phone
  SELECT * INTO _customer FROM customers WHERE phone = _phone AND is_active = true LIMIT 1;
  
  IF _customer IS NULL THEN
    RETURN jsonb_build_object(
      'success', false, 
      'error', 'No active customer found with this phone number. Please contact support.'
    );
  END IF;

  -- Create account (auto-approve since customer exists)
  INSERT INTO customer_accounts (customer_id, phone, pin_hash, is_approved, approval_status, approved_at)
  VALUES (
    _customer.id,
    _phone,
    crypt(_pin, gen_salt('bf')),
    true,
    'approved',
    NOW()
  )
  RETURNING id INTO _account_id;

  RETURN jsonb_build_object(
    'success', true,
    'approved', true,
    'customer_id', _customer.id,
    'customer_name', _customer.name,
    'message', 'Account created and approved'
  );
END;
$$;

-- 3. update_customer_pin - Change customer PIN
CREATE OR REPLACE FUNCTION public.update_customer_pin(_customer_id UUID, _current_pin TEXT, _new_pin TEXT)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  _account RECORD;
BEGIN
  -- Validate new PIN format
  IF _new_pin IS NULL OR length(_new_pin) != 6 OR _new_pin !~ '^[0-9]+$' THEN
    RETURN jsonb_build_object('success', false, 'error', 'New PIN must be 6 digits');
  END IF;

  -- Get account and verify current PIN
  SELECT * INTO _account FROM customer_accounts 
  WHERE customer_id = _customer_id 
    AND pin_hash = crypt(_current_pin, pin_hash);
  
  IF _account IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Current PIN is incorrect');
  END IF;

  -- Update PIN
  UPDATE customer_accounts 
  SET pin_hash = crypt(_new_pin, gen_salt('bf')), updated_at = NOW()
  WHERE id = _account.id;

  RETURN jsonb_build_object('success', true, 'message', 'PIN updated successfully');
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.verify_customer_pin(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.verify_customer_pin(TEXT, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION public.register_customer_account(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.register_customer_account(TEXT, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION public.update_customer_pin(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_customer_pin(UUID, TEXT, TEXT) TO service_role;

-- Also grant to anon for public registration
GRANT EXECUTE ON FUNCTION public.verify_customer_pin(TEXT, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION public.register_customer_account(TEXT, TEXT) TO anon;

SELECT '✅ Customer auth functions created!' AS status;

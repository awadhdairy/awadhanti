-- =====================================================
-- MISSING FUNCTIONS FOR USER CREATION
-- =====================================================
-- Run this in Supabase SQL Editor to fix user creation
-- These functions are required by the create-user API
-- =====================================================

-- Function to update only the PIN hash for a user
CREATE OR REPLACE FUNCTION public.update_pin_only(
  _user_id UUID,
  _pin TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _pin_hash TEXT;
BEGIN
  -- Hash the PIN using pgcrypto
  _pin_hash := crypt(_pin, gen_salt('bf'));
  
  -- Update the pin_hash in profiles table
  UPDATE public.profiles 
  SET pin_hash = _pin_hash, updated_at = NOW()
  WHERE id = _user_id;
  
  RETURN FOUND;
END;
$$;

-- Function to update user profile with PIN (alternative method)
CREATE OR REPLACE FUNCTION public.update_user_profile_with_pin(
  _user_id UUID,
  _full_name TEXT,
  _phone TEXT,
  _role TEXT,
  _pin TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _pin_hash TEXT;
  _user_role public.user_role;
BEGIN
  -- Hash the PIN
  _pin_hash := crypt(_pin, gen_salt('bf'));
  
  -- Cast the role string to user_role enum
  _user_role := _role::public.user_role;
  
  -- Upsert the profile
  INSERT INTO public.profiles (id, full_name, phone, pin_hash, role, is_active, created_at, updated_at)
  VALUES (_user_id, _full_name, _phone, _pin_hash, _user_role, true, NOW(), NOW())
  ON CONFLICT (id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    phone = EXCLUDED.phone,
    pin_hash = EXCLUDED.pin_hash,
    role = EXCLUDED.role,
    updated_at = NOW();
  
  RETURN TRUE;
END;
$$;

-- Function to verify PIN during login
CREATE OR REPLACE FUNCTION public.verify_pin(
  _phone TEXT,
  _pin TEXT
)
RETURNS TABLE(user_id UUID, role TEXT, full_name TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    p.role::TEXT,
    p.full_name
  FROM public.profiles p
  WHERE p.phone = _phone
    AND p.pin_hash = crypt(_pin, p.pin_hash)
    AND p.is_active = true;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION public.update_pin_only(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_pin_only(UUID, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION public.update_user_profile_with_pin(UUID, TEXT, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_user_profile_with_pin(UUID, TEXT, TEXT, TEXT, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION public.verify_pin(TEXT, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION public.verify_pin(TEXT, TEXT) TO authenticated;

-- Success message
SELECT 'User creation functions created successfully!' as status;

-- =====================================================
-- ENSURE PGCRYPTO EXTENSION IS ENABLED FIRST
-- =====================================================
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- =====================================================
-- ALL MISSING FUNCTIONS FOR USER MANAGEMENT
-- =====================================================
-- Run this in Supabase SQL Editor
-- =====================================================

-- Drop existing functions first
DROP FUNCTION IF EXISTS public.update_pin_only(UUID, TEXT);
DROP FUNCTION IF EXISTS public.update_user_profile_with_pin(UUID, TEXT, TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.verify_pin(TEXT, TEXT);
DROP FUNCTION IF EXISTS public.admin_update_user_status(UUID, BOOLEAN);
DROP FUNCTION IF EXISTS public.admin_reset_user_pin(UUID, TEXT);

-- =====================================================
-- 1. UPDATE PIN ONLY
-- =====================================================
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

-- =====================================================
-- 2. UPDATE USER PROFILE WITH PIN
-- =====================================================
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
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Error in update_user_profile_with_pin: %', SQLERRM;
  RETURN FALSE;
END;
$$;

-- =====================================================
-- 3. VERIFY PIN (for login)
-- =====================================================
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

-- =====================================================
-- 4. ADMIN UPDATE USER STATUS
-- =====================================================
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

-- =====================================================
-- 5. ADMIN RESET USER PIN
-- =====================================================
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
  -- Hash the new PIN
  _pin_hash := crypt(_new_pin, gen_salt('bf'));
  
  -- Update the pin_hash
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

-- =====================================================
-- GRANT PERMISSIONS
-- =====================================================
GRANT EXECUTE ON FUNCTION public.update_pin_only(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_pin_only(UUID, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION public.update_user_profile_with_pin(UUID, TEXT, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_user_profile_with_pin(UUID, TEXT, TEXT, TEXT, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION public.verify_pin(TEXT, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION public.verify_pin(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_user_status(UUID, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_reset_user_pin(UUID, TEXT) TO authenticated;

-- =====================================================
-- (pgcrypto extension is now enabled at the top of this file)
-- =====================================================

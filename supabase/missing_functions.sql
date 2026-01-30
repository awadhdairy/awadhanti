-- =====================================================
-- FIX MISSING FUNCTIONS - Run in Supabase SQL Editor
-- =====================================================
-- This file fixes missing database functions that were
-- causing errors in the Awadh Dairy application.
-- Run this ONCE in Supabase SQL Editor.
-- =====================================================

-- Ensure pgcrypto is enabled FIRST
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- =====================================================
-- 1. CHANGE_OWN_PIN - Self-service PIN change
-- =====================================================
-- Called by: Settings.tsx for user self-service PIN change
-- This function was MISSING and causing errors!

DROP FUNCTION IF EXISTS public.change_own_pin(TEXT, TEXT);

CREATE OR REPLACE FUNCTION public.change_own_pin(
  _current_pin TEXT,
  _new_pin TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _user_id UUID;
  _profile RECORD;
BEGIN
  -- Get the current user's ID
  _user_id := auth.uid();
  
  IF _user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;
  
  -- Validate new PIN format (must be exactly 6 digits)
  IF _new_pin IS NULL OR length(_new_pin) != 6 OR _new_pin !~ '^[0-9]+$' THEN
    RETURN jsonb_build_object('success', false, 'error', 'New PIN must be exactly 6 digits');
  END IF;
  
  -- Verify current PIN matches
  SELECT * INTO _profile
  FROM public.profiles
  WHERE id = _user_id
    AND pin_hash = crypt(_current_pin, pin_hash);
  
  IF _profile IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Current PIN is incorrect');
  END IF;
  
  -- Update to new PIN
  UPDATE public.profiles
  SET pin_hash = crypt(_new_pin, gen_salt('bf')),
      updated_at = NOW()
  WHERE id = _user_id;
  
  RETURN jsonb_build_object('success', true, 'message', 'PIN changed successfully');
END;
$$;

-- =====================================================
-- 2. ADMIN_UPDATE_USER_STATUS - Activate/deactivate users
-- =====================================================
-- Called by: UserManagement.tsx for toggling user status
-- Re-creating to ensure correct signature and permissions

DROP FUNCTION IF EXISTS public.admin_update_user_status(UUID, BOOLEAN);

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
  -- Verify caller is super_admin
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = auth.uid() AND role = 'super_admin'
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized - super_admin only');
  END IF;

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
-- 3. ADMIN_RESET_USER_PIN - Admin resets a user's PIN
-- =====================================================
-- Called by: UserManagement.tsx for resetting user PINs
-- Re-creating to ensure correct signature and permissions

DROP FUNCTION IF EXISTS public.admin_reset_user_pin(UUID, TEXT);

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
  -- Verify caller is super_admin
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = auth.uid() AND role = 'super_admin'
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized - super_admin only');
  END IF;

  -- Validate PIN format (must be exactly 6 digits)
  IF _new_pin IS NULL OR length(_new_pin) != 6 OR _new_pin !~ '^[0-9]+$' THEN
    RETURN jsonb_build_object('success', false, 'error', 'PIN must be exactly 6 digits');
  END IF;

  -- Hash the new PIN
  _pin_hash := crypt(_new_pin, gen_salt('bf'));
  
  -- Update the pin_hash for target user
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
-- 4. UPDATE_PIN_ONLY - Update just the PIN hash
-- =====================================================
-- Called by: API routes (create-user.ts)
-- Keeping both VOID and BOOLEAN return versions for compatibility

DROP FUNCTION IF EXISTS public.update_pin_only(UUID, TEXT);

CREATE OR REPLACE FUNCTION public.update_pin_only(
  _user_id UUID,
  _pin TEXT
)
RETURNS VOID
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
END;
$$;

-- =====================================================
-- 5. UPDATE_USER_PROFILE_WITH_PIN - Upsert profile with PIN
-- =====================================================
-- Called by: API routes (create-user.ts)

DROP FUNCTION IF EXISTS public.update_user_profile_with_pin(UUID, TEXT, TEXT, public.user_role, TEXT);

CREATE OR REPLACE FUNCTION public.update_user_profile_with_pin(
  _user_id UUID,
  _full_name TEXT,
  _phone TEXT,
  _role public.user_role,
  _pin TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _pin_hash TEXT;
BEGIN
  -- Hash the PIN
  _pin_hash := crypt(_pin, gen_salt('bf'));
  
  -- Upsert the profile
  INSERT INTO public.profiles (id, full_name, phone, pin_hash, role, is_active, created_at, updated_at)
  VALUES (_user_id, _full_name, _phone, _pin_hash, _role, true, NOW(), NOW())
  ON CONFLICT (id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    phone = EXCLUDED.phone,
    pin_hash = EXCLUDED.pin_hash,
    role = EXCLUDED.role,
    updated_at = NOW();
END;
$$;

-- =====================================================
-- GRANT PERMISSIONS
-- =====================================================

-- change_own_pin - Any authenticated user can change their own PIN
GRANT EXECUTE ON FUNCTION public.change_own_pin(TEXT, TEXT) TO authenticated;

-- Admin functions - Only authenticated users (app checks for super_admin role)
GRANT EXECUTE ON FUNCTION public.admin_update_user_status(UUID, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_reset_user_pin(UUID, TEXT) TO authenticated;

-- Profile update functions - Service role and authenticated
GRANT EXECUTE ON FUNCTION public.update_pin_only(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_pin_only(UUID, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION public.update_user_profile_with_pin(UUID, TEXT, TEXT, public.user_role, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_user_profile_with_pin(UUID, TEXT, TEXT, public.user_role, TEXT) TO service_role;

-- =====================================================
-- VERIFICATION - Check functions were created
-- =====================================================
SELECT 
  '✅ Functions Created Successfully!' as status,
  routine_name as function_name
FROM information_schema.routines 
WHERE routine_schema = 'public' 
  AND routine_name IN (
    'change_own_pin', 
    'admin_update_user_status', 
    'admin_reset_user_pin',
    'update_pin_only',
    'update_user_profile_with_pin'
  )
ORDER BY routine_name;

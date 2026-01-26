-- ============================================
-- FIX: Create missing admin_create_staff_user function
-- This function is called after supabase.auth.signUp to properly set up
-- the user's profile and role. It updates the profile created by handle_new_user
-- trigger to have the correct role assigned by the admin.
-- ============================================

CREATE OR REPLACE FUNCTION public.admin_create_staff_user(
  _user_id uuid,
  _full_name text,
  _phone text,
  _role user_role,
  _pin text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $$
BEGIN
  -- Verify caller is super_admin
  IF NOT public.has_role(auth.uid(), 'super_admin') THEN
    RETURN json_build_object('success', false, 'error', 'Only super admin can create users');
  END IF;

  -- Validate PIN format
  IF NOT (_pin ~ '^\d{6}$') THEN
    RETURN json_build_object('success', false, 'error', 'PIN must be exactly 6 digits');
  END IF;

  -- Update the profile that was created by handle_new_user trigger
  -- The trigger creates with farm_worker role, we override it here
  UPDATE public.profiles
  SET 
    full_name = _full_name,
    phone = _phone,
    role = _role,
    pin_hash = crypt(_pin, gen_salt('bf')),
    is_active = true
  WHERE id = _user_id;

  -- Check if profile was updated
  IF NOT FOUND THEN
    -- Profile doesn't exist yet (trigger might not have fired), create it
    INSERT INTO public.profiles (id, full_name, phone, role, pin_hash, is_active)
    VALUES (_user_id, _full_name, _phone, _role, crypt(_pin, gen_salt('bf')), true)
    ON CONFLICT (id) DO UPDATE
    SET 
      full_name = EXCLUDED.full_name,
      phone = EXCLUDED.phone,
      role = EXCLUDED.role,
      pin_hash = EXCLUDED.pin_hash,
      is_active = EXCLUDED.is_active;
  END IF;

  -- Update user_roles table (authoritative source for RLS policies)
  INSERT INTO public.user_roles (user_id, role)
  VALUES (_user_id, _role)
  ON CONFLICT (user_id) DO UPDATE SET role = EXCLUDED.role;

  RETURN json_build_object('success', true, 'message', 'User created successfully');
END;
$$;

-- ============================================
-- FIX: Create admin_update_user_status function if missing
-- ============================================

CREATE OR REPLACE FUNCTION public.admin_update_user_status(
  _target_user_id uuid,
  _is_active boolean
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  _target_role text;
BEGIN
  -- Verify caller is super_admin
  IF NOT public.has_role(auth.uid(), 'super_admin') THEN
    RETURN json_build_object('success', false, 'error', 'Only super admin can update user status');
  END IF;

  -- Prevent self-deactivation
  IF _target_user_id = auth.uid() AND NOT _is_active THEN
    RETURN json_build_object('success', false, 'error', 'Cannot deactivate your own account');
  END IF;

  -- Check if target is super_admin
  SELECT role INTO _target_role FROM public.user_roles WHERE user_id = _target_user_id;
  IF _target_role = 'super_admin' AND NOT _is_active THEN
    RETURN json_build_object('success', false, 'error', 'Cannot deactivate super admin account');
  END IF;

  -- Update the user's status
  UPDATE public.profiles
  SET is_active = _is_active
  WHERE id = _target_user_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'User not found');
  END IF;

  RETURN json_build_object(
    'success', true, 
    'message', CASE WHEN _is_active THEN 'User activated successfully' ELSE 'User deactivated successfully' END
  );
END;
$$;

-- ============================================
-- FIX: Create admin_reset_user_pin function if missing
-- ============================================

CREATE OR REPLACE FUNCTION public.admin_reset_user_pin(
  _target_user_id uuid,
  _new_pin text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $$
DECLARE
  _target_role text;
BEGIN
  -- Verify caller is super_admin
  IF NOT public.has_role(auth.uid(), 'super_admin') THEN
    RETURN json_build_object('success', false, 'error', 'Only super admin can reset PINs');
  END IF;

  -- Validate PIN format
  IF NOT (_new_pin ~ '^\d{6}$') THEN
    RETURN json_build_object('success', false, 'error', 'PIN must be exactly 6 digits');
  END IF;

  -- Check if target is super_admin (only allow self-reset for super_admin)
  SELECT role INTO _target_role FROM public.user_roles WHERE user_id = _target_user_id;
  IF _target_role = 'super_admin' AND _target_user_id != auth.uid() THEN
    RETURN json_build_object('success', false, 'error', 'Cannot reset another super admin PIN');
  END IF;

  -- Update the user's PIN
  UPDATE public.profiles
  SET pin_hash = crypt(_new_pin, gen_salt('bf'))
  WHERE id = _target_user_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'User not found');
  END IF;

  RETURN json_build_object('success', true, 'message', 'PIN reset successfully');
END;
$$;

-- ============================================
-- Grant execute permissions
-- ============================================
GRANT EXECUTE ON FUNCTION public.admin_create_staff_user(uuid, text, text, user_role, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_user_status(uuid, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_reset_user_pin(uuid, text) TO authenticated;

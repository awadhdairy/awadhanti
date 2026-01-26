-- =====================================================
-- CRITICAL FIX: Admin User Creation
-- =====================================================
-- This is the ONLY script you need to run to fix user creation.
-- Run this in: Supabase Dashboard > SQL Editor > New Query
-- =====================================================

-- Step 1: Ensure has_role function exists (required by admin functions)
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

GRANT EXECUTE ON FUNCTION public.has_role(uuid, user_role) TO authenticated;

-- Step 2: Create/Replace admin_create_staff_user function
-- This is the main function that assigns the correct role to new users
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
DECLARE
  _profile_updated boolean := false;
BEGIN
  -- Verify caller is super_admin
  IF NOT public.has_role(auth.uid(), 'super_admin') THEN
    RETURN json_build_object('success', false, 'error', 'Only super admin can create users');
  END IF;

  -- Validate PIN format
  IF NOT (_pin ~ '^\d{6}$') THEN
    RETURN json_build_object('success', false, 'error', 'PIN must be exactly 6 digits');
  END IF;

  -- Validate user_id corresponds to an existing auth user
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = _user_id) THEN
    RETURN json_build_object('success', false, 'error', 'Invalid user ID - auth user does not exist');
  END IF;

  -- Check phone uniqueness (excluding the target user)
  IF EXISTS (SELECT 1 FROM public.profiles WHERE phone = _phone AND id != _user_id) THEN
    RETURN json_build_object('success', false, 'error', 'Phone number already in use by another user');
  END IF;

  -- Update the profile that was created by handle_new_user trigger
  UPDATE public.profiles
  SET 
    full_name = _full_name,
    phone = _phone,
    role = _role,
    pin_hash = crypt(_pin, gen_salt('bf')),
    is_active = true
  WHERE id = _user_id;

  _profile_updated := FOUND;

  -- If profile doesn't exist yet, create it
  IF NOT _profile_updated THEN
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

  -- Update user_roles table (THIS IS THE KEY - RLS policies use this table)
  INSERT INTO public.user_roles (user_id, role)
  VALUES (_user_id, _role)
  ON CONFLICT (user_id) DO UPDATE SET role = EXCLUDED.role;

  RETURN json_build_object('success', true, 'message', 'User created successfully with role: ' || _role::text);

EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_create_staff_user(uuid, text, text, user_role, text) TO authenticated;

-- Step 3: Verify the functions were created
SELECT 
  proname as function_name,
  'CREATED' as status
FROM pg_proc 
WHERE proname IN ('admin_create_staff_user', 'has_role')
AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');

-- If you see 2 rows with "CREATED" status, the fix is applied!

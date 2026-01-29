-- =====================================================
-- SUPER ADMIN SETUP SCRIPT
-- =====================================================
-- Run this AFTER creating the super admin user in Supabase Dashboard
-- 
-- Super Admin UUID: 26a4eb5c-daeb-4d81-8e97-bf6c79793298
-- =====================================================

DO $$
DECLARE
  admin_user_id UUID := '26a4eb5c-daeb-4d81-8e97-bf6c79793298';
  admin_phone TEXT := '7897716792';
  admin_name TEXT := 'Super Admin';
  admin_pin TEXT := '101101';
BEGIN
  -- Create or update profile
  INSERT INTO public.profiles (id, full_name, phone, role, pin_hash, is_active)
  VALUES (
    admin_user_id,
    admin_name,
    admin_phone,
    'super_admin',
    crypt(admin_pin, gen_salt('bf')),
    true
  )
  ON CONFLICT (id) DO UPDATE
  SET full_name = admin_name,
      phone = admin_phone,
      role = 'super_admin',
      pin_hash = crypt(admin_pin, gen_salt('bf')),
      is_active = true,
      updated_at = NOW();

  -- Create or update user role
  INSERT INTO public.user_roles (user_id, role)
  VALUES (admin_user_id, 'super_admin')
  ON CONFLICT (user_id) DO UPDATE
  SET role = 'super_admin';

  RAISE NOTICE 'Super Admin created successfully!';
  RAISE NOTICE 'Login with: Phone = %, PIN = %', admin_phone, admin_pin;
END $$;

-- Verify the admin was created
SELECT 
  p.id,
  p.full_name,
  p.phone,
  p.role,
  ur.role as user_role,
  p.is_active
FROM public.profiles p
JOIN public.user_roles ur ON ur.user_id = p.id
WHERE p.role = 'super_admin';

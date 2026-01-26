
# Fix: Permanent User Deletion Not Removing auth.users Record

## Problem Analysis

When permanently deleting a user, the system fails to remove the record from `auth.users` table. This causes the "User already registered" error when trying to create a new user with the same phone number.

### Root Cause Chain

```text
1. Admin clicks "Permanent Delete"
              ↓
2. Frontend calls RPC: admin_permanent_delete_user (DOESN'T EXIST!)
              ↓
3. Even if it existed, admin_delete_user only:
   - DELETE FROM user_roles ✓
   - DELETE FROM profiles ✓
   - DELETE FROM auth.users ✗ (NOT DONE!)
              ↓
4. auth.users still contains: 9415688104@awadhdairy.com
              ↓
5. Next creation with phone 9415688104:
   - supabase.auth.signUp({ email: "9415688104@awadhdairy.com" })
   - Supabase Auth finds existing record
   - Returns: "User already registered"
```

### Current Database State

| Table | Phone 9415688104 | Status |
|-------|------------------|--------|
| `auth.users` | EXISTS (orphaned) | Problem! |
| `profiles` | DELETED | OK |
| `user_roles` | DELETED | OK |

---

## Solution

Create a proper `admin_permanent_delete_user` function that uses `SECURITY DEFINER` to delete from all three tables including `auth.users`.

### Why SECURITY DEFINER Works

- Functions with `SECURITY DEFINER` run with the privileges of the function owner (typically `postgres`)
- The `postgres` user has full access to `auth.users` table
- RLS policies are bypassed for the function owner
- This is a standard Supabase pattern for privileged operations

---

## SQL Migration (Run on External Supabase)

```sql
-- =====================================================
-- FIX: Complete Permanent User Deletion
-- Run on: https://supabase.com/dashboard/project/rihedsukjinwqvsvufls/sql/new
-- =====================================================

-- Create function to permanently delete user (including from auth.users)
CREATE OR REPLACE FUNCTION public.admin_permanent_delete_user(_target_user_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $$
DECLARE
  _target_role text;
  _target_email text;
BEGIN
  -- Verify caller is super_admin
  IF NOT public.has_any_role(auth.uid(), ARRAY['super_admin']::user_role[]) THEN
    RETURN json_build_object('success', false, 'error', 'Only super admin can permanently delete users');
  END IF;
  
  -- Prevent self-deletion
  IF _target_user_id = auth.uid() THEN
    RETURN json_build_object('success', false, 'error', 'Cannot delete your own account');
  END IF;
  
  -- Check if target is super_admin
  SELECT role::text INTO _target_role FROM public.user_roles WHERE user_id = _target_user_id;
  IF _target_role = 'super_admin' THEN
    RETURN json_build_object('success', false, 'error', 'Cannot delete super admin account');
  END IF;
  
  -- Get email for logging
  SELECT email INTO _target_email FROM auth.users WHERE id = _target_user_id;
  
  -- Step 1: Remove from user_roles
  DELETE FROM public.user_roles WHERE user_id = _target_user_id;
  
  -- Step 2: Remove from profiles
  DELETE FROM public.profiles WHERE id = _target_user_id;
  
  -- Step 3: Remove from auth.users (CRITICAL!)
  DELETE FROM auth.users WHERE id = _target_user_id;
  
  RETURN json_build_object(
    'success', true, 
    'message', 'User permanently deleted from all tables',
    'deleted_email', _target_email
  );
END;
$$;

-- Also update check_phone_availability to check auth.users
CREATE OR REPLACE FUNCTION public.check_phone_availability(_phone text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $$
DECLARE
  _existing_profile RECORD;
  _existing_auth RECORD;
  _expected_email text;
BEGIN
  _expected_email := _phone || '@awadhdairy.com';
  
  -- Check profiles table
  SELECT id, full_name, is_active, role INTO _existing_profile
  FROM public.profiles
  WHERE phone = _phone;
  
  -- Check auth.users table (for orphaned records)
  SELECT id INTO _existing_auth
  FROM auth.users
  WHERE email = _expected_email;
  
  IF _existing_profile IS NULL AND _existing_auth IS NULL THEN
    -- Completely available
    RETURN json_build_object('available', true);
  ELSIF _existing_profile IS NULL AND _existing_auth IS NOT NULL THEN
    -- Orphaned auth record (profile deleted but auth.users remains)
    RETURN json_build_object(
      'available', false, 
      'orphaned_auth', true,
      'auth_user_id', _existing_auth.id,
      'error', 'Orphaned auth record exists. Contact admin to clean up.'
    );
  ELSIF NOT _existing_profile.is_active THEN
    -- Soft-deleted profile (reactivatable)
    RETURN json_build_object(
      'available', false, 
      'reactivatable', true,
      'user_id', _existing_profile.id,
      'full_name', _existing_profile.full_name,
      'previous_role', _existing_profile.role
    );
  ELSE
    -- Active user exists
    RETURN json_build_object(
      'available', false, 
      'reactivatable', false,
      'error', 'Phone number already in use by active user'
    );
  END IF;
END;
$$;

-- Function to clean up orphaned auth records
CREATE OR REPLACE FUNCTION public.admin_cleanup_orphaned_auth(_phone text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $$
DECLARE
  _expected_email text;
  _auth_id uuid;
BEGIN
  -- Verify caller is super_admin
  IF NOT public.has_any_role(auth.uid(), ARRAY['super_admin']::user_role[]) THEN
    RETURN json_build_object('success', false, 'error', 'Only super admin can cleanup orphaned records');
  END IF;
  
  _expected_email := _phone || '@awadhdairy.com';
  
  -- Find orphaned auth record (exists in auth.users but not in profiles)
  SELECT au.id INTO _auth_id
  FROM auth.users au
  LEFT JOIN public.profiles p ON p.id = au.id
  WHERE au.email = _expected_email
    AND p.id IS NULL;
  
  IF _auth_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'No orphaned auth record found for this phone');
  END IF;
  
  -- Delete the orphaned auth record
  DELETE FROM auth.users WHERE id = _auth_id;
  
  RETURN json_build_object(
    'success', true, 
    'message', 'Orphaned auth record cleaned up',
    'deleted_auth_id', _auth_id
  );
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION public.admin_permanent_delete_user(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_phone_availability(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_cleanup_orphaned_auth(text) TO authenticated;

-- Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
```

---

## Cleanup Existing Orphaned Records

After running the migration above, you need to clean up the existing orphaned auth records. Run this SQL to identify them:

```sql
-- Find orphaned auth records (in auth.users but not in profiles)
SELECT 
  au.id,
  au.email,
  au.created_at,
  CASE WHEN p.id IS NULL THEN 'ORPHANED' ELSE 'OK' END as status
FROM auth.users au
LEFT JOIN public.profiles p ON p.id = au.id
ORDER BY status DESC, au.created_at DESC;
```

To clean up a specific orphaned record, use:

```sql
-- Delete specific orphaned auth record by phone
SELECT admin_cleanup_orphaned_auth('9415688104');
```

Or clean up all orphaned records at once:

```sql
-- Delete ALL orphaned auth records (users with no matching profile)
DELETE FROM auth.users au
WHERE NOT EXISTS (
  SELECT 1 FROM public.profiles p WHERE p.id = au.id
)
AND au.email LIKE '%@awadhdairy.com';
```

---

## Frontend Changes Required

Update `UserManagement.tsx` to handle orphaned auth records when creating users:

1. When `check_phone_availability` returns `orphaned_auth: true`, show a dialog offering to clean up
2. Call `admin_cleanup_orphaned_auth` before retrying user creation

### Updated handleCreateUser Flow

```text
1. Check phone availability
2. If orphaned_auth: true
   → Show "Cleanup required" dialog
   → Call admin_cleanup_orphaned_auth
   → Retry creation
3. If reactivatable: true
   → Show reactivation dialog (existing flow)
4. If available: true
   → Proceed with signUp + admin_create_staff_user
```

---

## Summary of Changes

| Component | Change |
|-----------|--------|
| `admin_permanent_delete_user` | **CREATE** new function that deletes from `auth.users` |
| `check_phone_availability` | **UPDATE** to detect orphaned auth records |
| `admin_cleanup_orphaned_auth` | **CREATE** new function to clean orphaned records |
| `UserManagement.tsx` | **UPDATE** to handle orphaned auth cleanup flow |

---

## Technical Details

### Why This Works

1. **SECURITY DEFINER**: The function runs with the privileges of the function owner (`postgres`), which has full access to `auth.users`
2. **SET search_path**: Including 'auth' in the search path allows referencing `auth.users` directly
3. **Permission isolation**: The function checks `super_admin` role internally before allowing deletion
4. **Idempotent cleanup**: The cleanup function safely handles cases where records don't exist

### Security Considerations

- Only `super_admin` can call `admin_permanent_delete_user`
- Only `super_admin` can call `admin_cleanup_orphaned_auth`
- Self-deletion is prevented
- Super admin accounts cannot be deleted
- All operations are logged via Supabase's built-in audit

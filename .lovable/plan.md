
# Comprehensive Fix: Permanent User Deletion & Recreation

## Summary of Issues Found

After thorough investigation, I identified why admin cannot permanently delete/recreate users:

### Root Cause 1: Soft Delete Only
The current `admin_delete_user` function only performs a **soft delete**:
- Removes role from `user_roles` table ✓
- Sets `is_active = false` in `profiles` ✓
- Sets `pin_hash = NULL` ✓
- Does **NOT** delete from `auth.users` ✗
- Does **NOT** delete from `profiles` table ✗

### Root Cause 2: Recreation Blocked
When you try to create a user with a previously "deleted" phone number:
1. `signUp()` fails with "User already registered" because `{phone}@awadhdairy.com` still exists in `auth.users`
2. Even if auth succeeded, the old `profiles` row still exists

### Root Cause 3: Supabase Auth Limitation
Standard SQL functions cannot delete from `auth.users` - it requires the `service_role` key via the Admin API, which is only accessible through an Edge Function or external backend.

---

## Implementation Plan

### Step 1: Create Edge Function for True User Deletion
Create a new Edge Function that uses the `service_role` key to permanently delete users from `auth.users`.

**File:** `supabase/functions/admin-delete-user/index.ts`

```typescript
// Edge function that:
// 1. Verifies caller is super_admin (via JWT)
// 2. Deletes from auth.users using Admin API
// 3. Cascade delete handles profiles (due to ON DELETE CASCADE)
```

### Step 2: Update Database Function for Cleanup
Modify `admin_delete_user` to fully delete from `profiles` and `user_roles` (for Edge Function fallback or when auth deletion is handled separately).

```sql
-- Updated admin_delete_user function
-- - Actually DELETE rows instead of soft delete
-- - Add option for "soft" vs "hard" delete
```

### Step 3: Update UserManagement.tsx
Enhance the deletion flow:
1. Call Edge Function for permanent deletion
2. Handle "User already exists" error gracefully during recreation
3. Offer option to "Reactivate" soft-deleted users
4. Add confirmation for permanent vs soft delete

### Step 4: Add Reactivation Flow
Allow admin to reactivate previously deleted users instead of recreating:
1. Check if phone exists in inactive profiles
2. If found, offer to reactivate with new PIN
3. Skip auth.signUp() and just update existing records

---

## Technical Details

### A. Edge Function: `admin-delete-user`

```typescript
import { createClient } from '@supabase/supabase-js';
import { corsHeaders, handleCors } from '../_shared/cors.ts';

Deno.serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') return handleCors();

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) throw new Error('Missing authorization');

    // Create client with user's JWT to verify identity
    const userClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } }
    );

    // Verify caller is super_admin
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) throw new Error('Not authenticated');

    const { data: roleCheck } = await userClient.rpc('has_role', {
      _user_id: user.id,
      _role: 'super_admin'
    });
    if (!roleCheck) throw new Error('Only super_admin can delete users');

    // Get target user ID from request
    const { target_user_id } = await req.json();
    if (!target_user_id) throw new Error('Missing target_user_id');

    // Prevent self-deletion and super_admin deletion
    if (target_user_id === user.id) {
      throw new Error('Cannot delete your own account');
    }

    // Create admin client with service_role key
    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
      { auth: { autoRefreshToken: false, persistSession: false } }
    );

    // Check if target is super_admin
    const { data: targetRole } = await adminClient
      .from('user_roles')
      .select('role')
      .eq('user_id', target_user_id)
      .single();
    
    if (targetRole?.role === 'super_admin') {
      throw new Error('Cannot delete super_admin account');
    }

    // Delete from auth.users (cascades to profiles due to FK)
    const { error: deleteError } = await adminClient.auth.admin.deleteUser(target_user_id);
    if (deleteError) throw deleteError;

    return new Response(
      JSON.stringify({ success: true, message: 'User permanently deleted' }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
```

### B. Database Migration

```sql
-- Update admin_delete_user to support hard delete
CREATE OR REPLACE FUNCTION public.admin_delete_user(_target_user_id uuid, _permanent boolean DEFAULT false)
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
    RETURN json_build_object('success', false, 'error', 'Only super admin can delete users');
  END IF;
  
  -- Prevent self-deletion
  IF _target_user_id = auth.uid() THEN
    RETURN json_build_object('success', false, 'error', 'Cannot delete your own account');
  END IF;
  
  -- Check if target is super_admin
  SELECT role INTO _target_role FROM public.user_roles WHERE user_id = _target_user_id;
  IF _target_role = 'super_admin' THEN
    RETURN json_build_object('success', false, 'error', 'Cannot delete super admin account');
  END IF;
  
  -- Remove from user_roles
  DELETE FROM public.user_roles WHERE user_id = _target_user_id;
  
  IF _permanent THEN
    -- Hard delete: remove profile entirely (auth.users deletion must be via Edge Function)
    DELETE FROM public.profiles WHERE id = _target_user_id;
    RETURN json_build_object('success', true, 'message', 'User profile deleted. Complete with Edge Function for auth removal.');
  ELSE
    -- Soft delete: mark inactive
    UPDATE public.profiles 
    SET is_active = false, pin_hash = NULL 
    WHERE id = _target_user_id;
    RETURN json_build_object('success', true, 'message', 'User deactivated successfully');
  END IF;
END;
$$;

-- Function to check if phone can be reused
CREATE OR REPLACE FUNCTION public.check_phone_availability(_phone text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  _existing RECORD;
BEGIN
  SELECT id, full_name, is_active INTO _existing
  FROM public.profiles
  WHERE phone = _phone;
  
  IF _existing IS NULL THEN
    RETURN json_build_object('available', true);
  ELSIF NOT _existing.is_active THEN
    RETURN json_build_object(
      'available', false, 
      'reactivatable', true,
      'user_id', _existing.id,
      'full_name', _existing.full_name
    );
  ELSE
    RETURN json_build_object(
      'available', false, 
      'reactivatable', false,
      'error', 'Phone number already in use by active user'
    );
  END IF;
END;
$$;

-- Function to reactivate a soft-deleted user
CREATE OR REPLACE FUNCTION public.admin_reactivate_user(
  _user_id uuid,
  _full_name text,
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
    RETURN json_build_object('success', false, 'error', 'Only super admin can reactivate users');
  END IF;
  
  -- Validate PIN format
  IF NOT (_pin ~ '^\d{6}$') THEN
    RETURN json_build_object('success', false, 'error', 'PIN must be exactly 6 digits');
  END IF;
  
  -- Update profile
  UPDATE public.profiles
  SET 
    full_name = _full_name,
    role = _role,
    is_active = true,
    pin_hash = crypt(_pin, gen_salt('bf'))
  WHERE id = _user_id;
  
  -- Upsert role
  INSERT INTO public.user_roles (user_id, role)
  VALUES (_user_id, _role)
  ON CONFLICT (user_id) DO UPDATE SET role = EXCLUDED.role;
  
  RETURN json_build_object('success', true, 'message', 'User reactivated successfully');
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.check_phone_availability(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_reactivate_user(uuid, text, user_role, text) TO authenticated;
```

### C. Updated UserManagement.tsx Changes

1. **Delete Flow**: Call Edge Function for permanent deletion
2. **Create Flow**: Check phone availability first, offer reactivation if applicable
3. **UI Enhancement**: Add delete type selector (Deactivate vs Permanently Delete)

```typescript
// Key changes to handleDeleteUser:
const handleDeleteUser = async (permanent: boolean = false) => {
  if (!selectedUser) return;

  setDeleting(true);
  try {
    if (permanent) {
      // Call Edge Function for permanent deletion
      const response = await supabase.functions.invoke('admin-delete-user', {
        body: { target_user_id: selectedUser.id }
      });
      
      if (response.error) throw new Error(response.error.message);
      if (!response.data?.success) throw new Error(response.data?.error);
    } else {
      // Soft delete via RPC
      const { data, error } = await supabase.rpc('admin_delete_user', {
        _target_user_id: selectedUser.id,
        _permanent: false
      });
      // ... handle response
    }
    
    toast.success(permanent ? 'User permanently deleted' : 'User deactivated');
    // ... cleanup
  } catch (error) {
    toast.error(error.message);
  }
};

// Key changes to handleCreateUser:
const handleCreateUser = async () => {
  // First check if phone is available or reactivatable
  const { data: availability } = await supabase.rpc('check_phone_availability', {
    _phone: phone
  });
  
  if (!availability.available) {
    if (availability.reactivatable) {
      // Show reactivation dialog instead
      setReactivationUser({
        id: availability.user_id,
        name: availability.full_name
      });
      setShowReactivateDialog(true);
      return;
    } else {
      toast.error(availability.error);
      return;
    }
  }
  
  // Continue with normal creation...
};
```

---

## Expected Behavior After Fix

| Action | Before | After |
|--------|--------|-------|
| Delete User | Soft delete only (stays in auth.users) | Option for soft or permanent delete |
| Recreate Same Phone | Fails with "User already registered" | Works (after permanent delete) OR offers reactivation |
| Reactivate User | Not possible | New feature: reactivate with new role/PIN |
| Super Admin Protection | Cannot delete | Still protected |
| Self-Deletion | Cannot delete | Still protected |

---

## Verification Checklist

After implementation:
1. [ ] Create a new test user (e.g., phone 1234567890)
2. [ ] Soft delete → user shows as inactive, cannot log in
3. [ ] Try recreate same phone → offered to reactivate
4. [ ] Permanently delete → user fully removed
5. [ ] Recreate same phone → works normally
6. [ ] Super admin deletion blocked
7. [ ] Self-deletion blocked

---

## Files to Create/Modify

1. **Create:** `supabase/functions/admin-delete-user/index.ts`
2. **Create:** `supabase/functions/_shared/cors.ts` (if not exists)
3. **Modify:** Database functions via migration
4. **Modify:** `src/pages/UserManagement.tsx` (deletion flow + reactivation)
5. **Modify:** `src/components/common/ConfirmDialog.tsx` (add delete type options)

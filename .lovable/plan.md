

# Complete Migration: Remove All Lovable Cloud Edge Functions

## Current Situation Analysis

### Edge Functions on Lovable Cloud

| Function | Status | Currently Used? |
|----------|--------|-----------------|
| `admin-delete-user` | Deployed on Lovable Cloud | Yes - called from UserManagement.tsx |
| `_shared/cors.ts` | Helper file | Used by admin-delete-user |

### What's Already Using Database RPCs (No Edge Function Needed)

The application has already migrated most functionality to database RPCs:

| Feature | RPC Function | Location |
|---------|--------------|----------|
| Staff Login | `verify_staff_pin` | Auth.tsx |
| Customer Login | `verify_customer_pin` | CustomerAuth.tsx |
| Customer Registration | `register_customer_account` | CustomerAuth.tsx |
| Soft Delete User | `admin_delete_user(_permanent: false)` | UserManagement.tsx |
| Reset PIN | `admin_reset_user_pin` | UserManagement.tsx |
| Update Status | `admin_update_user_status` | UserManagement.tsx |
| Create Staff | `admin_create_staff_user` | UserManagement.tsx |
| Reactivate User | `admin_reactivate_user` | UserManagement.tsx |
| Check Phone | `check_phone_availability` | UserManagement.tsx |

### The Only Remaining Edge Function Call

There is exactly **one** Edge Function invocation in the entire codebase:

```typescript
// src/pages/UserManagement.tsx, lines 376-378
const { data, error } = await supabase.functions.invoke('admin-delete-user', {
  body: { target_user_id: selectedUser.id }
});
```

This is for **permanent deletion** which requires deleting from `auth.users`.

---

## Migration Strategy

Since you want the website completely independent of Lovable Cloud Edge Functions, I will:

1. **Replace the Edge Function call with a Database RPC** that has elevated privileges
2. **Delete the Edge Function files** from the repository
3. **Clean up the config.toml** to remove function references

### Why Database RPC Works for `auth.users` Deletion

Using `SECURITY DEFINER` with `SET search_path TO 'public', 'auth'`, a PostgreSQL function can:
- Execute with the privileges of the function owner (usually `postgres` superuser)
- Access the `auth` schema to delete from `auth.users`
- Validate permissions within the function itself

---

## Implementation Steps

### Step 1: Create Database Function on External Supabase

You need to run this SQL in your external Supabase dashboard (https://supabase.com/dashboard/project/rihedsukjinwqvsvufls → SQL Editor):

```sql
-- Function to permanently delete a user from auth.users
-- Uses SECURITY DEFINER to run with elevated privileges
CREATE OR REPLACE FUNCTION public.admin_permanent_delete_user(_target_user_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $$
DECLARE
  _caller_id uuid;
  _target_role text;
BEGIN
  -- Get the authenticated caller's ID
  _caller_id := auth.uid();
  
  -- Must be authenticated
  IF _caller_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Not authenticated');
  END IF;
  
  -- Verify caller is super_admin
  IF NOT public.has_role(_caller_id, 'super_admin') THEN
    RETURN json_build_object('success', false, 'error', 'Only super admin can permanently delete users');
  END IF;
  
  -- Prevent self-deletion
  IF _target_user_id = _caller_id THEN
    RETURN json_build_object('success', false, 'error', 'Cannot delete your own account');
  END IF;
  
  -- Check if target user exists
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = _target_user_id) THEN
    RETURN json_build_object('success', false, 'error', 'User not found');
  END IF;
  
  -- Check if target is super_admin (cannot delete other super_admins)
  SELECT role INTO _target_role FROM public.user_roles WHERE user_id = _target_user_id;
  IF _target_role = 'super_admin' THEN
    RETURN json_build_object('success', false, 'error', 'Cannot delete super admin account');
  END IF;
  
  -- Step 1: Delete from user_roles
  DELETE FROM public.user_roles WHERE user_id = _target_user_id;
  
  -- Step 2: Delete from profiles
  DELETE FROM public.profiles WHERE id = _target_user_id;
  
  -- Step 3: Delete from auth.users (this is why we need SECURITY DEFINER)
  DELETE FROM auth.users WHERE id = _target_user_id;
  
  RETURN json_build_object('success', true, 'message', 'User permanently deleted');
END;
$$;

-- Grant execute permission to authenticated users
-- (the function itself checks for super_admin role)
GRANT EXECUTE ON FUNCTION public.admin_permanent_delete_user(uuid) TO authenticated;
```

### Step 2: Update UserManagement.tsx

Replace the Edge Function invocation with an RPC call:

**Current code (lines 374-386):**
```typescript
if (deleteType === "permanent") {
  // Call Edge Function for permanent deletion from auth.users
  const { data, error } = await supabase.functions.invoke('admin-delete-user', {
    body: { target_user_id: selectedUser.id }
  });
  
  if (error) {
    throw new Error(error.message);
  }
  
  if (!data?.success) {
    throw new Error(data?.error || "Failed to permanently delete user");
  }
  
  toast.success("User permanently deleted");
}
```

**New code:**
```typescript
if (deleteType === "permanent") {
  // Call database function for permanent deletion from auth.users
  const { data, error } = await supabase.rpc('admin_permanent_delete_user', {
    _target_user_id: selectedUser.id
  });
  
  if (error) {
    throw new Error(error.message);
  }
  
  const result = data as unknown as RpcResponse;
  if (!result?.success) {
    throw new Error(result?.error || "Failed to permanently delete user");
  }
  
  toast.success("User permanently deleted");
}
```

### Step 3: Delete Edge Function Files

Remove from repository:
- `supabase/functions/admin-delete-user/index.ts`
- `supabase/functions/_shared/cors.ts`
- `supabase/functions/_shared/` (directory)
- `supabase/functions/admin-delete-user/` (directory)

### Step 4: Update supabase/config.toml

Remove the function configuration, keeping only the project_id:

```toml
project_id = "rihedsukjinwqvsvufls"
```

---

## Architecture After Migration

```text
+-------------------+                    +---------------------------+
|    Frontend App   |                    |   External Supabase       |
|   (Lovable Host)  |                    | (rihedsukjinwqvsvufls)    |
+-------------------+                    +---------------------------+
         |                                          |
         |  supabase.rpc('admin_permanent_delete_user')
         +----------------------------------------->|
         |                                          |
         |  supabase.rpc('verify_staff_pin')        | Database Functions
         +----------------------------------------->| with SECURITY DEFINER
         |                                          |
         |  supabase.auth.signInWithPassword()      | auth.users
         +----------------------------------------->| profiles
         |                                          | user_roles
         |  supabase.from('...').select()           | (all tables)
         +----------------------------------------->|
                                                    |
                                                    |
     NO EDGE FUNCTIONS REQUIRED                     v
```

---

## Files Changed Summary

| File | Action |
|------|--------|
| `src/pages/UserManagement.tsx` | Modify - replace `functions.invoke` with `rpc` |
| `supabase/functions/admin-delete-user/index.ts` | Delete |
| `supabase/functions/_shared/cors.ts` | Delete |
| `supabase/config.toml` | Modify - remove function entry |

---

## What You Need to Do First

Before I make the code changes, you must run the SQL migration on your external Supabase:

1. Go to https://supabase.com/dashboard/project/rihedsukjinwqvsvufls
2. Click **SQL Editor** in the left sidebar
3. Paste and run the SQL from Step 1 above
4. Confirm the function was created successfully

Once you confirm the SQL has been executed, I will proceed with updating the frontend code and removing the Edge Function files.

---

## Technical Notes

### Why This Approach is Better

1. **No cross-origin issues**: Frontend and database are on the same Supabase project
2. **Simpler architecture**: Everything runs on your external Supabase
3. **No Lovable Cloud dependency**: Website is completely independent
4. **Same security model**: Function validates `super_admin` role before deletion
5. **Faster execution**: Direct database call vs HTTP to Edge Function

### Security Considerations

- The `SECURITY DEFINER` keyword allows the function to access `auth.users`
- Permission checks happen **inside** the function (caller must be `super_admin`)
- The `GRANT EXECUTE` only allows calling the function, not bypassing its logic
- Self-deletion and super_admin deletion are prevented


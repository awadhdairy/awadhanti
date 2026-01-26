

## Fix Plan: Create Missing `verify_staff_pin` Function

### Problem Summary
The `verify_staff_pin` database function was never created. The Auth.tsx code tries to call it, but it doesn't exist in your database, causing login to fail.

---

### Step 1: Create the Database Function

Run this SQL in your **Supabase Dashboard → SQL Editor**:

```sql
-- Function to verify staff PIN against profiles table
CREATE OR REPLACE FUNCTION public.verify_staff_pin(_phone text, _pin text)
RETURNS TABLE (user_id uuid, is_active boolean, full_name text, role text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public', 'extensions'
AS $$
BEGIN
  RETURN QUERY
  SELECT p.id, p.is_active, p.full_name, p.role::text
  FROM public.profiles p
  WHERE p.phone = _phone
    AND p.pin_hash = crypt(_pin, p.pin_hash);
END;
$$;

-- Grant access to anonymous users (needed for login before authenticated)
GRANT EXECUTE ON FUNCTION public.verify_staff_pin TO anon;
GRANT EXECUTE ON FUNCTION public.verify_staff_pin TO authenticated;
```

---

### Step 2: Verify Function Works

After creating the function, test it in SQL Editor:

```sql
-- Test with your super admin phone (will return row if PIN is correct)
SELECT * FROM public.verify_staff_pin('7897716792', 'YOUR_6_DIGIT_PIN');
```

If it returns a row with your user data, the function is working.

---

### Step 3: Supabase Auth Settings

Ensure these settings in **Supabase Dashboard → Authentication → Settings**:

| Setting | Value |
|---------|-------|
| **Site URL** | Your Vercel domain (e.g., `https://awadhdairy.vercel.app`) |
| **Confirm email** | **OFF** (or "Enable email confirmations" = OFF) |
| **Enable new user signups** | **ON** |

---

### Why This Will Work

After creating the function:

```text
User enters phone + PIN
         │
         ▼
signInWithPassword() → FAILS (user not in auth.users yet)
         │
         ▼
rpc('verify_staff_pin') → NOW WORKS! Returns user data
         │
         ▼
PIN Valid? → YES
         │
         ▼
signUp() → Creates auth account
         │
         ▼
Session created → Navigate to /dashboard
```

---

### No Code Changes Required

The Auth.tsx code is already correct. You just need to:

1. Create the `verify_staff_pin` function in Supabase SQL Editor
2. Ensure email confirmation is disabled
3. Try logging in again

---

### Quick Reference: Your Existing Users

| Name | Phone | Role | Can Login After Fix |
|------|-------|------|---------------------|
| Super Admin | 7897716792 | super_admin | ✅ |
| Kanhaiya Lal | 9451574464 | manager | ✅ |
| Surendra Singh | 9415688104 | auditor | ✅ |

All three users have valid `pin_hash` values and will be able to log in once the function is created.


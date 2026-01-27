import type { VercelRequest, VercelResponse } from '@vercel/node';
import { createClient } from '@supabase/supabase-js';

const ALLOWED_ORIGINS = [
  'https://awadhd.lovable.app',
  'https://awadhdairy.vercel.app',
  'http://localhost:5173',
  'http://localhost:3000',
  'http://localhost:5000',
];

function getCorsOrigin(origin: string | null): string {
  if (origin && ALLOWED_ORIGINS.some(allowed => origin.startsWith(allowed))) {
    return origin;
  }
  return ALLOWED_ORIGINS[0];
}

export default async function handler(req: VercelRequest, res: VercelResponse) {
  const origin = req.headers.origin as string | null;
  const corsOrigin = getCorsOrigin(origin);
  
  if (req.method === 'OPTIONS') {
    return res.status(200)
      .setHeader('Access-Control-Allow-Origin', corsOrigin)
      .setHeader('Access-Control-Allow-Headers', 'authorization, x-client-info, apikey, content-type, x-supabase-api-version')
      .setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS')
      .setHeader('Access-Control-Allow-Credentials', 'true')
      .end();
  }
  
  res.setHeader('Access-Control-Allow-Origin', corsOrigin);
  res.setHeader('Access-Control-Allow-Credentials', 'true');

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const supabaseUrl = process.env.VITE_SUPABASE_URL || process.env.SUPABASE_URL;
    const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

    if (!supabaseUrl || !supabaseServiceKey) {
      console.error('Missing Supabase environment variables');
      return res.status(500).json({ error: 'Server configuration error' });
    }

    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    const authHeader = req.headers.authorization;
    if (!authHeader) {
      console.error('No authorization header provided');
      return res.status(401).json({ error: 'Missing authorization header' });
    }

    const token = authHeader.replace('Bearer ', '');
    console.log('Token received, length:', token.length);
    
    const { data: { user: requestingUser }, error: userError } = await supabaseAdmin.auth.getUser(token);
    if (userError || !requestingUser) {
      console.error('Token validation error:', userError?.message || 'No user returned');
      return res.status(401).json({ error: 'Invalid authentication', details: userError?.message });
    }
    
    console.log('Authenticated user ID:', requestingUser.id);
    console.log('User email:', requestingUser.email);

    // Check role from profiles table first (primary source used by frontend)
    const { data: profileData, error: profileError } = await supabaseAdmin
      .from('profiles')
      .select('id, role, full_name')
      .eq('id', requestingUser.id)
      .single();

    console.log('Profile lookup - data:', JSON.stringify(profileData));
    console.log('Profile lookup - error:', profileError?.message || 'none');

    let userRole: string | null = profileData?.role || null;

    // Fallback to user_roles table if profiles doesn't have the role
    if (!userRole) {
      console.log('No role in profiles, checking user_roles table...');
      const { data: roleData, error: roleError } = await supabaseAdmin
        .from('user_roles')
        .select('role')
        .eq('user_id', requestingUser.id)
        .single();
      
      console.log('user_roles lookup - data:', JSON.stringify(roleData));
      console.log('user_roles lookup - error:', roleError?.message || 'none');
      userRole = roleData?.role || null;
    }

    console.log('Final resolved role:', userRole);

    // Case-insensitive comparison
    if (!userRole || userRole.toLowerCase() !== 'super_admin') {
      console.error('Role check failed. User role:', userRole, 'User ID:', requestingUser.id);
      return res.status(403).json({ 
        error: 'Only super admin can create users',
        debug: { 
          userId: requestingUser.id,
          foundRole: userRole,
          profileFound: !!profileData
        }
      });
    }

    console.log('Role verified as super_admin, proceeding with user creation');

    const { phone, pin, fullName, role } = req.body;

    if (!phone || !pin || !fullName || !role) {
      return res.status(400).json({ error: 'Missing required fields: phone, pin, fullName, role' });
    }

    if (!/^\d{6}$/.test(pin)) {
      return res.status(400).json({ error: 'PIN must be exactly 6 digits' });
    }

    const validRoles = ['super_admin', 'manager', 'accountant', 'delivery_staff', 'farm_worker', 'vet_staff', 'auditor'];
    if (!validRoles.includes(role)) {
      return res.status(400).json({ error: 'Invalid role' });
    }

    const { data: existingProfile } = await supabaseAdmin
      .from('profiles')
      .select('id')
      .eq('phone', phone)
      .single();

    if (existingProfile) {
      return res.status(400).json({ error: 'A user with this phone number already exists' });
    }

    const email = `${phone}@awadhdairy.com`;

    const { data: existingUsers } = await supabaseAdmin.auth.admin.listUsers();
    const emailExists = existingUsers?.users?.some(u => u.email === email);
    
    if (emailExists) {
      return res.status(400).json({ error: 'A user with this phone number already exists in the system. Please use a different phone number or contact support to reset the existing account.' });
    }

    console.log(`Creating auth user for phone: ${phone}, email: ${email}`);

    const { data: authData, error: createError } = await supabaseAdmin.auth.admin.createUser({
      email,
      password: pin,
      email_confirm: true,
      user_metadata: {
        full_name: fullName,
        phone: phone
      }
    });

    if (createError) {
      console.error('Error creating auth user:', createError);
      let errorMessage = 'Failed to create user';
      if (createError.message?.includes('already been registered')) {
        errorMessage = 'A user with this phone number already exists. Please use a different phone number.';
      } else if (createError.message) {
        errorMessage = createError.message;
      }
      return res.status(400).json({ error: errorMessage });
    }

    const userId = authData.user.id;
    console.log('Created auth user with ID:', userId);

    console.log('Upserting profile for user:', userId);
    const { error: profileUpsertError } = await supabaseAdmin
      .from('profiles')
      .upsert({
        id: userId,
        full_name: fullName,
        phone: phone,
        role: role,
        is_active: true
      }, { onConflict: 'id' });

    if (profileUpsertError) {
      console.error('Error upserting profile:', profileUpsertError);
    } else {
      console.log('Profile upserted successfully');
    }

    console.log('Setting PIN hash for user:', userId);
    const { error: pinError } = await supabaseAdmin.rpc('update_pin_only', {
      _user_id: userId,
      _pin: pin
    });

    if (pinError) {
      console.error('Error setting PIN hash:', pinError);
      const { error: altPinError } = await supabaseAdmin.rpc('update_user_profile_with_pin', {
        _user_id: userId,
        _full_name: fullName,
        _phone: phone,
        _role: role,
        _pin: pin
      });
      if (altPinError) {
        console.error('Alternative PIN set also failed:', altPinError);
      } else {
        console.log('PIN set via alternative method');
      }
    } else {
      console.log('PIN hash set successfully');
    }

    console.log('Upserting user role:', role);
    const { error: roleUpsertError } = await supabaseAdmin
      .from('user_roles')
      .upsert({
        user_id: userId,
        role: role
      }, { onConflict: 'user_id' });

    if (roleUpsertError) {
      console.error('Error upserting role:', roleUpsertError);
    } else {
      console.log('User role upserted successfully');
    }

    const { data: verifyProfile, error: verifyError } = await supabaseAdmin
      .from('profiles')
      .select('id, full_name, phone, role')
      .eq('id', userId)
      .single();

    if (verifyError || !verifyProfile) {
      console.error('Profile verification failed:', verifyError);
      await supabaseAdmin.auth.admin.deleteUser(userId);
      return res.status(500).json({ error: 'Failed to create user profile. Please try again.' });
    }

    console.log('User created and verified successfully:', verifyProfile);

    return res.status(200).json({ 
      success: true, 
      message: 'User created successfully',
      userId: userId
    });
  } catch (error) {
    console.error('Error in create-user function:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
}

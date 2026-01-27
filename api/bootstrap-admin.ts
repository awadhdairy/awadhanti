import type { VercelRequest, VercelResponse } from '@vercel/node';
import { createClient } from '@supabase/supabase-js';

export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method === 'OPTIONS') {
    return res.status(200)
      .setHeader('Access-Control-Allow-Origin', '*')
      .setHeader('Access-Control-Allow-Headers', 'authorization, x-client-info, apikey, content-type, x-supabase-api-version')
      .setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS')
      .end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const { phone, pin } = req.body;

    const ADMIN_PHONE = process.env.BOOTSTRAP_ADMIN_PHONE;
    const ADMIN_PIN = process.env.BOOTSTRAP_ADMIN_PIN;

    if (!ADMIN_PHONE || !ADMIN_PIN) {
      console.error('Bootstrap admin credentials not configured in environment');
      return res.status(500).json({ error: 'Bootstrap not configured' });
    }

    if (phone !== ADMIN_PHONE || pin !== ADMIN_PIN) {
      return res.status(400).json({ error: 'Invalid bootstrap credentials' });
    }

    const supabaseUrl = process.env.VITE_SUPABASE_URL || process.env.SUPABASE_URL;
    const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

    if (!supabaseUrl || !supabaseServiceKey) {
      console.error('Missing Supabase environment variables');
      return res.status(500).json({ error: 'Server configuration error' });
    }

    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false
      }
    });

    const email = `${phone}@awadhdairy.com`;

    const { data: existingUsers } = await supabaseAdmin.auth.admin.listUsers();
    const existingUser = existingUsers?.users?.find(u => u.email === email);

    if (existingUser) {
      const { error: roleUpdateError } = await supabaseAdmin
        .from('user_roles')
        .update({ role: 'super_admin' })
        .eq('user_id', existingUser.id);

      if (roleUpdateError) {
        console.error('Role update error:', roleUpdateError);
      }

      const { error: profileUpdateError } = await supabaseAdmin
        .from('profiles')
        .update({ role: 'super_admin', full_name: 'Super Admin' })
        .eq('id', existingUser.id);

      if (profileUpdateError) {
        console.error('Profile update error:', profileUpdateError);
      }

      return res.status(200).json({ 
        success: true, 
        message: 'Admin account ready. You can now login.',
        user_id: existingUser.id
      });
    }

    const { data: authData, error: authError } = await supabaseAdmin.auth.admin.createUser({
      email,
      password: pin,
      email_confirm: true,
      user_metadata: {
        phone: phone,
        full_name: 'Super Admin'
      }
    });

    if (authError) {
      console.error('Auth error:', authError);
      return res.status(400).json({ error: authError.message });
    }

    const userId = authData.user.id;

    const { error: profileUpsertError } = await supabaseAdmin
      .from('profiles')
      .upsert({
        id: userId,
        full_name: 'Super Admin',
        phone: phone,
        role: 'super_admin',
        is_active: true
      }, { onConflict: 'id' });

    if (profileUpsertError) {
      console.error('Profile upsert error:', profileUpsertError);
    }

    const { error: roleUpsertError } = await supabaseAdmin
      .from('user_roles')
      .upsert({ user_id: userId, role: 'super_admin' }, { onConflict: 'user_id' });

    if (roleUpsertError) {
      console.error('Role upsert error:', roleUpsertError);
    }

    const { error: pinError } = await supabaseAdmin.rpc('update_pin_only', {
      _user_id: userId,
      _pin: pin
    });

    if (pinError) {
      console.error('PIN set error:', pinError);
    }

    return res.status(200).json({ 
      success: true, 
      message: 'Super admin account created successfully. You can now login.',
      user_id: userId
    });

  } catch (error) {
    console.error('Bootstrap error:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
}

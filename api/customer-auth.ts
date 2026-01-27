import type { VercelRequest, VercelResponse } from '@vercel/node';
import { createClient } from '@supabase/supabase-js';

const ALLOWED_ORIGINS = [
  'https://awadhd.lovable.app',
  'https://awadhdairy.vercel.app',
  'https://id-preview--c9769607-a092-45ff-8257-44be40434034.lovable.app',
  'http://localhost:5173',
  'http://localhost:3000',
  'http://localhost:5000',
];

function isValidOrigin(origin: string | null): boolean {
  if (!origin) return false;
  return ALLOWED_ORIGINS.some(allowed => origin.startsWith(allowed));
}

function getSafeRedirectUrl(origin: string | null, path: string): string {
  if (origin && isValidOrigin(origin)) {
    return `${origin}${path}`;
  }
  return path;
}

function getCorsOrigin(origin: string | null): string {
  if (origin && isValidOrigin(origin)) {
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
    const supabaseAnonKey = process.env.VITE_SUPABASE_PUBLISHABLE_KEY || process.env.SUPABASE_ANON_KEY;

    if (!supabaseUrl || !supabaseServiceKey || !supabaseAnonKey) {
      console.error('Missing Supabase environment variables');
      return res.status(500).json({ success: false, error: 'Server configuration error' });
    }

    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);

    const { action, phone, pin, currentPin, newPin, customerId } = req.body;
    console.log(`Customer auth action: ${action} for phone: ${phone?.slice(-4) || 'N/A'}`);

    if ((action === 'register' || action === 'login') && phone) {
      if (!/^\d{10}$/.test(phone)) {
        return res.status(400).json({ success: false, error: 'Phone number must be 10 digits' });
      }
    }

    switch (action) {
      case 'register': {
        if (!phone || !pin) {
          return res.status(400).json({ success: false, error: 'Phone and PIN are required' });
        }

        if (!/^\d{6}$/.test(pin)) {
          return res.status(400).json({ success: false, error: 'PIN must be 6 digits' });
        }

        const { data, error } = await supabaseAdmin.rpc('register_customer_account', {
          _phone: phone,
          _pin: pin
        });

        if (error) {
          console.error('Registration error:', error);
          return res.status(400).json({ success: false, error: error.message });
        }

        console.log('Registration result:', data);

        if (data?.approved) {
          const email = `customer_${phone}@awadhdairy.com`;
          
          const { data: authUser, error: authError } = await supabaseAdmin.auth.admin.createUser({
            email,
            password: pin,
            email_confirm: true,
            user_metadata: {
              phone,
              customer_id: data.customer_id,
              is_customer: true
            }
          });

          if (authError) {
            console.error('Auth user creation error:', authError);
            await supabaseAdmin.from('customer_accounts').delete().eq('customer_id', data.customer_id);
            return res.status(500).json({ success: false, error: 'Failed to create auth account' });
          }

          await supabaseAdmin.from('customer_accounts')
            .update({ user_id: authUser.user.id })
            .eq('customer_id', data.customer_id);

          console.log('Customer registered and auth user created:', authUser.user.id);
        }

        return res.status(200).json(data);
      }

      case 'login': {
        if (!phone || !pin) {
          return res.status(400).json({ success: false, error: 'Phone and PIN are required' });
        }

        if (!/^\d{6}$/.test(pin)) {
          return res.status(400).json({ success: false, error: 'PIN must be 6 digits' });
        }

        const { data: verifyResult, error: verifyError } = await supabaseAdmin.rpc('verify_customer_pin', {
          _phone: phone,
          _pin: pin
        });

        if (verifyError) {
          console.error('PIN verification error:', verifyError);
          return res.status(400).json({ success: false, error: verifyError.message });
        }

        if (!verifyResult || verifyResult.length === 0) {
          return res.status(401).json({ success: false, error: 'Invalid phone number or PIN' });
        }

        const account = verifyResult[0];

        if (!account.is_approved) {
          return res.status(403).json({ success: false, error: 'Account pending approval', pending: true });
        }

        const email = `customer_${phone}@awadhdairy.com`;
        const origin = req.headers.origin as string | null;
        const safeRedirect = getSafeRedirectUrl(origin, '/customer/dashboard');
        
        const { data: signInData, error: signInError } = await supabaseAdmin.auth.admin.generateLink({
          type: 'magiclink',
          email,
          options: {
            redirectTo: safeRedirect
          }
        });

        if (signInError) {
          console.error('Sign in error:', signInError);
          
          if (signInError.message.includes('User not found')) {
            const { data: newUser, error: createError } = await supabaseAdmin.auth.admin.createUser({
              email,
              password: pin,
              email_confirm: true,
              user_metadata: {
                phone,
                customer_id: account.customer_id,
                is_customer: true
              }
            });

            if (createError) {
              return res.status(500).json({ success: false, error: 'Authentication failed' });
            }

            await supabaseAdmin.from('customer_accounts')
              .update({ user_id: newUser.user.id })
              .eq('customer_id', account.customer_id);
          }
        }

        const supabaseClient = createClient(supabaseUrl, supabaseAnonKey);
        const { data: session, error: sessionError } = await supabaseClient.auth.signInWithPassword({
          email,
          password: pin
        });

        if (sessionError) {
          console.error('Session creation error:', sessionError);
          
          const { data: userData } = await supabaseAdmin.auth.admin.listUsers();
          const existingUser = userData?.users?.find(u => u.email === email);
          
          if (existingUser) {
            await supabaseAdmin.auth.admin.updateUserById(existingUser.id, {
              password: pin,
              email_confirm: true
            });

            const { data: retrySession, error: retryError } = await supabaseClient.auth.signInWithPassword({
              email,
              password: pin
            });

            if (retryError) {
              return res.status(500).json({ success: false, error: 'Authentication failed' });
            }

            return res.status(200).json({
              success: true,
              session: retrySession.session,
              customer_id: account.customer_id
            });
          }

          return res.status(500).json({ success: false, error: 'Authentication failed' });
        }

        return res.status(200).json({
          success: true,
          session: session.session,
          customer_id: account.customer_id
        });
      }

      case 'change-pin': {
        if (!customerId || !currentPin || !newPin) {
          return res.status(400).json({ success: false, error: 'Customer ID, current PIN, and new PIN are required' });
        }

        if (!/^\d{6}$/.test(newPin)) {
          return res.status(400).json({ success: false, error: 'New PIN must be 6 digits' });
        }

        const { data, error } = await supabaseAdmin.rpc('update_customer_pin', {
          _customer_id: customerId,
          _current_pin: currentPin,
          _new_pin: newPin
        });

        if (error) {
          console.error('PIN update error:', error);
          return res.status(400).json({ success: false, error: error.message });
        }

        const { data: account } = await supabaseAdmin
          .from('customer_accounts')
          .select('user_id, phone')
          .eq('customer_id', customerId)
          .single();

        if (account?.user_id) {
          await supabaseAdmin.auth.admin.updateUserById(account.user_id, {
            password: newPin
          });
        }

        return res.status(200).json(data);
      }

      default:
        return res.status(400).json({ success: false, error: 'Invalid action' });
    }
  } catch (error) {
    console.error('Customer auth error:', error);
    return res.status(500).json({ success: false, error: 'Internal server error' });
  }
}

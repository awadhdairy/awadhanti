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
    const supabaseAnonKey = process.env.VITE_SUPABASE_PUBLISHABLE_KEY || process.env.SUPABASE_ANON_KEY;

    if (!supabaseUrl || !supabaseServiceKey || !supabaseAnonKey) {
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
      return res.status(401).json({ error: 'No authorization header' });
    }

    const token = authHeader.replace('Bearer ', '');
    const supabaseClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: `Bearer ${token}` } }
    });

    const { data: { user: requestingUser }, error: userError } = await supabaseClient.auth.getUser();
    
    if (userError || !requestingUser) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const { data: roleData, error: roleError } = await supabaseAdmin
      .from('user_roles')
      .select('role')
      .eq('user_id', requestingUser.id)
      .single();

    if (roleError || roleData?.role !== 'super_admin') {
      return res.status(403).json({ error: 'Only super_admin can delete users' });
    }

    const { userId, action, userIds } = req.body;

    if (action === 'find-and-cleanup-orphaned') {
      console.log('Finding and cleaning up orphaned users dynamically...');
      
      const { data: authUsers, error: listError } = await supabaseAdmin.auth.admin.listUsers();
      if (listError) {
        console.error('Failed to list auth users:', listError);
        return res.status(500).json({ error: 'Failed to list auth users' });
      }

      const { data: profiles, error: profilesError } = await supabaseAdmin
        .from('profiles')
        .select('id');

      if (profilesError) {
        console.error('Failed to list profiles:', profilesError);
        return res.status(500).json({ error: 'Failed to list profiles' });
      }

      const profileIds = new Set(profiles?.map(p => p.id) || []);
      
      const orphanedUsers = authUsers?.users?.filter(u => 
        u.email?.endsWith('@awadhdairy.com') && 
        !profileIds.has(u.id) &&
        u.id !== requestingUser.id
      ) || [];

      console.log(`Found ${orphanedUsers.length} orphaned users`);

      if (orphanedUsers.length === 0) {
        return res.status(200).json({ 
          success: true, 
          message: 'No orphaned users found',
          deleted_count: 0
        });
      }

      const results: Array<{ id: string; email: string | undefined; success: boolean; error?: string }> = [];
      for (const orphan of orphanedUsers) {
        try {
          const { error: deleteError } = await supabaseAdmin.auth.admin.deleteUser(orphan.id);
          if (deleteError) {
            console.error(`Failed to delete orphaned user ${orphan.id}:`, deleteError);
            results.push({ id: orphan.id, email: orphan.email, success: false, error: deleteError.message });
          } else {
            console.log(`Deleted orphaned user: ${orphan.id} (${orphan.email})`);
            results.push({ id: orphan.id, email: orphan.email, success: true });
          }
        } catch (err) {
          console.error(`Error deleting orphaned user ${orphan.id}:`, err);
          results.push({ id: orphan.id, email: orphan.email, success: false, error: String(err) });
        }
      }

      const deletedCount = results.filter(r => r.success).length;

      await supabaseAdmin
        .from('activity_logs')
        .insert({
          user_id: requestingUser.id,
          action: 'orphaned_users_cleanup',
          entity_type: 'user',
          details: {
            deleted_count: deletedCount,
            failed_count: results.filter(r => !r.success).length,
            results,
            deleted_by: requestingUser.email,
          },
        });

      return res.status(200).json({ 
        success: true, 
        message: `Cleaned up ${deletedCount} orphaned user(s)`,
        deleted_count: deletedCount,
        results 
      });
    }

    if (action === 'cleanup-orphaned' && userIds && Array.isArray(userIds)) {
      console.log('Cleaning up orphaned users (legacy):', userIds);
      const results: Array<{ id: string; success: boolean; error?: string }> = [];
      
      for (const id of userIds) {
        try {
          const { error: deleteError } = await supabaseAdmin.auth.admin.deleteUser(id);
          if (deleteError) {
            console.error(`Failed to delete orphaned user ${id}:`, deleteError);
            results.push({ id, success: false, error: deleteError.message });
          } else {
            console.log(`Deleted orphaned user: ${id}`);
            results.push({ id, success: true });
          }
        } catch (err) {
          console.error(`Error deleting orphaned user ${id}:`, err);
          results.push({ id, success: false, error: String(err) });
        }
      }

      await supabaseAdmin
        .from('activity_logs')
        .insert({
          user_id: requestingUser.id,
          action: 'orphaned_users_cleanup',
          entity_type: 'user',
          details: {
            deleted_count: results.filter(r => r.success).length,
            failed_count: results.filter(r => !r.success).length,
            results,
            deleted_by: requestingUser.email,
          },
        });

      return res.status(200).json({ 
        success: true, 
        message: `Cleaned up ${results.filter(r => r.success).length} orphaned users`,
        results 
      });
    }

    if (!userId) {
      return res.status(400).json({ error: 'User ID is required' });
    }

    if (userId === requestingUser.id) {
      return res.status(400).json({ error: 'Cannot delete your own account' });
    }

    const { data: targetRoleData } = await supabaseAdmin
      .from('user_roles')
      .select('role')
      .eq('user_id', userId)
      .single();

    if (targetRoleData?.role === 'super_admin') {
      return res.status(403).json({ error: 'Cannot delete super_admin accounts' });
    }

    const { data: targetProfile } = await supabaseAdmin
      .from('profiles')
      .select('full_name, phone')
      .eq('id', userId)
      .single();

    const { error: deleteError } = await supabaseAdmin.auth.admin.deleteUser(userId);

    if (deleteError) {
      console.error('Error deleting user:', deleteError);
      return res.status(500).json({ error: 'Failed to delete user' });
    }

    await supabaseAdmin
      .from('activity_logs')
      .insert({
        user_id: requestingUser.id,
        action: 'user_deleted',
        entity_type: 'user',
        entity_id: userId,
        details: {
          deleted_user_name: targetProfile?.full_name,
          deleted_user_phone: targetProfile?.phone,
          deleted_by: requestingUser.email,
        },
      });

    return res.status(200).json({ 
      success: true, 
      message: `User ${targetProfile?.full_name || 'unknown'} has been permanently deleted` 
    });

  } catch (error) {
    console.error('Error:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
}

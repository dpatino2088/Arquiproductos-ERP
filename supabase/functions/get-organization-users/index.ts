// Supabase Edge Function: Get Organization Users
// Returns list of users in an organization with their emails

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return new Response(
      JSON.stringify({ error: 'Method not allowed' }),
      {
        status: 405,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }

  try {
    // Get the service role key from environment
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error('Missing Supabase environment variables');
    }

    // Create admin client with service role key
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    const supabaseClient = createClient(supabaseUrl, supabaseServiceKey);

    // Parse request body
    const { organizationId } = await req.json();

    if (!organizationId) {
      return new Response(
        JSON.stringify({ error: 'Missing organizationId' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    // Get organization users
    const { data: orgUsers, error: orgUsersError } = await supabaseClient
      .from('OrganizationUsers')
      .select('id, role, created_at, user_id, invited_by')
      .eq('organization_id', organizationId)
      .eq('deleted', false)
      .order('created_at', { ascending: false });

    if (orgUsersError) {
      throw new Error(`Failed to fetch organization users: ${orgUsersError.message}`);
    }

    // Get emails for all users
    const { data: allUsers, error: usersError } = await supabaseAdmin.auth.admin.listUsers();

    if (usersError) {
      throw new Error(`Failed to fetch users: ${usersError.message}`);
    }

    // Map organization users with emails
    const usersWithEmails = (orgUsers || []).map((orgUser) => {
      const authUser = allUsers.users.find(u => u.id === orgUser.user_id);
      return {
        id: orgUser.id,
        role: orgUser.role,
        created_at: orgUser.created_at,
        user_id: orgUser.user_id,
        email: authUser?.email || undefined,
        invited_by: orgUser.invited_by || undefined,
      };
    });

    return new Response(
      JSON.stringify({
        success: true,
        users: usersWithEmails,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  } catch (error: any) {
    console.error('Error in get-organization-users function:', error);
    return new Response(
      JSON.stringify({
        error: error.message || 'Internal server error',
        details: error.toString(),
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});


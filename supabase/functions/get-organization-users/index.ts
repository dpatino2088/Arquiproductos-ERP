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

    // Get organization users (now includes name and email directly from table)
    const { data: orgUsers, error: orgUsersError } = await supabaseClient
      .from('OrganizationUsers')
      .select('id, role, created_at, user_id, user_name, email, invited_by')
      .eq('organization_id', organizationId)
      .eq('deleted', false)
      .eq('is_system', false)
      .order('created_at', { ascending: false });

    if (orgUsersError) {
      throw new Error(`Failed to fetch organization users: ${orgUsersError.message}`);
    }

    // If name or email are missing, try to get them from auth.users as fallback
    const usersWithData = await Promise.all((orgUsers || []).map(async (orgUser) => {
      // If we already have user_name and email, use them
      if (orgUser.user_name && orgUser.email) {
        return {
          id: orgUser.id,
          role: orgUser.role,
          created_at: orgUser.created_at,
          user_id: orgUser.user_id,
          name: orgUser.user_name,
          email: orgUser.email,
          invited_by: orgUser.invited_by || undefined,
        };
      }

      // Otherwise, fetch from auth.users
      try {
        const { data: authUser, error: getUserError } = await supabaseAdmin.auth.admin.getUserById(orgUser.user_id);
        
        if (!getUserError && authUser?.user) {
          const userName = orgUser.user_name || authUser.user.user_metadata?.name || authUser.user.email?.split('@')[0] || '';
          const email = orgUser.email || authUser.user.email || '';
          
          // Update OrganizationUsers with user_name and email if missing
          if (!orgUser.user_name || !orgUser.email) {
            await supabaseClient
              .from('OrganizationUsers')
              .update({ user_name: userName, email })
              .eq('id', orgUser.id);
          }
          
          return {
            id: orgUser.id,
            role: orgUser.role,
            created_at: orgUser.created_at,
            user_id: orgUser.user_id,
            name: userName,
            email,
            invited_by: orgUser.invited_by || undefined,
          };
        }
      } catch (err) {
        console.error(`Error fetching user ${orgUser.user_id}:`, err);
      }

      // Fallback if we can't get user data
      return {
        id: orgUser.id,
        role: orgUser.role,
        created_at: orgUser.created_at,
        user_id: orgUser.user_id,
        name: orgUser.user_name || '',
        email: orgUser.email || '',
        invited_by: orgUser.invited_by || undefined,
      };
    }));

    const usersWithEmails = usersWithData;

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


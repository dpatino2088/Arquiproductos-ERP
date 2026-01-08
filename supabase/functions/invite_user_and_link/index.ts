// Supabase Edge Function: Invite User and Link to Existing Record
// This function invites a user via email and links the auth user_id to an existing
// CustomerPortalUsers or OrganizationUsers record

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Max-Age': '86400',
};

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { 
      status: 200,
      headers: corsHeaders 
    });
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
    // Get environment variables
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    const appUrl = Deno.env.get('APP_URL') || 'http://localhost:5173';

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

    // Create regular client for RLS queries
    const supabaseClient = createClient(supabaseUrl, supabaseServiceKey);

    // Get auth token from request
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Missing authorization header' }),
        {
          status: 401,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    // Verify caller is authenticated
    const token = authHeader.replace('Bearer ', '');
    const { data: { user: callerUser }, error: authError } = await supabaseAdmin.auth.getUser(token);
    
    if (authError || !callerUser) {
      return new Response(
        JSON.stringify({ error: 'Invalid or expired token' }),
        {
          status: 401,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    // Parse request body
    const {
      organization_id,
      target,
      record_id,
      email,
      redirect_to,
    } = await req.json();

    // Validate required fields
    if (!organization_id || !target || !record_id || !email) {
      return new Response(
        JSON.stringify({ 
          error: 'Missing required fields: organization_id, target, record_id, email' 
        }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    // Validate target
    if (target !== 'portal' && target !== 'org') {
      return new Response(
        JSON.stringify({ error: 'Invalid target. Must be "portal" or "org"' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    // Validate email format
    const normalizedEmail = email.trim().toLowerCase();
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(normalizedEmail)) {
      return new Response(
        JSON.stringify({ error: 'Invalid email format' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    // Validate UUIDs
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    if (!uuidRegex.test(organization_id) || !uuidRegex.test(record_id)) {
      return new Response(
        JSON.stringify({ error: 'Invalid UUID format for organization_id or record_id' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    // Verify caller has permission in organization
    // Check if caller is SuperAdmin
    const { data: platformAdmin } = await supabaseClient
      .from('PlatformAdmins')
      .select('user_id')
      .eq('user_id', callerUser.id)
      .maybeSingle();

    const isSuperAdmin = !!platformAdmin;

    if (!isSuperAdmin) {
      // Check if caller belongs to organization and has admin role
      const { data: callerOrgUser, error: callerError } = await supabaseClient
        .from('OrganizationUsers')
        .select('role')
        .eq('organization_id', organization_id)
        .eq('user_id', callerUser.id)
        .eq('deleted', false)
        .maybeSingle();

      if (callerError || !callerOrgUser) {
        return new Response(
          JSON.stringify({ error: 'You do not have access to this organization' }),
          {
            status: 403,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          }
        );
      }

      // Only admins and owners can invite
      if (callerOrgUser.role !== 'admin' && callerOrgUser.role !== 'owner' && callerOrgUser.role !== 'superadmin') {
        return new Response(
          JSON.stringify({ error: 'Only admins and owners can invite users' }),
          {
            status: 403,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          }
        );
      }
    }

    // Verify the record exists and belongs to the organization
    if (target === 'portal') {
      const { data: portalUser, error: portalError } = await supabaseClient
        .from('CustomerPortalUsers')
        .select('id, organization_id, user_id, user_email, status')
        .eq('id', record_id)
        .eq('organization_id', organization_id)
        .eq('deleted', false)
        .maybeSingle();

      if (portalError || !portalUser) {
        return new Response(
          JSON.stringify({ error: 'Portal user record not found or access denied' }),
          {
            status: 404,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          }
        );
      }

      // Verify email matches
      if (portalUser.user_email?.toLowerCase() !== normalizedEmail) {
        return new Response(
          JSON.stringify({ error: 'Email does not match portal user record' }),
          {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          }
        );
      }

      // Check if already linked
      if (portalUser.user_id) {
        return new Response(
          JSON.stringify({ 
            error: 'Portal user is already linked to an auth user',
            auth_user_id: portalUser.user_id 
          }),
          {
            status: 409,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          }
        );
      }
    } else if (target === 'org') {
      const { data: orgUser, error: orgError } = await supabaseClient
        .from('OrganizationUsers')
        .select('id, organization_id, user_id, email, status')
        .eq('id', record_id)
        .eq('organization_id', organization_id)
        .eq('deleted', false)
        .maybeSingle();

      if (orgError || !orgUser) {
        return new Response(
          JSON.stringify({ error: 'Organization user record not found or access denied' }),
          {
            status: 404,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          }
        );
      }

      // Verify email matches
      if (orgUser.email?.toLowerCase() !== normalizedEmail) {
        return new Response(
          JSON.stringify({ error: 'Email does not match organization user record' }),
          {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          }
        );
      }

      // Check if already linked
      if (orgUser.user_id) {
        return new Response(
          JSON.stringify({ 
            error: 'Organization user is already linked to an auth user',
            auth_user_id: orgUser.user_id 
          }),
          {
            status: 409,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          }
        );
      }
    }

    // Check if user already exists in auth
    const { data: existingAuthUser, error: getUserError } = await supabaseAdmin.auth.admin.getUserByEmail(normalizedEmail);

    let authUserId: string;

    if (getUserError && getUserError.message?.includes('User not found')) {
      // User doesn't exist - invite them
      const redirectUrl = redirect_to || `${appUrl}/auth/callback?next=/dashboard`;
      
      const { data: inviteData, error: inviteError } = await supabaseAdmin.auth.admin.inviteUserByEmail(
        normalizedEmail,
        {
          redirectTo: redirectUrl,
          data: {
            organization_id: organization_id,
            target: target,
            record_id: record_id,
          },
        }
      );

      if (inviteError) {
        console.error('Error inviting user:', inviteError);
        throw new Error(`Failed to send invitation: ${inviteError.message}`);
      }

      if (!inviteData?.user) {
        throw new Error('Invitation sent but no user data returned');
      }

      authUserId = inviteData.user.id;
      console.log('Invitation sent, user ID:', authUserId);
    } else if (getUserError) {
      console.error('Error checking existing user:', getUserError);
      throw new Error('Failed to check existing user');
    } else if (existingAuthUser?.user) {
      // User already exists - use their ID
      authUserId = existingAuthUser.user.id;
      console.log('User already exists, linking to record:', authUserId);
    } else {
      throw new Error('Unexpected state: no user found and no error');
    }

    // Update the record with user_id and set status to 'invited'
    if (target === 'portal') {
      const { error: updateError } = await supabaseClient
        .from('CustomerPortalUsers')
        .update({
          user_id: authUserId,
          status: 'invited',
          updated_at: new Date().toISOString(),
        })
        .eq('id', record_id)
        .eq('organization_id', organization_id);

      if (updateError) {
        console.error('Error updating CustomerPortalUsers:', updateError);
        throw new Error(`Failed to link portal user: ${updateError.message}`);
      }
    } else if (target === 'org') {
      const { error: updateError } = await supabaseClient
        .from('OrganizationUsers')
        .update({
          user_id: authUserId,
          status: 'invited',
          updated_at: new Date().toISOString(),
        })
        .eq('id', record_id)
        .eq('organization_id', organization_id);

      if (updateError) {
        console.error('Error updating OrganizationUsers:', updateError);
        throw new Error(`Failed to link organization user: ${updateError.message}`);
      }
    }

    // Return success
    return new Response(
      JSON.stringify({
        success: true,
        auth_user_id: authUserId,
        message: 'User invited and linked successfully',
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  } catch (error: any) {
    console.error('Error in invite_user_and_link function:', error);
    
    let statusCode = 500;
    let errorMessage = error.message || 'Internal server error';
    
    // Handle specific error types
    if (error.message?.includes('permission') || error.message?.includes('403')) {
      statusCode = 403;
    } else if (error.message?.includes('already') || error.message?.includes('409')) {
      statusCode = 409;
    } else if (error.message?.includes('not found') || error.message?.includes('404')) {
      statusCode = 404;
    } else if (error.message?.includes('Missing Supabase environment variables')) {
      statusCode = 500;
      errorMessage = 'Server configuration error. Please contact administrator.';
    }
    
    return new Response(
      JSON.stringify({
        success: false,
        error: errorMessage,
      }),
      {
        status: statusCode,
        headers: { 
          ...corsHeaders, 
          'Content-Type': 'application/json' 
        },
      }
    );
  }
});


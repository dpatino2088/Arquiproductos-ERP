// Supabase Edge Function: Invite User to Organization
// This function invites a user to an organization with a specific role
// Uses inviteUserByEmail to send magic link emails

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Max-Age': '86400',
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
    const {
      organizationId,
      email,
      role,
      invitedByUserId,
    } = await req.json();

    if (!organizationId || !email || !role || !invitedByUserId) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: organizationId, email, role, invitedByUserId' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    // Validate and normalize email
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

    // Validate role
    if (!['owner', 'admin', 'member', 'viewer'].includes(role)) {
      return new Response(
        JSON.stringify({ error: 'Invalid role. Must be one of: owner, admin, member, viewer' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    console.log('Inviting user to organization:', { organizationId, email: normalizedEmail, role, invitedByUserId });

    // 1) Verify that the inviter has permission (owner or admin)
    const { data: inviterRole, error: inviterError } = await supabaseClient
      .from('OrganizationUsers')
      .select('role')
      .eq('organization_id', organizationId)
      .eq('user_id', invitedByUserId)
      .eq('deleted', false)
      .single();

    if (inviterError || !inviterRole) {
      return new Response(
        JSON.stringify({ error: 'Inviter does not have access to this organization' }),
        {
          status: 403,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    const inviterRoleValue = inviterRole.role;
    if (inviterRoleValue !== 'owner' && inviterRoleValue !== 'admin') {
      return new Response(
        JSON.stringify({ error: 'Only owners and admins can invite users' }),
        {
          status: 403,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    // 2) Check if user already exists in auth.users
    let userId: string;
    let isNewUser = false;

    // Try to get user by email
    const { data: existingUser, error: getUserError } = await supabaseAdmin.auth.admin.getUserByEmail(normalizedEmail);

    if (getUserError && getUserError.message?.includes('User not found')) {
      // User doesn't exist - invite them
      console.log('User does not exist, sending invitation email:', normalizedEmail);
      isNewUser = true;

      // Get the app URL from environment or construct from request
      let appUrl = Deno.env.get('APP_URL');
      
      if (!appUrl) {
        const origin = req.headers.get('origin') || req.headers.get('referer') || '';
        try {
          appUrl = origin ? new URL(origin).origin : 'http://localhost:5173';
        } catch {
          appUrl = 'http://localhost:5173';
        }
      }
      
      // Construct redirect URL for the magic link
      const redirectTo = `${appUrl}/auth/callback?next=/dashboard`;

      const { data: inviteData, error: inviteError } = await supabaseAdmin.auth.admin.inviteUserByEmail(
        normalizedEmail,
        {
          redirectTo: redirectTo,
          data: {
            organization_id: organizationId,
            role: role,
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

      userId = inviteData.user.id;
      console.log('Invitation sent, user ID:', userId);
    } else if (getUserError) {
      // Unexpected error
      console.error('Error checking existing user:', getUserError);
      throw new Error('Failed to check existing user');
    } else if (existingUser?.user) {
      // User already exists - reuse their ID
      console.log('User already exists:', existingUser.user.id);
      userId = existingUser.user.id;

      // Update user_metadata if needed
      const currentMetadata = existingUser.user.user_metadata || {};
      const needsUpdate = !currentMetadata.default_organization_id || 
                         currentMetadata.default_organization_id !== organizationId;

      if (needsUpdate) {
        const updatedMetadata = {
          ...currentMetadata,
          global_role: 'org_user',
          default_organization_id: organizationId,
        };

        const { error: updateError } = await supabaseAdmin.auth.admin.updateUserById(
          userId,
          { user_metadata: updatedMetadata }
        );

        if (updateError) {
          console.error('Error updating user metadata:', updateError);
          // Continue anyway - the user exists
        }
      }
    } else {
      throw new Error('Unexpected state: no user found and no error');
    }

    // 3) Check if user is already in OrganizationUsers for this organization
    const { data: existingOrgUser, error: checkError } = await supabaseClient
      .from('OrganizationUsers')
      .select('id, deleted')
      .eq('organization_id', organizationId)
      .eq('user_id', userId)
      .single();

    if (checkError && checkError.code !== 'PGRST116') { // PGRST116 = not found
      console.error('Error checking existing OrganizationUsers:', checkError);
      throw new Error('Failed to check existing organization membership');
    }

    if (existingOrgUser) {
      if (existingOrgUser.deleted) {
        // Reactivate the user
        const { error: reactivateError } = await supabaseClient
          .from('OrganizationUsers')
          .update({
            role: role,
            deleted: false,
            updated_at: new Date().toISOString(),
          })
          .eq('id', existingOrgUser.id);

        if (reactivateError) {
          throw new Error('Failed to reactivate user in organization');
        }
      } else {
        // User already exists and is active
        return new Response(
          JSON.stringify({ 
            error: 'User is already a member of this organization',
            userId: userId,
          }),
          {
            status: 409,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          }
        );
      }
    } else {
      // Insert new OrganizationUsers entry
      const { error: insertError } = await supabaseClient
        .from('OrganizationUsers')
        .insert({
          organization_id: organizationId,
          user_id: userId,
          role: role,
          invited_by: invitedByUserId,
          deleted: false,
        });

      if (insertError) {
        console.error('Error inserting OrganizationUsers:', insertError);
        throw new Error(`Failed to add user to organization: ${insertError.message}`);
      }
    }

    // 4) Get updated list of organization users
    const { data: orgUsers, error: fetchError } = await supabaseClient
      .from('OrganizationUsers')
      .select(`
        id,
        role,
        created_at,
        user_id,
        users:user_id (
          email
        )
      `)
      .eq('organization_id', organizationId)
      .eq('deleted', false)
      .order('created_at', { ascending: false });

    if (fetchError) {
      console.error('Error fetching organization users:', fetchError);
      // Don't fail the whole operation, just return without the list
    }

    // 5) Return success response
    return new Response(
      JSON.stringify({
        success: true,
        userId: userId,
        isNewUser: isNewUser,
        message: isNewUser 
          ? 'Invitation email sent successfully' 
          : 'User has been added to the organization',
        users: orgUsers || [],
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  } catch (error: any) {
    console.error('Error in invite-user-to-organization function:', error);
    
    // Determine appropriate status code
    let statusCode = 500;
    let errorMessage = error.message || 'Internal server error';
    
    // Handle specific error types
    if (error.message?.includes('permission') || error.message?.includes('403')) {
      statusCode = 403;
      errorMessage = 'No tienes permisos para invitar usuarios. Solo owners y admins pueden invitar usuarios.';
    } else if (error.message?.includes('already') || error.message?.includes('409')) {
      statusCode = 409;
      errorMessage = error.message;
    } else if (error.message?.includes('not found') || error.message?.includes('404')) {
      statusCode = 404;
      errorMessage = 'Recurso no encontrado';
    }
    
    return new Response(
      JSON.stringify({
        success: false,
        error: errorMessage,
      }),
      {
        status: statusCode,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});


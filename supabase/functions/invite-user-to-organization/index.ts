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
  // IMPORTANT: Must return 200 OK with CORS headers for preflight to pass
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
      name,
      email,
      role,
      invitedByUserId,
    } = await req.json();

    // Validación mejorada de campos requeridos
    if (!organizationId || !email || !role || !invitedByUserId) {
      return new Response(
        JSON.stringify({ 
          error: 'Missing required fields: organizationId, email, role, invitedByUserId',
          received: { 
            hasOrganizationId: !!organizationId,
            hasEmail: !!email,
            hasRole: !!role,
            hasInvitedByUserId: !!invitedByUserId
          }
        }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    // Validar que organizationId es un UUID válido
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    if (!uuidRegex.test(organizationId)) {
      return new Response(
        JSON.stringify({ error: 'Invalid organizationId format. Must be a valid UUID.' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    // Verificar que la organización existe y no está eliminada
    const { data: org, error: orgError } = await supabaseClient
      .from('Organizations')
      .select('id, organization_name, deleted')
      .eq('id', organizationId)
      .single();

    if (orgError || !org) {
      console.error('Organization not found:', { organizationId, error: orgError });
      return new Response(
        JSON.stringify({ error: 'Organization not found or has been deleted' }),
        {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    if (org.deleted) {
      return new Response(
        JSON.stringify({ error: 'Cannot add users to a deleted organization' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    console.log('Creating user for organization:', org.organization_name, '(', organizationId, ')');

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

    // 1) First check if inviter is SuperAdmin
    const { data: platformAdmin } = await supabaseClient
      .from('PlatformAdmins')
      .select('user_id')
      .eq('user_id', invitedByUserId)
      .maybeSingle();

    const isSuperAdmin = !!platformAdmin;

    // 2) If not SuperAdmin, verify they have permission in the organization
    let inviterRoleValue: string | null = null;
    
    if (!isSuperAdmin) {
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

      inviterRoleValue = inviterRole.role;
      if (inviterRoleValue !== 'owner' && inviterRoleValue !== 'admin') {
        return new Response(
          JSON.stringify({ error: 'Only owners and admins can invite users' }),
          {
            status: 403,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          }
        );
      }

      // IMPORTANT: Admins cannot create owners, only owners can create owners
      if (role === 'owner' && inviterRoleValue !== 'owner') {
        return new Response(
          JSON.stringify({ 
            error: 'Only owners and superadmins can create users with owner role' 
          }),
          {
            status: 403,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          }
        );
      }
    } else {
      // SuperAdmin can create any role, including owners
      console.log('SuperAdmin is creating user - bypassing role restrictions');
    }

    // 2) Check if user already exists in auth.users
    let userId: string;
    let isNewUser = false;
    let userName: string | undefined;
    let userEmail: string = normalizedEmail;

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
      // Use name from request if provided, otherwise try to get from user metadata or email
      userName = name?.trim() || inviteData.user.user_metadata?.name || normalizedEmail.split('@')[0];
      userEmail = inviteData.user.email || normalizedEmail;
      console.log('Invitation sent, user ID:', userId);
    } else if (getUserError) {
      // Unexpected error
      console.error('Error checking existing user:', getUserError);
      throw new Error('Failed to check existing user');
    } else if (existingUser?.user) {
      // User already exists - reuse their ID
      console.log('User already exists:', existingUser.user.id);
      userId = existingUser.user.id;
      // Use name from request if provided, otherwise try to get from user metadata or email
      userName = name?.trim() || existingUser.user.user_metadata?.name || existingUser.user.email?.split('@')[0] || normalizedEmail.split('@')[0];
      userEmail = existingUser.user.email || normalizedEmail;

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
            user_name: userName,
            email: userEmail,
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
      // Asegurar que organization_id se asigna correctamente
      const insertData = {
        organization_id: organizationId, // ✅ Siempre usar el organizationId del request
        user_id: userId,
        role: role,
        user_name: userName,
        email: userEmail,
        invited_by: invitedByUserId,
        deleted: false,
      };

      console.log('Inserting OrganizationUser with data:', {
        organization_id: insertData.organization_id,
        user_id: insertData.user_id,
        role: insertData.role,
        email: insertData.email,
      });

      const { error: insertError } = await supabaseClient
        .from('OrganizationUsers')
        .insert(insertData);

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
        name,
        email
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
    } else if (error.message?.includes('Missing Supabase environment variables')) {
      statusCode = 500;
      errorMessage = 'Server configuration error. Please contact administrator.';
    }
    
    // IMPORTANT: Always include CORS headers in error responses
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


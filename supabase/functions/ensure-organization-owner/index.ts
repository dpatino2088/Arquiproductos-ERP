// Supabase Edge Function: Ensure Organization Owner User
// This function creates/invites a user for an organization's main email
// and links them as the owner.

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

  try {
    // Get the service role key from environment (set in Supabase dashboard)
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

    // Parse request body
    const { organizationId, mainEmail } = await req.json();

    if (!organizationId || !mainEmail) {
      return new Response(
        JSON.stringify({ error: 'Missing organizationId or mainEmail' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    console.log('Ensuring owner user for organization:', { organizationId, mainEmail });

    // 1) Check if there is already an auth user with this email
    const { data: existingUsers, error: listError } =
      await supabaseAdmin.auth.admin.listUsers();

    if (listError) {
      console.error('Error listing auth users:', listError);
      throw listError;
    }

    // Find user by email
    let authUser = existingUsers?.users?.find((u) => u.email === mainEmail) ?? null;

    // 2) If no auth user, invite one
    if (!authUser) {
      console.log('No existing user found, inviting new user...');
      
      const { data: invited, error: inviteError } =
        await supabaseAdmin.auth.admin.inviteUserByEmail(mainEmail, {
          redirectTo: `${Deno.env.get('SITE_URL') || 'http://localhost:5173'}/auth/callback?source=invite`,
        });

      if (inviteError) {
        console.error('Error inviting org owner:', inviteError);
        throw inviteError;
      }

      authUser = invited?.user ?? null;
    }

    if (!authUser) {
      throw new Error('Could not resolve or create auth user for organization owner.');
    }

    console.log('Auth user resolved:', { userId: authUser.id, email: authUser.email });

    const authUserId = authUser.id;

    // 3) Ensure a row exists in "Users"
    const { data: userRow, error: userUpsertError } = await supabaseAdmin
      .from('Users')
      .upsert(
        {
          id: authUserId,
          full_name: authUser.user_metadata?.full_name ?? authUser.user_metadata?.name ?? '',
          avatar_url: authUser.user_metadata?.avatar_url ?? '',
        },
        { onConflict: 'id' }
      )
      .select()
      .single();

    if (userUpsertError) {
      console.error('Error upserting Users row:', userUpsertError);
      throw userUpsertError;
    }

    console.log('Users row ensured:', userRow.id);

    // 4) Ensure an "OrganizationUsers" row with role = 'owner'
    const { data: orgUserRow, error: orgUserError } = await supabaseAdmin
      .from('OrganizationUsers')
      .upsert(
        {
          organization_id: organizationId,
          user_id: userRow.id,
          role: 'owner',
          status: 'invited',
        },
        { onConflict: 'organization_id,user_id' }
      )
      .select()
      .single();

    if (orgUserError) {
      console.error('Error upserting OrganizationUsers (owner):', orgUserError);
      throw orgUserError;
    }

    console.log('OrganizationUsers row ensured:', orgUserRow.id);

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Organization owner user created successfully',
        data: {
          authUser: {
            id: authUser.id,
            email: authUser.email,
          },
          userRow: {
            id: userRow.id,
            full_name: userRow.full_name,
          },
          orgUserRow: {
            id: orgUserRow.id,
            role: orgUserRow.role,
            status: orgUserRow.status,
          },
        },
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  } catch (error) {
    console.error('Error in ensure-organization-owner function:', error);
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


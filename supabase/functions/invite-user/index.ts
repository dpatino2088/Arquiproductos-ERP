// Supabase Edge Function: Unified Invite User
// This function invites users to either OrganizationUsers or CompanyPortalUsers
// Uses Supabase Auth admin API to send magic link emails

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Max-Age': '86400',
};

type InvitePayload = {
  email: string;
  user_type: 'org' | 'portal';
  organization_id: string;
  company_id?: string | null;
  role: string;
  redirect_to?: string;
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      status: 200,
      headers: corsHeaders,
    });
  }

  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed. Use POST.' }, 405);
  }

  try {
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
    const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

    if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
      return json(
        { error: 'Missing environment variables: SUPABASE_URL or SERVICE_ROLE_KEY' },
        500
      );
    }

    // Create admin client with service role key
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    // Parse request body
    let payload: InvitePayload;
    try {
      payload = await req.json();
    } catch {
      return json({ error: 'Invalid JSON in request body' }, 400);
    }

    const { email, user_type, organization_id, company_id, role, redirect_to } = payload;

    // Validate required fields
    if (!email || !user_type || !organization_id || !role) {
      return json(
        {
          error: 'Missing required fields',
          required: ['email', 'user_type', 'organization_id', 'role'],
          received: {
            hasEmail: !!email,
            hasUserType: !!user_type,
            hasOrganizationId: !!organization_id,
            hasRole: !!role,
          },
        },
        400
      );
    }

    // Validate user_type
    if (user_type !== 'org' && user_type !== 'portal') {
      return json(
        { error: 'user_type must be "org" or "portal"' },
        400
      );
    }

    // Validate portal user requires company_id
    if (user_type === 'portal' && !company_id) {
      return json(
        { error: 'company_id is required for portal users' },
        400
      );
    }

    // Normalize email (trim + lowercase)
    const normalizedEmail = email.trim().toLowerCase();
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(normalizedEmail)) {
      return json({ error: 'Invalid email format' }, 400);
    }

    // Default redirect_to if not provided
    // Extract site URL from SUPABASE_URL or use default
    let siteUrl = Deno.env.get('SITE_URL');
    if (!siteUrl) {
      // Try to extract from SUPABASE_URL (remove .supabase.co suffix)
      siteUrl = SUPABASE_URL.replace(/\.supabase\.co$/, '').replace(/https?:\/\//, 'http://localhost:5173');
      // For production, use https
      if (!siteUrl.includes('localhost')) {
        siteUrl = SUPABASE_URL.replace(/\.supabase\.co$/, '').replace(/https?:\/\//, 'https://');
      }
    }
    // Include email parameter for invite safety (prevent accepting invite with different user logged in)
    const defaultRedirectTo = `${siteUrl}/auth/callback?next=/set-password&email=${encodeURIComponent(normalizedEmail)}`;
    const finalRedirectTo = redirect_to || defaultRedirectTo;

    // Check if user exists in auth
    let userId: string;
    let isExistingUser = false;

    try {
      const { data: existingUser, error: getUserError } = await admin.auth.admin.getUserByEmail(normalizedEmail);

      if (getUserError && getUserError.message?.includes('User not found')) {
        // User doesn't exist - invite them
        console.log('User does not exist, sending invitation:', normalizedEmail);
      } else if (getUserError) {
        console.error('Error getting user:', getUserError);
        return json(
          { error: `Failed to check user: ${getUserError.message}` },
          500
        );
      } else if (existingUser?.user) {
        // User exists - use existing user ID
        userId = existingUser.user.id;
        isExistingUser = true;
        console.log(`User already exists: ${userId}`);
      } else {
        // Should not happen, but handle gracefully
        console.log('No user found and no error - treating as new user');
      }
    } catch (error) {
      console.error('Unexpected error checking user:', error);
      // Continue to try to invite
    }

    // If user doesn't exist, invite them
    if (!isExistingUser) {
      try {
        // Use inviteUserByEmail to send magic link (Supabase sends email automatically)
        const { data: inviteData, error: inviteError } = await admin.auth.admin.inviteUserByEmail(
          normalizedEmail,
          {
            redirectTo: finalRedirectTo,
            data: {
              organization_id: organization_id,
              role: role,
              user_type: user_type,
            },
          }
        );

        if (inviteError) {
          console.error('Error inviting user:', inviteError);
          return json(
            { error: `Failed to invite user: ${inviteError.message}` },
            500
          );
        }

        userId = inviteData.user?.id;
        if (!userId) {
          return json(
            { error: 'User invited but no user ID returned' },
            500
          );
        }

        console.log(`New user invited: ${userId}`);
      } catch (error) {
        console.error('Unexpected error inviting user:', error);
        return json(
          {
            error: 'Failed to invite user',
            message: error instanceof Error ? error.message : 'Unknown error',
          },
          500
        );
      }
    }

    // Upsert membership in appropriate table
    if (user_type === 'org') {
      // Upsert OrganizationUsers
      const { data: orgUser, error: orgError } = await admin
        .from('OrganizationUsers')
        .upsert(
          {
            user_id: userId,
            organization_id: organization_id,
            role: role,
            status: 'invited',
            deleted: false,
          },
          {
            onConflict: 'user_id,organization_id',
          }
        )
        .select()
        .single();

      if (orgError) {
        console.error('Error upserting OrganizationUser:', orgError);
        return json(
          { error: `Failed to create organization membership: ${orgError.message}` },
          500
        );
      }

      console.log('OrganizationUser created/updated:', orgUser?.id);
    } else {
      // user_type === 'portal'
      // Upsert CompanyPortalUsers
      const { data: portalUser, error: portalError } = await admin
        .from('CompanyPortalUsers')
        .upsert(
          {
            user_id: userId,
            organization_id: organization_id,
            company_id: company_id,
            role: role,
            status: 'invited',
            deleted: false,
          },
          {
            onConflict: 'user_id,company_id',
          }
        )
        .select()
        .single();

      if (portalError) {
        console.error('Error upserting CompanyPortalUser:', portalError);
        return json(
          { error: `Failed to create portal membership: ${portalError.message}` },
          500
        );
      }

      console.log('CompanyPortalUser created/updated:', portalUser?.id);
    }

    // Return success
    // In development, optionally return the invite link
    const isDev = Deno.env.get('ENVIRONMENT') === 'development' || !Deno.env.get('ENVIRONMENT');
    
    const response: { ok: boolean; invite_link?: string } = {
      ok: true,
    };

    // In dev, try to get the action link if available
    if (isDev && !existingUser) {
      // The link was already sent via email, but we can't retrieve it here
      // Supabase Auth sends the email automatically
      response.invite_link = `Magic link sent to ${normalizedEmail}. Check email or use Supabase Dashboard to resend.`;
    }

    return json(response, 200);
  } catch (error) {
    console.error('Unexpected error in invite-user:', error);
    return json(
      {
        error: 'Internal server error',
        message: error instanceof Error ? error.message : 'Unknown error',
      },
      500
    );
  }
});

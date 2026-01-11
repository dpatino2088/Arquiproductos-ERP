// Supabase Edge Function: send-org-invite
// Invites organization users via MagicLink using Supabase Auth SMTP

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type Payload = {
  organization_id: string;
  user_email: string;
  role: 'owner' | 'admin' | 'member' | 'viewer';
  redirect_to?: string;
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ error: "Use POST" }, 405);
  }

  const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
  const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
    return json(
      { error: "Missing env vars SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY" },
      500
    );
  }

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });

  let payload: Payload;
  try {
    payload = await req.json();
  } catch {
    return json({ error: "Invalid JSON" }, 400);
  }

  const { organization_id, user_email, role, redirect_to } = payload;

  // Validate organization_id (UUID)
  if (!organization_id || typeof organization_id !== 'string') {
    return json({ error: "Missing or invalid organization_id" }, 400);
  }
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  if (!uuidRegex.test(organization_id)) {
    return json({ error: "Invalid organization_id format. Must be a valid UUID." }, 400);
  }

  // Validate user_email
  if (!user_email || typeof user_email !== 'string') {
    return json({ error: "Missing or invalid user_email" }, 400);
  }
  const normalizedEmail = user_email.trim().toLowerCase();
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(normalizedEmail)) {
    return json({ error: "Invalid email format" }, 400);
  }

  // Validate role
  const allowedRoles = ['owner', 'admin', 'member', 'viewer'];
  if (!role || !allowedRoles.includes(role)) {
    return json({ error: `Invalid role. Must be one of: ${allowedRoles.join(', ')}` }, 400);
  }

  // Set default redirect_to
  const finalRedirectTo = redirect_to || `${SUPABASE_URL.replace('/rest/v1', '')}/auth/callback`;

  try {
    // Get current user from Authorization header (if available)
    const authHeader = req.headers.get("Authorization");
    let invitedByUserId: string | null = null;
    
    if (authHeader) {
      try {
        const token = authHeader.replace("Bearer ", "");
        const { data: { user } } = await admin.auth.getUser(token);
        invitedByUserId = user?.id || null;
      } catch {
        // If token is invalid, continue with null
      }
    }

    // Upsert in OrganizationUsers
    // First, try to get existing record
    const { data: existingUser } = await admin
      .from("OrganizationUsers")
      .select("id, deleted, user_id")
      .eq("organization_id", organization_id)
      .eq("user_email", normalizedEmail)
      .maybeSingle();

    let orgUser;
    if (existingUser && !existingUser.deleted) {
      // User exists and is active - update
      const { data: updated, error: updateError } = await admin
        .from("OrganizationUsers")
        .update({
          role,
          status: 'invited',
          invited_at: new Date().toISOString(),
          invited_by_user_id: invitedByUserId,
          updated_at: new Date().toISOString(),
        })
        .eq("id", existingUser.id)
        .select()
        .single();

      if (updateError) {
        console.error("Error updating OrganizationUsers:", updateError);
        return json({ error: `Failed to update organization user: ${updateError.message}` }, 500);
      }
      orgUser = updated;
    } else if (existingUser && existingUser.deleted) {
      // User exists but is deleted - reactivate
      const { data: reactivated, error: reactivateError } = await admin
        .from("OrganizationUsers")
        .update({
          role,
          status: 'invited',
          deleted: false,
          invited_at: new Date().toISOString(),
          invited_by_user_id: invitedByUserId,
          user_id: null, // Reset user_id for new invite
          updated_at: new Date().toISOString(),
        })
        .eq("id", existingUser.id)
        .select()
        .single();

      if (reactivateError) {
        console.error("Error reactivating OrganizationUsers:", reactivateError);
        return json({ error: `Failed to reactivate organization user: ${reactivateError.message}` }, 500);
      }
      orgUser = reactivated;
    } else {
      // New user - insert
      const upsertData = {
        organization_id,
        user_email: normalizedEmail,
        role,
        status: 'invited' as const,
        deleted: false,
        invited_at: new Date().toISOString(),
        invited_by_user_id: invitedByUserId,
        user_id: null, // Will be linked when user accepts invite
      };

      const { data: inserted, error: insertError } = await admin
        .from("OrganizationUsers")
        .insert(upsertData)
        .select()
        .single();

      if (insertError) {
        console.error("Error inserting OrganizationUsers:", insertError);
        return json({ error: `Failed to create organization user: ${insertError.message}` }, 500);
      }
      orgUser = inserted;
    }

    // Send MagicLink via Supabase Auth SMTP
    const { data: inviteData, error: inviteError } = await admin.auth.admin.inviteUserByEmail(
      normalizedEmail,
      {
        redirectTo: finalRedirectTo,
        data: {
          organization_id,
          role,
        },
      }
    );

    if (inviteError) {
      console.error("Error sending invite:", inviteError);
      return json({ error: `Failed to send invitation: ${inviteError.message}` }, 500);
    }

    // Return success
    return json({ ok: true });
  } catch (error: any) {
    console.error("Unexpected error in send-org-invite:", error);
    return json({ error: error.message || "Internal server error" }, 500);
  }
});

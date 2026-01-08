import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type Payload = {
  organization_id: string;
  portal_user_id: string; // CustomerPortalUsers.id
  email: string;
  name?: string | null;
  redirect_to?: string | null;
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "Use POST" }, 405);

  const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
  const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");
  const EMAIL_FROM = Deno.env.get("EMAIL_FROM");

  if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
    return json(
      { error: "Missing env vars SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY" },
      500
    );
  }

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  let payload: Payload;
  try {
    payload = await req.json();
  } catch {
    return json({ error: "Invalid JSON" }, 400);
  }

  const { organization_id, portal_user_id, email, name, redirect_to } = payload;

  if (!organization_id || !portal_user_id || !email) {
    return json({ error: "Missing required fields" }, 400);
  }

  // 1) Generate invite link (sends email)
  const { data: linkData, error: linkError } = await admin.auth.admin.generateLink({
    type: "invite",
    email: email,
    options: {
      data: { full_name: name ?? null, organization_id },
      redirectTo: redirect_to ?? undefined,
    },
  });

  if (linkError) {
    return json({ error: linkError.message }, 400);
  }

  const userId = linkData.user?.id;
  const actionLink = linkData.properties?.action_link;

  if (!userId) {
    return json({ error: "Link generated but no user id" }, 500);
  }

  // 2) Update CustomerPortalUsers row
  const { error: updErr } = await admin
    .from("CustomerPortalUsers")
    .update({ user_id: userId, status: "invited" })
    .eq("id", portal_user_id)
    .eq("organization_id", organization_id);

  if (updErr) return json({ error: updErr.message }, 400);

  // 3) Send email via Resend API
  let emailSent = false;
  let emailError: string | null = null;

  if (RESEND_API_KEY && EMAIL_FROM && actionLink) {
    try {
      const resendResponse = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${RESEND_API_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          from: EMAIL_FROM,
          to: [email],
          subject: "Portal Invite",
          html: `<a href="${actionLink}">Activate</a>`,
        }),
      });

      if (resendResponse.ok) {
        emailSent = true;
      } else {
        const resendError = await resendResponse.json();
        emailError = resendError.message || "Failed to send email via Resend";
      }
    } catch (err: any) {
      emailError = err.message || "Resend API error";
    }
  } else {
    emailError = "RESEND_API_KEY or EMAIL_FROM not configured";
  }

  return json({
    ok: true,
    invite_link: actionLink,
    email_sent: emailSent,
    ...(emailError && { email_error: emailError }),
  });
});

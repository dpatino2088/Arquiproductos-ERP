/**
 * Edge Function: send-invite
 * Invita usuarios por Supabase Auth (inviteUserByEmail). Soporta org y portal (dealer).
 * Portal usa dealer_id y tabla DealerUsers (no company_id / CompanyPortalUsers).
 */
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

type Body =
  | {
      kind: "org";
      organization_id: string;
      email: string;
      role?: string;
      name?: string | null;
      redirect_to?: string | null;
    }
  | {
      kind: "portal";
      organization_id: string;
      dealer_id: string;
      email: string;
      role?: "member" | "member_manager";
      name?: string | null;
      redirect_to?: string | null;
    };

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ ok: false, error: "Use POST" }, 405);

  try {
    const body = (await req.json()) as Body;

    const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
    const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
      return json(
        { ok: false, error: "Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY" },
        500
      );
    }

    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });

    const email = (body.email ?? "").toString().trim().toLowerCase();
    if (!email) return json({ ok: false, error: "Missing email" }, 400);

    if (!body.kind || (body.kind !== "org" && body.kind !== "portal")) {
      return json({ ok: false, error: "Missing or invalid kind: org | portal" }, 400);
    }

    if (body.kind === "portal") {
      const dealerId = (body as Extract<Body, { kind: "portal" }>).dealer_id;
      if (!dealerId || typeof dealerId !== "string") {
        return json({ ok: false, error: "Missing dealer_id for portal invite" }, 400);
      }
    }

    const redirectTo =
      (body.redirect_to && String(body.redirect_to).trim()) ||
      Deno.env.get("APP_ORIGIN") ||
      "http://localhost:5173/auth/callback";

    // 1) Ensure auth user exists (create if needed)
    let userId: string | null = null;
    const createRes = await supabase.auth.admin.createUser({
      email,
      email_confirm: true,
      user_metadata: { name: (body as any).name ?? null },
    });

    if (createRes.data?.user?.id) {
      userId = createRes.data.user.id;
    } else {
      const list = await supabase.auth.admin.listUsers({ page: 1, perPage: 200 });
      const found = list.data?.users?.find((u) => (u.email || "").toLowerCase() === email);
      if (!found?.id) {
        return json({ ok: false, error: "Could not create/find auth user" }, 500);
      }
      userId = found.id;
    }

    // 2) Send invite email via Supabase Auth
    const inviteRes = await supabase.auth.admin.inviteUserByEmail(email, {
      redirectTo,
      data: {
        kind: body.kind,
        ...(body.kind === "portal" && { dealer_id: (body as Extract<Body, { kind: "portal" }>).dealer_id }),
      },
    });

    if (inviteRes.error) {
      return json({ ok: false, error: inviteRes.error.message }, 500);
    }

    // 3) Upsert membership
    if (body.kind === "org") {
      const b = body as Extract<Body, { kind: "org" }>;
      if (!b.organization_id) {
        return json({ ok: false, error: "Missing organization_id" }, 400);
      }
      const ins = await supabase.from("OrganizationUsers").upsert(
        {
          organization_id: b.organization_id,
          user_id: userId,
          user_email: email,
          user_name: b.name ?? null,
          role: b.role ?? "operator",
          status: "active",
          must_change_password: false,
        },
        { onConflict: "organization_id,user_email" }
      );
      if (ins.error) return json({ ok: false, error: ins.error.message }, 500);
    } else {
      const b = body as Extract<Body, { kind: "portal" }>;
      const now = new Date().toISOString();
      const ins = await supabase.from("DealerUsers").upsert(
        {
          organization_id: b.organization_id,
          dealer_id: b.dealer_id,
          user_id: userId,
          portal_user_email: email,
          portal_user_name: b.name ?? null,
          role: b.role ?? "member",
          status: "invited",
          must_change_password: false,
          deleted: false,
          updated_at: now,
        },
        { onConflict: "dealer_id,portal_user_email" }
      );
      if (ins.error) return json({ ok: false, error: ins.error.message }, 500);
    }

    return json({
      ok: true,
      user_id: userId,
      email,
      redirect_to: redirectTo,
      invite_debug: inviteRes.data ?? null,
    });
  } catch (e) {
    return json({ ok: false, error: String((e as any)?.message ?? e) }, 500);
  }
});

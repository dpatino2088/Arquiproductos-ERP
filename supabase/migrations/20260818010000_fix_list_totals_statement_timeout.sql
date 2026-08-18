-- Fix: Proposals list failed with "canceling statement due to statement timeout".
--
-- Root cause: proposal_list_totals / quote_list_totals were SECURITY INVOKER, so
-- the RLS policies on ProposalLines / QuoteLines / ProposalLineAddOns re-evaluated
-- the session helper functions (session_is_org_user, can_read_sales_org,
-- current_dealer_id, ...) for EVERY line row. With hundreds of proposals x dozens
-- of lines that is thousands of AppUsers/permission EXISTS probes per call:
-- measured 7.2s for 164 proposals — over Supabase's 8s statement timeout under load.
--
-- Fix: SECURITY DEFINER + an explicit visibility pre-filter that replicates the
-- parent table's SELECT policy (proposals_select / quotes_select) ONCE per
-- proposal/quote instead of once per line. current_dealer_id() is hoisted into a
-- single-evaluation CTE. Only ids the caller can already read are aggregated, so
-- the security surface is unchanged.
--
-- IMPORTANT: all totals formulas are byte-identical to the previous versions —
-- this migration changes only the security model and visibility filtering.

CREATE OR REPLACE FUNCTION public.proposal_list_totals(p_proposal_ids uuid[])
RETURNS TABLE(
  proposal_id uuid,
  material_subtotal numeric,
  installation_total numeric,
  installation_net numeric,
  other_addons numeric,
  subtotal numeric,
  discount_amount numeric,
  taxable_base numeric,
  tax_amount numeric,
  global_fee_amount numeric,
  total_amount numeric
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $function$
  with dctx as (
    select public.current_dealer_id() as dealer_id
  ),
  -- Visibility guard: replicates the proposals_select RLS policy, evaluated once
  -- per proposal (not per line). Ids the caller cannot read are silently dropped.
  vis as (
    select p.id
    from public."Proposals" p, dctx
    where p.id = any(p_proposal_ids)
      and p.deleted is not true
      and p.organization_id is not null
      and (
        (public.session_is_org_user(p.organization_id)
          and public.can_read_sales_org(p.organization_id)
          and (dctx.dealer_id is null or p.dealer_id = dctx.dealer_id))
        or (public.session_is_dealer_user(p.organization_id) and p.dealer_id = dctx.dealer_id)
        or (p.dealer_id is not null and public.session_is_dealer_portal(p.dealer_id))
      )
  ),
  mat as (
    select pl.proposal_id,
      coalesce(sum(
        case
          when pl.line_type = 'custom' then (
            (coalesce(pl.qty,1) * coalesce(pl.unit_price,0))
            * (1 + coalesce(pl.line_adjustment_pct,0)/100.0)
          )
          when pl.line_type = 'from_quote' then (
            coalesce(
              nullif(pl.quote_line_snapshot->>'base_line_msrp','')::numeric,
              case when ql.msrp is not null and ql.msrp > 0 then ql.msrp
                   when ql.unit_msrp is not null and ql.quantity is not null then ql.unit_msrp * ql.quantity
                   else 0 end,
              0
            ) * (1 + coalesce(pl.line_adjustment_pct,0)/100.0)
          )
          else 0
        end
      ),0) as material_subtotal
    from public."ProposalLines" pl
    left join public."QuoteLines" ql on ql.id = pl.quote_line_id
    where pl.proposal_id in (select id from vis)
      and pl.deleted = false
    group by pl.proposal_id
  ),
  ad as (
    select ao.proposal_id,
      coalesce(sum(case when ao.addon_type = 'installation' then ao.sale_amount else 0 end),0) as installation_total,
      coalesce(sum(case when ao.addon_type <> 'installation' or ao.addon_type is null then ao.sale_amount else 0 end),0) as other_addons
    from public."ProposalLineAddOns" ao
    where ao.proposal_id in (select id from vis)
      and ao.deleted = false
    group by ao.proposal_id
  ),
  b as (
    select p.id as proposal_id,
           p.organization_id,
           coalesce(p.exempt_tax,false) as exempt_tax,
           coalesce(p.global_discount_pct,0)::numeric as global_discount_pct,
           coalesce(p.global_fee_amount,0)::numeric as global_fee_amount,
           coalesce(mat.material_subtotal,0) as material_subtotal,
           coalesce(ad.installation_total,0) as installation_total,
           round(coalesce(ad.installation_total,0) * (1 - coalesce(p.global_installation_discount_pct,0)/100.0) * (1 + coalesce(p.global_installation_fee_pct,0)/100.0), 2) as installation_net,
           coalesce(ad.other_addons,0) as other_addons
    from public."Proposals" p
    left join mat on mat.proposal_id = p.id
    left join ad on ad.proposal_id = p.id
    where p.id in (select id from vis)
  ),
  t as (
    select b.*,
           (b.material_subtotal + b.installation_net + b.other_addons) as subtotal,
           round((b.material_subtotal + b.installation_net + b.other_addons) * (b.global_discount_pct/100.0), 2) as discount_amount
    from b
  ),
  tx as (
    select t.*,
           greatest(t.subtotal - t.discount_amount, 0) as taxable_base,
           case when t.exempt_tax then 0::numeric
                else coalesce((select cs.tax_pct from public."CostSettings" cs where cs.organization_id = t.organization_id and coalesce(cs.is_active,true) order by cs.created_at desc limit 1), 0.07)
           end as tax_pct
    from t
  )
  select
    tx.proposal_id,
    tx.material_subtotal,
    tx.installation_total,
    tx.installation_net,
    tx.other_addons,
    tx.subtotal,
    tx.discount_amount,
    tx.taxable_base,
    case when tx.exempt_tax then 0::numeric else round(tx.taxable_base * tx.tax_pct, 2) end as tax_amount,
    tx.global_fee_amount,
    round(tx.taxable_base + (case when tx.exempt_tax then 0::numeric else round(tx.taxable_base * tx.tax_pct, 2) end), 2) as total_amount
  from tx;
$function$;

CREATE OR REPLACE FUNCTION public.quote_list_totals(p_quote_ids uuid[])
RETURNS TABLE(
  quote_id uuid,
  line_count integer,
  dealer_subtotal numeric,
  msrp_subtotal numeric,
  tax_amount numeric,
  total_amount numeric
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $function$
  with dctx as (
    select public.current_dealer_id() as dealer_id
  ),
  -- Visibility guard: replicates the quotes_select RLS policy once per quote.
  vis as (
    select q.id
    from public."Quotes" q, dctx
    where q.id = any(p_quote_ids)
      and q.deleted is not true
      and q.organization_id is not null
      and (
        (public.session_is_org_user(q.organization_id)
          and public.can_read_sales_org(q.organization_id)
          and (dctx.dealer_id is null or q.dealer_id = dctx.dealer_id))
        or (public.session_is_dealer_user(q.organization_id) and q.dealer_id = dctx.dealer_id)
        or (q.dealer_id is not null and public.is_dealer_portal_user(q.dealer_id))
      )
  ),
  la as (
    select ql.quote_id,
           count(*)::int as line_count,
           coalesce(sum(case when coalesce(ql.dealer_price_total,0) > 0
                              then ql.dealer_price_total
                              else coalesce(ql.msrp,0) end),0) as dealer_subtotal,
           coalesce(sum(coalesce(ql.msrp,0)),0) as msrp_subtotal
    from "QuoteLines" ql
    where ql.quote_id in (select id from vis)
    group by ql.quote_id
  )
  select q.id as quote_id,
         coalesce(la.line_count,0) as line_count,
         coalesce(la.dealer_subtotal,0) as dealer_subtotal,
         coalesce(la.msrp_subtotal,0) as msrp_subtotal,
         case when coalesce(q.exempt_tax,false) then 0
              else round(coalesce(la.dealer_subtotal,0) * coalesce(cs.tax_pct,0.07),2) end as tax_amount,
         coalesce(la.dealer_subtotal,0)
           + case when coalesce(q.exempt_tax,false) then 0
                  else round(coalesce(la.dealer_subtotal,0) * coalesce(cs.tax_pct,0.07),2) end as total_amount
  from "Quotes" q
  left join la on la.quote_id = q.id
  left join "CostSettings" cs on cs.organization_id = q.organization_id
  where q.id in (select id from vis);
$function$;

COMMENT ON FUNCTION public.proposal_list_totals(uuid[]) IS
  'Live proposal totals for the list. SECURITY DEFINER with a per-proposal visibility guard replicating proposals_select RLS (fixes per-line RLS statement timeout). Formulas unchanged.';
COMMENT ON FUNCTION public.quote_list_totals(uuid[]) IS
  'Per-quote line totals for lists. SECURITY DEFINER with a per-quote visibility guard replicating quotes_select RLS (fixes per-line RLS statement timeout). Formulas unchanged.';

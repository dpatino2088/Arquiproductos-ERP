-- Global Fee model change: the fee is no longer a separate post-tax lump. It is distributed into
-- each line via ProposalLines.line_adjustment_pct (set on every line, last-writer-wins, applied on
-- the immutable base so it never compounds). Consequences for proposal_list_totals:
--   1. custom lines must honor line_adjustment_pct just like from_quote lines.
--   2. total_amount must NOT add global_fee_amount anymore (it's already inside material_subtotal).
-- This keeps list/detail/PDF reading ONE source (the line totals). Existing data is unaffected:
-- no proposal has a non-zero global_fee_amount and no custom line has a non-zero adjustment.

CREATE OR REPLACE FUNCTION public.proposal_list_totals(p_proposal_ids uuid[])
 RETURNS TABLE(proposal_id uuid, material_subtotal numeric, installation_total numeric, installation_net numeric, other_addons numeric, subtotal numeric, discount_amount numeric, taxable_base numeric, tax_amount numeric, global_fee_amount numeric, total_amount numeric)
 LANGUAGE sql
 STABLE
AS $function$
  with mat as (
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
    where pl.proposal_id = any(p_proposal_ids)
      and pl.deleted = false
    group by pl.proposal_id
  ),
  ad as (
    select ao.proposal_id,
      coalesce(sum(case when ao.addon_type = 'installation' then ao.sale_amount else 0 end),0) as installation_total,
      coalesce(sum(case when ao.addon_type <> 'installation' or ao.addon_type is null then ao.sale_amount else 0 end),0) as other_addons
    from public."ProposalLineAddOns" ao
    where ao.proposal_id = any(p_proposal_ids)
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
    where p.id = any(p_proposal_ids)
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
    -- Global Fee is now inside material_subtotal (per-line), so it is NOT re-added here.
    round(tx.taxable_base + (case when tx.exempt_tax then 0::numeric else round(tx.taxable_base * tx.tax_pct, 2) end), 2) as total_amount
  from tx;
$function$;

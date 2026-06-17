-- proposal_list_totals: live per-proposal totals for the Proposals list.
--
-- Mirrors the ProposalDetail / ProposalPrint UI formula (the customer-facing source of truth),
-- NOT recalc_proposal_totals. from_quote lines = base * (1 + line_adjustment_pct/100) with
-- base = frozen snapshot base_line_msrp (or live QuoteLine MSRP fallback); custom = qty*unit_price.
-- Then installation net (global install discount/fee), global discount, tax (from CostSettings,
-- exempt_tax aware) and global fee, exactly like the detail's `totals` useMemo.
--
-- Why: recalc_proposal_totals uses override_mode and ignores line_adjustment_pct, so its persisted
-- total over-counts lines that the UI zeroes out via line_adjustment_pct = -100 (e.g. PR-00197:
-- recalc 18,791.74 vs detail 16,637.60). The list must equal the detail, so it aggregates with
-- this function. Read-only (no UPDATE); ids consumed via any() so callers can chunk to avoid the
-- 1000-row cap.
create or replace function public.proposal_list_totals(p_proposal_ids uuid[])
returns table (
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
language sql
stable
security invoker
as $$
  with mat as (
    select pl.proposal_id,
      coalesce(sum(
        case
          when pl.line_type = 'custom' then (coalesce(pl.qty,1) * coalesce(pl.unit_price,0))
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
    round(tx.taxable_base + (case when tx.exempt_tax then 0::numeric else round(tx.taxable_base * tx.tax_pct, 2) end) + tx.global_fee_amount, 2) as total_amount
  from tx;
$$;

grant execute on function public.proposal_list_totals(uuid[]) to authenticated, service_role;

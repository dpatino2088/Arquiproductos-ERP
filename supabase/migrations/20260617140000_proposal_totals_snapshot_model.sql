-- Proposal totals: snapshot + manual-recalc model.
--
-- Why: a committed proposal is a price commitment to the customer. Totals must NOT change
-- silently when lines/adjustments are edited or when pricing rules change. They are frozen in
-- Proposals.* (snapshot) and only change when a user explicitly presses "Recalculate" on a DRAFT
-- (proposal_recalc_totals_v2) or at proposal creation. Sent/accepted proposals are locked.
--
-- This migration:
--   1. Drops the 3 AFTER triggers that auto-recalculated totals on every edit.
--   2. Adds total_product_amount (Material+Custom subtotal) so the Summary fully reconstructs
--      from the snapshot.
--   3. Creates proposal_recalc_totals_v2 — the canonical recompute (draft-only guard).
--   4. Backfills every non-deleted proposal's snapshot to the value currently shown in the detail
--      (legacy rule via proposal_list_totals) so already-committed amounts are preserved.

-- 1. Disable auto-recalc -------------------------------------------------------
drop trigger if exists trg_proposal_lines_recalc_totals on public."ProposalLines";
drop trigger if exists trg_proposal_line_addons_recalc_totals on public."ProposalLineAddOns";
drop trigger if exists trg_proposals_recalc_totals on public."Proposals";

-- 2. Snapshot column -----------------------------------------------------------
alter table public."Proposals" add column if not exists total_product_amount numeric(12,4);

-- 3. Canonical recompute (draft-only) -----------------------------------------
-- Rule: global discount/fee apply to Material+Custom ONLY (not installation); global fee is NOT
-- discounted but IS taxed (inside the taxable base); labor discount/fee apply to installation
-- ONLY; tax (CostSettings.tax_pct, exempt_tax aware) is charged on the resulting base.
create or replace function public.proposal_recalc_totals_v2(p_proposal_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_org uuid;
  v_status text;
  v_exempt boolean;
  v_gdisc numeric; v_gfee numeric; v_ldisc numeric; v_lfee numeric;
  v_material numeric := 0;
  v_install_total numeric := 0;
  v_other numeric := 0;
  v_tax_pct numeric := 0.07;
  v_product_net numeric; v_install_net numeric; v_base numeric; v_discount numeric; v_tax numeric; v_total numeric;
begin
  select p.organization_id, p.status, coalesce(p.exempt_tax,false),
         coalesce(p.global_discount_pct,0), coalesce(p.global_fee_amount,0),
         coalesce(p.global_installation_discount_pct,0), coalesce(p.global_installation_fee_pct,0)
    into v_org, v_status, v_exempt, v_gdisc, v_gfee, v_ldisc, v_lfee
  from "Proposals" p where p.id = p_proposal_id and p.deleted = false;
  if v_org is null then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;
  if v_status is distinct from 'draft' then
    return jsonb_build_object('ok', false, 'reason', 'locked', 'status', v_status);
  end if;

  select coalesce(sum(
    case when pl.line_type='custom' then coalesce(pl.qty,1)*coalesce(pl.unit_price,0)
         when pl.line_type='from_quote' then coalesce(
              nullif(pl.quote_line_snapshot->>'base_line_msrp','')::numeric,
              case when ql.msrp is not null and ql.msrp>0 then ql.msrp
                   when ql.unit_msrp is not null and ql.quantity is not null then ql.unit_msrp*ql.quantity
                   else 0 end, 0) * (1 + coalesce(pl.line_adjustment_pct,0)/100.0)
         else 0 end),0)
    into v_material
  from "ProposalLines" pl left join "QuoteLines" ql on ql.id=pl.quote_line_id
  where pl.proposal_id=p_proposal_id and pl.deleted=false;

  select coalesce(sum(case when ao.addon_type='installation' then ao.sale_amount else 0 end),0),
         coalesce(sum(case when ao.addon_type<>'installation' or ao.addon_type is null then ao.sale_amount else 0 end),0)
    into v_install_total, v_other
  from "ProposalLineAddOns" ao where ao.proposal_id=p_proposal_id and ao.deleted=false;

  if not v_exempt then
    select coalesce(cs.tax_pct,0.07) into v_tax_pct from "CostSettings" cs
     where cs.organization_id=v_org and coalesce(cs.is_active,true)
     order by cs.created_at desc limit 1;
  end if;

  v_discount := round(v_material*(v_gdisc/100.0),2);
  v_product_net := v_material - v_discount + v_gfee;
  v_install_net := round(v_install_total*(1 - v_ldisc/100.0)*(1 + v_lfee/100.0),2);
  v_base := v_product_net + v_install_net + v_other;
  if v_exempt then v_tax := 0; else v_tax := round(v_base*v_tax_pct,2); end if;
  v_total := round(v_base + v_tax,2);

  update "Proposals" set
    total_product_amount = v_material,
    discount_amount = v_discount,
    installation_amount = v_install_net,
    subtotal_amount = v_base,
    tax_amount = v_tax,
    total_amount = v_total
  where id = p_proposal_id;

  return jsonb_build_object('ok',true,'total_product',v_material,'discount',v_discount,'installation',v_install_net,'subtotal',v_base,'tax',v_tax,'total',v_total);
end;
$$;

grant execute on function public.proposal_recalc_totals_v2(uuid) to authenticated, service_role;

-- 4. Backfill: freeze current shown value (legacy rule) ------------------------
update public."Proposals" p set
  total_product_amount = t.material_subtotal,
  discount_amount = t.discount_amount,
  installation_amount = t.installation_net,
  subtotal_amount = t.taxable_base,
  tax_amount = t.tax_amount,
  total_amount = t.total_amount
from public.proposal_list_totals(array(select id from public."Proposals" where deleted = false)) t
where p.id = t.proposal_id;

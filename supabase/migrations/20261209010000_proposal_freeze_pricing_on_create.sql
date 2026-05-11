SET search_path = public;

-- Capture a frozen snapshot for quote-based proposal lines at creation time.
-- This prevents later Quote edits from changing existing Proposal economics.
CREATE OR REPLACE FUNCTION public.capture_proposal_snapshot(p_proposal_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_exists uuid;
  v_pl RECORD;
  v_ql RECORD;
  v_config jsonb;
  v_snapshot jsonb;
  v_base_mode text;
  v_base_unit numeric(12,4);
  v_base_line numeric(12,4);
BEGIN
  SELECT p.id
    INTO v_exists
  FROM public."Proposals" p
  WHERE p.id = p_proposal_id
    AND p.deleted = false;

  IF v_exists IS NULL THEN
    RETURN;
  END IF;

  FOR v_pl IN
    SELECT pl.id, pl.quote_line_id
    FROM public."ProposalLines" pl
    WHERE pl.proposal_id = p_proposal_id
      AND pl.deleted = false
      AND pl.line_type = 'from_quote'
      AND pl.quote_line_id IS NOT NULL
      AND pl.quote_line_snapshot IS NULL
  LOOP
    SELECT ql.name, ql.sku, ql.quantity, ql.width_m, ql.height_m, ql.area, ql.position,
           ql.product_type, ql.collection_name, ql.variant_name, ql.drive_type,
           ql.msrp, ql.unit_msrp, ql.configured_product_id
    INTO v_ql
    FROM public."QuoteLines" ql
    WHERE ql.id = v_pl.quote_line_id
    LIMIT 1;

    IF NOT FOUND THEN
      v_snapshot := jsonb_build_object(
        'name', '—',
        'sku', NULL,
        'qty', 1,
        'width_m', NULL,
        'height_m', NULL,
        'measurements', '{}'::jsonb,
        'accessories', NULL,
        'opening_direction', NULL,
        'base_price_mode', 'msrp',
        'base_unit_msrp', NULL,
        'base_line_msrp', NULL,
        'captured_at', now()
      );
    ELSE
      v_config := NULL;
      IF v_ql.configured_product_id IS NOT NULL THEN
        SELECT config_snapshot
        INTO v_config
        FROM public."ConfiguredProducts"
        WHERE id = v_ql.configured_product_id
          AND deleted = false
        LIMIT 1;
      END IF;

      v_base_mode := CASE
        WHEN v_ql.msrp IS NOT NULL AND v_ql.msrp > 0 THEN 'msrp'
        ELSE 'unit_msrp'
      END;
      v_base_unit := COALESCE(v_ql.unit_msrp, v_ql.msrp / NULLIF(v_ql.quantity, 0));
      v_base_line := COALESCE(v_ql.msrp, v_ql.unit_msrp * NULLIF(v_ql.quantity, 0));

      v_snapshot := jsonb_build_object(
        'name', v_ql.name,
        'sku', v_ql.sku,
        'qty', COALESCE(v_ql.quantity, 1),
        'width_m', v_ql.width_m,
        'height_m', v_ql.height_m,
        'area', v_ql.area,
        'position', v_ql.position,
        'product_type', v_ql.product_type,
        'collection_name', v_ql.collection_name,
        'variant_name', v_ql.variant_name,
        'drive_type', v_ql.drive_type,
        'measurements', COALESCE(v_config->'measurements', '{}'::jsonb),
        'accessories', v_config->'accessories',
        'opening_direction', COALESCE(v_config->>'opening_direction', v_config->>'openingDirection'),
        'base_price_mode', v_base_mode,
        'base_unit_msrp', v_base_unit,
        'base_line_msrp', v_base_line,
        'captured_at', now()
      );
    END IF;

    UPDATE public."ProposalLines"
    SET quote_line_snapshot = v_snapshot
    WHERE id = v_pl.id;
  END LOOP;
END;
$$;

COMMENT ON FUNCTION public.capture_proposal_snapshot(uuid) IS
'Captures frozen quote_line_snapshot for from_quote proposal lines. Intended to run at proposal creation so quote edits do not alter existing proposal pricing.';

-- Keep existing trigger behavior: when moving to sent/accepted, ensure snapshot exists and set sent_at once.
CREATE OR REPLACE FUNCTION public.freeze_proposal_snapshot(p_proposal_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_status text;
BEGIN
  SELECT p.status
    INTO v_status
  FROM public."Proposals" p
  WHERE p.id = p_proposal_id
    AND p.deleted = false;

  IF v_status IS NULL THEN
    RETURN;
  END IF;

  PERFORM public.capture_proposal_snapshot(p_proposal_id);

  IF v_status IN ('sent', 'accepted') THEN
    UPDATE public."Proposals"
    SET sent_at = COALESCE(sent_at, now())
    WHERE id = p_proposal_id;
  END IF;
END;
$$;

-- Recalc totals from frozen snapshot when available (not live QuoteLines),
-- so Proposal totals remain stable after Quote edits.
CREATE OR REPLACE FUNCTION public.recalc_proposal_totals(p_proposal_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_org_id uuid;
  v_subtotal_material numeric(12,4) := 0;
  v_installation_total numeric(12,4) := 0;
  v_installation_net numeric(12,4) := 0;
  v_other_addons numeric(12,4) := 0;
  v_inst_discount_pct numeric(7,4) := 0;
  v_inst_fee_pct numeric(7,4) := 0;
  v_subtotal numeric(12,4);
  v_discount_pct numeric(12,6);
  v_discount_amount numeric(12,4) := 0;
  v_taxable_base numeric(12,4);
  v_tax_pct numeric(7,4) := 0.07;
  v_tax_amount numeric(12,4) := 0;
  v_fee numeric(12,4);
  v_total numeric(12,4);
  v_exempt_tax boolean := false;
BEGIN
  SELECT p.organization_id, COALESCE(p.exempt_tax, false),
         COALESCE(p.global_installation_discount_pct, 0), COALESCE(p.global_installation_fee_pct, 0)
    INTO v_org_id, v_exempt_tax, v_inst_discount_pct, v_inst_fee_pct
  FROM public."Proposals" p
  WHERE p.id = p_proposal_id AND p.deleted = false;

  IF v_org_id IS NULL THEN
    RETURN;
  END IF;

  IF NOT v_exempt_tax THEN
    SELECT COALESCE(cs.tax_pct, 0.07)
      INTO v_tax_pct
    FROM public."CostSettings" cs
    WHERE cs.organization_id = v_org_id
      AND COALESCE(cs.is_active, true)
    ORDER BY cs.created_at DESC
    LIMIT 1;
  END IF;

  SELECT COALESCE(SUM(
    CASE
      WHEN pl.line_type = 'custom' THEN (COALESCE(pl.qty, 1) * COALESCE(pl.unit_price, 0))
      WHEN pl.line_type = 'from_quote' AND pl.quote_line_id IS NOT NULL THEN (
        CASE COALESCE(pl.override_mode::text, 'inherit')
          WHEN 'inherit' THEN COALESCE(
            NULLIF(pl.quote_line_snapshot->>'base_line_msrp', '')::numeric,
            (
              SELECT COALESCE(
                ql.msrp,
                (COALESCE(ql.unit_msrp_total_snapshot, ql.msrp / NULLIF(ql.quantity, 0)) * COALESCE(NULLIF(ql.quantity, 0), 1)),
                0
              )
              FROM public."QuoteLines" ql
              WHERE ql.id = pl.quote_line_id
              LIMIT 1
            ),
            0
          )
          WHEN 'discount_pct' THEN (
            COALESCE(
              NULLIF(pl.quote_line_snapshot->>'base_line_msrp', '')::numeric,
              (
                SELECT COALESCE(
                  ql.msrp,
                  (COALESCE(ql.unit_msrp_total_snapshot, ql.msrp / NULLIF(ql.quantity, 0)) * COALESCE(NULLIF(ql.quantity, 0), 1)),
                  0
                )
                FROM public."QuoteLines" ql
                WHERE ql.id = pl.quote_line_id
                LIMIT 1
              ),
              0
            ) * (1 - COALESCE(pl.discount_pct, 0) / 100.0)
          )
          WHEN 'markup_pct' THEN (
            COALESCE(
              NULLIF(pl.quote_line_snapshot->>'base_line_msrp', '')::numeric,
              (
                SELECT COALESCE(
                  ql.msrp,
                  (COALESCE(ql.unit_msrp_total_snapshot, ql.msrp / NULLIF(ql.quantity, 0)) * COALESCE(NULLIF(ql.quantity, 0), 1)),
                  0
                )
                FROM public."QuoteLines" ql
                WHERE ql.id = pl.quote_line_id
                LIMIT 1
              ),
              0
            ) * (1 + COALESCE(pl.markup_pct, 0) / 100.0)
          )
          WHEN 'fixed_unit_price' THEN (
            COALESCE(pl.fixed_unit_price, 0) * COALESCE(
              NULLIF(NULLIF(pl.quote_line_snapshot->>'qty', '')::numeric, 0),
              (
                SELECT COALESCE(NULLIF(ql.quantity, 0), 1)
                FROM public."QuoteLines" ql
                WHERE ql.id = pl.quote_line_id
                LIMIT 1
              ),
              1
            )
          )
          WHEN 'fixed_line_total' THEN COALESCE(pl.fixed_line_total, 0)
          ELSE COALESCE(
            NULLIF(pl.quote_line_snapshot->>'base_line_msrp', '')::numeric,
            (
              SELECT COALESCE(
                ql.msrp,
                (COALESCE(ql.unit_msrp_total_snapshot, ql.msrp / NULLIF(ql.quantity, 0)) * COALESCE(NULLIF(ql.quantity, 0), 1)),
                0
              )
              FROM public."QuoteLines" ql
              WHERE ql.id = pl.quote_line_id
              LIMIT 1
            ),
            0
          )
        END
      )
      ELSE 0
    END
  ), 0)
    INTO v_subtotal_material
  FROM public."ProposalLines" pl
  WHERE pl.proposal_id = p_proposal_id
    AND pl.deleted = false;

  SELECT COALESCE(SUM(CASE WHEN ao.addon_type = 'installation' THEN ao.sale_amount ELSE 0 END), 0),
         COALESCE(SUM(CASE WHEN ao.addon_type <> 'installation' OR ao.addon_type IS NULL THEN ao.sale_amount ELSE 0 END), 0)
    INTO v_installation_total, v_other_addons
  FROM public."ProposalLineAddOns" ao
  WHERE ao.proposal_id = p_proposal_id
    AND ao.deleted = false;

  v_installation_net := ROUND(v_installation_total * (1 - v_inst_discount_pct / 100.0) * (1 + v_inst_fee_pct / 100.0), 2);
  v_subtotal := v_subtotal_material + v_installation_net + v_other_addons;

  SELECT COALESCE(p.global_discount_pct, 0), COALESCE(p.global_fee_amount, 0)
    INTO v_discount_pct, v_fee
  FROM public."Proposals" p
  WHERE p.id = p_proposal_id;

  v_discount_amount := ROUND(v_subtotal * (v_discount_pct / 100.0), 2);
  v_taxable_base := GREATEST(v_subtotal - v_discount_amount, 0);

  IF v_exempt_tax THEN
    v_tax_amount := 0;
  ELSE
    v_tax_amount := ROUND(v_taxable_base * v_tax_pct, 2);
  END IF;

  v_total := ROUND(v_taxable_base + v_tax_amount + COALESCE(v_fee, 0), 2);

  UPDATE public."Proposals"
  SET subtotal_amount = v_subtotal,
      installation_amount = v_installation_total,
      discount_amount = v_discount_amount,
      tax_amount = v_tax_amount,
      total_amount = v_total
  WHERE id = p_proposal_id;
END;
$$;

-- One-time backfill for legacy proposal lines that still have NULL snapshot.
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT DISTINCT pl.proposal_id
    FROM public."ProposalLines" pl
    JOIN public."Proposals" p ON p.id = pl.proposal_id
    WHERE pl.line_type = 'from_quote'
      AND pl.quote_line_id IS NOT NULL
      AND pl.quote_line_snapshot IS NULL
      AND pl.deleted = false
      AND p.deleted = false
  LOOP
    PERFORM public.capture_proposal_snapshot(r.proposal_id);
    PERFORM public.recalc_proposal_totals(r.proposal_id);
  END LOOP;
END $$;

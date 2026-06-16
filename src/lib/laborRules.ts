// Client-side replica of public.resolve_labor_cost_from_rules.
// Used by the Labor Rules tester. The authoritative resolution still happens
// in SQL (calculate_configured_product_totals); this lets the UI preview the
// match without a round trip.
//
// STRICT mode: when no rule matches, no fallback is applied and the result is
// flagged as 'unresolved'. The configurator UI uses this to BLOCK saving.

import type { LaborRuleRow } from '../hooks/useCostEngineSettings';

export interface LaborTestContext {
  productTypeId: string | null;
  widthMm: number;
  heightMm: number;
  panelCount: number;
  drops: number;
  hasMotor: boolean;
  operatingType?: string | null;
  materialsCost: number;
  /** Linear meters of heatseal to charge (seams × effective fabric width). Default 0. */
  heatsealLengthM?: number;
  /** Whether the bottom bar is wrapped with fabric (charges per linear meter of width). Default false. */
  bottomBarWrapped?: boolean;
}

export interface LaborTestBreakdownLine {
  key: string;
  label: string;
  contribution: number;
  description: string;
  active: boolean;
}

export interface LaborTestResult {
  matched: LaborRuleRow | null;
  laborCost: number;
  laborPctEffective: number;
  rawCost: number;
  breakdown: LaborTestBreakdownLine[];
  source: 'labor_rule' | 'unresolved';
  unresolvedReason?: string;
}

const inRange = (v: number, min: number | null | undefined, max: number | null | undefined) => {
  if (min != null && v < Number(min)) return false;
  if (max != null && v > Number(max)) return false;
  return true;
};

const ruleApplies = (rule: LaborRuleRow & Record<string, any>, ctx: LaborTestContext) => {
  if (!rule.is_active) return false;
  if (rule.product_type_id != null && rule.product_type_id !== ctx.productTypeId) return false;
  if (!inRange(ctx.widthMm, rule.width_min_mm, rule.width_max_mm)) return false;
  if (!inRange(ctx.heightMm, rule.height_min_mm, rule.height_max_mm)) return false;
  const areaM2 = (ctx.widthMm / 1000) * (ctx.heightMm / 1000);
  if (!inRange(areaM2, rule.area_min_m2, rule.area_max_m2)) return false;
  if (!inRange(ctx.panelCount, rule.panel_count_min, rule.panel_count_max)) return false;
  if (!inRange(ctx.drops, rule.drops_min, rule.drops_max)) return false;
  if (rule.operating_type) {
    const want = String(rule.operating_type).trim().toLowerCase();
    const got = String(ctx.operatingType ?? '').trim().toLowerCase();
    if (want !== got) return false;
  }
  if (rule.motor_required != null && Boolean(rule.motor_required) !== ctx.hasMotor) return false;
  return true;
};

const buildBreakdown = (
  rule: LaborRuleRow & Record<string, any>,
  ctx: LaborTestContext,
): { raw: number; lines: LaborTestBreakdownLine[] } => {
  const areaM2 = (ctx.widthMm / 1000) * (ctx.heightMm / 1000);
  const heightM = ctx.heightMm / 1000;
  const widthM = ctx.widthMm / 1000;

  const fixed = Number(rule.fixed_amount ?? 0);
  const ratePerM2 = Number(rule.rate_per_m2 ?? 0);
  const ratePerDrop = Number(rule.rate_per_drop ?? 0);
  const ratePerPanel = Number(rule.rate_per_panel ?? 0);
  const ratePerHeightM = Number(rule.rate_per_height_m ?? 0);
  const ratePerWidthM = Number(rule.rate_per_width_m ?? 0);
  const motorAddon = Number(rule.rate_motor_addon ?? 0);
  const pctMaterials = Number(rule.pct_materials ?? 0);

  const sizeEscPct = Number(rule.size_escalation_pct ?? 0);
  const sizeRefWidthM = Number(rule.size_reference_width_m ?? 1);
  const heatsealRatePerM = Number(rule.heatseal_rate_per_m ?? 0);
  const wrapRatePerM = Number(rule.bottom_bar_wrap_rate_per_m ?? 0);
  const confectionBase = Number(rule.confection_base ?? 0);
  const confectionRatePerM2 = Number(rule.confection_rate_per_m2 ?? 0);
  const confectionEscPct = Number(rule.confection_size_escalation_pct ?? 0);
  const confectionRefWidthM = Number(rule.confection_size_reference_width_m ?? 1);

  const heatsealLengthM = Math.max(Number(ctx.heatsealLengthM ?? 0), 0);
  const wrapped = Boolean(ctx.bottomBarWrapped);

  const m2Contribution = ratePerM2 * areaM2;
  const dropContribution = ratePerDrop * ctx.drops;
  const panelContribution = ratePerPanel * ctx.panelCount;
  const heightContribution = ratePerHeightM * heightM;
  const widthContribution = ratePerWidthM * widthM;
  const motorContribution = ctx.hasMotor ? motorAddon : 0;
  const pctContribution = pctMaterials * Math.max(ctx.materialsCost, 0);

  const sizeFactor = sizeEscPct > 0 && sizeRefWidthM > 0
    ? 1 + sizeEscPct * Math.max(widthM - sizeRefWidthM, 0)
    : 1;

  const heatsealContribution = heatsealRatePerM * heatsealLengthM;
  const wrapContribution = wrapped ? wrapRatePerM * widthM : 0;

  const confectionRaw = confectionBase + confectionRatePerM2 * areaM2;
  const confectionFactor = confectionEscPct > 0 && confectionRefWidthM > 0
    ? 1 + confectionEscPct * Math.max(widthM - confectionRefWidthM, 0)
    : 1;
  const confectionContribution = confectionRaw * confectionFactor;

  const lines: LaborTestBreakdownLine[] = [];
  let raw = 0;

  switch (rule.calc_mode) {
    case 'pct_materials':
      raw = pctContribution;
      lines.push({
        key: 'pct_materials',
        label: '% of materials',
        contribution: pctContribution,
        description: `${(pctMaterials * 100).toFixed(1)}% × $${ctx.materialsCost.toFixed(2)} materials`,
        active: pctMaterials > 0,
      });
      break;
    case 'fixed':
      raw = fixed;
      lines.push({
        key: 'fixed',
        label: 'Fixed amount',
        contribution: fixed,
        description: `$${fixed.toFixed(2)} flat`,
        active: fixed > 0,
      });
      break;
    case 'per_m2':
      raw = m2Contribution;
      lines.push({
        key: 'rate_per_m2',
        label: 'Per m²',
        contribution: m2Contribution,
        description: `$${ratePerM2.toFixed(2)} × ${areaM2.toFixed(2)} m²`,
        active: ratePerM2 > 0,
      });
      break;
    case 'per_drop':
      raw = dropContribution;
      lines.push({
        key: 'rate_per_drop',
        label: 'Per drop',
        contribution: dropContribution,
        description: `$${ratePerDrop.toFixed(2)} × ${ctx.drops} drops`,
        active: ratePerDrop > 0,
      });
      break;
    case 'per_panel':
      raw = panelContribution;
      lines.push({
        key: 'rate_per_panel',
        label: 'Per panel',
        contribution: panelContribution,
        description: `$${ratePerPanel.toFixed(2)} × ${ctx.panelCount} panels`,
        active: ratePerPanel > 0,
      });
      break;
    case 'per_height_m':
      raw = heightContribution;
      lines.push({
        key: 'rate_per_height_m',
        label: 'Per height m',
        contribution: heightContribution,
        description: `$${ratePerHeightM.toFixed(2)} × ${heightM.toFixed(2)} m`,
        active: ratePerHeightM > 0,
      });
      break;
    case 'per_width_m':
      raw = widthContribution;
      lines.push({
        key: 'rate_per_width_m',
        label: 'Per width m',
        contribution: widthContribution,
        description: `$${ratePerWidthM.toFixed(2)} × ${widthM.toFixed(2)} m`,
        active: ratePerWidthM > 0,
      });
      break;
    case 'composite':
    default: {
      const baseRaw =
        fixed +
        m2Contribution +
        dropContribution +
        panelContribution +
        heightContribution +
        widthContribution +
        motorContribution;
      const baseEscalated = baseRaw * sizeFactor;
      raw = baseEscalated + heatsealContribution + wrapContribution + confectionContribution;
      lines.push(
        {
          key: 'fixed',
          label: 'Fixed amount',
          contribution: fixed,
          description: `$${fixed.toFixed(2)} flat`,
          active: fixed > 0,
        },
        {
          key: 'rate_per_m2',
          label: 'Per m²',
          contribution: m2Contribution,
          description: `$${ratePerM2.toFixed(2)} × ${areaM2.toFixed(2)} m²`,
          active: ratePerM2 > 0,
        },
        {
          key: 'rate_per_drop',
          label: 'Per drop',
          contribution: dropContribution,
          description: `$${ratePerDrop.toFixed(2)} × ${ctx.drops} drops`,
          active: ratePerDrop > 0,
        },
        {
          key: 'rate_per_panel',
          label: 'Per panel',
          contribution: panelContribution,
          description: `$${ratePerPanel.toFixed(2)} × ${ctx.panelCount} panels`,
          active: ratePerPanel > 0,
        },
        {
          key: 'rate_per_height_m',
          label: 'Per height m',
          contribution: heightContribution,
          description: `$${ratePerHeightM.toFixed(2)} × ${heightM.toFixed(2)} m`,
          active: ratePerHeightM > 0,
        },
        {
          key: 'rate_per_width_m',
          label: 'Per width m',
          contribution: widthContribution,
          description: `$${ratePerWidthM.toFixed(2)} × ${widthM.toFixed(2)} m`,
          active: ratePerWidthM > 0,
        },
        {
          key: 'rate_motor_addon',
          label: 'Motor add-on',
          contribution: motorContribution,
          description: ctx.hasMotor
            ? `$${motorAddon.toFixed(2)} (motor on)`
            : `$${motorAddon.toFixed(2)} (motor off → not added)`,
          active: ctx.hasMotor && motorAddon > 0,
        },
        {
          key: 'size_escalation',
          label: 'Size escalation',
          contribution: baseEscalated - baseRaw,
          description: sizeEscPct > 0
            ? `× ${sizeFactor.toFixed(3)} ( +${(sizeEscPct * 100).toFixed(2)}%/m over ${sizeRefWidthM.toFixed(2)} m ref )`
            : 'inactive (size_escalation_pct = 0)',
          active: sizeEscPct > 0 && sizeFactor !== 1,
        },
        {
          key: 'heatseal',
          label: 'Heatseal',
          contribution: heatsealContribution,
          description: heatsealRatePerM > 0
            ? `$${heatsealRatePerM.toFixed(2)}/m × ${heatsealLengthM.toFixed(2)} m`
            : 'inactive (heatseal_rate_per_m = 0)',
          active: heatsealContribution > 0,
        },
        {
          key: 'bottom_bar_wrap',
          label: 'Bottom bar wrap',
          contribution: wrapContribution,
          description: wrapped
            ? `$${wrapRatePerM.toFixed(2)}/m × ${widthM.toFixed(2)} m width`
            : 'inactive (bottom bar not wrapped)',
          active: wrapContribution > 0,
        },
        {
          key: 'confection',
          label: 'Confection',
          contribution: confectionContribution,
          description: confectionRaw > 0
            ? `($${confectionBase.toFixed(2)} + $${confectionRatePerM2.toFixed(2)}/m² × ${areaM2.toFixed(2)} m²) × ${confectionFactor.toFixed(3)}`
            : 'inactive (no confection rates configured)',
          active: confectionContribution > 0,
        },
      );
      break;
    }
  }

  return { raw, lines };
};

/**
 * Compute the labor breakdown for a SPECIFIC rule (no matcher). Display-only.
 * Use to reconstruct, for verification, how a stored labor cost was composed when
 * the matched rule id is already known (e.g. from ConfiguredProducts.labor_calc_meta).
 * Mirrors the SQL math; intermediate rounding (round_to_increment) is NOT applied here,
 * so callers should reconcile the sum against the authoritative rounded cost.
 */
export function computeLaborBreakdownForRule(
  rule: LaborRuleRow,
  ctx: LaborTestContext,
): { laborCost: number; rawCost: number; breakdown: LaborTestBreakdownLine[] } {
  const { raw, lines } = buildBreakdown(rule as LaborRuleRow & Record<string, any>, ctx);
  let bounded = raw;
  if (rule.min_charge != null) bounded = Math.max(bounded, Number(rule.min_charge));
  if (rule.max_charge != null) bounded = Math.min(bounded, Number(rule.max_charge));
  return {
    laborCost: Number(bounded.toFixed(4)),
    rawCost: Number(raw.toFixed(4)),
    breakdown: lines,
  };
}

export function resolveLaborRuleClient(rules: LaborRuleRow[], ctx: LaborTestContext): LaborTestResult {
  const candidates = rules
    .filter((rule) => ruleApplies(rule, ctx))
    .sort((a, b) => {
      const pa = Number(a.priority ?? 0);
      const pb = Number(b.priority ?? 0);
      if (pa !== pb) return pb - pa;
      const ca = a.created_at ? new Date(a.created_at).getTime() : 0;
      const cb = b.created_at ? new Date(b.created_at).getTime() : 0;
      return ca - cb;
    });

  const matched = candidates[0] ?? null;

  if (!matched) {
    return {
      matched: null,
      laborCost: 0,
      laborPctEffective: 0,
      rawCost: 0,
      breakdown: [],
      source: 'unresolved',
      unresolvedReason:
        'No active LaborRule matches this configuration. Pricing is BLOCKED. Add a rule that covers product_type, motor, dimensions and panel/drop counts.',
    };
  }

  const { raw, lines } = buildBreakdown(matched, ctx);
  let bounded = raw;
  if (matched.min_charge != null) bounded = Math.max(bounded, Number(matched.min_charge));
  if (matched.max_charge != null) bounded = Math.min(bounded, Number(matched.max_charge));
  const labor = Number(bounded.toFixed(4));

  return {
    matched,
    laborCost: labor,
    laborPctEffective: ctx.materialsCost > 0 ? labor / ctx.materialsCost : 0,
    rawCost: Number(raw.toFixed(4)),
    breakdown: lines,
    source: 'labor_rule',
  };
}

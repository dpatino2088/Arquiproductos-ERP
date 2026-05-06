import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';

// ====================================================
// COST SETTINGS (organization defaults)
// ====================================================

/** Valores válidos para fabric_pricing_basis */
export type FabricPricingBasis = 'auto' | 'linear' | 'sqm';

/** CostSettings: columnas según BD. PK = organization_id; sin tiers. */
export interface CostSettingsRow {
  organization_id: string;
  labor_pct: number;
  labor_dealer_pct?: number | null;
  labor_msrp_pct?: number | null;
  shipping_pct: number;
  global_import_tax_pct: number;
  minimum_margin_pct: number;
  default_msrp_pct: number; // Default MSRP % (0-1, e.g. 0.65 = 65%)
  tax_pct?: number;       // Tax % (0-1, e.g. 0.07 = 7%). Used in Proposals.
  import_tax_pct?: number;  // generated = global_import_tax_pct
  /** Display/quote basis for fabric rolls. Only affects bom_preview_snapshot. */
  fabric_pricing_basis?: FabricPricingBasis;
  is_active?: boolean;
  created_at?: string;
  updated_at?: string | null;
}

export function useCostSettings() {
  const [settings, setSettings] = useState<CostSettingsRow | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const { activeOrganizationId } = useOrganizationContext();

  const refetch = async () => {
    if (!activeOrganizationId) {
      setSettings(null);
      setLoading(false);
      return;
    }

    try {
      setLoading(true);
      setError(null);

      const { data, error: queryError } = await supabase
        .from('CostSettings')
        .select('*')
        .eq('organization_id', activeOrganizationId)
        .maybeSingle();

      if (queryError) throw queryError;
      
      if (data) {
        console.log('📥 CostSettings loaded from DB:', {
          organization_id: data.organization_id,
          default_msrp_pct: data.default_msrp_pct,
          default_msrp_pct_ui: data.default_msrp_pct ? Math.round(data.default_msrp_pct * 100) : 'N/A',
        });
      } else {
        console.warn('⚠️ No CostSettings found for organization:', activeOrganizationId);
      }
      
      setSettings(data);
    } catch (err: any) {
      console.error('Error loading CostSettings:', err);
      setError(err.message || 'Error loading cost settings');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    refetch();
  }, [activeOrganizationId]);

  const upsertSettings = async (data: Partial<Omit<CostSettingsRow, 'id' | 'organization_id' | 'created_at' | 'updated_at'>>) => {
    if (!activeOrganizationId) throw new Error('No organization selected');

    const payload = {
      ...data,
      organization_id: activeOrganizationId,
    };

    console.log('💾 Upserting CostSettings:', payload);

    const { data: result, error } = await supabase
      .from('CostSettings')
      .upsert(payload, {
        onConflict: 'organization_id',
        ignoreDuplicates: false,
      })
      .select()
      .maybeSingle();

    if (error) {
      console.error('❌ Error upserting CostSettings:', {
        message: error.message,
        code: error.code,
        details: error.details,
        hint: error.hint,
      });
      throw error;
    }

    console.log('✅ CostSettings upserted:', result);
    await refetch();
  };

  return { settings, loading, error, refetch, upsertSettings };
}

// ====================================================
// IMPORT TAX RULES (by category)
// ====================================================

export interface ImportTaxRuleRow {
  id: string;
  organization_id: string;
  category_id: string;
  import_tax_pct: number;
  created_at: string;
  updated_at?: string | null;
}

export function useImportTaxRules() {
  const [rules, setRules] = useState<ImportTaxRuleRow[]>([]);
  const [loading, setLoading] = useState(true);
  const { activeOrganizationId } = useOrganizationContext();

  const refetch = async () => {
    if (!activeOrganizationId) {
      setRules([]);
      setLoading(false);
      return;
    }

    try {
      setLoading(true);
      const { data, error } = await supabase
        .from('ImportTaxRules')
        .select('*')
        .eq('organization_id', activeOrganizationId);

      if (error) throw error;
      setRules(data || []);
      console.log('📦 ImportTaxRules loaded:', data?.length || 0, 'rules');
    } catch (err: any) {
      console.error('Error loading ImportTaxRules:', err);
      setRules([]);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    refetch();
  }, [activeOrganizationId]);

  const upsertRule = async (category_id: string, import_tax_pct: number) => {
    if (!activeOrganizationId) throw new Error('No organization selected');

    const payload = {
      organization_id: activeOrganizationId,
      category_id,
      import_tax_pct,
    };

    console.log('💾 Upserting ImportTaxRule:', payload);

    const { data, error } = await supabase
      .from('ImportTaxRules')
      .upsert(payload, {
        onConflict: 'organization_id,category_id',
        ignoreDuplicates: false,
      })
      .select()
      .maybeSingle();

    if (error) {
      console.error('❌ Error upserting ImportTaxRule:', error);
      throw error;
    }

    console.log('✅ ImportTaxRule upserted:', data);
    await refetch();
    console.log('🔄 Rules refetched');
  };

  const deleteRule = async (id: string) => {
    const { error } = await supabase
      .from('ImportTaxRules')
      .delete()
      .eq('id', id)
      .eq('organization_id', activeOrganizationId);

    if (error) throw error;
    await refetch();
  };

  return { rules, loading, refetch, upsertRule, deleteRule };
}

// ====================================================
// CATEGORY MARGINS (by category)
// ====================================================

export interface CategoryMarginRow {
  id: string;
  organization_id: string;
  category_id: string;
  minimum_margin_pct: number; // Minimum margin (sale-in / dealer price)
  msrp_pct: number; // MSRP % (margin-on-sale for public price)
  created_at: string;
  updated_at?: string | null;
}

export function useCategoryMargins() {
  const [margins, setMargins] = useState<CategoryMarginRow[]>([]);
  const [loading, setLoading] = useState(true);
  const { activeOrganizationId } = useOrganizationContext();

  const refetch = async () => {
    if (!activeOrganizationId) {
      setMargins([]);
      setLoading(false);
      return;
    }

    try {
      setLoading(true);
      const { data, error } = await supabase
        .from('CategoryMargins')
        .select('*')
        .eq('organization_id', activeOrganizationId);

      if (error) throw error;
      setMargins(data || []);
      console.log('📦 CategoryMargins loaded:', data?.length || 0, 'margins');
    } catch (err: any) {
      console.error('Error loading CategoryMargins:', err);
      setMargins([]);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    refetch();
  }, [activeOrganizationId]);

  const upsertMargin = async (category_id: string, minimum_margin_pct: number, msrp_pct: number) => {
    if (!activeOrganizationId) throw new Error('No organization selected');

    const payload = {
      organization_id: activeOrganizationId,
      category_id,
      minimum_margin_pct,
      msrp_pct,
      is_active: true,
    };

    console.log('💾 Upserting CategoryMargin:', payload);

    const { data, error } = await supabase
      .from('CategoryMargins')
      .upsert(payload, {
        onConflict: 'organization_id,category_id',
        ignoreDuplicates: false,
      })
      .select()
      .maybeSingle();

    if (error) {
      const msg = error.message || error.details || String(error);
      console.error('❌ Error upserting CategoryMargin:', error);
      throw new Error(msg);
    }

    console.log('✅ CategoryMargin upserted:', data);
    await refetch();
    console.log('🔄 Margins refetched');
  };

  const deleteMargin = async (id: string) => {
    const { error } = await supabase
      .from('CategoryMargins')
      .delete()
      .eq('id', id)
      .eq('organization_id', activeOrganizationId);

    if (error) throw error;
    await refetch();
  };

  return { margins, loading, refetch, upsertMargin, deleteMargin };
}

// ====================================================
// LABOR RULES (by product type / size)
// ====================================================

export interface LaborRuleRow {
  id: string;
  organization_id: string;
  product_type_id: string | null;
  display_name: string;
  priority: number;
  is_active: boolean;
  calc_mode: string;
  fixed_amount: number | null;
  rate_per_m2: number | null;
  rate_per_drop: number | null;
  rate_per_panel?: number | null;
  rate_per_height_m?: number | null;
  rate_per_width_m?: number | null;
  rate_motor_addon: number | null;
  pct_materials?: number | null;
  min_charge: number | null;
  max_charge: number | null;
  width_min_mm?: number | null;
  width_max_mm?: number | null;
  height_min_mm?: number | null;
  height_max_mm?: number | null;
  area_min_m2?: number | null;
  area_max_m2?: number | null;
  panel_count_min?: number | null;
  panel_count_max?: number | null;
  drops_min?: number | null;
  drops_max?: number | null;
  operating_type?: string | null;
  motor_required?: boolean | null;
  size_escalation_pct?: number | null;
  size_reference_width_m?: number | null;
  heatseal_rate_per_m?: number | null;
  bottom_bar_wrap_rate_per_m?: number | null;
  confection_base?: number | null;
  confection_rate_per_m2?: number | null;
  confection_size_escalation_pct?: number | null;
  confection_size_reference_width_m?: number | null;
  created_at?: string;
  updated_at?: string | null;
}

export interface LaborRuleUpsertInput {
  id?: string;
  product_type_id?: string | null;
  display_name: string;
  priority?: number;
  is_active?: boolean;
  calc_mode?: string;
  fixed_amount?: number | null;
  rate_per_m2?: number | null;
  rate_per_drop?: number | null;
  rate_per_panel?: number | null;
  rate_per_height_m?: number | null;
  rate_per_width_m?: number | null;
  rate_motor_addon?: number | null;
  pct_materials?: number | null;
  min_charge?: number | null;
  max_charge?: number | null;
  width_min_mm?: number | null;
  width_max_mm?: number | null;
  height_min_mm?: number | null;
  height_max_mm?: number | null;
  area_min_m2?: number | null;
  area_max_m2?: number | null;
  panel_count_min?: number | null;
  panel_count_max?: number | null;
  drops_min?: number | null;
  drops_max?: number | null;
  operating_type?: string | null;
  motor_required?: boolean | null;
  size_escalation_pct?: number | null;
  size_reference_width_m?: number | null;
  heatseal_rate_per_m?: number | null;
  bottom_bar_wrap_rate_per_m?: number | null;
  confection_base?: number | null;
  confection_rate_per_m2?: number | null;
  confection_size_escalation_pct?: number | null;
  confection_size_reference_width_m?: number | null;
}

export interface LaborCoverageGap {
  product_type_id: string | null;
  product_type_code: string | null;
  product_type_name: string | null;
  has_motor: boolean;
  width_min_mm: number | null;
  width_max_mm: number | null;
  height_min_mm: number | null;
  height_max_mm: number | null;
  sample_count: number;
  example_configured_product_id: string | null;
}

export function useLaborRules() {
  const [rules, setRules] = useState<LaborRuleRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const { activeOrganizationId } = useOrganizationContext();

  const refetch = async () => {
    if (!activeOrganizationId) {
      setRules([]);
      setLoading(false);
      return;
    }

    try {
      setLoading(true);
      setError(null);
      const { data, error: queryError } = await supabase
        .from('LaborRules')
        .select('*')
        .eq('organization_id', activeOrganizationId)
        .order('priority', { ascending: false })
        .order('created_at', { ascending: true });

      if (queryError) throw queryError;
      setRules((data as LaborRuleRow[]) || []);
    } catch (err: any) {
      setRules([]);
      setError(err?.message || 'Error loading Labor Rules');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    refetch();
  }, [activeOrganizationId]);

  const upsertRule = async (input: LaborRuleUpsertInput) => {
    if (!activeOrganizationId) throw new Error('No organization selected');

    const payload: Record<string, any> = {
      organization_id: activeOrganizationId,
      product_type_id: input.product_type_id ?? null,
      display_name: input.display_name,
      priority: input.priority ?? 100,
      is_active: input.is_active ?? true,
      calc_mode: input.calc_mode ?? 'composite',
      fixed_amount: input.fixed_amount ?? null,
      rate_per_m2: input.rate_per_m2 ?? null,
      rate_per_drop: input.rate_per_drop ?? null,
      rate_per_panel: input.rate_per_panel ?? null,
      rate_per_height_m: input.rate_per_height_m ?? null,
      rate_per_width_m: input.rate_per_width_m ?? null,
      rate_motor_addon: input.rate_motor_addon ?? null,
      pct_materials: input.pct_materials ?? null,
      min_charge: input.min_charge ?? null,
      max_charge: input.max_charge ?? null,
      width_min_mm: input.width_min_mm ?? null,
      width_max_mm: input.width_max_mm ?? null,
      height_min_mm: input.height_min_mm ?? null,
      height_max_mm: input.height_max_mm ?? null,
      area_min_m2: input.area_min_m2 ?? null,
      area_max_m2: input.area_max_m2 ?? null,
      panel_count_min: input.panel_count_min ?? null,
      panel_count_max: input.panel_count_max ?? null,
      drops_min: input.drops_min ?? null,
      drops_max: input.drops_max ?? null,
      operating_type: input.operating_type ?? null,
      motor_required: input.motor_required ?? null,
      size_escalation_pct: input.size_escalation_pct ?? 0,
      size_reference_width_m: input.size_reference_width_m ?? 1,
      heatseal_rate_per_m: input.heatseal_rate_per_m ?? 0,
      bottom_bar_wrap_rate_per_m: input.bottom_bar_wrap_rate_per_m ?? 0,
      confection_base: input.confection_base ?? 0,
      confection_rate_per_m2: input.confection_rate_per_m2 ?? 0,
      confection_size_escalation_pct: input.confection_size_escalation_pct ?? 0,
      confection_size_reference_width_m: input.confection_size_reference_width_m ?? 1,
    };

    if (input.id) payload.id = input.id;

    const { error: upsertError } = await supabase
      .from('LaborRules')
      .upsert(payload)
      .select('id')
      .maybeSingle();

    if (upsertError) throw upsertError;
    await refetch();
  };

  const deleteRule = async (id: string) => {
    if (!activeOrganizationId) throw new Error('No organization selected');
    const { error: deleteError } = await supabase
      .from('LaborRules')
      .delete()
      .eq('id', id)
      .eq('organization_id', activeOrganizationId);

    if (deleteError) throw deleteError;
    await refetch();
  };

  return { rules, loading, error, refetch, upsertRule, deleteRule };
}

export function useLaborCoverageGaps(days: number = 90) {
  const [gaps, setGaps] = useState<LaborCoverageGap[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const { activeOrganizationId } = useOrganizationContext();

  const refetch = async () => {
    if (!activeOrganizationId) {
      setGaps([]);
      return;
    }
    try {
      setLoading(true);
      setError(null);
      const { data, error: rpcError } = await supabase.rpc('labor_rules_coverage_gaps', {
        p_org_id: activeOrganizationId,
        p_days: days,
      });
      if (rpcError) throw rpcError;
      setGaps((data as LaborCoverageGap[]) || []);
    } catch (err: any) {
      setGaps([]);
      setError(err?.message || 'Error loading coverage gaps');
    } finally {
      setLoading(false);
    }
  };

  return { gaps, loading, error, refetch };
}

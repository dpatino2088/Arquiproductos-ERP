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
  itbms_pct?: number;       // Tax % (0-1, e.g. 0.07 = 7%). Used in Proposals.
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

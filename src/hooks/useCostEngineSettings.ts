import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';

// ====================================================
// COST SETTINGS (organization defaults)
// ====================================================

export interface CostSettingsRow {
  id: string;
  organization_id: string;
  labor_pct: number;
  shipping_pct: number;
  global_import_tax_pct: number;
  default_msrp_pct_sale_out: number; // Global MSRP % Sale Out default (e.g., 0.35 = 35%)
  reseller_discount_pct: number;
  distributor_discount_pct: number;
  partner_discount_pct: number;
  vip_discount_pct: number;
  minimum_margin_pct: number;
  default_margin_pct: number;
  is_active: boolean;
  created_at: string;
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
          default_msrp_pct_sale_out: data.default_msrp_pct_sale_out,
          default_msrp_pct_sale_out_ui: data.default_msrp_pct_sale_out ? Math.round(data.default_msrp_pct_sale_out * 100) : 'N/A',
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
  msrp_pct_sale_in: number; // MSRP % Sale-In (margin-on-sale) - defines distributor/internal price
  msrp_pct_sale_out: number; // MSRP % Sale Out (margin-on-sale) - defines public price
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

  const upsertMargin = async (category_id: string, msrp_pct_sale_in: number, msrp_pct_sale_out: number) => {
    if (!activeOrganizationId) throw new Error('No organization selected');

    const payload = {
      organization_id: activeOrganizationId,
      category_id,
      msrp_pct_sale_in,
      msrp_pct_sale_out,
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
      console.error('❌ Error upserting CategoryMargin:', error);
      throw error;
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

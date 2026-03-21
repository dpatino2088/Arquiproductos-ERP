import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';

export interface FabricRule {
  id: string;
  organization_id: string;
  product_type_id: string;
  style_code: string | null;
  display_name: string | null;
  image_url: string | null;
  product_line: string | null;
  fabric_group: string | null;
  formula_code: string;
  height_multiplier: number;
  width_multiplier: number;
  fullness_factor: number;
  extra_height_m: number;
  extra_width_m: number;
  pricing_output_uom: string;
  waste_pct: number;
  round_to_increment: number;
  min_qty: number;
  top_hem_cm: number;
  bottom_hem_cm: number;
  side_hem_cm: number;
  fabric_orientation: string;
  fabric_width_source: string;
  tube_wrap_mm: number;
  bottom_wrap_mm: number;
  safety_margin_mm: number;
  panel_multiplier: number;
  heatseal_price_per_m: number;
  bottom_bar_wrap_pct: number;
  confection_pct: number;
  allow_rotation: boolean;
  heatseal_direction: 'horizontal' | 'vertical' | 'none';
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface SystemRule {
  id: string;
  organization_id: string;
  product_type_id: string;
  style_code: string | null;
  rule_key: string;
  rule_value: number;
  catalog_item_id: string | null;
  is_active: boolean;
}

export function useFabricRules() {
  const { activeOrganizationId } = useOrganizationContext();
  const [rules, setRules] = useState<FabricRule[]>([]);
  const [systemRules, setSystemRules] = useState<SystemRule[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchRules = useCallback(async () => {
    if (!activeOrganizationId) return;
    setLoading(true);
    setError(null);

    const [fabricRes, systemRes] = await Promise.all([
      supabase
        .from('FabricRules')
        .select('*')
        .eq('organization_id', activeOrganizationId)
        .order('product_type_id')
        .order('style_code'),
      supabase
        .from('SystemRules')
        .select('*')
        .eq('organization_id', activeOrganizationId)
        .order('product_type_id')
        .order('style_code')
        .order('rule_key'),
    ]);

    if (fabricRes.error) {
      setError(fabricRes.error.message);
      setLoading(false);
      return;
    }
    if (systemRes.error) {
      console.warn('SystemRules load error:', systemRes.error.message);
    }

    setRules(fabricRes.data || []);
    setSystemRules(systemRes.data || []);
    setLoading(false);
  }, [activeOrganizationId]);

  useEffect(() => { fetchRules(); }, [fetchRules]);

  const createRule = useCallback(async (rule: Partial<FabricRule>): Promise<FabricRule | null> => {
    if (!activeOrganizationId) return null;
    const { data, error: err } = await supabase
      .from('FabricRules')
      .insert({ ...rule, organization_id: activeOrganizationId })
      .select('*')
      .single();
    if (err) { setError(err.message); return null; }
    setRules(prev => [...prev, data]);
    return data;
  }, [activeOrganizationId]);

  const updateRule = useCallback(async (id: string, updates: Partial<FabricRule>): Promise<boolean> => {
    const { error: err } = await supabase
      .from('FabricRules')
      .update({ ...updates, updated_at: new Date().toISOString() })
      .eq('id', id);
    if (err) { setError(err.message); return false; }
    setRules(prev => prev.map(r => r.id === id ? { ...r, ...updates } : r));
    return true;
  }, []);

  const deleteRule = useCallback(async (id: string): Promise<boolean> => {
    const { error: err } = await supabase
      .from('FabricRules')
      .delete()
      .eq('id', id);
    if (err) { setError(err.message); return false; }
    setRules(prev => prev.filter(r => r.id !== id));
    return true;
  }, []);

  const createSystemRule = useCallback(async (rule: Partial<SystemRule>): Promise<SystemRule | null> => {
    if (!activeOrganizationId) return null;
    const { data, error: err } = await supabase
      .from('SystemRules')
      .insert({ ...rule, organization_id: activeOrganizationId })
      .select('*')
      .single();
    if (err) { setError(err.message); return null; }
    setSystemRules(prev => [...prev, data]);
    return data;
  }, [activeOrganizationId]);

  const updateSystemRule = useCallback(async (id: string, updates: Partial<SystemRule>): Promise<boolean> => {
    const { error: err } = await supabase
      .from('SystemRules')
      .update({ ...updates, updated_at: new Date().toISOString() })
      .eq('id', id);
    if (err) { setError(err.message); return false; }
    setSystemRules(prev => prev.map(r => r.id === id ? { ...r, ...updates } : r));
    return true;
  }, []);

  const deleteSystemRule = useCallback(async (id: string): Promise<boolean> => {
    const { error: err } = await supabase
      .from('SystemRules')
      .delete()
      .eq('id', id);
    if (err) { setError(err.message); return false; }
    setSystemRules(prev => prev.filter(r => r.id !== id));
    return true;
  }, []);

  return {
    rules,
    systemRules,
    loading,
    error,
    fetchRules,
    createRule,
    updateRule,
    deleteRule,
    createSystemRule,
    updateSystemRule,
    deleteSystemRule,
  };
}

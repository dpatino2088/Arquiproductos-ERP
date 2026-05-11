import React, { useState, useEffect, useMemo } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { useCostSettings, useImportTaxRules, useCategoryMargins, useLaborRules } from '../../hooks/useCostEngineSettings';
import { useUIStore } from '../../stores/ui-store';
import { useCatalogCategories } from '../../hooks/useCatalog';
import Input from '../../components/ui/Input';
import Label from '../../components/ui/Label';
import { Save, AlertCircle, Plus, Edit2, X, Check, Search, Filter } from 'lucide-react';
import DealerTiersSettings from './DealerTiersSettings';
import { useProductTypes } from '../../hooks/useProductTypes';

const costSettingsSchema = z.object({
  labor_cost_percentage: z.number().min(0, 'Labor cost % must be >= 0').max(100, 'Labor cost % must be <= 100'),
  labor_dealer_margin_pct: z.number().min(0).max(95).optional(),
  labor_msrp_margin_pct: z.number().min(0).max(95).optional(),
  shipping_percentage: z.number().min(0, 'Shipping percentage must be >= 0').max(100, 'Shipping percentage must be <= 100'),
  import_tax_percent: z.number().min(0, 'Import tax percentage must be >= 0').max(100, 'Import tax percentage must be <= 100'),
  tax_percent: z.number().min(0, 'Tax % must be >= 0').max(100, 'Tax % must be <= 100'),
  msrp_pct: z.number().min(0, 'MSRP % must be >= 0').max(200, 'MSRP % must be <= 200'),
  min_margin_pct: z.number().min(0, 'Minimum margin must be >= 0').max(95, 'Minimum margin must be <= 95').optional(),
});

type CostSettingsFormData = z.infer<typeof costSettingsSchema>;

export default function CostEngineSettings() {
  const [activeTab, setActiveTab] = useState<'defaults' | 'import_taxes' | 'category_margins' | 'dealer_tiers' | 'fabric_pricing' | 'labor_rules'>('defaults');
  const [fabricPricingBasis, setFabricPricingBasis] = useState<'auto' | 'linear' | 'sqm'>('auto');
  const [savingFabric, setSavingFabric] = useState(false);
  const [fabricSaveSuccess, setFabricSaveSuccess] = useState(false);
  const { settings, loading, error, upsertSettings } = useCostSettings();
  const { rules, loading: rulesLoading, upsertRule, deleteRule } = useImportTaxRules();
  const { margins, loading: marginsLoading, upsertMargin, deleteMargin } = useCategoryMargins();
  const {
    rules: laborRules,
    loading: laborRulesLoading,
    error: laborRulesError,
    upsertRule: upsertLaborRule,
    deleteRule: deleteLaborRule,
  } = useLaborRules();
  const { productTypes } = useProductTypes();
  const [showNewLaborRule, setShowNewLaborRule] = useState(false);
  const [editingLaborRuleId, setEditingLaborRuleId] = useState<string | null>(null);
  const [isSavingLaborRule, setIsSavingLaborRule] = useState(false);
  const [laborRuleDraft, setLaborRuleDraft] = useState({
    display_name: '',
    product_type_id: '',
    calc_mode: 'composite',
    priority: '100',
    is_active: true,
    motor_required: '',
    track_only_required: '',
    operating_type: '',
    width_min_mm: '',
    width_max_mm: '',
    height_min_mm: '',
    height_max_mm: '',
    area_min_m2: '',
    area_max_m2: '',
    panel_count_min: '',
    panel_count_max: '',
    drops_min: '',
    drops_max: '',
    fixed_amount: '0',
    rate_per_m2: '0',
    rate_per_drop: '0',
    rate_per_panel: '0',
    rate_per_height_m: '0',
    rate_per_width_m: '0',
    rate_motor_addon: '0',
    pct_materials: '0',
    min_charge: '0',
    max_charge: '',
    size_escalation_pct: '0',
    size_reference_width_m: '1',
    heatseal_rate_per_m: '0',
    bottom_bar_wrap_rate_per_m: '0',
    confection_base: '0',
    confection_rate_per_m2: '0',
    confection_size_escalation_pct: '0',
    confection_size_reference_width_m: '1',
  });
  const [laborSearch, setLaborSearch] = useState('');
  const [laborStatusFilter, setLaborStatusFilter] = useState<'active' | 'all' | 'inactive'>('active');
  const [laborProductFilter, setLaborProductFilter] = useState<string>('all');
  const [collapsedGroups, setCollapsedGroups] = useState<Record<string, boolean>>({});
  const toggleGroup = (key: string) =>
    setCollapsedGroups((prev) => {
      const currentlyCollapsed = prev[key] !== false;
      return { ...prev, [key]: !currentlyCollapsed };
    });
  const laborStats = useMemo(() => {
    const total = laborRules.length;
    const active = laborRules.filter((r) => r.is_active).length;
    return { total, active, inactive: total - active };
  }, [laborRules]);

  const laborGroups = useMemo(() => {
    const lookup = new Map<string, string>();
    (productTypes || []).forEach((pt) => lookup.set(pt.id, pt.name));
    const term = laborSearch.trim().toLowerCase();
    const filtered = (laborRules || []).filter((rule) => {
      if (laborStatusFilter === 'active' && !rule.is_active) return false;
      if (laborStatusFilter === 'inactive' && rule.is_active) return false;
      if (laborProductFilter !== 'all') {
        if (laborProductFilter === '__wildcard__') {
          if (rule.product_type_id != null) return false;
        } else if (rule.product_type_id !== laborProductFilter) {
          return false;
        }
      }
      if (term) {
        const productName = rule.product_type_id
          ? (lookup.get(rule.product_type_id) || '').toLowerCase()
          : 'any wildcard';
        const haystack = [
          rule.display_name || '',
          rule.calc_mode || '',
          rule.operating_type || '',
          productName,
        ]
          .join(' ')
          .toLowerCase();
        if (!haystack.includes(term)) return false;
      }
      return true;
    });

    const map = new Map<string, { key: string; label: string; rules: typeof filtered }>();
    filtered.forEach((rule) => {
      const key = rule.product_type_id || '__wildcard__';
      const label = rule.product_type_id
        ? lookup.get(rule.product_type_id) || rule.product_type_id
        : 'Any (wildcard)';
      if (!map.has(key)) map.set(key, { key, label, rules: [] });
      map.get(key)!.rules.push(rule);
    });

    const groups = Array.from(map.values()).sort((a, b) => a.label.localeCompare(b.label));
    groups.forEach((g) => {
      g.rules.sort((a, b) => {
        if (a.is_active !== b.is_active) return a.is_active ? -1 : 1;
        const pa = Number(a.priority ?? 0);
        const pb = Number(b.priority ?? 0);
        if (pa !== pb) return pb - pa;
        return (a.display_name || '').localeCompare(b.display_name || '');
      });
    });
    return { groups, totalAfterFilters: filtered.length };
  }, [laborRules, laborSearch, laborStatusFilter, laborProductFilter, productTypes]);
  const setGlobalLoading = useUIStore((s) => s.setGlobalLoading);
  const [saveSuccess, setSaveSuccess] = useState(false);
  const [isSaving, setIsSaving] = useState(false);

  useEffect(() => {
    setGlobalLoading(loading);
    return () => setGlobalLoading(false);
  }, [loading, setGlobalLoading]);

  const {
    register,
    handleSubmit,
    setValue,
    getValues,
    watch,
    formState: { errors, isDirty },
  } = useForm<CostSettingsFormData>({
    resolver: zodResolver(costSettingsSchema),
    defaultValues: {
      labor_cost_percentage: 10.0000,
      labor_dealer_margin_pct: 35,
      labor_msrp_margin_pct: 65,
      shipping_percentage: 15.0000,
      import_tax_percent: 0,
      tax_percent: 7, // Default 7% tax (0.07 in DB). Used in Proposals.
      msrp_pct: 65, // Default 65% MSRP (0.65 in DB)
      min_margin_pct: 35, // Default 35% minimum margin (margin-on-sale, used as pricing floor)
    },
  });

  const { leafCategories: categories } = useCatalogCategories(); // Only show leaf categories (is_group=false)
  const [editingRuleId, setEditingRuleId] = useState<string | null>(null);
  const [editingCategoryId, setEditingCategoryId] = useState<string | null>(null);
  const [newRuleCategoryId, setNewRuleCategoryId] = useState<string>('');
  const [newRulePercentage, setNewRulePercentage] = useState<string>('');
  const [editingPercentage, setEditingPercentage] = useState<string>('');
  // Category Margins state
  const [editingMarginId, setEditingMarginId] = useState<string | null>(null);
  const [editingMarginCategoryId, setEditingMarginCategoryId] = useState<string | null>(null);
  const [editingMarginPercentage, setEditingMarginPercentage] = useState<string>('');
  const [editingMsrpPct, setEditingMsrpPct] = useState<string>('');
  // Search and filter state for Category Margins
  const [searchTerm, setSearchTerm] = useState('');
  const [showFilters, setShowFilters] = useState(false);
  const [filterHasCustomMargin, setFilterHasCustomMargin] = useState<string>('all'); // 'all', 'custom', 'default'
  // Search and filter state for Import Taxes
  const [importTaxSearchTerm, setImportTaxSearchTerm] = useState('');
  const [showImportTaxFilters, setShowImportTaxFilters] = useState(false);
  const [filterImportTaxType, setFilterImportTaxType] = useState<string>('all'); // 'all', 'custom', 'default'
  // Defaults tab: which row is being edited (Dealer Tiers style)
  const [editingDefaultKey, setEditingDefaultKey] = useState<'shipping' | 'import_tax' | 'tax' | null>(null);
  const [defaultEditValue, setDefaultEditValue] = useState<string>('');

  // Filtered categories for Category Margins tab
  const filteredCategories = useMemo(() => {
    let filtered = categories;
    
    // Apply search filter
    if (searchTerm) {
      const search = searchTerm.toLowerCase();
      filtered = filtered.filter(cat => 
        cat.name.toLowerCase().includes(search)
      );
    }
    
    // Apply margin type filter
    if (filterHasCustomMargin === 'custom') {
      filtered = filtered.filter(cat => 
        margins.some(m => m.category_id === cat.id)
      );
    } else if (filterHasCustomMargin === 'default') {
      filtered = filtered.filter(cat => 
        !margins.some(m => m.category_id === cat.id)
      );
    }
    
    return filtered;
  }, [categories, margins, searchTerm, filterHasCustomMargin]);

  // Filtered categories for Import Taxes tab
  const filteredImportTaxCategories = useMemo(() => {
    let filtered = categories;
    
    // Apply search filter
    if (importTaxSearchTerm) {
      const search = importTaxSearchTerm.toLowerCase();
      filtered = filtered.filter(cat => 
        cat.name.toLowerCase().includes(search)
      );
    }
    
    // Apply tax type filter
    if (filterImportTaxType === 'custom') {
      filtered = filtered.filter(cat => 
        rules.some(r => r.category_id === cat.id)
      );
    } else if (filterImportTaxType === 'default') {
      filtered = filtered.filter(cat => 
        !rules.some(r => r.category_id === cat.id)
      );
    }
    
    return filtered;
  }, [categories, rules, importTaxSearchTerm, filterImportTaxType]);

  const productTypeNameById = useMemo(() => {
    const entries = productTypes.map((pt) => [pt.id, pt.name] as const);
    return new Map(entries);
  }, [productTypes]);

  const resetLaborRuleDraft = () => {
    setLaborRuleDraft({
      display_name: '',
      product_type_id: '',
      calc_mode: 'composite',
      priority: '100',
      is_active: true,
      motor_required: '',
      track_only_required: '',
      operating_type: '',
      width_min_mm: '',
      width_max_mm: '',
      height_min_mm: '',
      height_max_mm: '',
      area_min_m2: '',
      area_max_m2: '',
      panel_count_min: '',
      panel_count_max: '',
      drops_min: '',
      drops_max: '',
      fixed_amount: '0',
      rate_per_m2: '0',
      rate_per_drop: '0',
      rate_per_panel: '0',
      rate_per_height_m: '0',
      rate_per_width_m: '0',
      rate_motor_addon: '0',
      pct_materials: '0',
      min_charge: '0',
      max_charge: '',
      size_escalation_pct: '0',
      size_reference_width_m: '1',
      heatseal_rate_per_m: '0',
      bottom_bar_wrap_rate_per_m: '0',
      confection_base: '0',
      confection_rate_per_m2: '0',
      confection_size_escalation_pct: '0',
      confection_size_reference_width_m: '1',
    });
  };

  const beginEditLaborRule = (rule: any) => {
    setEditingLaborRuleId(rule.id);
    setShowNewLaborRule(false);
    const numStr = (v: any) => (v == null ? '' : String(v));
    setLaborRuleDraft({
      display_name: rule.display_name || '',
      product_type_id: rule.product_type_id || '',
      calc_mode: rule.calc_mode || 'composite',
      priority: String(rule.priority ?? 100),
      is_active: Boolean(rule.is_active ?? true),
      motor_required:
        rule.motor_required == null
          ? ''
          : rule.motor_required
          ? 'true'
          : 'false',
      track_only_required:
        rule.track_only_required == null
          ? ''
          : rule.track_only_required
          ? 'true'
          : 'false',
      operating_type: rule.operating_type || '',
      width_min_mm: numStr(rule.width_min_mm),
      width_max_mm: numStr(rule.width_max_mm),
      height_min_mm: numStr(rule.height_min_mm),
      height_max_mm: numStr(rule.height_max_mm),
      area_min_m2: numStr(rule.area_min_m2),
      area_max_m2: numStr(rule.area_max_m2),
      panel_count_min: numStr(rule.panel_count_min),
      panel_count_max: numStr(rule.panel_count_max),
      drops_min: numStr(rule.drops_min),
      drops_max: numStr(rule.drops_max),
      fixed_amount: String(rule.fixed_amount ?? 0),
      rate_per_m2: String(rule.rate_per_m2 ?? 0),
      rate_per_drop: String(rule.rate_per_drop ?? 0),
      rate_per_panel: String(rule.rate_per_panel ?? 0),
      rate_per_height_m: String(rule.rate_per_height_m ?? 0),
      rate_per_width_m: String(rule.rate_per_width_m ?? 0),
      rate_motor_addon: String(rule.rate_motor_addon ?? 0),
      pct_materials: String(rule.pct_materials ?? 0),
      min_charge: String(rule.min_charge ?? 0),
      max_charge: rule.max_charge == null ? '' : String(rule.max_charge),
      size_escalation_pct: String(rule.size_escalation_pct ?? 0),
      size_reference_width_m: String(rule.size_reference_width_m ?? 1),
      heatseal_rate_per_m: String(rule.heatseal_rate_per_m ?? 0),
      bottom_bar_wrap_rate_per_m: String(rule.bottom_bar_wrap_rate_per_m ?? 0),
      confection_base: String(rule.confection_base ?? 0),
      confection_rate_per_m2: String(rule.confection_rate_per_m2 ?? 0),
      confection_size_escalation_pct: String(rule.confection_size_escalation_pct ?? 0),
      confection_size_reference_width_m: String(rule.confection_size_reference_width_m ?? 1),
    });
  };

  const toNullableNumber = (v: string) => {
    const t = v.trim();
    if (t === '') return null;
    const n = Number(t);
    return Number.isFinite(n) ? n : null;
  };

  const saveLaborRule = async () => {
    if (!laborRuleDraft.display_name.trim()) {
      alert('Rule name is required.');
      return;
    }

    // Validate dimension filters: must be null or >= 0, and max >= min when both set
    const dimFields: Array<{ label: string; minKey: string; maxKey: string }> = [
      { label: 'Width', minKey: 'width_min_mm', maxKey: 'width_max_mm' },
      { label: 'Height', minKey: 'height_min_mm', maxKey: 'height_max_mm' },
      { label: 'Area', minKey: 'area_min_m2', maxKey: 'area_max_m2' },
    ];
    for (const { label, minKey, maxKey } of dimFields) {
      const minVal = toNullableNumber((laborRuleDraft as any)[minKey]);
      const maxVal = toNullableNumber((laborRuleDraft as any)[maxKey]);
      if (minVal != null && minVal < 0) {
        alert(`${label} min cannot be negative. Leave blank for no limit.`);
        return;
      }
      if (maxVal != null && maxVal < 0) {
        alert(`${label} max cannot be negative. Leave blank for no limit.`);
        return;
      }
      if (minVal != null && maxVal != null && maxVal < minVal) {
        alert(`${label} max must be greater than or equal to ${label} min.`);
        return;
      }
    }

    try {
      setIsSavingLaborRule(true);
      await upsertLaborRule({
        id: editingLaborRuleId || undefined,
        display_name: laborRuleDraft.display_name.trim(),
        product_type_id: laborRuleDraft.product_type_id || null,
        calc_mode: laborRuleDraft.calc_mode,
        priority: Number(laborRuleDraft.priority || 100),
        is_active: laborRuleDraft.is_active,
        motor_required:
          laborRuleDraft.motor_required === ''
            ? null
            : laborRuleDraft.motor_required === 'true',
        track_only_required:
          laborRuleDraft.track_only_required === ''
            ? null
            : laborRuleDraft.track_only_required === 'true',
        operating_type: laborRuleDraft.operating_type.trim() || null,
        width_min_mm: toNullableNumber(laborRuleDraft.width_min_mm),
        width_max_mm: toNullableNumber(laborRuleDraft.width_max_mm),
        height_min_mm: toNullableNumber(laborRuleDraft.height_min_mm),
        height_max_mm: toNullableNumber(laborRuleDraft.height_max_mm),
        area_min_m2: toNullableNumber(laborRuleDraft.area_min_m2),
        area_max_m2: toNullableNumber(laborRuleDraft.area_max_m2),
        panel_count_min: toNullableNumber(laborRuleDraft.panel_count_min),
        panel_count_max: toNullableNumber(laborRuleDraft.panel_count_max),
        drops_min: toNullableNumber(laborRuleDraft.drops_min),
        drops_max: toNullableNumber(laborRuleDraft.drops_max),
        fixed_amount: toNullableNumber(laborRuleDraft.fixed_amount),
        rate_per_m2: toNullableNumber(laborRuleDraft.rate_per_m2),
        rate_per_drop: toNullableNumber(laborRuleDraft.rate_per_drop),
        rate_per_panel: toNullableNumber(laborRuleDraft.rate_per_panel),
        rate_per_height_m: toNullableNumber(laborRuleDraft.rate_per_height_m),
        rate_per_width_m: toNullableNumber(laborRuleDraft.rate_per_width_m),
        rate_motor_addon: toNullableNumber(laborRuleDraft.rate_motor_addon),
        pct_materials: toNullableNumber(laborRuleDraft.pct_materials),
        min_charge: toNullableNumber(laborRuleDraft.min_charge),
        max_charge: toNullableNumber(laborRuleDraft.max_charge),
        size_escalation_pct: toNullableNumber(laborRuleDraft.size_escalation_pct),
        size_reference_width_m: toNullableNumber(laborRuleDraft.size_reference_width_m),
        heatseal_rate_per_m: toNullableNumber(laborRuleDraft.heatseal_rate_per_m),
        bottom_bar_wrap_rate_per_m: toNullableNumber(laborRuleDraft.bottom_bar_wrap_rate_per_m),
        confection_base: toNullableNumber(laborRuleDraft.confection_base),
        confection_rate_per_m2: toNullableNumber(laborRuleDraft.confection_rate_per_m2),
        confection_size_escalation_pct: toNullableNumber(laborRuleDraft.confection_size_escalation_pct),
        confection_size_reference_width_m: toNullableNumber(laborRuleDraft.confection_size_reference_width_m),
      });
      setEditingLaborRuleId(null);
      setShowNewLaborRule(false);
      resetLaborRuleDraft();
    } catch (err: any) {
      alert(err?.message || 'Error saving labor rule.');
    } finally {
      setIsSavingLaborRule(false);
    }
  };

  // Load settings when they become available
  useEffect(() => {
    if (settings) {
      console.log('📥 Loading CostSettings into form:', {
        default_msrp_pct: settings.default_msrp_pct,
        default_msrp_pct_ui: Math.round((settings.default_msrp_pct || 0.65) * 100),
      });
      
      // DB: 0.10 → UI: 10 (rounded)
      setValue('labor_cost_percentage', Math.round((settings.labor_pct ?? 0.10) * 100));
      setValue('labor_dealer_margin_pct', Math.round(((settings as any).labor_dealer_pct ?? settings.minimum_margin_pct ?? 0.35) * 100));
      setValue('labor_msrp_margin_pct', Math.round(((settings as any).labor_msrp_pct ?? settings.default_msrp_pct ?? 0.65) * 100));
      setValue('shipping_percentage', Math.round(settings.shipping_pct * 100));
      setValue('import_tax_percent', Math.round(settings.global_import_tax_pct * 100));
      setValue('tax_percent', Math.round((settings.tax_pct ?? 0.07) * 100));
      
      const msrpValue = Math.round((settings.default_msrp_pct || 0.65) * 100);
      console.log('📥 Setting msrp_pct to:', msrpValue);
      setValue('msrp_pct', msrpValue);
      
      setValue('min_margin_pct', Math.round(settings.minimum_margin_pct * 100));
      setFabricPricingBasis((settings as any).fabric_pricing_basis || 'auto');
    }
  }, [settings, setValue]);

  const onSubmit = async (data: CostSettingsFormData) => {
    try {
      setIsSaving(true);
      setSaveSuccess(false);
      
      // Convert percentages to decimals: UI 10 → DB 0.10
      // MSRP % (default): preserve existing value when not in form
      const msrpPct = data.msrp_pct != null
        ? data.msrp_pct / 100
        : (settings?.default_msrp_pct ?? 0.65);
      const laborPctValue = data.labor_cost_percentage / 100;
      const payload = {
        labor_pct: laborPctValue,
        labor_dealer_pct: (data.labor_dealer_margin_pct ?? 35) / 100,
        labor_msrp_pct: (data.labor_msrp_margin_pct ?? 65) / 100,
        shipping_pct: data.shipping_percentage / 100,
        global_import_tax_pct: data.import_tax_percent / 100,
        tax_pct: (data.tax_percent ?? 7) / 100,
        default_msrp_pct: msrpPct,
        minimum_margin_pct: (data.min_margin_pct ?? 35) / 100,
      };
      
      console.log('💾 Saving CostSettings payload:', payload);
      console.log('💾 MSRP % value:', data.msrp_pct, '→ DB:', payload.default_msrp_pct);
      
      await upsertSettings(payload);
      
      setSaveSuccess(true);
      setTimeout(() => setSaveSuccess(false), 3000);
    } catch (err: any) {
      // Format error message properly (avoid circular reference)
      const errorMessage = err?.message || err?.error_description || err?.hint || JSON.stringify(err, Object.getOwnPropertyNames(err), 2) || 'Unknown error';
      console.error('Error saving cost settings:', {
        message: err?.message,
        code: err?.code,
        details: err?.details,
        hint: err?.hint,
        fullError: errorMessage,
      });
      alert(`Error saving settings: ${errorMessage}`);
    } finally {
      setIsSaving(false);
    }
  };

  if (loading) return <div className="py-6 px-6" />;

  return (
    <div className="py-6 px-6">
      {/* Header */}
      <div className="mb-6">
        <h1 className="text-xl font-semibold text-foreground mb-1">
          Settings
        </h1>
      </div>

      {error && (
        <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded-md flex items-start gap-2">
          <AlertCircle className="w-4 h-4 text-red-600 mt-0.5 flex-shrink-0" />
          <div className="text-sm text-red-800">
            <p className="font-medium">Error loading settings</p>
            <p className="text-xs mt-1">{error}</p>
          </div>
        </div>
      )}

      {saveSuccess && (
        <div className="mb-4 p-3 bg-green-50 border border-green-200 rounded-md text-sm text-green-800">
          Settings saved successfully!
        </div>
      )}

      {/* Main Content Card - Matching CustomerNew structure */}
      <div className="bg-white border border-gray-200 rounded-lg overflow-hidden mb-4">
        {/* Tab Toggle Header - Matching CustomerNew style */}
        <div 
          className="border-b"
          style={{
            height: '2.625rem',
            backgroundColor: 'var(--gray-100)',
            borderColor: 'var(--gray-250)'
          }}
        >
          <div className="flex items-stretch h-full" role="tablist">
            <button
              onClick={() => setActiveTab('defaults')}
              className={`transition-colors flex items-center justify-start border-r ${
                activeTab === 'defaults'
                  ? 'bg-white font-semibold'
                  : 'hover:bg-white/50 font-normal'
              }`}
              style={{
                fontSize: '12px',
                padding: '0 48px',
                height: '100%',
                minWidth: '140px',
                width: 'auto',
                color: 'var(--graphite-black-hex)',
                borderColor: 'var(--gray-250)',
                borderBottom: activeTab === 'defaults' ? '2px solid var(--tab-active-underline)' : 'none'
              }}
              role="tab"
              aria-selected={activeTab === 'defaults'}
              aria-label={`Defaults${activeTab === 'defaults' ? ' (current tab)' : ''}`}
            >
              Defaults
            </button>
            <button
              onClick={() => setActiveTab('dealer_tiers')}
              className={`transition-colors flex items-center justify-start border-r ${
                activeTab === 'dealer_tiers'
                  ? 'bg-white font-semibold'
                  : 'hover:bg-white/50 font-normal'
              }`}
              style={{
                fontSize: '12px',
                padding: '0 48px',
                height: '100%',
                minWidth: '140px',
                width: 'auto',
                color: 'var(--graphite-black-hex)',
                borderColor: 'var(--gray-250)',
                borderBottom: activeTab === 'dealer_tiers' ? '2px solid var(--tab-active-underline)' : 'none'
              }}
              role="tab"
              aria-selected={activeTab === 'dealer_tiers'}
              aria-label={`Dealer Tiers${activeTab === 'dealer_tiers' ? ' (current tab)' : ''}`}
            >
              Dealer Tiers
            </button>
            <button
              onClick={() => setActiveTab('import_taxes')}
              className={`transition-colors flex items-center justify-start border-r ${
                activeTab === 'import_taxes'
                  ? 'bg-white font-semibold'
                  : 'hover:bg-white/50 font-normal'
              }`}
              style={{
                fontSize: '12px',
                padding: '0 48px',
                height: '100%',
                minWidth: '140px',
                width: 'auto',
                color: 'var(--graphite-black-hex)',
                borderColor: 'var(--gray-250)',
                borderBottom: activeTab === 'import_taxes' ? '2px solid var(--tab-active-underline)' : 'none'
              }}
              role="tab"
              aria-selected={activeTab === 'import_taxes'}
              aria-label={`Import Taxes${activeTab === 'import_taxes' ? ' (current tab)' : ''}`}
            >
              Import Taxes
            </button>
            <button
              onClick={() => setActiveTab('category_margins')}
              className={`transition-colors flex items-center justify-start border-r ${
                activeTab === 'category_margins'
                  ? 'bg-white font-semibold'
                  : 'hover:bg-white/50 font-normal'
              }`}
              style={{
                fontSize: '12px',
                padding: '0 48px',
                height: '100%',
                minWidth: '140px',
                width: 'auto',
                color: 'var(--graphite-black-hex)',
                borderColor: 'var(--gray-250)',
                borderBottom: activeTab === 'category_margins' ? '2px solid var(--tab-active-underline)' : 'none'
              }}
              role="tab"
              aria-selected={activeTab === 'category_margins'}
              aria-label={`Category Margins${activeTab === 'category_margins' ? ' (current tab)' : ''}`}
            >
              Category Margins
            </button>
            <button
              onClick={() => setActiveTab('labor_rules')}
              className={`transition-colors flex items-center justify-start border-r ${
                activeTab === 'labor_rules'
                  ? 'bg-white font-semibold'
                  : 'hover:bg-white/50 font-normal'
              }`}
              style={{
                fontSize: '12px',
                padding: '0 48px',
                height: '100%',
                minWidth: '140px',
                width: 'auto',
                color: 'var(--graphite-black-hex)',
                borderColor: 'var(--gray-250)',
                borderBottom: activeTab === 'labor_rules' ? '2px solid var(--tab-active-underline)' : 'none'
              }}
              role="tab"
              aria-selected={activeTab === 'labor_rules'}
              aria-label={`Labor Rules${activeTab === 'labor_rules' ? ' (current tab)' : ''}`}
            >
              Labor Rules
            </button>
            <button
              onClick={() => setActiveTab('fabric_pricing')}
              className={`transition-colors flex items-center justify-start ${
                activeTab === 'fabric_pricing'
                  ? 'bg-white font-semibold'
                  : 'hover:bg-white/50 font-normal'
              }`}
              style={{
                fontSize: '12px',
                padding: '0 48px',
                height: '100%',
                minWidth: '140px',
                width: 'auto',
                color: 'var(--graphite-black-hex)',
                borderBottom: activeTab === 'fabric_pricing' ? '2px solid var(--tab-active-underline)' : 'none'
              }}
              role="tab"
              aria-selected={activeTab === 'fabric_pricing'}
              aria-label={`Fabric Pricing${activeTab === 'fabric_pricing' ? ' (current tab)' : ''}`}
            >
              Fabric Pricing
            </button>
          </div>
        </div>

        {/* Form Body - Matching CustomerNew content structure */}
        <div className="py-6 px-6">
          {activeTab === 'defaults' && (
            <div className="space-y-8">
              {/* Cost Engine Defaults (no Labor) */}
              <div>
                <h3 className="text-sm font-semibold text-gray-900 mb-4">Cost Engine Defaults</h3>
                <div className="grid grid-cols-2 gap-3">
                {[
                  { key: 'shipping' as const, label: 'Shipping Percentage (%)', field: 'shipping_percentage' as const },
                  { key: 'import_tax' as const, label: 'Global Import Tax % (Fallback)', field: 'import_tax_percent' as const },
                  { key: 'tax' as const, label: 'Tax % (Proposals)', field: 'tax_percent' as const, tooltip: 'General tax (Panama). Used in Proposals/Invoices.' },
                ].map(({ key, label, field, tooltip }) => {
                  const isEditing = editingDefaultKey === key;
                  const displayValue = watch(field) ?? 0;
                  const handleStartEdit = () => {
                    setEditingDefaultKey(key);
                    setDefaultEditValue(String(Math.round(Number(displayValue))));
                  };
                    const handleSaveDefault = async () => {
                    const num = parseFloat(defaultEditValue);
                    if (Number.isNaN(num) || num < 0 || num > 100) {
                      alert(`${label} must be between 0 and 100.`);
                      return;
                    }
                    setValue(field, num);
                    setEditingDefaultKey(null);
                    setDefaultEditValue('');
                    try {
                      setIsSaving(true);
                      const data = getValues();
                      await upsertSettings({
                        shipping_pct: (data.shipping_percentage ?? 15) / 100,
                        global_import_tax_pct: (data.import_tax_percent ?? 0) / 100,
                        tax_pct: (data.tax_percent ?? 7) / 100,
                        default_msrp_pct: (settings?.default_msrp_pct ?? 0.65),
                        minimum_margin_pct: (settings?.minimum_margin_pct ?? 0.35),
                        labor_pct: (settings?.labor_pct ?? 0.10),
                        labor_dealer_pct: ((settings as any)?.labor_dealer_pct ?? 0.35),
                        labor_msrp_pct: ((settings as any)?.labor_msrp_pct ?? 0.65),
                      });
                      setSaveSuccess(true);
                      setTimeout(() => setSaveSuccess(false), 3000);
                    } catch (err: any) {
                      alert(err?.message ?? 'Failed to save.');
                    } finally {
                      setIsSaving(false);
                    }
                  };
                  return (
                    <div
                      key={key}
                      className="col-span-1 col-start-1 flex items-center gap-4 p-4 bg-white border border-gray-200 rounded-lg"
                      title={tooltip}
                    >
                      <div className="flex-1 min-w-0">
                        <span className="font-medium text-gray-900">{label}</span>
                      </div>
                      <div className="flex items-center gap-4 shrink-0">
                        {isEditing ? (
                          <>
                            <div className="w-24">
                              <Input
                                type="number"
                                min={0}
                                max={100}
                                step={1}
                                value={defaultEditValue}
                                onChange={(e) => setDefaultEditValue(e.target.value)}
                                className="py-1 text-xs text-right"
                                placeholder="0"
                              />
                            </div>
                            <span className="text-gray-500 text-sm">%</span>
                            <button
                              type="button"
                              onClick={handleSaveDefault}
                              disabled={isSaving}
                              className="p-2 text-primary hover:bg-primary/10 rounded-md"
                              title="Save"
                            >
                              <Save className="w-4 h-4" />
                            </button>
                            <button
                              type="button"
                              onClick={() => { setEditingDefaultKey(null); setDefaultEditValue(''); }}
                              className="p-2 text-gray-500 hover:bg-gray-100 rounded-md"
                            >
                              <X className="w-4 h-4" />
                            </button>
                          </>
                        ) : (
                          <>
                            <div className="w-20 text-right shrink-0 mr-6">
                              <span className="text-gray-700 font-medium whitespace-nowrap">{Math.round(Number(displayValue))}%</span>
                            </div>
                            <button
                              type="button"
                              onClick={handleStartEdit}
                              className="text-sm text-primary hover:underline"
                            >
                              Edit
                            </button>
                          </>
                        )}
                      </div>
                    </div>
                  );
                })}
              </div>
              </div>

            </div>
          )}

          {activeTab === 'import_taxes' && (
            <div>
              {/* Header */}
              <div className="mb-6">
                <h3 className="text-sm font-semibold text-gray-900 mb-1">Import Tax Rules by Category</h3>
              </div>

              {/* Search and Filters */}
              <div className="mb-4">
                <div className={`bg-white border border-gray-200 py-6 px-6 ${
                  showImportTaxFilters ? 'rounded-t-lg' : 'rounded-lg'
                }`}>
                  <div className="flex items-center justify-between gap-3">
                    <div className="flex-1 relative">
                      <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
                      <input
                        type="text"
                        placeholder="Search categories by name..."
                        value={importTaxSearchTerm}
                        onChange={(e) => setImportTaxSearchTerm(e.target.value)}
                        className="w-full pl-9 pr-3 py-1 border border-gray-200 rounded text-sm bg-gray-50 focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
                        aria-label="Search categories"
                      />
                    </div>
                    
                    <div className="flex items-center gap-2">
                      <button
                        onClick={() => setShowImportTaxFilters(!showImportTaxFilters)}
                        className={`flex items-center gap-2 px-2 py-1 border border-gray-300 rounded transition-colors text-sm ${
                          showImportTaxFilters ? 'bg-gray-300 text-black' : 'bg-white text-gray-700 hover:bg-gray-50'
                        }`}
                      >
                        <Filter style={{ width: '14px', height: '14px' }} />
                        Filters
                      </button>
                    </div>
                  </div>

                  {/* Filters Panel */}
                  {showImportTaxFilters && (
                    <div className="mt-4 pt-4 border-t border-gray-200">
                      <div className="grid grid-cols-12 gap-4">
                        <div className="col-span-3">
                          <Label className="text-xs">Tax Type</Label>
                          <select
                            value={filterImportTaxType}
                            onChange={(e) => setFilterImportTaxType(e.target.value)}
                            className="w-full px-2 py-1 border border-gray-200 rounded text-xs bg-white focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
                          >
                            <option value="all">All Categories</option>
                            <option value="custom">Custom Rules</option>
                            <option value="default">Default Only</option>
                          </select>
                        </div>
                      </div>
                    </div>
                  )}
                </div>
              </div>

              {/* List: two columns (Dealer Tiers style) */}
              {rulesLoading ? (
                <div className="text-center py-8 bg-white border border-gray-200 rounded-lg">
                  <div className="text-sm text-gray-500">Loading rules...</div>
                </div>
              ) : filteredImportTaxCategories.length === 0 ? (
                <div className="py-8 text-center text-sm text-gray-500 bg-white border border-gray-200 rounded-lg">
                  No categories found matching your search criteria.
                </div>
              ) : (
                <div className="grid grid-cols-2 gap-3">
                  {/* Header above left column (same measures as Category Margins) */}
                  <div className="flex items-center gap-4 px-4 py-1 text-xs font-medium text-gray-500">
                    <div className="flex-1 min-w-0">
                      <span className="whitespace-nowrap">Category</span>
                    </div>
                    <div className="w-40 shrink-0" aria-hidden />
                    <div className="w-[4.5rem] shrink-0" aria-hidden />
                  </div>
                  {/* Header above right column */}
                  <div className="flex items-center gap-4 px-4 py-1 text-xs font-medium text-gray-500">
                    <div className="flex-1 min-w-0">
                      <span className="whitespace-nowrap">Category</span>
                    </div>
                    <div className="w-40 shrink-0" aria-hidden />
                    <div className="w-[4.5rem] shrink-0" aria-hidden />
                  </div>
                  {filteredImportTaxCategories.map((category) => {
                    const existingRule = rules.find(r => r.category_id === category.id);
                    const isEditing = editingRuleId === existingRule?.id || editingCategoryId === category.id;
                    const taxPct = existingRule 
                      ? Math.round(existingRule.import_tax_pct * 100)
                      : Math.round((settings?.global_import_tax_pct ?? 0) * 100);

                    return (
                      <div
                        key={category.id}
                        className="flex items-center gap-4 p-4 bg-white border border-gray-200 rounded-lg"
                      >
                        <div className="flex-1 min-w-0">
                          <span className="font-medium text-gray-900">{category.name}</span>
                        </div>
                        <div className="flex items-center gap-4 shrink-0">
                          {isEditing ? (
                            <>
                              <div className="w-20">
                                <Input
                                  type="number"
                                  step="1"
                                  min="0"
                                  max="100"
                                  value={editingPercentage}
                                  onChange={(e) => setEditingPercentage(e.target.value)}
                                  className="py-1 text-xs text-right"
                                  placeholder="0"
                                />
                              </div>
                              <span className="text-gray-500 text-sm">%</span>
                              <button
                                type="button"
                                onClick={async () => {
                                  const percentage = parseFloat(editingPercentage);
                                  if (isNaN(percentage) || percentage < 0) {
                                    alert('Please enter a valid non-negative number');
                                    return;
                                  }
                                  try {
                                    await upsertRule(category.id, percentage / 100);
                                    setEditingRuleId(null);
                                    setEditingCategoryId(null);
                                    setEditingPercentage('');
                                  } catch (err) {
                                    console.error('Error saving rule:', err);
                                    alert('Error saving rule. Check console for details.');
                                  }
                                }}
                                className="p-1.5 hover:bg-green-50 rounded transition-colors text-green-600"
                                title="Save"
                              >
                                <Check className="w-4 h-4" />
                              </button>
                              <button
                                type="button"
                                onClick={() => {
                                  setEditingRuleId(null);
                                  setEditingCategoryId(null);
                                  setEditingPercentage('');
                                }}
                                className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600"
                                title="Cancel"
                              >
                                <X className="w-4 h-4" />
                              </button>
                            </>
                          ) : (
                            <>
                              <div className="w-20 text-right shrink-0 mr-6">
                                <span className="text-gray-700 font-medium whitespace-nowrap">{taxPct}%</span>
                              </div>
                              <button
                                type="button"
                                onClick={() => {
                                  setEditingRuleId(existingRule?.id || null);
                                  setEditingCategoryId(existingRule ? null : category.id);
                                  const valueFromDb = existingRule?.import_tax_pct ?? (settings?.global_import_tax_pct ?? 0);
                                  setEditingPercentage(Math.round(valueFromDb * 100).toString());
                                }}
                                className="text-sm text-primary hover:underline"
                                title={existingRule ? 'Edit' : 'Add'}
                              >
                                Edit
                              </button>
                            </>
                          )}
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          )}

          {activeTab === 'category_margins' && (
            <div>
              {/* Header */}
              <div className="mb-6">
                <h3 className="text-sm font-semibold text-gray-900 mb-1">Category Margins</h3>
              </div>

              {/* Search and Filters */}
              <div className="mb-4">
                <div className={`bg-white border border-gray-200 py-6 px-6 ${
                  showFilters ? 'rounded-t-lg' : 'rounded-lg'
                }`}>
                  <div className="flex items-center justify-between gap-3">
                    <div className="flex-1 relative">
                      <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
                      <input
                        type="text"
                        placeholder="Search categories by name..."
                        value={searchTerm}
                        onChange={(e) => setSearchTerm(e.target.value)}
                        className="w-full pl-9 pr-3 py-1 border border-gray-200 rounded text-sm bg-gray-50 focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
                        aria-label="Search categories"
                      />
                    </div>
                    
                    <div className="flex items-center gap-2">
                      <button
                        onClick={() => setShowFilters(!showFilters)}
                        className={`flex items-center gap-2 px-2 py-1 border border-gray-300 rounded transition-colors text-sm ${
                          showFilters ? 'bg-gray-300 text-black' : 'bg-white text-gray-700 hover:bg-gray-50'
                        }`}
                      >
                        <Filter style={{ width: '14px', height: '14px' }} />
                        Filters
                      </button>
                    </div>
                  </div>

                  {/* Filters Panel */}
                  {showFilters && (
                    <div className="mt-4 pt-4 border-t border-gray-200">
                      <div className="grid grid-cols-12 gap-4">
                        <div className="col-span-3">
                          <Label className="text-xs">Margin Type</Label>
                          <select
                            value={filterHasCustomMargin}
                            onChange={(e) => setFilterHasCustomMargin(e.target.value)}
                            className="w-full px-2 py-1 border border-gray-200 rounded text-xs bg-white focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
                          >
                            <option value="all">All Categories</option>
                            <option value="custom">Custom Margins</option>
                            <option value="default">Default Only</option>
                          </select>
                        </div>
                      </div>
                    </div>
                  )}
                </div>
              </div>

              {/* List: two columns (same as Import Tax / Dealer Tiers) */}
              {marginsLoading ? (
                <div className="text-center py-8 bg-white border border-gray-200 rounded-lg">
                  <div className="text-sm text-gray-500">Loading margins...</div>
                </div>
              ) : (() => {
                let filtered = categories;
                if (searchTerm) {
                  const search = searchTerm.toLowerCase();
                  filtered = filtered.filter(cat => cat.name.toLowerCase().includes(search));
                }
                if (filterHasCustomMargin === 'custom') {
                  filtered = filtered.filter(cat => margins.some(m => m.category_id === cat.id));
                } else if (filterHasCustomMargin === 'default') {
                  filtered = filtered.filter(cat => !margins.some(m => m.category_id === cat.id));
                }
                if (filtered.length === 0) {
                  return (
                    <div className="py-8 text-center text-sm text-gray-500 bg-white border border-gray-200 rounded-lg">
                      No categories found matching your search criteria.
                    </div>
                  );
                }
                return (
                  <div className="grid grid-cols-2 gap-3">
                    {/* Header: same box as card (p-4 + border) so grid aligns exactly with (35%|65% + Edit) */}
                    <div className="flex items-center gap-4 p-4 border border-transparent rounded-lg text-xs font-medium text-gray-500">
                      <div className="w-44 shrink-0 min-w-0">
                        <span className="whitespace-nowrap">Category</span>
                      </div>
                      <div className="flex-1 min-w-0" aria-hidden />
                      <div className="flex items-center gap-4 shrink-0">
                        <div className="grid grid-cols-2 gap-4 shrink-0 w-40 [&>span]:block [&>span]:w-full [&>span]:text-center [&>span]:whitespace-nowrap">
                          <span className="ml-[50px]">Min. Margin %</span>
                          <span className="ml-[50px]">MSRP %</span>
                        </div>
                        <div className="w-[4.5rem] shrink-0" aria-hidden />
                      </div>
                    </div>
                    {/* Header above right column */}
                    <div className="flex items-center gap-4 p-4 border border-transparent rounded-lg text-xs font-medium text-gray-500">
                      <div className="w-44 shrink-0 min-w-0">
                        <span className="whitespace-nowrap">Category</span>
                      </div>
                      <div className="flex-1 min-w-0" aria-hidden />
                      <div className="flex items-center gap-4 shrink-0">
                        <div className="grid grid-cols-2 gap-4 shrink-0 w-40 [&>span]:block [&>span]:w-full [&>span]:text-center [&>span]:whitespace-nowrap">
                          <span className="ml-[50px]">Min. Margin %</span>
                          <span className="ml-[50px]">MSRP %</span>
                        </div>
                        <div className="w-[4.5rem] shrink-0" aria-hidden />
                      </div>
                    </div>
                    {filtered.map((category) => {
                      const existingMargin = margins.find(m => m.category_id === category.id);
                      const isEditing = editingMarginId === existingMargin?.id || editingMarginCategoryId === category.id;
                      const saleInPct = existingMargin
                        ? Math.round(((existingMargin as any).minimum_margin_pct ?? 0.35) * 100)
                        : 35;
                      const msrpPctDisplay = existingMargin && (existingMargin as any).msrp_pct != null
                        ? Math.round((existingMargin as any).msrp_pct * 100)
                        : 65;

                      return (
                        <div
                          key={category.id}
                          className="flex items-center gap-4 p-4 bg-white border border-gray-200 rounded-lg"
                        >
                          <div className="w-44 shrink-0 min-w-0">
                            <span className="font-medium text-gray-900 truncate block">{category.name}</span>
                          </div>
                          <div className="ml-auto flex items-center gap-4 shrink-0">
                            {isEditing ? (
                              <>
                                <div className="grid grid-cols-2 gap-4 w-40 shrink-0">
                                  <Input
                                    type="number"
                                    step="1"
                                    min="0"
                                    max="100"
                                    value={editingMarginPercentage}
                                    onChange={(e) => setEditingMarginPercentage(e.target.value)}
                                    className="w-14 py-1 text-xs text-right justify-self-center"
                                    placeholder="35"
                                  />
                                  <Input
                                    type="number"
                                    step="1"
                                    min="0"
                                    max="200"
                                    value={editingMsrpPct}
                                    onChange={(e) => setEditingMsrpPct(e.target.value)}
                                    className="w-14 py-1 text-xs text-right justify-self-center"
                                    placeholder="65"
                                  />
                                </div>
                                <button
                                  type="button"
                                  onClick={async () => {
                                    const marginPct = parseFloat(editingMarginPercentage);
                                    const msrpPctVal = parseFloat(editingMsrpPct);
                                    if (isNaN(marginPct) || marginPct < 0 || marginPct > 100) {
                                      alert('Min. margin % must be between 0 and 100');
                                      return;
                                    }
                                    if (isNaN(msrpPctVal) || msrpPctVal < 0 || msrpPctVal > 200) {
                                      alert('MSRP % must be between 0 and 200');
                                      return;
                                    }
                                    try {
                                      await upsertMargin(category.id, marginPct / 100, msrpPctVal / 100);
                                      setEditingMarginId(null);
                                      setEditingMarginCategoryId(null);
                                      setEditingMarginPercentage('');
                                      setEditingMsrpPct('');
                                    } catch (err: any) {
                                      console.error('Error saving margin:', err);
                                      alert(err?.message || 'Error saving margin.');
                                    }
                                  }}
                                  className="p-1.5 hover:bg-green-50 rounded text-green-600"
                                  title="Save"
                                >
                                  <Check className="w-4 h-4" />
                                </button>
                                <button
                                  type="button"
                                  onClick={() => {
                                    setEditingMarginId(null);
                                    setEditingMarginCategoryId(null);
                                    setEditingMarginPercentage('');
                                    setEditingMsrpPct('');
                                  }}
                                  className="p-1.5 hover:bg-gray-100 rounded text-gray-600"
                                  title="Cancel"
                                >
                                  <X className="w-4 h-4" />
                                </button>
                              </>
                            ) : (
                              <>
                                <div className="grid grid-cols-2 gap-4 w-40 shrink-0 [&>span]:block [&>span]:w-full [&>span]:text-center [&>span]:whitespace-nowrap">
                                  <span className="text-gray-700 text-sm font-medium">{saleInPct}%</span>
                                  <span className="text-gray-700 text-sm font-medium">{msrpPctDisplay}%</span>
                                </div>
                                <button
                                  type="button"
                                  onClick={() => {
                                    setEditingMarginId(existingMargin?.id || null);
                                    setEditingMarginCategoryId(existingMargin ? null : category.id);
                                    const marginFromDb = (existingMargin as any)?.minimum_margin_pct ?? (settings?.minimum_margin_pct ?? 0.35);
                                    const msrpFromDb = (existingMargin as any)?.msrp_pct ?? (settings?.default_msrp_pct ?? 0.65);
                                    setEditingMarginPercentage(Math.round(marginFromDb * 100).toString());
                                    setEditingMsrpPct(Math.round(msrpFromDb * 100).toString());
                                  }}
                                  className="text-sm text-primary hover:underline"
                                  title={existingMargin ? 'Edit' : 'Add'}
                                >
                                  Edit
                                </button>
                              </>
                            )}
                          </div>
                        </div>
                      );
                    })}
                  </div>
                );
              })()}
            </div>
          )}

          {activeTab === 'dealer_tiers' && (
            <DealerTiersSettings />
          )}

          {activeTab === 'labor_rules' && (
            <div>
              <div className="mb-6 flex items-start justify-between gap-3">
                <div>
                  <h3 className="text-sm font-semibold text-gray-900">Labor Rules Engine</h3>
                </div>
                <div className="flex items-center gap-2">
                  <button
                    type="button"
                    onClick={() => {
                      setEditingLaborRuleId(null);
                      resetLaborRuleDraft();
                      setShowNewLaborRule((v) => !v);
                    }}
                    className="inline-flex items-center gap-2 px-3 py-2 text-xs border border-gray-300 rounded-md hover:bg-gray-50"
                  >
                    <Plus className="w-3.5 h-3.5" />
                    Add Rule
                  </button>
                </div>
              </div>

              {laborRulesError && (
                <div className="mb-4 p-3 bg-amber-50 border border-amber-200 rounded-md text-sm text-amber-800">
                  {laborRulesError}
                </div>
              )}

              {(showNewLaborRule && !editingLaborRuleId) && (
                <div className="mb-4 p-0 bg-white border border-blue-300 rounded-lg overflow-hidden shadow-sm">
                  <div className="px-4 py-2 bg-blue-600 flex items-center gap-2">
                    <Plus className="w-3.5 h-3.5 text-white" />
                    <span className="text-xs font-semibold text-white uppercase tracking-wide">New Labor Rule</span>
                  </div>
                  <div className="p-0 bg-white border border-gray-200 rounded-b-lg overflow-hidden">
                  {/* Section 1: Identification */}
                  <div className="px-4 py-3 bg-gray-50 border-b border-gray-200">
                    <div className="text-[11px] uppercase tracking-wide font-semibold text-gray-700">
                      1. Identification
                    </div>
                  </div>
                  <div className="p-4 grid grid-cols-1 md:grid-cols-12 gap-3 border-b border-gray-100">
                    <div className="md:col-span-6">
                      <Label className="text-xs">
                        Rule Name <span className="text-red-500">*</span>
                      </Label>
                      <Input
                        value={laborRuleDraft.display_name}
                        onChange={(e) => setLaborRuleDraft((p) => ({ ...p, display_name: e.target.value }))}
                        placeholder="Labor Roman Shade v1 (base + area)"
                      />
                    </div>
                    <div className="md:col-span-3">
                      <Label className="text-xs">
                        Product Type <span className="text-red-500">*</span>
                      </Label>
                      <select
                        value={laborRuleDraft.product_type_id}
                        onChange={(e) => setLaborRuleDraft((p) => ({ ...p, product_type_id: e.target.value }))}
                        className="w-full px-2 py-2 border border-gray-200 rounded text-sm bg-white"
                      >
                        <option value="">— Any (wildcard) —</option>
                        {productTypes.map((pt) => (
                          <option key={pt.id} value={pt.id}>
                            {pt.name}
                          </option>
                        ))}
                      </select>
                      <p className="text-[10px] text-gray-500 mt-1">
                        Wildcard rules apply to any type that has no specific rule.
                      </p>
                    </div>
                    <div className="md:col-span-2">
                      <Label className="text-xs">Priority</Label>
                      <Input
                        type="number"
                        value={laborRuleDraft.priority}
                        onChange={(e) => setLaborRuleDraft((p) => ({ ...p, priority: e.target.value }))}
                      />
                      <p className="text-[10px] text-gray-500 mt-1">Higher wins on ties.</p>
                    </div>
                    <div className="md:col-span-1">
                      <Label className="text-xs">Active</Label>
                      <div className="h-9 flex items-center">
                        <button
                          type="button"
                          onClick={() => setLaborRuleDraft((p) => ({ ...p, is_active: !p.is_active }))}
                          className={`px-3 py-1.5 rounded text-xs font-medium border ${
                            laborRuleDraft.is_active
                              ? 'bg-emerald-50 border-emerald-300 text-emerald-700'
                              : 'bg-gray-50 border-gray-300 text-gray-600'
                          }`}
                        >
                          {laborRuleDraft.is_active ? 'Yes' : 'No'}
                        </button>
                      </div>
                    </div>
                  </div>

                  {/* Section 2: Filters */}
                  <div className="px-4 py-3 bg-gray-50 border-b border-gray-200">
                    <div className="flex items-center justify-between">
                      <div className="text-[11px] uppercase tracking-wide font-semibold text-gray-700">
                        2. When this rule applies (filters)
                      </div>
                      <div className="text-[10px] text-gray-500">
                        All filters use AND. Empty = no restriction.
                      </div>
                    </div>
                  </div>
                  <div className="p-4 grid grid-cols-1 md:grid-cols-6 gap-3 border-b border-gray-100">
                    <div className="md:col-span-2">
                      <Label className="text-xs">Motor</Label>
                      <select
                        value={laborRuleDraft.motor_required}
                        onChange={(e) => setLaborRuleDraft((p) => ({ ...p, motor_required: e.target.value }))}
                        className="w-full px-2 py-2 border border-gray-200 rounded text-sm bg-white"
                      >
                        <option value="">Any</option>
                        <option value="true">Required</option>
                        <option value="false">Not allowed</option>
                      </select>
                    </div>
                    <div className="md:col-span-2">
                      <Label className="text-xs">Track Only</Label>
                      <select
                        value={laborRuleDraft.track_only_required}
                        onChange={(e) => setLaborRuleDraft((p) => ({ ...p, track_only_required: e.target.value }))}
                        className="w-full px-2 py-2 border border-gray-200 rounded text-sm bg-white"
                      >
                        <option value="">Any</option>
                        <option value="true">Track only</option>
                        <option value="false">With fabric</option>
                      </select>
                    </div>
                    <div className="md:col-span-2">
                      <Label className="text-xs">Operating Type</Label>
                      <Input
                        type="text"
                        placeholder="e.g. motorized, manual, chain (optional)"
                        value={laborRuleDraft.operating_type}
                        onChange={(e) => setLaborRuleDraft((p) => ({ ...p, operating_type: e.target.value }))}
                      />
                    </div>

                    <div className="md:col-span-3">
                      <Label className="text-xs">Width range (mm)</Label>
                      <div className="flex items-center gap-2">
                        <Input
                          type="number"
                          placeholder="min"
                          value={laborRuleDraft.width_min_mm}
                          onChange={(e) => setLaborRuleDraft((p) => ({ ...p, width_min_mm: e.target.value }))}
                        />
                        <span className="text-xs text-gray-400">–</span>
                        <Input
                          type="number"
                          placeholder="max"
                          value={laborRuleDraft.width_max_mm}
                          onChange={(e) => setLaborRuleDraft((p) => ({ ...p, width_max_mm: e.target.value }))}
                        />
                      </div>
                    </div>
                    <div className="md:col-span-3">
                      <Label className="text-xs">Height range (mm)</Label>
                      <div className="flex items-center gap-2">
                        <Input
                          type="number"
                          placeholder="min"
                          value={laborRuleDraft.height_min_mm}
                          onChange={(e) => setLaborRuleDraft((p) => ({ ...p, height_min_mm: e.target.value }))}
                        />
                        <span className="text-xs text-gray-400">–</span>
                        <Input
                          type="number"
                          placeholder="max"
                          value={laborRuleDraft.height_max_mm}
                          onChange={(e) => setLaborRuleDraft((p) => ({ ...p, height_max_mm: e.target.value }))}
                        />
                      </div>
                    </div>
                    <div className="md:col-span-2">
                      <Label className="text-xs">Area range (m²)</Label>
                      <div className="flex items-center gap-2">
                        <Input
                          type="number"
                          step="0.01"
                          placeholder="min"
                          value={laborRuleDraft.area_min_m2}
                          onChange={(e) => setLaborRuleDraft((p) => ({ ...p, area_min_m2: e.target.value }))}
                        />
                        <span className="text-xs text-gray-400">–</span>
                        <Input
                          type="number"
                          step="0.01"
                          placeholder="max"
                          value={laborRuleDraft.area_max_m2}
                          onChange={(e) => setLaborRuleDraft((p) => ({ ...p, area_max_m2: e.target.value }))}
                        />
                      </div>
                    </div>
                    <div className="md:col-span-2">
                      <Label className="text-xs">Panels</Label>
                      <div className="flex items-center gap-2">
                        <Input
                          type="number"
                          placeholder="min"
                          value={laborRuleDraft.panel_count_min}
                          onChange={(e) => setLaborRuleDraft((p) => ({ ...p, panel_count_min: e.target.value }))}
                        />
                        <span className="text-xs text-gray-400">–</span>
                        <Input
                          type="number"
                          placeholder="max"
                          value={laborRuleDraft.panel_count_max}
                          onChange={(e) => setLaborRuleDraft((p) => ({ ...p, panel_count_max: e.target.value }))}
                        />
                      </div>
                    </div>
                    <div className="md:col-span-2">
                      <Label className="text-xs">Drops</Label>
                      <div className="flex items-center gap-2">
                        <Input
                          type="number"
                          placeholder="min"
                          value={laborRuleDraft.drops_min}
                          onChange={(e) => setLaborRuleDraft((p) => ({ ...p, drops_min: e.target.value }))}
                        />
                        <span className="text-xs text-gray-400">–</span>
                        <Input
                          type="number"
                          placeholder="max"
                          value={laborRuleDraft.drops_max}
                          onChange={(e) => setLaborRuleDraft((p) => ({ ...p, drops_max: e.target.value }))}
                        />
                      </div>
                    </div>
                  </div>

                  {/* Section 3: Calculation */}
                  <div className="px-4 py-3 bg-gray-50 border-b border-gray-200">
                    <div className="flex items-center justify-between">
                      <div className="text-[11px] uppercase tracking-wide font-semibold text-gray-700">
                        3. How labor is calculated
                      </div>
                      <div className="text-[10px] text-gray-500">
                        Composite sums all rates below. Other modes use only their own rate.
                      </div>
                    </div>
                  </div>
                  <div className="p-4 grid grid-cols-1 md:grid-cols-6 gap-3">
                    <div className="md:col-span-2">
                      <Label className="text-xs">Calc Mode</Label>
                      <select
                        value={laborRuleDraft.calc_mode}
                        onChange={(e) => setLaborRuleDraft((p) => ({ ...p, calc_mode: e.target.value }))}
                        className="w-full px-2 py-2 border border-gray-200 rounded text-sm bg-white"
                      >
                        <option value="composite">Composite (recommended)</option>
                        <option value="pct_materials">% of materials</option>
                        <option value="fixed">Fixed amount only</option>
                        <option value="per_m2">Per m² only</option>
                        <option value="per_drop">Per drop only</option>
                        <option value="per_panel">Per panel only</option>
                        <option value="per_height_m">Per height m only</option>
                        <option value="per_width_m">Per width m only</option>
                      </select>
                    </div>

                    {laborRuleDraft.calc_mode === 'pct_materials' && (
                      <div className="md:col-span-2">
                        <Label className="text-xs">% of materials (0-1, e.g. 0.10 = 10%)</Label>
                        <Input
                          type="number"
                          step="0.01"
                          value={laborRuleDraft.pct_materials}
                          onChange={(e) => setLaborRuleDraft((p) => ({ ...p, pct_materials: e.target.value }))}
                        />
                      </div>
                    )}

                    <div className="md:col-span-2">
                      <Label className="text-xs">Fixed amount ($)</Label>
                      <Input
                        type="number"
                        step="0.01"
                        value={laborRuleDraft.fixed_amount}
                        onChange={(e) => setLaborRuleDraft((p) => ({ ...p, fixed_amount: e.target.value }))}
                      />
                    </div>
                    <div className="md:col-span-2">
                      <Label className="text-xs">Rate per m² ($)</Label>
                      <Input
                        type="number"
                        step="0.01"
                        value={laborRuleDraft.rate_per_m2}
                        onChange={(e) => setLaborRuleDraft((p) => ({ ...p, rate_per_m2: e.target.value }))}
                      />
                    </div>
                    <div className="md:col-span-2">
                      <Label className="text-xs">
                        Rate per drop ($) <span className="text-gray-400">× drops</span>
                      </Label>
                      <Input
                        type="number"
                        step="0.01"
                        value={laborRuleDraft.rate_per_drop}
                        onChange={(e) => setLaborRuleDraft((p) => ({ ...p, rate_per_drop: e.target.value }))}
                      />
                    </div>
                    <div className="md:col-span-2">
                      <Label className="text-xs">
                        Rate per panel ($) <span className="text-gray-400">× panels</span>
                      </Label>
                      <Input
                        type="number"
                        step="0.01"
                        value={laborRuleDraft.rate_per_panel}
                        onChange={(e) => setLaborRuleDraft((p) => ({ ...p, rate_per_panel: e.target.value }))}
                      />
                    </div>
                    <div className="md:col-span-2">
                      <Label className="text-xs">Rate per height m ($)</Label>
                      <Input
                        type="number"
                        step="0.01"
                        value={laborRuleDraft.rate_per_height_m}
                        onChange={(e) => setLaborRuleDraft((p) => ({ ...p, rate_per_height_m: e.target.value }))}
                      />
                    </div>
                    <div className="md:col-span-2">
                      <Label className="text-xs">Rate per width m ($)</Label>
                      <Input
                        type="number"
                        step="0.01"
                        value={laborRuleDraft.rate_per_width_m}
                        onChange={(e) => setLaborRuleDraft((p) => ({ ...p, rate_per_width_m: e.target.value }))}
                      />
                    </div>
                    <div className="md:col-span-2">
                      <Label className="text-xs">
                        Motor add-on ($) <span className="text-gray-400">if motor on</span>
                      </Label>
                      <Input
                        type="number"
                        step="0.01"
                        value={laborRuleDraft.rate_motor_addon}
                        onChange={(e) => setLaborRuleDraft((p) => ({ ...p, rate_motor_addon: e.target.value }))}
                      />
                    </div>

                    <div className="md:col-span-3">
                      <Label className="text-xs">Min charge ($)</Label>
                      <Input
                        type="number"
                        step="0.01"
                        value={laborRuleDraft.min_charge}
                        onChange={(e) => setLaborRuleDraft((p) => ({ ...p, min_charge: e.target.value }))}
                      />
                    </div>
                    <div className="md:col-span-3">
                      <Label className="text-xs">Max charge ($, optional)</Label>
                      <Input
                        type="number"
                        step="0.01"
                        placeholder="No cap"
                        value={laborRuleDraft.max_charge}
                        onChange={(e) => setLaborRuleDraft((p) => ({ ...p, max_charge: e.target.value }))}
                      />
                    </div>

                    <div className="md:col-span-6 mt-2 pt-2 border-t border-gray-200">
                      <div className="text-[11px] font-semibold text-gray-700 uppercase tracking-wide mb-2">
                        Size escalation (base labor)
                      </div>
                      <div className="text-[11px] text-gray-500 mb-2">
                        Multiplies the composite base by <code className="px-1 bg-gray-100 rounded">1 + escalation × max(width − reference, 0)</code>.
                        Use <code className="px-1 bg-gray-100 rounded">0</code> to disable.
                      </div>
                    </div>
                    <div className="md:col-span-3">
                      <Label className="text-xs">Size escalation (% per m, decimal)</Label>
                      <Input
                        type="number"
                        step="0.001"
                        placeholder="0 = off, 0.05 = +5%/m"
                        value={laborRuleDraft.size_escalation_pct}
                        onChange={(e) => setLaborRuleDraft((p) => ({ ...p, size_escalation_pct: e.target.value }))}
                      />
                    </div>
                    <div className="md:col-span-3">
                      <Label className="text-xs">Reference width (m)</Label>
                      <Input
                        type="number"
                        step="0.01"
                        value={laborRuleDraft.size_reference_width_m}
                        onChange={(e) => setLaborRuleDraft((p) => ({ ...p, size_reference_width_m: e.target.value }))}
                      />
                    </div>

                    <div className="md:col-span-6 mt-2 pt-2 border-t border-gray-200">
                      <div className="text-[11px] font-semibold text-gray-700 uppercase tracking-wide mb-2">
                        Heatseal & bottom-bar wrap
                      </div>
                      <div className="text-[11px] text-gray-500 mb-2">
                        Heatseal charges <code className="px-1 bg-gray-100 rounded">rate × heatseal_length_m</code> only when fabric rotation triggers seams.
                        Wrap charges <code className="px-1 bg-gray-100 rounded">rate × width_m</code> only when bottom bar is wrapped.
                      </div>
                    </div>
                    <div className="md:col-span-3">
                      <Label className="text-xs">Heatseal rate ($/m of seam)</Label>
                      <Input
                        type="number"
                        step="0.01"
                        value={laborRuleDraft.heatseal_rate_per_m}
                        onChange={(e) => setLaborRuleDraft((p) => ({ ...p, heatseal_rate_per_m: e.target.value }))}
                      />
                    </div>
                    <div className="md:col-span-3">
                      <Label className="text-xs">Bottom-bar wrap rate ($/m of width)</Label>
                      <Input
                        type="number"
                        step="0.01"
                        value={laborRuleDraft.bottom_bar_wrap_rate_per_m}
                        onChange={(e) => setLaborRuleDraft((p) => ({ ...p, bottom_bar_wrap_rate_per_m: e.target.value }))}
                      />
                    </div>

                    <div className="md:col-span-6 mt-2 pt-2 border-t border-gray-200">
                      <div className="text-[11px] font-semibold text-gray-700 uppercase tracking-wide mb-2">
                        Confection (drapery / outsourced fabric work)
                      </div>
                      <div className="text-[11px] text-gray-500 mb-2">
                        Total confection = <code className="px-1 bg-gray-100 rounded">(base + rate_per_m² × area) × (1 + escalation × max(width − reference, 0))</code>.
                        Leave at 0 to disable.
                      </div>
                    </div>
                    <div className="md:col-span-2">
                      <Label className="text-xs">Confection base ($)</Label>
                      <Input
                        type="number"
                        step="0.01"
                        value={laborRuleDraft.confection_base}
                        onChange={(e) => setLaborRuleDraft((p) => ({ ...p, confection_base: e.target.value }))}
                      />
                    </div>
                    <div className="md:col-span-2">
                      <Label className="text-xs">Confection rate ($/m²)</Label>
                      <Input
                        type="number"
                        step="0.01"
                        value={laborRuleDraft.confection_rate_per_m2}
                        onChange={(e) => setLaborRuleDraft((p) => ({ ...p, confection_rate_per_m2: e.target.value }))}
                      />
                    </div>
                    <div className="md:col-span-1">
                      <Label className="text-xs">Conf. esc. (per m)</Label>
                      <Input
                        type="number"
                        step="0.001"
                        value={laborRuleDraft.confection_size_escalation_pct}
                        onChange={(e) => setLaborRuleDraft((p) => ({ ...p, confection_size_escalation_pct: e.target.value }))}
                      />
                    </div>
                    <div className="md:col-span-1">
                      <Label className="text-xs">Conf. ref. width (m)</Label>
                      <Input
                        type="number"
                        step="0.01"
                        value={laborRuleDraft.confection_size_reference_width_m}
                        onChange={(e) => setLaborRuleDraft((p) => ({ ...p, confection_size_reference_width_m: e.target.value }))}
                      />
                    </div>
                  </div>

                  <div className="px-4 py-3 bg-gray-50 border-t border-gray-200 flex items-center justify-end gap-2">
                    <button
                      type="button"
                      onClick={() => {
                        setShowNewLaborRule(false);
                        setEditingLaborRuleId(null);
                        resetLaborRuleDraft();
                      }}
                      className="px-3 py-2 text-xs border border-gray-300 rounded-md hover:bg-gray-50"
                    >
                      Cancel
                    </button>
                    <button
                      type="button"
                      disabled={isSavingLaborRule}
                      onClick={saveLaborRule}
                      className="inline-flex items-center gap-2 px-3 py-2 text-xs bg-primary text-white rounded-md hover:bg-primary/90 disabled:opacity-50"
                    >
                      <Save className="w-3.5 h-3.5" />
                      Create Rule
                    </button>
                  </div>
                  </div>
                </div>
              )}

              {laborRulesLoading ? (
                <div className="text-center py-8 bg-white border border-gray-200 rounded-lg">
                  <div className="text-sm text-gray-500">Loading labor rules...</div>
                </div>
              ) : laborRules.length === 0 ? (
                <div className="py-8 text-center text-sm text-gray-500 bg-white border border-gray-200 rounded-lg">
                  No labor rules found for this organization yet.
                </div>
              ) : (
                <>
                  {/* ── Filter / search toolbar ────────────────────────── */}
                  <div className="mb-4 flex flex-wrap items-center gap-2.5 p-4 bg-white border border-gray-200 rounded-lg">
                    <div className="flex items-center gap-1.5 text-xs bg-gray-100 rounded px-2.5 py-1.5 text-gray-700">
                      <span>Total <strong>{laborStats.total}</strong></span>
                      <span className="text-gray-400">·</span>
                      <span className="text-emerald-700">Active <strong>{laborStats.active}</strong></span>
                      <span className="text-gray-400">·</span>
                      <span className="text-gray-500">Inactive <strong>{laborStats.inactive}</strong></span>
                    </div>
                    <div className="inline-flex rounded border border-gray-300 overflow-hidden text-xs">
                      {(['active', 'all', 'inactive'] as const).map((status) => (
                        <button
                          key={status}
                          type="button"
                          onClick={() => setLaborStatusFilter(status)}
                          className={`px-2 py-1 ${
                            laborStatusFilter === status
                              ? 'bg-gray-900 text-white'
                              : 'bg-white text-gray-700 hover:bg-gray-50'
                          }`}
                        >
                          {status === 'all' ? 'All' : status === 'active' ? 'Active only' : 'Inactive'}
                        </button>
                      ))}
                    </div>
                    <select
                      value={laborProductFilter}
                      onChange={(e) => setLaborProductFilter(e.target.value)}
                      className="text-xs border border-gray-300 rounded px-2 py-1 bg-white"
                    >
                      <option value="all">All product types</option>
                      <option value="__wildcard__">Any (wildcard)</option>
                      {productTypes.map((pt) => (
                        <option key={pt.id} value={pt.id}>
                          {pt.name}
                        </option>
                      ))}
                    </select>
                    <div className="flex-1 min-w-[240px]">
                      <Input
                        type="text"
                        value={laborSearch}
                        onChange={(e) => setLaborSearch(e.target.value)}
                        placeholder="Search rule name, product type, or operation mode..."
                        className="text-sm h-9"
                      />
                    </div>
                    {(laborSearch || laborStatusFilter !== 'active' || laborProductFilter !== 'all') && (
                      <button
                        type="button"
                        onClick={() => {
                          setLaborSearch('');
                          setLaborStatusFilter('active');
                          setLaborProductFilter('all');
                        }}
                        className="text-xs underline text-gray-600 hover:text-gray-800"
                      >
                        Reset
                      </button>
                    )}
                  </div>

                  {laborGroups.totalAfterFilters === 0 ? (
                    <div className="py-8 text-center text-sm text-gray-500 bg-white border border-gray-200 rounded-lg">
                      No labor rules match the current filters.
                    </div>
                  ) : (
                    <div className="space-y-4">
                      {laborGroups.groups.map((group) => {
                        const collapsed = collapsedGroups[group.key] !== false;
                        const activeCount = group.rules.filter((r) => r.is_active).length;
                        return (
                          <div key={group.key} className="bg-white border border-gray-200 rounded-lg overflow-hidden">
                            <button
                              type="button"
                              onClick={() => toggleGroup(group.key)}
                              className="w-full flex items-center justify-between gap-3 px-4 py-3 bg-gray-50 hover:bg-gray-100 border-b border-gray-200"
                            >
                              <div className="flex items-center gap-2 text-base font-semibold text-gray-900">
                                <span className="text-gray-400 text-sm">{collapsed ? '▸' : '▾'}</span>
                                {group.label}
                                <span className="text-[11px] font-medium px-2 py-0.5 rounded bg-emerald-100 text-emerald-700">
                                  {activeCount} active
                                </span>
                                {group.rules.length > activeCount && (
                                  <span className="text-[11px] font-medium px-2 py-0.5 rounded bg-gray-200 text-gray-600">
                                    {group.rules.length - activeCount} inactive
                                  </span>
                                )}
                              </div>
                              <span className="text-xs text-gray-500">
                                {group.rules.length} rule{group.rules.length === 1 ? '' : 's'}
                              </span>
                            </button>

                            {!collapsed && (
                              <div className="divide-y divide-gray-100">
                                {group.rules.map((rule) => {
                                  const fmtRange = (lo: any, hi: any, suffix: string) => {
                                    if (lo == null && hi == null) return null;
                                    const a = lo != null ? `${Number(lo)}` : '–';
                                    const b = hi != null ? `${Number(hi)}` : '–';
                                    return `${a}…${b} ${suffix}`;
                                  };
                                  const filterChips = [
                                    rule.motor_required == null ? null : rule.motor_required ? 'motor required' : 'no motor',
                                    rule.track_only_required == null ? null : rule.track_only_required ? 'track only' : 'with fabric',
                                    rule.operating_type ? `op: ${rule.operating_type}` : null,
                                    fmtRange(rule.width_min_mm, rule.width_max_mm, 'mm w'),
                                    fmtRange(rule.height_min_mm, rule.height_max_mm, 'mm h'),
                                    fmtRange(rule.area_min_m2, rule.area_max_m2, 'm²'),
                                    fmtRange(rule.panel_count_min, rule.panel_count_max, 'panels'),
                                    fmtRange(rule.drops_min, rule.drops_max, 'drops'),
                                  ].filter(Boolean) as string[];

                                  const fmt$ = (v: any) => `$${Number(v ?? 0).toFixed(2)}`;
                                  const baseParts: string[] = [];
                                  if (Number(rule.fixed_amount ?? 0) > 0) baseParts.push(`${fmt$(rule.fixed_amount)} flat`);
                                  if (Number(rule.rate_per_m2 ?? 0) > 0) baseParts.push(`${fmt$(rule.rate_per_m2)}/m²`);
                                  if (Number(rule.rate_per_drop ?? 0) > 0) baseParts.push(`${fmt$(rule.rate_per_drop)}/drop`);
                                  if (Number((rule as any).rate_per_panel ?? 0) > 0) baseParts.push(`${fmt$((rule as any).rate_per_panel)}/panel`);
                                  if (Number((rule as any).rate_per_height_m ?? 0) > 0) baseParts.push(`${fmt$((rule as any).rate_per_height_m)}/m·h`);
                                  if (Number((rule as any).rate_per_width_m ?? 0) > 0) baseParts.push(`${fmt$((rule as any).rate_per_width_m)}/m·w`);
                                  if (Number(rule.rate_motor_addon ?? 0) > 0) baseParts.push(`+${fmt$(rule.rate_motor_addon)} motor`);
                                  if (Number((rule as any).pct_materials ?? 0) > 0) baseParts.push(`${(Number((rule as any).pct_materials) * 100).toFixed(1)}% materials`);

                                  const surchargeParts: { label: string; value: string }[] = [];
                                  const hsRate = Number((rule as any).heatseal_rate_per_m ?? 0);
                                  const wrapRate = Number((rule as any).bottom_bar_wrap_rate_per_m ?? 0);
                                  const confBase = Number((rule as any).confection_base ?? 0);
                                  const confM2 = Number((rule as any).confection_rate_per_m2 ?? 0);
                                  if (hsRate > 0) surchargeParts.push({ label: 'Heatseal', value: `${fmt$(hsRate)}/m of seam` });
                                  if (wrapRate > 0) surchargeParts.push({ label: 'BB Wrap', value: `${fmt$(wrapRate)}/m of width` });
                                  if (confBase > 0 || confM2 > 0) surchargeParts.push({
                                    label: 'Confection',
                                    value: `${fmt$(confBase)} + ${fmt$(confM2)}/m²`,
                                  });

                                  const sizeEsc = Number((rule as any).size_escalation_pct ?? 0);
                                  const sizeRef = Number((rule as any).size_reference_width_m ?? 1);
                                  const confEsc = Number((rule as any).confection_size_escalation_pct ?? 0);
                                  const confRef = Number((rule as any).confection_size_reference_width_m ?? 1);

                                  return (
                                    <React.Fragment key={rule.id}>
                                    <div
                                      className={`px-4 py-4 ${rule.is_active ? 'bg-white' : 'bg-gray-50/60 opacity-70'}`}
                                    >
                                      <div className="flex items-start justify-between gap-3">
                                        <div className="flex-1 min-w-0">
                                          <div className="flex items-center gap-2 flex-wrap mb-1">
                                            <span className="text-[11px] uppercase tracking-wide text-gray-500">
                                              Rule
                                            </span>
                                            <span className={`text-base font-semibold ${rule.is_active ? 'text-gray-900' : 'text-gray-500 line-through decoration-gray-400'}`}>
                                              {rule.display_name}
                                            </span>
                                            <span className="text-[11px] px-2 py-0.5 rounded bg-purple-50 text-purple-700 border border-purple-100">
                                              mode: {rule.calc_mode || 'composite'}
                                            </span>
                                            <span className="text-[11px] px-2 py-0.5 rounded bg-gray-100 text-gray-700">
                                              priority {rule.priority}
                                            </span>
                                            <span
                                              className={`text-[11px] px-2 py-0.5 rounded-full whitespace-nowrap ${
                                                rule.is_active
                                                  ? 'bg-emerald-100 text-emerald-700'
                                                  : 'bg-gray-200 text-gray-600'
                                              }`}
                                            >
                                              {rule.is_active ? 'Active' : 'Inactive'}
                                            </span>
                                          </div>
                                          {filterChips.length > 0 && (
                                            <div className="mt-2 flex items-center gap-1.5 flex-wrap">
                                              <span className="text-[11px] uppercase tracking-wide text-gray-500 mr-1">
                                                Applies when
                                              </span>
                                              {filterChips.map((chip) => (
                                                <span
                                                  key={chip}
                                                  className="text-[11px] text-gray-600 px-2 py-0.5 rounded border border-gray-200 bg-gray-50"
                                                >
                                                  {chip}
                                                </span>
                                              ))}
                                            </div>
                                          )}

                                          <div className="mt-3 grid grid-cols-1 md:grid-cols-2 gap-x-6 gap-y-2 text-xs">
                                            <div>
                                              <span className="text-gray-500 font-semibold uppercase tracking-wide text-[11px]">Base formula </span>
                                              <span className="text-gray-700">
                                                {baseParts.length > 0 ? baseParts.join(' + ') : <em className="text-gray-400">— no base components configured —</em>}
                                              </span>
                                              {(Number(rule.min_charge ?? 0) > 0 || rule.max_charge != null) && (
                                                <span className="ml-2 text-gray-500">
                                                  ({Number(rule.min_charge ?? 0) > 0 ? `min ${fmt$(rule.min_charge)}` : 'no min'}
                                                  {' / '}
                                                  {rule.max_charge != null ? `max ${fmt$(rule.max_charge)}` : 'no cap'})
                                                </span>
                                              )}
                                            </div>
                                            <div>
                                              <span className="text-gray-500 font-semibold uppercase tracking-wide text-[11px]">Surcharges </span>
                                              {surchargeParts.length > 0 ? (
                                                <span className="text-gray-700">
                                                  {surchargeParts.map((s, i) => (
                                                    <span key={s.label}>
                                                      {i > 0 && ' · '}
                                                      <span className="text-gray-500">{s.label}:</span> {s.value}
                                                    </span>
                                                  ))}
                                                </span>
                                              ) : (
                                                <em className="text-gray-400">none</em>
                                              )}
                                            </div>
                                          </div>

                                          {(sizeEsc > 0 || confEsc > 0) && (
                                            <div className="mt-2 text-[11px] text-blue-700 bg-blue-50/60 rounded px-2.5 py-1 inline-block">
                                              {sizeEsc > 0 && (
                                                <span>
                                                  Size esc: <strong>{(sizeEsc * 100).toFixed(2)}%/m</strong> over <strong>{sizeRef.toFixed(2)} m</strong>
                                                </span>
                                              )}
                                              {sizeEsc > 0 && confEsc > 0 && <span className="mx-1.5">·</span>}
                                              {confEsc > 0 && (
                                                <span>
                                                  Conf esc: <strong>{(confEsc * 100).toFixed(2)}%/m</strong> over <strong>{confRef.toFixed(2)} m</strong>
                                                </span>
                                              )}
                                            </div>
                                          )}
                                        </div>

                                        <div className="flex flex-col items-end gap-1">
                                          <div className="flex items-center gap-1">
                                            <button
                                              type="button"
                                              onClick={() => {
                                                setShowNewLaborRule(false);
                                                beginEditLaborRule(rule);
                                              }}
                                              className={`inline-flex items-center gap-1.5 px-2 py-1 text-[11px] border rounded ${
                                                editingLaborRuleId === rule.id
                                                  ? 'border-blue-400 bg-blue-50 text-blue-700'
                                                  : 'border-gray-300 hover:bg-gray-50 text-gray-700'
                                              }`}
                                              title="Edit rule"
                                            >
                                              <Edit2 className="w-3 h-3" />
                                              {editingLaborRuleId === rule.id ? 'Editing…' : 'Edit'}
                                            </button>
                                            <button
                                              type="button"
                                              onClick={async () => {
                                                try {
                                                  await upsertLaborRule({
                                                    id: rule.id,
                                                    display_name: rule.display_name,
                                                    product_type_id: rule.product_type_id,
                                                    is_active: !rule.is_active,
                                                    priority: rule.priority,
                                                    calc_mode: rule.calc_mode,
                                                    fixed_amount: rule.fixed_amount,
                                                    rate_per_m2: rule.rate_per_m2,
                                                    rate_per_drop: rule.rate_per_drop,
                                                    rate_per_panel: (rule as any).rate_per_panel,
                                                    rate_per_height_m: (rule as any).rate_per_height_m,
                                                    rate_per_width_m: (rule as any).rate_per_width_m,
                                                    rate_motor_addon: rule.rate_motor_addon,
                                                    pct_materials: (rule as any).pct_materials,
                                                    min_charge: rule.min_charge,
                                                    max_charge: rule.max_charge,
                                                    width_min_mm: rule.width_min_mm,
                                                    width_max_mm: rule.width_max_mm,
                                                    height_min_mm: rule.height_min_mm,
                                                    height_max_mm: rule.height_max_mm,
                                                    area_min_m2: rule.area_min_m2,
                                                    area_max_m2: rule.area_max_m2,
                                                    panel_count_min: rule.panel_count_min,
                                                    panel_count_max: rule.panel_count_max,
                                                    drops_min: rule.drops_min,
                                                    drops_max: rule.drops_max,
                                                    operating_type: rule.operating_type,
                                                    motor_required: rule.motor_required,
                                                    track_only_required: (rule as any).track_only_required,
                                                    size_escalation_pct: (rule as any).size_escalation_pct,
                                                    size_reference_width_m: (rule as any).size_reference_width_m,
                                                    heatseal_rate_per_m: (rule as any).heatseal_rate_per_m,
                                                    bottom_bar_wrap_rate_per_m: (rule as any).bottom_bar_wrap_rate_per_m,
                                                    confection_base: (rule as any).confection_base,
                                                    confection_rate_per_m2: (rule as any).confection_rate_per_m2,
                                                    confection_size_escalation_pct: (rule as any).confection_size_escalation_pct,
                                                    confection_size_reference_width_m: (rule as any).confection_size_reference_width_m,
                                                  });
                                                } catch (err: any) {
                                                  alert(err?.message || 'Error toggling rule.');
                                                }
                                              }}
                                              className={`inline-flex items-center gap-1.5 px-2 py-1 text-[11px] border rounded ${
                                                rule.is_active
                                                  ? 'border-amber-300 text-amber-700 hover:bg-amber-50'
                                                  : 'border-emerald-300 text-emerald-700 hover:bg-emerald-50'
                                              }`}
                                              title={rule.is_active ? 'Deactivate' : 'Activate'}
                                            >
                                              {rule.is_active ? 'Deactivate' : 'Activate'}
                                            </button>
                                            <button
                                              type="button"
                                              onClick={async () => {
                                                if (!confirm('Delete this labor rule?')) return;
                                                try {
                                                  await deleteLaborRule(rule.id);
                                                  if (editingLaborRuleId === rule.id) {
                                                    setEditingLaborRuleId(null);
                                                    resetLaborRuleDraft();
                                                  }
                                                } catch (err: any) {
                                                  alert(err?.message || 'Error deleting rule.');
                                                }
                                              }}
                                              className="inline-flex items-center gap-1.5 px-2 py-1 text-[11px] border border-red-200 text-red-700 rounded hover:bg-red-50"
                                              title="Delete rule"
                                            >
                                              <X className="w-3 h-3" />
                                            </button>
                                          </div>
                                        </div>
                                      </div>
                                    </div>

                                    {/* ── Inline edit form ── */}
                                    {editingLaborRuleId === rule.id && (
                                      <div className="border-t-2 border-blue-400 bg-blue-50/30 p-0">
                                        <div className="px-4 py-2 bg-blue-600 flex items-center justify-between gap-2">
                                          <div className="flex items-center gap-2">
                                            <Edit2 className="w-3.5 h-3.5 text-white" />
                                            <span className="text-xs font-semibold text-white uppercase tracking-wide">
                                              Editing: {rule.display_name}
                                            </span>
                                          </div>
                                          <button
                                            type="button"
                                            onClick={() => { setEditingLaborRuleId(null); resetLaborRuleDraft(); }}
                                            className="text-white/70 hover:text-white"
                                          >
                                            <X className="w-4 h-4" />
                                          </button>
                                        </div>
                                        <div className="bg-white">

                                          {/* Section 1: Identification */}
                                          <div className="px-4 py-3 bg-gray-50 border-b border-gray-200">
                                            <div className="text-[11px] uppercase tracking-wide font-semibold text-gray-700">1. Identification</div>
                                          </div>
                                          <div className="p-4 grid grid-cols-1 md:grid-cols-12 gap-3 border-b border-gray-100">
                                            <div className="md:col-span-6">
                                              <Label className="text-xs">Rule Name <span className="text-red-500">*</span></Label>
                                              <Input value={laborRuleDraft.display_name} onChange={(e) => setLaborRuleDraft((p) => ({ ...p, display_name: e.target.value }))} placeholder="Labor Roman Shade v1 (base + area)" />
                                            </div>
                                            <div className="md:col-span-3">
                                              <Label className="text-xs">Product Type <span className="text-red-500">*</span></Label>
                                              <select value={laborRuleDraft.product_type_id} onChange={(e) => setLaborRuleDraft((p) => ({ ...p, product_type_id: e.target.value }))} className="w-full px-2 py-2 border border-gray-200 rounded text-sm bg-white">
                                                <option value="">— Any (wildcard) —</option>
                                                {productTypes.map((pt) => <option key={pt.id} value={pt.id}>{pt.name}</option>)}
                                              </select>
                                            </div>
                                            <div className="md:col-span-2">
                                              <Label className="text-xs">Priority</Label>
                                              <Input type="number" value={laborRuleDraft.priority} onChange={(e) => setLaborRuleDraft((p) => ({ ...p, priority: e.target.value }))} />
                                              <p className="text-[10px] text-gray-500 mt-1">Higher wins on ties.</p>
                                            </div>
                                            <div className="md:col-span-1">
                                              <Label className="text-xs">Active</Label>
                                              <div className="h-9 flex items-center">
                                                <button type="button" onClick={() => setLaborRuleDraft((p) => ({ ...p, is_active: !p.is_active }))} className={`px-3 py-1.5 rounded text-xs font-medium border ${laborRuleDraft.is_active ? 'bg-emerald-50 border-emerald-300 text-emerald-700' : 'bg-gray-50 border-gray-300 text-gray-600'}`}>
                                                  {laborRuleDraft.is_active ? 'Yes' : 'No'}
                                                </button>
                                              </div>
                                            </div>
                                          </div>

                                          {/* Section 2: Filters */}
                                          <div className="px-4 py-3 bg-gray-50 border-b border-gray-200">
                                            <div className="flex items-center justify-between">
                                              <div className="text-[11px] uppercase tracking-wide font-semibold text-gray-700">2. When this rule applies (filters)</div>
                                              <div className="text-[10px] text-gray-500">All filters use AND. Empty = no restriction.</div>
                                            </div>
                                          </div>
                                          <div className="p-4 grid grid-cols-1 md:grid-cols-6 gap-3 border-b border-gray-100">
                                            <div className="md:col-span-2">
                                              <Label className="text-xs">Motor</Label>
                                              <select value={laborRuleDraft.motor_required} onChange={(e) => setLaborRuleDraft((p) => ({ ...p, motor_required: e.target.value }))} className="w-full px-2 py-2 border border-gray-200 rounded text-sm bg-white">
                                                <option value="">Any</option>
                                                <option value="true">Required</option>
                                                <option value="false">Not allowed</option>
                                              </select>
                                            </div>
                                            <div className="md:col-span-2">
                                              <Label className="text-xs">Track Only</Label>
                                              <select value={laborRuleDraft.track_only_required} onChange={(e) => setLaborRuleDraft((p) => ({ ...p, track_only_required: e.target.value }))} className="w-full px-2 py-2 border border-gray-200 rounded text-sm bg-white">
                                                <option value="">Any</option>
                                                <option value="true">Track only</option>
                                                <option value="false">With fabric</option>
                                              </select>
                                            </div>
                                            <div className="md:col-span-2">
                                              <Label className="text-xs">Operating Type</Label>
                                              <Input type="text" placeholder="e.g. motorized, manual, chain (optional)" value={laborRuleDraft.operating_type} onChange={(e) => setLaborRuleDraft((p) => ({ ...p, operating_type: e.target.value }))} />
                                            </div>
                                            <div className="md:col-span-3">
                                              <Label className="text-xs">Width range (mm)</Label>
                                              <div className="flex items-center gap-2">
                                                <Input type="number" placeholder="min" value={laborRuleDraft.width_min_mm} onChange={(e) => setLaborRuleDraft((p) => ({ ...p, width_min_mm: e.target.value }))} />
                                                <span className="text-xs text-gray-400">–</span>
                                                <Input type="number" placeholder="max" value={laborRuleDraft.width_max_mm} onChange={(e) => setLaborRuleDraft((p) => ({ ...p, width_max_mm: e.target.value }))} />
                                              </div>
                                            </div>
                                            <div className="md:col-span-3">
                                              <Label className="text-xs">Height range (mm)</Label>
                                              <div className="flex items-center gap-2">
                                                <Input type="number" placeholder="min" value={laborRuleDraft.height_min_mm} onChange={(e) => setLaborRuleDraft((p) => ({ ...p, height_min_mm: e.target.value }))} />
                                                <span className="text-xs text-gray-400">–</span>
                                                <Input type="number" placeholder="max" value={laborRuleDraft.height_max_mm} onChange={(e) => setLaborRuleDraft((p) => ({ ...p, height_max_mm: e.target.value }))} />
                                              </div>
                                            </div>
                                            <div className="md:col-span-2">
                                              <Label className="text-xs">Area range (m²)</Label>
                                              <div className="flex items-center gap-2">
                                                <Input type="number" step="0.01" placeholder="min" value={laborRuleDraft.area_min_m2} onChange={(e) => setLaborRuleDraft((p) => ({ ...p, area_min_m2: e.target.value }))} />
                                                <span className="text-xs text-gray-400">–</span>
                                                <Input type="number" step="0.01" placeholder="max" value={laborRuleDraft.area_max_m2} onChange={(e) => setLaborRuleDraft((p) => ({ ...p, area_max_m2: e.target.value }))} />
                                              </div>
                                            </div>
                                            <div className="md:col-span-2">
                                              <Label className="text-xs">Panels</Label>
                                              <div className="flex items-center gap-2">
                                                <Input type="number" placeholder="min" value={laborRuleDraft.panel_count_min} onChange={(e) => setLaborRuleDraft((p) => ({ ...p, panel_count_min: e.target.value }))} />
                                                <span className="text-xs text-gray-400">–</span>
                                                <Input type="number" placeholder="max" value={laborRuleDraft.panel_count_max} onChange={(e) => setLaborRuleDraft((p) => ({ ...p, panel_count_max: e.target.value }))} />
                                              </div>
                                            </div>
                                            <div className="md:col-span-2">
                                              <Label className="text-xs">Drops</Label>
                                              <div className="flex items-center gap-2">
                                                <Input type="number" placeholder="min" value={laborRuleDraft.drops_min} onChange={(e) => setLaborRuleDraft((p) => ({ ...p, drops_min: e.target.value }))} />
                                                <span className="text-xs text-gray-400">–</span>
                                                <Input type="number" placeholder="max" value={laborRuleDraft.drops_max} onChange={(e) => setLaborRuleDraft((p) => ({ ...p, drops_max: e.target.value }))} />
                                              </div>
                                            </div>
                                          </div>

                                          {/* Section 3: Calculation */}
                                          <div className="px-4 py-3 bg-gray-50 border-b border-gray-200">
                                            <div className="flex items-center justify-between">
                                              <div className="text-[11px] uppercase tracking-wide font-semibold text-gray-700">3. How labor is calculated</div>
                                              <div className="text-[10px] text-gray-500">Composite sums all rates below.</div>
                                            </div>
                                          </div>
                                          <div className="p-4 grid grid-cols-1 md:grid-cols-6 gap-3">
                                            <div className="md:col-span-2">
                                              <Label className="text-xs">Calc Mode</Label>
                                              <select value={laborRuleDraft.calc_mode} onChange={(e) => setLaborRuleDraft((p) => ({ ...p, calc_mode: e.target.value }))} className="w-full px-2 py-2 border border-gray-200 rounded text-sm bg-white">
                                                <option value="composite">Composite (recommended)</option>
                                                <option value="pct_materials">% of materials</option>
                                                <option value="fixed">Fixed amount only</option>
                                                <option value="per_m2">Per m² only</option>
                                                <option value="per_drop">Per drop only</option>
                                                <option value="per_panel">Per panel only</option>
                                                <option value="per_height_m">Per height m only</option>
                                                <option value="per_width_m">Per width m only</option>
                                              </select>
                                            </div>
                                            {laborRuleDraft.calc_mode === 'pct_materials' && (
                                              <div className="md:col-span-2">
                                                <Label className="text-xs">% of materials (0-1)</Label>
                                                <Input type="number" step="0.01" value={laborRuleDraft.pct_materials} onChange={(e) => setLaborRuleDraft((p) => ({ ...p, pct_materials: e.target.value }))} />
                                              </div>
                                            )}
                                            <div className="md:col-span-2"><Label className="text-xs">Fixed amount ($)</Label><Input type="number" step="0.01" value={laborRuleDraft.fixed_amount} onChange={(e) => setLaborRuleDraft((p) => ({ ...p, fixed_amount: e.target.value }))} /></div>
                                            <div className="md:col-span-2"><Label className="text-xs">Rate per m² ($)</Label><Input type="number" step="0.01" value={laborRuleDraft.rate_per_m2} onChange={(e) => setLaborRuleDraft((p) => ({ ...p, rate_per_m2: e.target.value }))} /></div>
                                            <div className="md:col-span-2"><Label className="text-xs">Rate per drop ($)</Label><Input type="number" step="0.01" value={laborRuleDraft.rate_per_drop} onChange={(e) => setLaborRuleDraft((p) => ({ ...p, rate_per_drop: e.target.value }))} /></div>
                                            <div className="md:col-span-2"><Label className="text-xs">Rate per panel ($)</Label><Input type="number" step="0.01" value={laborRuleDraft.rate_per_panel} onChange={(e) => setLaborRuleDraft((p) => ({ ...p, rate_per_panel: e.target.value }))} /></div>
                                            <div className="md:col-span-2"><Label className="text-xs">Rate per height m ($)</Label><Input type="number" step="0.01" value={laborRuleDraft.rate_per_height_m} onChange={(e) => setLaborRuleDraft((p) => ({ ...p, rate_per_height_m: e.target.value }))} /></div>
                                            <div className="md:col-span-2"><Label className="text-xs">Rate per width m ($)</Label><Input type="number" step="0.01" value={laborRuleDraft.rate_per_width_m} onChange={(e) => setLaborRuleDraft((p) => ({ ...p, rate_per_width_m: e.target.value }))} /></div>
                                            <div className="md:col-span-2"><Label className="text-xs">Motor add-on ($)</Label><Input type="number" step="0.01" value={laborRuleDraft.rate_motor_addon} onChange={(e) => setLaborRuleDraft((p) => ({ ...p, rate_motor_addon: e.target.value }))} /></div>
                                            <div className="md:col-span-3"><Label className="text-xs">Min charge ($)</Label><Input type="number" step="0.01" value={laborRuleDraft.min_charge} onChange={(e) => setLaborRuleDraft((p) => ({ ...p, min_charge: e.target.value }))} /></div>
                                            <div className="md:col-span-3"><Label className="text-xs">Max charge ($, optional)</Label><Input type="number" step="0.01" placeholder="No cap" value={laborRuleDraft.max_charge} onChange={(e) => setLaborRuleDraft((p) => ({ ...p, max_charge: e.target.value }))} /></div>

                                            <div className="md:col-span-6 mt-2 pt-2 border-t border-gray-200">
                                              <div className="text-[11px] font-semibold text-gray-700 uppercase tracking-wide mb-1">Size escalation (base labor)</div>
                                              <div className="text-[11px] text-gray-500 mb-2">Multiplies composite base by <code className="px-1 bg-gray-100 rounded">1 + escalation × max(width − reference, 0)</code>. Use 0 to disable.</div>
                                            </div>
                                            <div className="md:col-span-3"><Label className="text-xs">Size escalation (% per m, decimal)</Label><Input type="number" step="0.001" placeholder="0 = off" value={laborRuleDraft.size_escalation_pct} onChange={(e) => setLaborRuleDraft((p) => ({ ...p, size_escalation_pct: e.target.value }))} /></div>
                                            <div className="md:col-span-3"><Label className="text-xs">Reference width (m)</Label><Input type="number" step="0.01" value={laborRuleDraft.size_reference_width_m} onChange={(e) => setLaborRuleDraft((p) => ({ ...p, size_reference_width_m: e.target.value }))} /></div>

                                            <div className="md:col-span-6 mt-2 pt-2 border-t border-gray-200">
                                              <div className="text-[11px] font-semibold text-gray-700 uppercase tracking-wide mb-1">Heatseal & bottom-bar wrap</div>
                                              <div className="text-[11px] text-gray-500 mb-2">Heatseal: rate × seam length (only on rotation). Wrap: rate × width (only if bottom bar wrapped).</div>
                                            </div>
                                            <div className="md:col-span-3"><Label className="text-xs">Heatseal rate ($/m of seam)</Label><Input type="number" step="0.01" value={laborRuleDraft.heatseal_rate_per_m} onChange={(e) => setLaborRuleDraft((p) => ({ ...p, heatseal_rate_per_m: e.target.value }))} /></div>
                                            <div className="md:col-span-3"><Label className="text-xs">Bottom-bar wrap rate ($/m of width)</Label><Input type="number" step="0.01" value={laborRuleDraft.bottom_bar_wrap_rate_per_m} onChange={(e) => setLaborRuleDraft((p) => ({ ...p, bottom_bar_wrap_rate_per_m: e.target.value }))} /></div>

                                            <div className="md:col-span-6 mt-2 pt-2 border-t border-gray-200">
                                              <div className="text-[11px] font-semibold text-gray-700 uppercase tracking-wide mb-1">Confection (drapery / outsourced fabric work)</div>
                                              <div className="text-[11px] text-gray-500 mb-2">Total = (base + rate/m² × area) × (1 + escalation × max(width − reference, 0)). Leave at 0 to disable.</div>
                                            </div>
                                            <div className="md:col-span-2"><Label className="text-xs">Confection base ($)</Label><Input type="number" step="0.01" value={laborRuleDraft.confection_base} onChange={(e) => setLaborRuleDraft((p) => ({ ...p, confection_base: e.target.value }))} /></div>
                                            <div className="md:col-span-2"><Label className="text-xs">Confection rate ($/m²)</Label><Input type="number" step="0.01" value={laborRuleDraft.confection_rate_per_m2} onChange={(e) => setLaborRuleDraft((p) => ({ ...p, confection_rate_per_m2: e.target.value }))} /></div>
                                            <div className="md:col-span-1"><Label className="text-xs">Conf. esc. (per m)</Label><Input type="number" step="0.001" value={laborRuleDraft.confection_size_escalation_pct} onChange={(e) => setLaborRuleDraft((p) => ({ ...p, confection_size_escalation_pct: e.target.value }))} /></div>
                                            <div className="md:col-span-1"><Label className="text-xs">Conf. ref. width (m)</Label><Input type="number" step="0.01" value={laborRuleDraft.confection_size_reference_width_m} onChange={(e) => setLaborRuleDraft((p) => ({ ...p, confection_size_reference_width_m: e.target.value }))} /></div>
                                          </div>

                                          <div className="px-4 py-3 bg-gray-50 border-t border-gray-200 flex items-center justify-end gap-2">
                                            <button type="button" onClick={() => { setEditingLaborRuleId(null); resetLaborRuleDraft(); }} className="px-3 py-2 text-xs border border-gray-300 rounded-md hover:bg-gray-50">
                                              Cancel
                                            </button>
                                            <button type="button" disabled={isSavingLaborRule} onClick={saveLaborRule} className="inline-flex items-center gap-2 px-3 py-2 text-xs bg-primary text-white rounded-md hover:bg-primary/90 disabled:opacity-50">
                                              <Save className="w-3.5 h-3.5" />
                                              {isSavingLaborRule ? 'Saving...' : 'Update Rule'}
                                            </button>
                                          </div>
                                        </div>
                                      </div>
                                    )}
                                    </React.Fragment>
                                  );
                                })}
                              </div>
                            )}
                          </div>
                        );
                      })}
                    </div>
                  )}
                </>
              )}
            </div>
          )}

          {activeTab === 'fabric_pricing' && (
            <div>
              <div className="mb-6">
                <h3 className="text-sm font-semibold text-gray-900 mb-1">Fabric Pricing Basis</h3>
                <p className="text-xs text-gray-500">
                  Controls how fabric/roll quantity and unit price are displayed in quotes and BOM preview.
                  This is a <strong>display setting only</strong> — it does not affect real costs or totals.
                  The economic total (qty × unit price) is always the same regardless of basis.
                </p>
                <p className="text-xs text-amber-700 mt-2 bg-amber-50 px-2 py-1 rounded">
                  <strong>Applies to new configured products going forward.</strong> Existing quotes/products keep their saved snapshot.
                </p>
              </div>

              <div className="space-y-3 max-w-lg">
                {([
                  {
                    value: 'auto',
                    label: 'Auto (use catalog item pricing mode)',
                    description: 'Each fabric uses its own roll_pricing_mode (per_linear_meter → m, per_square_meter → m²).',
                  },
                  {
                    value: 'linear',
                    label: 'Linear meter (m)',
                    description: 'Always quote fabric in linear meters. Unit price is converted to $/m when the catalog price is in $/m².',
                  },
                  {
                    value: 'sqm',
                    label: 'Square meter (m²)',
                    description: 'Always quote fabric in m². Unit price is converted to $/m² when the catalog price is in $/m.',
                  },
                ] as { value: 'auto' | 'linear' | 'sqm'; label: string; description: string }[]).map((option) => (
                  <label
                    key={option.value}
                    className={`flex items-start gap-3 p-4 border rounded-lg cursor-pointer transition-colors ${
                      fabricPricingBasis === option.value
                        ? 'border-primary bg-primary/5'
                        : 'border-gray-200 hover:border-gray-300 bg-white'
                    }`}
                  >
                    <input
                      type="radio"
                      name="fabric_pricing_basis"
                      value={option.value}
                      checked={fabricPricingBasis === option.value}
                      onChange={() => setFabricPricingBasis(option.value)}
                      className="mt-0.5 accent-primary"
                    />
                    <div className="min-w-0">
                      <div className="text-sm font-medium text-gray-900">{option.label}</div>
                      <div className="text-xs text-gray-500 mt-0.5">{option.description}</div>
                    </div>
                  </label>
                ))}
              </div>

              {/* Example */}
              <div className="mt-6 p-4 bg-gray-50 border border-gray-200 rounded-lg max-w-lg">
                <p className="text-xs font-medium text-gray-700 mb-2">Example — same fabric, same total:</p>
                <div className="grid grid-cols-3 gap-2 text-xs text-gray-600">
                  <div className="font-medium text-gray-500 uppercase tracking-wide">Basis</div>
                  <div className="font-medium text-gray-500 uppercase tracking-wide text-right">Qty / UOM</div>
                  <div className="font-medium text-gray-500 uppercase tracking-wide text-right">Unit Price</div>
                  <div className={fabricPricingBasis === 'auto' ? 'text-primary font-semibold' : ''}>Auto (linear)</div>
                  <div className={`text-right ${fabricPricingBasis === 'auto' ? 'text-primary font-semibold' : ''}`}>1.20 m</div>
                  <div className={`text-right ${fabricPricingBasis === 'auto' ? 'text-primary font-semibold' : ''}`}>$88.82 / m</div>
                  <div className={fabricPricingBasis === 'sqm' ? 'text-primary font-semibold' : ''}>Square meter</div>
                  <div className={`text-right ${fabricPricingBasis === 'sqm' ? 'text-primary font-semibold' : ''}`}>2.40 m²</div>
                  <div className={`text-right ${fabricPricingBasis === 'sqm' ? 'text-primary font-semibold' : ''}`}>$44.41 / m²</div>
                  <div className="col-span-3 border-t border-gray-300 mt-1 pt-1 text-gray-700">
                    Total: <strong>$106.58</strong> in both cases
                  </div>
                </div>
              </div>

              {/* Save button */}
              <div className="mt-6">
                {fabricSaveSuccess && (
                  <p className="text-sm text-green-700 mb-2">Fabric pricing basis saved.</p>
                )}
                <button
                  type="button"
                  disabled={savingFabric}
                  onClick={async () => {
                    try {
                      setSavingFabric(true);
                      setFabricSaveSuccess(false);
                      await upsertSettings({ fabric_pricing_basis: fabricPricingBasis } as any);
                      setFabricSaveSuccess(true);
                      setTimeout(() => setFabricSaveSuccess(false), 3000);
                    } catch (err: any) {
                      alert(err?.message ?? 'Error saving fabric pricing basis.');
                    } finally {
                      setSavingFabric(false);
                    }
                  }}
                  className="flex items-center gap-2 px-4 py-2 bg-primary text-white text-sm rounded-md hover:bg-primary/90 disabled:opacity-50"
                >
                  <Save className="w-4 h-4" />
                  {savingFabric ? 'Saving…' : 'Save Fabric Pricing Basis'}
                </button>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

import { useState, useEffect, useMemo } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { useCostSettings, useImportTaxRules, useCategoryMargins } from '../../hooks/useCostEngineSettings';
import { useUIStore } from '../../stores/ui-store';
import { useCatalogCategories } from '../../hooks/useCatalog';
import Input from '../../components/ui/Input';
import Label from '../../components/ui/Label';
import { Save, AlertCircle, Plus, Edit2, X, Check, Search, Filter } from 'lucide-react';
import DealerTiersSettings from './DealerTiersSettings';

const costSettingsSchema = z.object({
  labor_percentage: z.number().min(0, 'Labor percentage must be >= 0').max(100, 'Labor percentage must be <= 100'),
  shipping_percentage: z.number().min(0, 'Shipping percentage must be >= 0').max(100, 'Shipping percentage must be <= 100'),
  import_tax_percent: z.number().min(0, 'Import tax percentage must be >= 0').max(100, 'Import tax percentage must be <= 100'),
  itbms_percent: z.number().min(0, 'ITBMS % must be >= 0').max(100, 'ITBMS % must be <= 100'),
  msrp_pct: z.number().min(0, 'MSRP % must be >= 0').max(200, 'MSRP % must be <= 200'),
  min_margin_pct: z.number().min(0, 'Minimum margin must be >= 0').max(95, 'Minimum margin must be <= 95').optional(),
});

type CostSettingsFormData = z.infer<typeof costSettingsSchema>;

export default function CostEngineSettings() {
  const [activeTab, setActiveTab] = useState<'defaults' | 'import_taxes' | 'category_margins' | 'dealer_tiers'>('defaults');
  const { settings, loading, error, upsertSettings } = useCostSettings();
  const { rules, loading: rulesLoading, upsertRule, deleteRule } = useImportTaxRules();
  const { margins, loading: marginsLoading, upsertMargin, deleteMargin } = useCategoryMargins();
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
      labor_percentage: 10.0000,
      shipping_percentage: 15.0000,
      import_tax_percent: 0,
      itbms_percent: 7, // Default 7% ITBMS (0.07 in DB). Used in Proposals.
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
  const [editingDefaultKey, setEditingDefaultKey] = useState<'labor' | 'shipping' | 'import_tax' | 'itbms' | null>(null);
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

  // Load settings when they become available
  useEffect(() => {
    if (settings) {
      console.log('📥 Loading CostSettings into form:', {
        default_msrp_pct: settings.default_msrp_pct,
        default_msrp_pct_ui: Math.round((settings.default_msrp_pct || 0.65) * 100),
      });
      
      // DB: 0.10 → UI: 10 (rounded)
      setValue('labor_percentage', Math.round(settings.labor_pct * 100));
      setValue('shipping_percentage', Math.round(settings.shipping_pct * 100));
      setValue('import_tax_percent', Math.round(settings.global_import_tax_pct * 100));
      setValue('itbms_percent', Math.round((settings.itbms_pct ?? 0.07) * 100));
      
      const msrpValue = Math.round((settings.default_msrp_pct || 0.65) * 100);
      console.log('📥 Setting msrp_pct to:', msrpValue);
      setValue('msrp_pct', msrpValue);
      
      setValue('min_margin_pct', Math.round(settings.minimum_margin_pct * 100));
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
      const payload = {
        labor_pct: data.labor_percentage / 100,
        shipping_pct: data.shipping_percentage / 100,
        global_import_tax_pct: data.import_tax_percent / 100,
        itbms_pct: (data.itbms_percent ?? 7) / 100,
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
              className={`transition-colors flex items-center justify-start ${
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
                borderBottom: activeTab === 'category_margins' ? '2px solid var(--tab-active-underline)' : 'none'
              }}
              role="tab"
              aria-selected={activeTab === 'category_margins'}
              aria-label={`Category Margins${activeTab === 'category_margins' ? ' (current tab)' : ''}`}
            >
              Category Margins
            </button>
          </div>
        </div>

        {/* Form Body - Matching CustomerNew content structure */}
        <div className="py-6 px-6">
          {activeTab === 'defaults' && (
            <div>
              <div className="mb-4">
                <h3 className="text-sm font-semibold text-gray-900">Cost Engine Defaults</h3>
              </div>
              <div className="grid grid-cols-2 gap-3">
                {[
                  { key: 'labor' as const, label: 'Labor Percentage (%)', field: 'labor_percentage' as const },
                  { key: 'shipping' as const, label: 'Shipping Percentage (%)', field: 'shipping_percentage' as const },
                  { key: 'import_tax' as const, label: 'Global Import Tax % (Fallback)', field: 'import_tax_percent' as const },
                  { key: 'itbms' as const, label: 'ITBMS % (Proposals)', field: 'itbms_percent' as const, tooltip: 'Impuesto general (Panamá). Se usa en Proposals/Invoices.' },
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
                        labor_pct: (data.labor_percentage ?? 10) / 100,
                        shipping_pct: (data.shipping_percentage ?? 15) / 100,
                        global_import_tax_pct: (data.import_tax_percent ?? 0) / 100,
                        itbms_pct: (data.itbms_percent ?? 7) / 100,
                        default_msrp_pct: (settings?.default_msrp_pct ?? 0.65),
                        minimum_margin_pct: (settings?.minimum_margin_pct ?? 0.35),
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
        </div>
      </div>
    </div>
  );
}

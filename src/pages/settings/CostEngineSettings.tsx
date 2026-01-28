import { useState, useEffect, useMemo } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { useCostSettings, useImportTaxRules, useCategoryMargins } from '../../hooks/useCostEngineSettings';
import { useCatalogCategories } from '../../hooks/useCatalog';
import Input from '../../components/ui/Input';
import Label from '../../components/ui/Label';
import { DollarSign, Save, AlertCircle, Plus, Trash2, Edit2, X, Check, Search, Filter } from 'lucide-react';

const costSettingsSchema = z.object({
  labor_percentage: z.number().min(0, 'Labor percentage must be >= 0').max(100, 'Labor percentage must be <= 100'),
  shipping_percentage: z.number().min(0, 'Shipping percentage must be >= 0').max(100, 'Shipping percentage must be <= 100'),
  import_tax_percent: z.number().min(0, 'Import tax percentage must be >= 0').max(100, 'Import tax percentage must be <= 100'),
  msrp_pct_sale_out: z.number().min(0, 'MSRP % must be >= 0').max(200, 'MSRP % must be <= 200'),
  discount_reseller_pct: z.number().min(0, 'Discount must be >= 0').max(100, 'Discount must be <= 100').optional(),
  discount_distributor_pct: z.number().min(0, 'Discount must be >= 0').max(100, 'Discount must be <= 100').optional(),
  discount_partner_pct: z.number().min(0, 'Discount must be >= 0').max(100, 'Discount must be <= 100').optional(),
  discount_vip_pct: z.number().min(0, 'Discount must be >= 0').max(100, 'Discount must be <= 100').optional(),
  min_margin_pct: z.number().min(0, 'Minimum margin must be >= 0').max(95, 'Minimum margin must be <= 95').optional(),
});

type CostSettingsFormData = z.infer<typeof costSettingsSchema>;

export default function CostEngineSettings() {
  const [activeTab, setActiveTab] = useState<'defaults' | 'import_taxes' | 'category_margins'>('defaults');
  const { settings, loading, error, upsertSettings } = useCostSettings();
  const { rules, loading: rulesLoading, upsertRule, deleteRule } = useImportTaxRules();
  const { margins, loading: marginsLoading, upsertMargin, deleteMargin } = useCategoryMargins();
  const [saveSuccess, setSaveSuccess] = useState(false);
  const [isSaving, setIsSaving] = useState(false);

  const {
    register,
    handleSubmit,
    setValue,
    formState: { errors, isDirty },
  } = useForm<CostSettingsFormData>({
    resolver: zodResolver(costSettingsSchema),
    defaultValues: {
      labor_percentage: 10.0000,
      shipping_percentage: 15.0000,
      import_tax_percent: 0,
      msrp_pct_sale_out: 65, // Default 65% MSRP % Sale Out (0.65 in DB)
      discount_reseller_pct: 0,
      discount_distributor_pct: 0,
      discount_partner_pct: 0,
      discount_vip_pct: 0,
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
  const [editingMsrpPctSaleOut, setEditingMsrpPctSaleOut] = useState<string>('');
  // Search and filter state for Category Margins
  const [searchTerm, setSearchTerm] = useState('');
  const [showFilters, setShowFilters] = useState(false);
  const [filterHasCustomMargin, setFilterHasCustomMargin] = useState<string>('all'); // 'all', 'custom', 'default'
  // Search and filter state for Import Taxes
  const [importTaxSearchTerm, setImportTaxSearchTerm] = useState('');
  const [showImportTaxFilters, setShowImportTaxFilters] = useState(false);
  const [filterImportTaxType, setFilterImportTaxType] = useState<string>('all'); // 'all', 'custom', 'default'

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
        default_msrp_pct_sale_out: settings.default_msrp_pct_sale_out,
        default_msrp_pct_sale_out_ui: Math.round((settings.default_msrp_pct_sale_out || 0.65) * 100),
      });
      
      // DB: 0.10 → UI: 10 (rounded)
      setValue('labor_percentage', Math.round(settings.labor_pct * 100));
      setValue('shipping_percentage', Math.round(settings.shipping_pct * 100));
      setValue('import_tax_percent', Math.round(settings.global_import_tax_pct * 100));
      
      const msrpValue = Math.round((settings.default_msrp_pct_sale_out || 0.65) * 100);
      console.log('📥 Setting msrp_pct_sale_out to:', msrpValue);
      setValue('msrp_pct_sale_out', msrpValue);
      
      setValue('discount_reseller_pct', Math.round(settings.reseller_discount_pct * 100));
      setValue('discount_distributor_pct', Math.round(settings.distributor_discount_pct * 100));
      setValue('discount_partner_pct', Math.round(settings.partner_discount_pct * 100));
      setValue('discount_vip_pct', Math.round(settings.vip_discount_pct * 100));
      setValue('min_margin_pct', Math.round(settings.minimum_margin_pct * 100));
    }
  }, [settings, setValue]);

  const onSubmit = async (data: CostSettingsFormData) => {
    try {
      setIsSaving(true);
      setSaveSuccess(false);
      
      // Convert percentages to decimals: UI 10 → DB 0.10
      // MSRP % Sale Out is not editable in Defaults; preserve existing value when not in form
      const msrpSaleOut = data.msrp_pct_sale_out != null
        ? data.msrp_pct_sale_out / 100
        : (settings?.default_msrp_pct_sale_out ?? 0.65);
      const payload = {
        labor_pct: data.labor_percentage / 100,
        shipping_pct: data.shipping_percentage / 100,
        global_import_tax_pct: data.import_tax_percent / 100,
        default_msrp_pct_sale_out: msrpSaleOut,
        reseller_discount_pct: (data.discount_reseller_pct ?? 0) / 100,
        distributor_discount_pct: (data.discount_distributor_pct ?? 0) / 100,
        partner_discount_pct: (data.discount_partner_pct ?? 0) / 100,
        vip_discount_pct: (data.discount_vip_pct ?? 0) / 100,
        minimum_margin_pct: (data.min_margin_pct ?? 35) / 100,
      };
      
      console.log('💾 Saving CostSettings payload:', payload);
      console.log('💾 MSRP % Sale Out value:', data.msrp_pct_sale_out, '→ DB:', payload.default_msrp_pct_sale_out);
      
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

  if (loading) {
    return (
      <div className="py-6 px-6">
        <div className="flex items-center justify-center min-h-[400px]">
          <div className="text-center">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary mx-auto mb-4"></div>
            <p className="text-sm text-gray-600">Loading cost settings...</p>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="py-6 px-6">
      {/* Header */}
      <div className="mb-6">
        <h1 className="text-xl font-semibold text-foreground mb-1">
          Cost Engine Settings
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
            <form onSubmit={handleSubmit(onSubmit)}>
              <div className="space-y-10">
                {/* Row 1: Cost Engine Defaults */}
                <div>
                  <div className="flex items-center gap-2 mb-4">
                    <DollarSign className="w-5 h-5 text-gray-700" />
                    <h3 className="text-sm font-semibold text-gray-900">Cost Engine Defaults</h3>
                  </div>
                  <div className="grid grid-cols-12 gap-x-4 gap-y-4">
                    <div className="col-span-3">
                      <Label htmlFor="labor_percentage" className="text-xs" required>
                        Labor Percentage (%)
                      </Label>
                      <Input
                        id="labor_percentage"
                        type="number"
                        step="1"
                        min="0"
                        max="100"
                        {...register('labor_percentage', { valueAsNumber: true })}
                        className="py-1 text-xs"
                        error={errors.labor_percentage?.message}
                        placeholder="10"
                      />
                    </div>
                    <div className="col-span-3">
                      <Label htmlFor="shipping_percentage" className="text-xs" required>
                        Shipping Percentage (%)
                      </Label>
                      <Input
                        id="shipping_percentage"
                        type="number"
                        step="1"
                        min="0"
                        max="100"
                        {...register('shipping_percentage', { valueAsNumber: true })}
                        className="py-1 text-xs"
                        error={errors.shipping_percentage?.message}
                        placeholder="15"
                      />
                    </div>
                    <div className="col-span-3">
                      <Label htmlFor="import_tax_percent" className="text-xs" required>
                        Global Import Tax % (Fallback)
                      </Label>
                      <Input
                        id="import_tax_percent"
                        type="number"
                        step="1"
                        min="0"
                        max="100"
                        {...register('import_tax_percent', { valueAsNumber: true })}
                        className="py-1 text-xs"
                        error={errors.import_tax_percent?.message}
                        placeholder="0"
                      />
                    </div>
                  </div>
                </div>

                {/* Row 2: Customer Discounts */}
                <div>
                  <div className="flex items-center gap-2 mb-4">
                    <DollarSign className="w-5 h-5 text-gray-700" />
                    <h3 className="text-sm font-semibold text-gray-900">Customer Discounts</h3>
                  </div>
                  <div className="grid grid-cols-12 gap-x-4 gap-y-4">
                    <div className="col-span-3">
                      <Label htmlFor="discount_distributor_pct" className="text-xs">
                        Distributor Discount (%)
                      </Label>
                      <Input
                        id="discount_distributor_pct"
                        type="number"
                        step="1"
                        min="0"
                        max="100"
                        {...register('discount_distributor_pct', { valueAsNumber: true })}
                        className="py-1 text-xs"
                        error={errors.discount_distributor_pct?.message}
                        placeholder="0"
                      />
                    </div>
                    <div className="col-span-3">
                      <Label htmlFor="discount_reseller_pct" className="text-xs">
                        Reseller Discount (%)
                      </Label>
                      <Input
                        id="discount_reseller_pct"
                        type="number"
                        step="1"
                        min="0"
                        max="100"
                        {...register('discount_reseller_pct', { valueAsNumber: true })}
                        className="py-1 text-xs"
                        error={errors.discount_reseller_pct?.message}
                        placeholder="0"
                      />
                    </div>
                    <div className="col-span-3">
                      <Label htmlFor="discount_partner_pct" className="text-xs">
                        Partner Discount (%)
                      </Label>
                      <Input
                        id="discount_partner_pct"
                        type="number"
                        step="1"
                        min="0"
                        max="100"
                        {...register('discount_partner_pct', { valueAsNumber: true })}
                        className="py-1 text-xs"
                        error={errors.discount_partner_pct?.message}
                        placeholder="0"
                      />
                    </div>
                    <div className="col-span-3">
                      <Label htmlFor="discount_vip_pct" className="text-xs">
                        VIP Discount (%)
                      </Label>
                      <Input
                        id="discount_vip_pct"
                        type="number"
                        step="1"
                        min="0"
                        max="100"
                        {...register('discount_vip_pct', { valueAsNumber: true })}
                        className="py-1 text-xs"
                        error={errors.discount_vip_pct?.message}
                        placeholder="0"
                      />
                    </div>
                  </div>
                </div>
              </div>

              {/* Minimum Margin Section - HIDDEN (deprecated, use CategoryMargins instead) */}
              {false && (
              <div className="mb-6">
                <div className="flex items-center gap-2 mb-4">
                  <DollarSign className="w-5 h-5 text-gray-700" />
                  <h3 className="text-sm font-semibold text-gray-900">Minimum Margin (Pricing Guardrail)</h3>
                </div>
                <p className="text-xs text-gray-600 mb-4">
                  DEPRECATED: Use Category Margins tab instead. This global value is only used as fallback for categories without CategoryMargin.
                </p>

                <div className="grid grid-cols-12 gap-x-4 gap-y-4">
                  <div className="col-span-3">
                    <Label htmlFor="min_margin_pct" className="text-xs">
                      Minimum Margin (%)
                    </Label>
                    <Input
                      id="min_margin_pct"
                      type="number"
                      step="1"
                      min="0"
                      max="95"
                      {...register('min_margin_pct', { valueAsNumber: true })}
                      className="py-1 text-xs"
                      error={errors.min_margin_pct?.message}
                      placeholder="35.00"
                    />
                    <p className="text-xs text-gray-500 mt-1">
                      Pricing floor margin (margin-on-sale, default: 35%)
                    </p>
                  </div>
                </div>
              </div>
              )}

              {/* Save Button */}
              <div className="flex justify-end gap-3 pt-4 border-t border-gray-200">
                <button
                  type="submit"
                  disabled={isSaving || !isDirty}
                  className="px-4 py-2 bg-primary text-white text-sm font-medium rounded-md hover:bg-primary/90 disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
                >
                  <Save className="w-4 h-4" />
                  {isSaving ? 'Saving...' : 'Save Settings'}
                </button>
              </div>
            </form>
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

              {/* Table */}
              {rulesLoading ? (
                <div className="text-center py-8 bg-white border border-gray-200 rounded-lg">
                  <div className="text-sm text-gray-500">Loading rules...</div>
                </div>
              ) : (
                <div className="bg-white border border-gray-200 rounded-lg overflow-hidden">
                  <div className="overflow-x-auto">
                    <table className="w-full">
                      <thead>
                        <tr className="border-b border-gray-200 bg-gray-50">
                          <th className="text-left py-2 px-4 text-xs font-semibold text-gray-700">Category</th>
                          <th className="text-left py-2 px-4 text-xs font-semibold text-gray-700">Import Tax %</th>
                          <th className="text-right py-2 px-4 text-xs font-semibold text-gray-700">Actions</th>
                        </tr>
                      </thead>
                      <tbody>
                        {filteredImportTaxCategories.length === 0 ? (
                          <tr>
                            <td colSpan={3} className="py-8 text-center text-sm text-gray-500">
                              No categories found matching your search criteria.
                            </td>
                          </tr>
                        ) : (
                          filteredImportTaxCategories.map((category) => {
                            const existingRule = rules.find(r => r.category_id === category.id);
                            const isEditing = editingRuleId === existingRule?.id || editingCategoryId === category.id;
                            const taxPct = existingRule 
                              ? Math.round(existingRule.import_tax_pct * 100)
                              : Math.round((settings?.global_import_tax_pct ?? 0) * 100);

                            return (
                              <tr key={category.id} className="border-b border-gray-100 hover:bg-gray-50">
                                <td className="py-3 px-4 text-xs text-gray-900 font-medium">
                                  {category.name}
                                </td>
                                <td className="py-3 px-4 text-xs text-gray-700">
                                  {isEditing ? (
                                    <Input
                                      type="number"
                                      step="1"
                                      min="0"
                                      max="100"
                                      value={editingPercentage}
                                      onChange={(e) => setEditingPercentage(e.target.value)}
                                      className="w-20 py-1 text-xs"
                                      placeholder="0"
                                    />
                                  ) : (
                                    <span>{taxPct}%{!existingRule && <span className="text-gray-400 ml-1">(default)</span>}</span>
                                  )}
                                </td>
                                <td className="py-3 px-4 text-right">
                                  <div className="flex items-center justify-end gap-2">
                                    {isEditing ? (
                                      <>
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
                                        <button
                                          type="button"
                                          onClick={() => {
                                            setEditingRuleId(existingRule?.id || null);
                                            setEditingCategoryId(existingRule ? null : category.id);
                                            const valueFromDb = existingRule?.import_tax_pct ?? (settings?.global_import_tax_pct ?? 0);
                                            setEditingPercentage(Math.round(valueFromDb * 100).toString());
                                          }}
                                          className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600"
                                          title={existingRule ? 'Edit' : 'Add'}
                                        >
                                          {existingRule ? <Edit2 className="w-4 h-4" /> : <Plus className="w-4 h-4" />}
                                        </button>
                                        {existingRule && (
                                          <button
                                            type="button"
                                            onClick={async () => {
                                              if (confirm('Are you sure you want to delete this rule?')) {
                                                try {
                                                  await deleteRule(existingRule.id);
                                                } catch (err) {
                                                  console.error('Error deleting rule:', err);
                                                }
                                              }
                                            }}
                                            className="p-1.5 hover:bg-red-50 rounded transition-colors text-red-600"
                                            title="Delete"
                                          >
                                            <Trash2 className="w-4 h-4" />
                                          </button>
                                        )}
                                      </>
                                    )}
                                  </div>
                                </td>
                              </tr>
                            );
                          })
                        )}
                      </tbody>
                    </table>
                  </div>
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

              {/* Table */}
              {marginsLoading ? (
                <div className="text-center py-8 bg-white border border-gray-200 rounded-lg">
                  <div className="text-sm text-gray-500">Loading margins...</div>
                </div>
              ) : (
                <div className="bg-white border border-gray-200 rounded-lg overflow-hidden">
                  <div className="overflow-x-auto">
                    <table className="w-full">
                      <thead>
                        <tr className="border-b border-gray-200 bg-gray-50">
                          <th className="text-left py-2 px-4 text-xs font-semibold text-gray-700">Category</th>
                          <th className="text-left py-2 px-4 text-xs font-semibold text-gray-700">MSRP % Sale-In</th>
                          <th className="text-left py-2 px-4 text-xs font-semibold text-gray-700">MSRP % Sale Out</th>
                          <th className="text-right py-2 px-4 text-xs font-semibold text-gray-700">Actions</th>
                        </tr>
                      </thead>
                      <tbody>
                        {(() => {
                          // Filter categories
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
                        })().map((category) => {
                          const existingMargin = margins.find(m => m.category_id === category.id);
                          const isEditing = editingMarginId === existingMargin?.id || editingMarginCategoryId === category.id;
                          const saleInPct = existingMargin 
                            ? Math.round(((existingMargin as any).msrp_pct_sale_in || (existingMargin as any).default_margin_pct || 0.35) * 100)
                            : 35;
                          const saleOutPct = existingMargin && (existingMargin as any).msrp_pct_sale_out
                            ? Math.round((existingMargin as any).msrp_pct_sale_out * 100)
                            : 65;

                          return (
                            <tr key={category.id} className="border-b border-gray-100 hover:bg-gray-50">
                              <td className="py-3 px-4 text-xs text-gray-900 font-medium">
                                {category.name}
                              </td>
                              <td className="py-3 px-4 text-xs text-gray-700">
                                {isEditing ? (
                                  <Input
                                    type="number"
                                    step="1"
                                    min="0"
                                    max="100"
                                    value={editingMarginPercentage}
                                    onChange={(e) => setEditingMarginPercentage(e.target.value)}
                                    className="w-20 py-1 text-xs"
                                    placeholder="35"
                                  />
                                ) : (
                                  <span>{saleInPct}%{!existingMargin && <span className="text-gray-400 ml-1">(default)</span>}</span>
                                )}
                              </td>
                              <td className="py-3 px-4 text-xs text-gray-700">
                                {isEditing ? (
                                  <Input
                                    type="number"
                                    step="1"
                                    min="0"
                                    max="200"
                                    value={editingMsrpPctSaleOut}
                                    onChange={(e) => setEditingMsrpPctSaleOut(e.target.value)}
                                    className="w-20 py-1 text-xs"
                                    placeholder="65"
                                  />
                                ) : (
                                  <span>{saleOutPct}%{!existingMargin && <span className="text-gray-400 ml-1">(default)</span>}</span>
                                )}
                              </td>
                              <td className="py-3 px-4 text-right">
                                <div className="flex items-center justify-end gap-2">
                                  {isEditing ? (
                                    <>
                                      <button
                                        type="button"
                                        onClick={async () => {
                                          const marginPct = parseFloat(editingMarginPercentage);
                                          const msrpPct = parseFloat(editingMsrpPctSaleOut);
                                          
                                          if (isNaN(marginPct) || marginPct < 0 || marginPct > 100) {
                                            alert('MSRP % Sale-In must be between 0 and 100');
                                            return;
                                          }
                                          
                                          if (isNaN(msrpPct) || msrpPct < 0 || msrpPct > 200) {
                                            alert('MSRP % Sale Out must be between 0 and 200');
                                            return;
                                          }
                                          
                                          try {
                                            await upsertMargin(category.id, marginPct / 100, msrpPct / 100);
                                            setEditingMarginId(null);
                                            setEditingMarginCategoryId(null);
                                            setEditingMarginPercentage('');
                                            setEditingMsrpPctSaleOut('');
                                          } catch (err) {
                                            console.error('Error saving margin:', err);
                                            alert('Error saving margin. Check console for details.');
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
                                          setEditingMarginId(null);
                                          setEditingMarginCategoryId(null);
                                          setEditingMarginPercentage('');
                                          setEditingMsrpPctSaleOut('');
                                        }}
                                        className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600"
                                        title="Cancel"
                                      >
                                        <X className="w-4 h-4" />
                                      </button>
                                    </>
                                  ) : (
                                    <>
                                      <button
                                        type="button"
                                        onClick={() => {
                                          setEditingMarginId(existingMargin?.id || null);
                                          setEditingMarginCategoryId(existingMargin ? null : category.id);
                                          const marginFromDb = (existingMargin as any)?.msrp_pct_sale_in || (existingMargin as any)?.default_margin_pct || (settings?.minimum_margin_pct ?? 0.35);
                                          const msrpFromDb = (existingMargin as any)?.msrp_pct_sale_out ?? (settings?.default_msrp_pct_sale_out ?? 0.65);
                                          setEditingMarginPercentage(Math.round(marginFromDb * 100).toString());
                                          setEditingMsrpPctSaleOut(Math.round(msrpFromDb * 100).toString());
                                        }}
                                        className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600"
                                        title={existingMargin ? 'Edit' : 'Add'}
                                      >
                                        {existingMargin ? <Edit2 className="w-4 h-4" /> : <Plus className="w-4 h-4" />}
                                      </button>
                                      {existingMargin && (
                                        <button
                                          type="button"
                                          onClick={async () => {
                                            if (confirm('Are you sure you want to delete this margin?')) {
                                              try {
                                                await deleteMargin(existingMargin.id);
                                              } catch (err) {
                                                console.error('Error deleting margin:', err);
                                                alert('Error deleting margin. Please try again.');
                                              }
                                            }
                                          }}
                                          className="p-1.5 hover:bg-red-50 rounded transition-colors text-red-600"
                                          title="Delete"
                                        >
                                          <Trash2 className="w-4 h-4" />
                                        </button>
                                      )}
                                    </>
                                  )}
                                </div>
                              </td>
                            </tr>
                          );
                        })}
                      </tbody>
                    </table>
                  </div>
                </div>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

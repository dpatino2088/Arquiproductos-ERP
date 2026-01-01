import { useState, useEffect } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { useCostSettings, useCreateCostSettings, useUpdateCostSettings } from '../../hooks/useCosts';
import { useImportTaxRulesCRUD } from '../../hooks/useImportTaxRules';
import { useCategoryMarginsCRUD } from '../../hooks/useCategoryMargins';
import { useLeafItemCategories } from '../../hooks/useCatalog';
import Input from '../../components/ui/Input';
import Label from '../../components/ui/Label';
import { DollarSign, Save, AlertCircle, Plus, Trash2, Edit2, X, Check } from 'lucide-react';

const costSettingsSchema = z.object({
  labor_percentage: z.number().min(0, 'Labor percentage must be >= 0').max(100, 'Labor percentage must be <= 100'),
  shipping_percentage: z.number().min(0, 'Shipping percentage must be >= 0').max(100, 'Shipping percentage must be <= 100'),
  import_tax_percent: z.number().min(0, 'Import tax percentage must be >= 0').max(100, 'Import tax percentage must be <= 100'),
  discount_reseller_pct: z.number().min(0, 'Discount must be >= 0').max(100, 'Discount must be <= 100').optional(),
  discount_distributor_pct: z.number().min(0, 'Discount must be >= 0').max(100, 'Discount must be <= 100').optional(),
  discount_partner_pct: z.number().min(0, 'Discount must be >= 0').max(100, 'Discount must be <= 100').optional(),
  discount_vip_pct: z.number().min(0, 'Discount must be >= 0').max(100, 'Discount must be <= 100').optional(),
  min_margin_pct: z.number().min(0, 'Minimum margin must be >= 0').max(95, 'Minimum margin must be <= 95').optional(),
});

type CostSettingsFormData = z.infer<typeof costSettingsSchema>;

export default function CostEngineSettings() {
  const [activeTab, setActiveTab] = useState<'defaults' | 'import_taxes' | 'category_margins'>('defaults');
  const { settings, loading, error, refetch } = useCostSettings();
  const { createSettings, isCreating } = useCreateCostSettings();
  const { updateSettings, isUpdating } = useUpdateCostSettings();
  const [saveSuccess, setSaveSuccess] = useState(false);

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
      discount_reseller_pct: 0,
      discount_distributor_pct: 0,
      discount_partner_pct: 0,
      discount_vip_pct: 0,
      min_margin_pct: 35, // Default 35% minimum margin (margin-on-sale, used as pricing floor)
    },
  });

  const { categories } = useLeafItemCategories(); // Only show leaf categories (is_group=false)
  const { rules, loading: rulesLoading, createRule, updateRule, deleteRule } = useImportTaxRulesCRUD();
  const { margins, loading: marginsLoading, createMargin, updateMargin, deleteMargin } = useCategoryMarginsCRUD();
  const [editingRuleId, setEditingRuleId] = useState<string | null>(null);
  const [editingCategoryId, setEditingCategoryId] = useState<string | null>(null);
  const [newRuleCategoryId, setNewRuleCategoryId] = useState<string>('');
  const [newRulePercentage, setNewRulePercentage] = useState<string>('');
  const [editingPercentage, setEditingPercentage] = useState<string>('');
  // Category Margins state
  const [editingMarginId, setEditingMarginId] = useState<string | null>(null);
  const [editingMarginCategoryId, setEditingMarginCategoryId] = useState<string | null>(null);
  const [editingMarginPercentage, setEditingMarginPercentage] = useState<string>('');

  // Load settings when they become available
  useEffect(() => {
    if (settings) {
      setValue('labor_percentage', settings.labor_percentage ?? 10.0000);
      setValue('shipping_percentage', settings.shipping_percentage ?? 15.0000);
      setValue('import_tax_percent', settings.import_tax_percent ?? 0);
      setValue('discount_reseller_pct', settings.discount_reseller_pct ?? 0);
      setValue('discount_distributor_pct', settings.discount_distributor_pct ?? 0);
      setValue('discount_partner_pct', settings.discount_partner_pct ?? 0);
      setValue('discount_vip_pct', settings.discount_vip_pct ?? 0);
      setValue('min_margin_pct', settings.min_margin_pct ?? 35);
    }
  }, [settings, setValue]);

  const onSubmit = async (data: CostSettingsFormData) => {
    try {
      setSaveSuccess(false);
      
      if (settings) {
        // Update existing
        await updateSettings({
          labor_percentage: data.labor_percentage,
          shipping_percentage: data.shipping_percentage,
          import_tax_percent: data.import_tax_percent,
          discount_reseller_pct: data.discount_reseller_pct ?? 0,
          discount_distributor_pct: data.discount_distributor_pct ?? 0,
          discount_partner_pct: data.discount_partner_pct ?? 0,
          discount_vip_pct: data.discount_vip_pct ?? 0,
          min_margin_pct: data.min_margin_pct ?? 35,
        });
      } else {
        // Create new
        await createSettings({
          currency_code: 'USD',
          labor_percentage: data.labor_percentage,
          shipping_percentage: data.shipping_percentage,
          import_tax_percent: data.import_tax_percent,
          discount_reseller_pct: data.discount_reseller_pct ?? 0,
          discount_distributor_pct: data.discount_distributor_pct ?? 0,
          discount_partner_pct: data.discount_partner_pct ?? 0,
          discount_vip_pct: data.discount_vip_pct ?? 0,
          min_margin_pct: data.min_margin_pct ?? 35,
          // Legacy fields (set to 0 for v1)
          labor_rate_per_hour: 0,
          default_labor_minutes_per_unit: 0,
          shipping_base_cost: 0,
          shipping_cost_per_kg: 0,
          handling_fee: 0,
        });
      }
      
      await refetch();
      setSaveSuccess(true);
      setTimeout(() => setSaveSuccess(false), 3000);
    } catch (err) {
      console.error('Error saving cost settings:', err);
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
        <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
          Configure and manage your cost engine settings and content
        </p>
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
                color: activeTab === 'defaults' ? 'var(--primary-brand-hex)' : 'var(--graphite-black-hex)',
                borderColor: 'var(--gray-250)',
                borderBottom: activeTab === 'defaults' ? '2px solid var(--primary-brand-hex)' : 'none'
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
                color: activeTab === 'import_taxes' ? 'var(--primary-brand-hex)' : 'var(--graphite-black-hex)',
                borderColor: 'var(--gray-250)',
                borderBottom: activeTab === 'import_taxes' ? '2px solid var(--primary-brand-hex)' : 'none'
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
                color: activeTab === 'category_margins' ? 'var(--primary-brand-hex)' : 'var(--graphite-black-hex)',
                borderBottom: activeTab === 'category_margins' ? '2px solid var(--primary-brand-hex)' : 'none'
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
            <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
              {/* Cost Engine Defaults Section */}
              <div className="mb-8">
                <div className="flex items-center gap-2 mb-4">
                  <DollarSign className="w-5 h-5 text-gray-700" />
                  <h3 className="text-sm font-semibold text-gray-900">Cost Engine Defaults</h3>
                </div>
                <p className="text-xs text-gray-600 mb-4">
                  Configure default cost percentages for new quote lines. These values only affect new quotes or explicit resets.
                </p>

                <div className="grid grid-cols-12 gap-x-4 gap-y-4">
                  <div className="col-span-4">
                    <Label htmlFor="labor_percentage" className="text-xs" required>
                      Labor Percentage (%)
                    </Label>
                    <Input
                      id="labor_percentage"
                      type="number"
                      step="0.0001"
                      min="0"
                      max="100"
                      {...register('labor_percentage', { valueAsNumber: true })}
                      className="py-1 text-xs"
                      error={errors.labor_percentage?.message}
                      placeholder="10.0000"
                    />
                    <p className="text-xs text-gray-500 mt-1">
                      Default labor cost as a percentage of base material cost
                    </p>
                  </div>

                  <div className="col-span-4">
                    <Label htmlFor="shipping_percentage" className="text-xs" required>
                      Shipping Percentage (%)
                    </Label>
                    <Input
                      id="shipping_percentage"
                      type="number"
                      step="0.0001"
                      min="0"
                      max="100"
                      {...register('shipping_percentage', { valueAsNumber: true })}
                      className="py-1 text-xs"
                      error={errors.shipping_percentage?.message}
                      placeholder="15.0000"
                    />
                    <p className="text-xs text-gray-500 mt-1">
                      Default shipping cost as a percentage of base material cost
                    </p>
                  </div>

                  <div className="col-span-4">
                    <Label htmlFor="import_tax_percent" className="text-xs" required>
                      Global Import Tax % (Fallback)
                    </Label>
                    <Input
                      id="import_tax_percent"
                      type="number"
                      step="0.0001"
                      min="0"
                      max="100"
                      {...register('import_tax_percent', { valueAsNumber: true })}
                      className="py-1 text-xs"
                      error={errors.import_tax_percent?.message}
                      placeholder="0.0000"
                    />
                    <p className="text-xs text-gray-500 mt-1">
                      Default import tax percentage. Used when no category-specific rule exists
                    </p>
                  </div>
                </div>
              </div>

              {/* Customer Discounts Section */}
              <div className="mb-6">
                <div className="flex items-center gap-2 mb-4">
                  <DollarSign className="w-5 h-5 text-gray-700" />
                  <h3 className="text-sm font-semibold text-gray-900">Customer Discounts</h3>
                </div>
                <p className="text-xs text-gray-600 mb-4">
                  Set default discount percentages by customer type. These discounts will be applied automatically when a customer's type matches, unless the customer has a manual discount override.
                </p>

                <div className="grid grid-cols-12 gap-x-4 gap-y-4">
                  <div className="col-span-3">
                    <Label htmlFor="discount_reseller_pct" className="text-xs">
                      Reseller Discount (%)
                    </Label>
                    <Input
                      id="discount_reseller_pct"
                      type="number"
                      step="0.01"
                      min="0"
                      max="100"
                      {...register('discount_reseller_pct', { valueAsNumber: true })}
                      className="py-1 text-xs"
                      error={errors.discount_reseller_pct?.message}
                      placeholder="0.00"
                    />
                    <p className="text-xs text-gray-500 mt-1">
                      Default discount for Reseller customers
                    </p>
                  </div>

                  <div className="col-span-3">
                    <Label htmlFor="discount_distributor_pct" className="text-xs">
                      Distributor Discount (%)
                    </Label>
                    <Input
                      id="discount_distributor_pct"
                      type="number"
                      step="0.01"
                      min="0"
                      max="100"
                      {...register('discount_distributor_pct', { valueAsNumber: true })}
                      className="py-1 text-xs"
                      error={errors.discount_distributor_pct?.message}
                      placeholder="0.00"
                    />
                    <p className="text-xs text-gray-500 mt-1">
                      Default discount for Distributor customers
                    </p>
                  </div>

                  <div className="col-span-3">
                    <Label htmlFor="discount_partner_pct" className="text-xs">
                      Partner Discount (%)
                    </Label>
                    <Input
                      id="discount_partner_pct"
                      type="number"
                      step="0.01"
                      min="0"
                      max="100"
                      {...register('discount_partner_pct', { valueAsNumber: true })}
                      className="py-1 text-xs"
                      error={errors.discount_partner_pct?.message}
                      placeholder="0.00"
                    />
                    <p className="text-xs text-gray-500 mt-1">
                      Default discount for Partner customers
                    </p>
                  </div>

                  <div className="col-span-3">
                    <Label htmlFor="discount_vip_pct" className="text-xs">
                      VIP Discount (%)
                    </Label>
                    <Input
                      id="discount_vip_pct"
                      type="number"
                      step="0.01"
                      min="0"
                      max="100"
                      {...register('discount_vip_pct', { valueAsNumber: true })}
                      className="py-1 text-xs"
                      error={errors.discount_vip_pct?.message}
                      placeholder="0.00"
                    />
                    <p className="text-xs text-gray-500 mt-1">
                      Default discount for VIP customers
                    </p>
                  </div>
                </div>
              </div>

              {/* Minimum Margin Section */}
              <div className="mb-6">
                <div className="flex items-center gap-2 mb-4">
                  <DollarSign className="w-5 h-5 text-gray-700" />
                  <h3 className="text-sm font-semibold text-gray-900">Minimum Margin (Pricing Guardrail)</h3>
                </div>
                <p className="text-xs text-gray-600 mb-4">
                  Minimum margin percentage (margin-on-sale) used as pricing floor. This ensures quotes never go below this margin percentage, protecting profitability even with tier discounts.
                </p>

                <div className="grid grid-cols-12 gap-x-4 gap-y-4">
                  <div className="col-span-3">
                    <Label htmlFor="min_margin_pct" className="text-xs">
                      Minimum Margin (%)
                    </Label>
                    <Input
                      id="min_margin_pct"
                      type="number"
                      step="0.01"
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

              {/* Save Button */}
              <div className="flex justify-end gap-3 pt-4 border-t border-gray-200">
                <button
                  type="submit"
                  disabled={isCreating || isUpdating || !isDirty}
                  className="px-4 py-2 bg-primary text-white text-sm font-medium rounded-md hover:bg-primary/90 disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
                >
                  <Save className="w-4 h-4" />
                  {isCreating || isUpdating ? 'Saving...' : 'Save Settings'}
                </button>
              </div>
            </form>
          )}

          {activeTab === 'import_taxes' && (
            <div>
              <div className="mb-4">
                <h3 className="text-sm font-semibold text-gray-900 mb-2">Import Tax Rules by Category</h3>
                <p className="text-xs text-gray-600">
                  Set category-specific import tax percentages. These override the global default for items in those categories.
                </p>
              </div>

              {rulesLoading ? (
                <div className="text-center py-4 text-sm text-gray-500">Loading rules...</div>
              ) : (
                <div className="border border-gray-200 rounded-lg">
                  <div className="divide-y divide-gray-200">
                    {categories.map((category) => {
                      const existingRule = rules.find(r => r.category_id === category.id && r.active && !r.deleted);
                      const isEditing = editingRuleId === existingRule?.id || editingCategoryId === category.id;

                      return (
                        <div key={category.id} className="p-4">
                          <div className="flex items-center justify-between">
                            <div className="flex-1">
                              <Label className="text-xs font-medium text-gray-900">{category.name}</Label>
                              {existingRule && !isEditing ? (
                                <div className="mt-1">
                                  <p className="text-xs text-gray-700 font-medium">
                                    Current: {existingRule.import_tax_percentage.toFixed(4)}%
                                  </p>
                                  {existingRule.default_value_percentage !== null && existingRule.default_value_percentage !== undefined && (
                                    <p className="text-xs text-gray-500 mt-0.5">
                                      Default: {existingRule.default_value_percentage.toFixed(4)}%
                                      {existingRule.is_using_default && (
                                        <span className="ml-2 text-blue-600">(Using default)</span>
                                      )}
                                    </p>
                                  )}
                                </div>
                              ) : !isEditing && (
                                <p className="text-xs text-gray-500 mt-1">
                                  Default: {settings?.import_tax_percent || 0}% (from global settings)
                                </p>
                              )}
                            </div>
                            <div className="flex items-center gap-2">
                              {isEditing ? (
                                <>
                                  <Input
                                    type="number"
                                    step="0.0001"
                                    min="0"
                                    max="100"
                                    value={editingPercentage}
                                    onChange={(e) => setEditingPercentage(e.target.value)}
                                    className="w-32 py-1 text-xs"
                                    placeholder="0.0000"
                                  />
                                  <button
                                    type="button"
                                    onClick={async () => {
                                      const percentage = parseFloat(editingPercentage);
                                      if (isNaN(percentage) || percentage < 0) {
                                        alert('Please enter a valid non-negative number');
                                        return;
                                      }
                                      try {
                                        const defaultTax = settings?.import_tax_percent || 0;
                                        
                                        if (existingRule) {
                                          await updateRule(existingRule.id, { 
                                            import_tax_percentage: percentage,
                                            default_value_percentage: defaultTax,
                                            is_using_default: percentage === defaultTax,
                                          });
                                        } else {
                                          await createRule({
                                            category_id: category.id,
                                            import_tax_percentage: percentage,
                                            default_value_percentage: defaultTax,
                                            is_using_default: percentage === defaultTax,
                                            active: true,
                                          });
                                        }
                                        setEditingRuleId(null);
                                        setEditingCategoryId(null);
                                        setEditingPercentage('');
                                      } catch (err) {
                                        console.error('Error saving rule:', err);
                                      }
                                    }}
                                    className="p-1 text-green-600 hover:text-green-700"
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
                                    className="p-1 text-gray-600 hover:text-gray-700"
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
                                      setEditingPercentage(existingRule?.import_tax_percentage.toString() || '0');
                                    }}
                                    className="p-1 text-primary hover:text-primary/80"
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
                                      className="p-1 text-red-600 hover:text-red-700"
                                      title="Delete"
                                    >
                                      <Trash2 className="w-4 h-4" />
                                    </button>
                                  )}
                                </>
                              )}
                            </div>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </div>
              )}
            </div>
          )}

          {activeTab === 'category_margins' && (
            <div>
              <div className="mb-4">
                <h3 className="text-sm font-semibold text-gray-900 mb-2">Category Margins</h3>
                <p className="text-xs text-gray-600">
                  Set global margin percentages per category. These margins will be used as defaults when creating new catalog items or calculating MSRP.
                </p>
              </div>

              {marginsLoading ? (
                <div className="text-center py-4 text-sm text-gray-500">Loading margins...</div>
              ) : (
                <div className="border border-gray-200 rounded-lg">
                  <div className="divide-y divide-gray-200">
                    {categories.map((category) => {
                      const existingMargin = margins.find(m => m.category_id === category.id && m.active && !m.deleted);
                      const isEditing = editingMarginId === existingMargin?.id || editingMarginCategoryId === category.id;

                      return (
                        <div key={category.id} className="p-4">
                          <div className="flex items-center justify-between">
                            <div className="flex-1">
                              <Label className="text-xs font-medium text-gray-900">{category.name}</Label>
                              {existingMargin && !isEditing ? (
                                <div className="mt-1">
                                  <p className="text-xs text-gray-700 font-medium">
                                    Current: {existingMargin.margin_percentage.toFixed(2)}%
                                  </p>
                                  {existingMargin.default_value_percentage !== null && existingMargin.default_value_percentage !== undefined && (
                                    <p className="text-xs text-gray-500 mt-0.5">
                                      Default: {existingMargin.default_value_percentage.toFixed(2)}%
                                      {existingMargin.is_using_default && (
                                        <span className="ml-2 text-blue-600">(Using default)</span>
                                      )}
                                    </p>
                                  )}
                                </div>
                              ) : !isEditing && (
                                <p className="text-xs text-gray-500 mt-1">
                                  No margin set (default: 35%)
                                </p>
                              )}
                            </div>
                            <div className="flex items-center gap-2">
                              {isEditing ? (
                                <>
                                  <Input
                                    type="number"
                                    step="0.01"
                                    min="0"
                                    max="100"
                                    value={editingMarginPercentage}
                                    onChange={(e) => setEditingMarginPercentage(e.target.value)}
                                    className="w-32 py-1 text-xs"
                                    placeholder="35.00"
                                  />
                                  <button
                                    type="button"
                                    onClick={async () => {
                                      const percentage = parseFloat(editingMarginPercentage);
                                      if (isNaN(percentage) || percentage < 0 || percentage > 100) {
                                        alert('Please enter a valid number between 0 and 100');
                                        return;
                                      }
                                      try {
                                        const defaultMargin = 35;
                                        
                                        if (existingMargin) {
                                          await updateMargin(existingMargin.id, { 
                                            margin_percentage: percentage,
                                            default_value_percentage: defaultMargin,
                                            is_using_default: percentage === defaultMargin,
                                          });
                                        } else {
                                          await createMargin({
                                            category_id: category.id,
                                            margin_percentage: percentage,
                                            default_value_percentage: defaultMargin,
                                            is_using_default: percentage === defaultMargin,
                                            active: true,
                                          });
                                        }
                                        setEditingMarginId(null);
                                        setEditingMarginCategoryId(null);
                                        setEditingMarginPercentage('');
                                      } catch (err) {
                                        console.error('Error saving margin:', err);
                                        alert('Error saving margin. Please try again.');
                                      }
                                    }}
                                    className="p-1 text-green-600 hover:text-green-700"
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
                                    }}
                                    className="p-1 text-gray-600 hover:text-gray-700"
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
                                      setEditingMarginPercentage(existingMargin?.margin_percentage.toString() || '35.00');
                                    }}
                                    className="p-1 text-primary hover:text-primary/80"
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
                                      className="p-1 text-red-600 hover:text-red-700"
                                      title="Delete"
                                    >
                                      <Trash2 className="w-4 h-4" />
                                    </button>
                                  )}
                                </>
                              )}
                            </div>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </div>
              )}
            </div>
          )}
        </div>
      </div>

      {/* Info Note */}
      <div className="mt-4 p-4 bg-blue-50 border border-blue-200 rounded-lg">
        <p className="text-xs text-blue-800">
          <strong>Note:</strong> These percentages are defaults only. Once a quote line is created, 
          labor, shipping, and import tax costs are stored and frozen. They are recalculated only if the user 
          explicitly clicks "Reset" on a quote line, or if the quote line is manually edited.
        </p>
      </div>
    </div>
  );
}

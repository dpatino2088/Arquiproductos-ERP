import { useState, useEffect } from 'react';
import { useQuoteLineCosts, useUpdateQuoteLineCosts, useRecalculateQuoteLineCosts } from '../../hooks/useCosts';
import { useCostSettings } from '../../hooks/useCosts';
import { useImportTaxBreakdown } from '../../hooks/useImportTaxBreakdown';
import Input from '../ui/Input';
import Label from '../ui/Label';
import { DollarSign, RotateCcw, Edit2, ChevronDown, ChevronUp } from 'lucide-react';
import { supabase } from '../../lib/supabase/client';

// Format currency
const formatCurrency = (amount: number, currency: string = 'USD') => {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: currency,
    minimumFractionDigits: 2,
    maximumFractionDigits: 4,
  }).format(amount);
};

interface QuoteLineCostsSectionV1Props {
  quoteLineId: string;
  currency?: string;
  onUpdate?: () => void;
}

export default function QuoteLineCostsSectionV1({ 
  quoteLineId, 
  currency = 'USD',
  onUpdate 
}: QuoteLineCostsSectionV1Props) {
  const [isExpanded, setIsExpanded] = useState(false);
  const [editingLabor, setEditingLabor] = useState(false);
  const [editingShipping, setEditingShipping] = useState(false);
  const [editingImportTax, setEditingImportTax] = useState(false);
  const [laborValue, setLaborValue] = useState<string>('');
  const [shippingValue, setShippingValue] = useState<string>('');
  const [importTaxValue, setImportTaxValue] = useState<string>('');
  
  const { costs, loading, error, refetch } = useQuoteLineCosts(quoteLineId);
  const { settings } = useCostSettings();
  const { updateCosts, isUpdating } = useUpdateQuoteLineCosts();
  const { recalculateCosts, isRecalculating } = useRecalculateQuoteLineCosts();
  const { breakdown: importTaxBreakdown, loading: breakdownLoading } = useImportTaxBreakdown(quoteLineId);
  const [showBreakdown, setShowBreakdown] = useState(false);

  // Initialize form values when costs load
  useEffect(() => {
    if (costs) {
      setLaborValue(costs.labor_cost.toString());
      setShippingValue(costs.shipping_cost.toString());
      setImportTaxValue(costs.import_tax_cost?.toString() || '0');
    }
  }, [costs]);

  const handleResetLabor = async () => {
    try {
      await supabase.rpc('compute_quote_line_cost', {
        p_quote_line_id: quoteLineId,
        p_options: { reset_labor: true }
      });
      await refetch();
      if (onUpdate) onUpdate();
    } catch (err) {
      console.error('Error resetting labor:', err);
    }
  };

  const handleResetShipping = async () => {
    try {
      await supabase.rpc('compute_quote_line_cost', {
        p_quote_line_id: quoteLineId,
        p_options: { reset_shipping: true }
      });
      await refetch();
      if (onUpdate) onUpdate();
    } catch (err) {
      console.error('Error resetting shipping:', err);
    }
  };

  const handleResetImportTax = async () => {
    try {
      await supabase.rpc('compute_quote_line_cost', {
        p_quote_line_id: quoteLineId,
        p_options: { reset_import_tax: true }
      });
      await refetch();
      if (onUpdate) onUpdate();
    } catch (err) {
      console.error('Error resetting import tax:', err);
    }
  };

  const handleSaveLabor = async () => {
    const numValue = parseFloat(laborValue);
    if (isNaN(numValue) || numValue < 0) {
      alert('Please enter a valid non-negative number');
      return;
    }

    try {
      await updateCosts(quoteLineId, {
        labor_cost: numValue,
        labor_source: 'manual',
      });
      setEditingLabor(false);
      await refetch();
      if (onUpdate) onUpdate();
    } catch (err) {
      console.error('Error updating labor cost:', err);
    }
  };

  const handleSaveShipping = async () => {
    const numValue = parseFloat(shippingValue);
    if (isNaN(numValue) || numValue < 0) {
      alert('Please enter a valid non-negative number');
      return;
    }

    try {
      await updateCosts(quoteLineId, {
        shipping_cost: numValue,
        shipping_source: 'manual',
      });
      setEditingShipping(false);
      await refetch();
      if (onUpdate) onUpdate();
    } catch (err) {
      console.error('Error updating shipping cost:', err);
    }
  };

  const handleSaveImportTax = async () => {
    const numValue = parseFloat(importTaxValue);
    if (isNaN(numValue) || numValue < 0) {
      alert('Please enter a valid non-negative number');
      return;
    }

    try {
      await updateCosts(quoteLineId, {
        import_tax_cost: numValue,
        import_tax_source: 'manual',
      });
      setEditingImportTax(false);
      await refetch();
      if (onUpdate) onUpdate();
    } catch (err) {
      console.error('Error updating import tax cost:', err);
    }
  };

  if (loading) {
    return (
      <div className="text-sm text-gray-500 py-2">
        Loading costs...
      </div>
    );
  }

  if (error) {
    return (
      <div className="text-sm text-red-600 py-2">
        Error loading costs: {error}
      </div>
    );
  }

  if (!costs) {
    return (
      <div className="text-sm text-gray-500 py-2">
        No cost data available. Costs will be calculated automatically.
      </div>
    );
  }

  const laborPercentage = settings?.labor_percentage ?? 10.0000;
  const shippingPercentage = settings?.shipping_percentage ?? 15.0000;
  const isLaborManual = costs.labor_source === 'manual';
  const isShippingManual = costs.shipping_source === 'manual';
  const isImportTaxManual = costs.import_tax_source === 'manual';

  return (
    <div className="border-t border-gray-200 pt-4 mt-4">
      <button
        type="button"
        onClick={() => setIsExpanded(!isExpanded)}
        className="flex items-center justify-between w-full text-left text-sm font-medium text-gray-900 hover:text-gray-700 mb-2"
      >
        <div className="flex items-center gap-2">
          <DollarSign className="w-4 h-4" />
          <span>Cost Summary</span>
        </div>
        <span className="text-xs text-gray-500">
          {isExpanded ? 'Hide' : 'Show'}
        </span>
      </button>

      {isExpanded && (
        <div className="bg-gray-50 rounded-lg p-4 space-y-4">
          {/* Base Material Cost (Read-only) */}
          <div>
            <Label className="text-xs text-gray-600 mb-1">Base Material Cost</Label>
            <div className="font-medium text-gray-900 text-sm">
              {formatCurrency(costs.base_material_cost, costs.currency_code)}
            </div>
          </div>

          {/* Labor Cost (Editable) */}
          <div>
            <div className="flex items-center justify-between mb-1">
              <Label className="text-xs text-gray-600">
                Labor Cost
                {isLaborManual && (
                  <span className="ml-2 text-xs bg-yellow-100 text-yellow-800 px-2 py-0.5 rounded">
                    Manual
                  </span>
                )}
              </Label>
              {!editingLabor && (
                <button
                  type="button"
                  onClick={handleResetLabor}
                  disabled={isRecalculating || !isLaborManual}
                  className="text-xs text-primary hover:text-primary/80 disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-1"
                  title="Reset to default percentage"
                >
                  <RotateCcw className="w-3 h-3" />
                  Reset Labor
                </button>
              )}
            </div>
            {editingLabor ? (
              <div className="flex items-center gap-2">
                <Input
                  type="number"
                  step="0.01"
                  min="0"
                  value={laborValue}
                  onChange={(e) => setLaborValue(e.target.value)}
                  className="flex-1 text-sm"
                />
                <button
                  type="button"
                  onClick={handleSaveLabor}
                  disabled={isUpdating}
                  className="px-3 py-1 bg-primary text-white text-xs rounded hover:bg-primary/90 disabled:opacity-50"
                >
                  Save
                </button>
                <button
                  type="button"
                  onClick={() => {
                    setEditingLabor(false);
                    setLaborValue(costs.labor_cost.toString());
                  }}
                  className="px-3 py-1 bg-gray-200 text-gray-700 text-xs rounded hover:bg-gray-300"
                >
                  Cancel
                </button>
              </div>
            ) : (
              <div className="flex items-center justify-between">
                <div className="font-medium text-gray-900 text-sm">
                  {formatCurrency(costs.labor_cost, costs.currency_code)}
                </div>
                <button
                  type="button"
                  onClick={() => setEditingLabor(true)}
                  className="text-xs text-primary hover:text-primary/80 flex items-center gap-1"
                >
                  <Edit2 className="w-3 h-3" />
                  Edit
                </button>
              </div>
            )}
            <p className="text-xs text-gray-500 mt-1">
              Default: {laborPercentage.toFixed(2)}% of material cost
            </p>
          </div>

          {/* Shipping Cost (Editable) */}
          <div>
            <div className="flex items-center justify-between mb-1">
              <Label className="text-xs text-gray-600">
                Shipping Cost
                {isShippingManual && (
                  <span className="ml-2 text-xs bg-yellow-100 text-yellow-800 px-2 py-0.5 rounded">
                    Manual
                  </span>
                )}
              </Label>
              {!editingShipping && (
                <button
                  type="button"
                  onClick={handleResetShipping}
                  disabled={isRecalculating || !isShippingManual}
                  className="text-xs text-primary hover:text-primary/80 disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-1"
                  title="Reset to default percentage"
                >
                  <RotateCcw className="w-3 h-3" />
                  Reset Shipping
                </button>
              )}
            </div>
            {editingShipping ? (
              <div className="flex items-center gap-2">
                <Input
                  type="number"
                  step="0.01"
                  min="0"
                  value={shippingValue}
                  onChange={(e) => setShippingValue(e.target.value)}
                  className="flex-1 text-sm"
                />
                <button
                  type="button"
                  onClick={handleSaveShipping}
                  disabled={isUpdating}
                  className="px-3 py-1 bg-primary text-white text-xs rounded hover:bg-primary/90 disabled:opacity-50"
                >
                  Save
                </button>
                <button
                  type="button"
                  onClick={() => {
                    setEditingShipping(false);
                    setShippingValue(costs.shipping_cost.toString());
                  }}
                  className="px-3 py-1 bg-gray-200 text-gray-700 text-xs rounded hover:bg-gray-300"
                >
                  Cancel
                </button>
              </div>
            ) : (
              <div className="flex items-center justify-between">
                <div className="font-medium text-gray-900 text-sm">
                  {formatCurrency(costs.shipping_cost, costs.currency_code)}
                </div>
                <button
                  type="button"
                  onClick={() => setEditingShipping(true)}
                  className="text-xs text-primary hover:text-primary/80 flex items-center gap-1"
                >
                  <Edit2 className="w-3 h-3" />
                  Edit
                </button>
              </div>
            )}
            <p className="text-xs text-gray-500 mt-1">
              Default: {shippingPercentage.toFixed(2)}% of material cost
            </p>
          </div>

          {/* Import Tax Cost (Editable) */}
          <div>
            <div className="flex items-center justify-between mb-1">
              <Label className="text-xs text-gray-600">
                Import Tax Cost
                {isImportTaxManual && (
                  <span className="ml-2 text-xs bg-yellow-100 text-yellow-800 px-2 py-0.5 rounded">
                    Manual
                  </span>
                )}
              </Label>
              {!editingImportTax && (
                <button
                  type="button"
                  onClick={handleResetImportTax}
                  disabled={isRecalculating || !isImportTaxManual}
                  className="text-xs text-primary hover:text-primary/80 disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-1"
                  title="Reset to calculated from components"
                >
                  <RotateCcw className="w-3 h-3" />
                  Reset Import Tax
                </button>
              )}
            </div>
            {editingImportTax ? (
              <div className="flex items-center gap-2">
                <Input
                  type="number"
                  step="0.01"
                  min="0"
                  value={importTaxValue}
                  onChange={(e) => setImportTaxValue(e.target.value)}
                  className="flex-1 text-sm"
                />
                <button
                  type="button"
                  onClick={handleSaveImportTax}
                  disabled={isUpdating}
                  className="px-3 py-1 bg-primary text-white text-xs rounded hover:bg-primary/90 disabled:opacity-50"
                >
                  Save
                </button>
                <button
                  type="button"
                  onClick={() => {
                    setEditingImportTax(false);
                    setImportTaxValue(costs.import_tax_cost?.toString() || '0');
                  }}
                  className="px-3 py-1 bg-gray-200 text-gray-700 text-xs rounded hover:bg-gray-300"
                >
                  Cancel
                </button>
              </div>
            ) : (
              <div className="flex items-center justify-between">
                <div className="font-medium text-gray-900 text-sm">
                  {formatCurrency(costs.import_tax_cost || 0, costs.currency_code)}
                </div>
                <button
                  type="button"
                  onClick={() => setEditingImportTax(true)}
                  className="text-xs text-primary hover:text-primary/80 flex items-center gap-1"
                >
                  <Edit2 className="w-3 h-3" />
                  Edit
                </button>
              </div>
            )}
            <p className="text-xs text-gray-500 mt-1">
              Calculated from component categories
            </p>
            
            {/* Import Tax Breakdown by Category */}
            {!breakdownLoading && importTaxBreakdown.length > 0 && (
              <div className="mt-3 pt-3 border-t border-gray-200">
                <button
                  type="button"
                  onClick={() => setShowBreakdown(!showBreakdown)}
                  className="flex items-center justify-between w-full text-left text-xs text-gray-600 hover:text-gray-900 mb-2"
                >
                  <span>View breakdown by category ({importTaxBreakdown.length} {importTaxBreakdown.length === 1 ? 'category' : 'categories'})</span>
                  {showBreakdown ? (
                    <ChevronUp className="w-3 h-3" />
                  ) : (
                    <ChevronDown className="w-3 h-3" />
                  )}
                </button>
                
                {showBreakdown && (
                  <div className="space-y-2 bg-white rounded border border-gray-200 p-3">
                    {/* Header */}
                    <div className="grid grid-cols-4 gap-2 text-xs font-semibold text-gray-700 pb-2 border-b border-gray-200">
                      <div className="col-span-1">Category</div>
                      <div className="col-span-1 text-right">Extended Cost</div>
                      <div className="col-span-1 text-right">Tax %</div>
                      <div className="col-span-1 text-right">Tax Amount</div>
                    </div>
                    
                    {/* Breakdown rows */}
                    {importTaxBreakdown.map((item) => (
                      <div key={item.id} className="grid grid-cols-4 gap-2 text-xs py-1 border-b border-gray-100 last:border-0">
                        <div className="col-span-1">
                          <span className="font-medium text-gray-700">
                            {item.category_name || 'No Category'}
                          </span>
                        </div>
                        <div className="col-span-1 text-right">
                          <span className="text-gray-600">
                            {formatCurrency(item.extended_cost, costs.currency_code)}
                          </span>
                        </div>
                        <div className="col-span-1 text-right">
                          <span className="text-gray-600">
                            {item.import_tax_percentage.toFixed(2)}%
                          </span>
                        </div>
                        <div className="col-span-1 text-right">
                          <span className="font-medium text-gray-900">
                            {formatCurrency(item.import_tax_amount, costs.currency_code)}
                          </span>
                        </div>
                      </div>
                    ))}
                    
                    {/* Total */}
                    <div className="pt-2 mt-2 border-t border-gray-300 grid grid-cols-4 gap-2 text-xs">
                      <div className="col-span-3 text-right font-semibold text-gray-900">
                        Total Import Tax:
                      </div>
                      <div className="col-span-1 text-right font-semibold text-gray-900">
                        {formatCurrency(costs.import_tax_cost || 0, costs.currency_code)}
                      </div>
                    </div>
                  </div>
                )}
              </div>
            )}
          </div>

          {/* Total Cost (Read-only) */}
          <div className="border-t border-gray-300 pt-3 mt-3">
            <div className="flex items-center justify-between">
              <Label className="text-sm font-semibold text-gray-900">Total Cost</Label>
              <div className="text-lg font-bold text-gray-900">
                {formatCurrency(costs.total_cost, costs.currency_code)}
              </div>
            </div>
          </div>

          {costs.calculated_at && (
            <div className="text-xs text-gray-500 mt-2">
              Last calculated: {new Date(costs.calculated_at).toLocaleString()}
            </div>
          )}
        </div>
      )}
    </div>
  );
}


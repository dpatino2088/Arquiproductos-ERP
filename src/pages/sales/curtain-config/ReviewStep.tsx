import { useState, useEffect, useMemo } from 'react';
import { ProductConfig } from '../product-config/types';
import Label from '../../../components/ui/Label';
import { supabase } from '../../../lib/supabase/client';
import { useOrganizationContext } from '../../../context/OrganizationContext';
import { ChevronDown, ChevronUp } from 'lucide-react';

// ============================================================================
// BOM Preview Snapshot types (from ConfiguredProducts.bom_preview_snapshot)
// ============================================================================
interface BOMSnapshotItem {
  id: string;
  kind: 'roll' | 'parent' | 'child' | 'accessory' | 'labor' | 'other';
  role: string;
  level: number;
  selected: boolean;
  catalog_item_id: string | null;
  sku: string | null;
  name: string | null;
  qty: number;
  uom: string;
  unit_price: number;
  line_total: number;
  children?: BOMSnapshotItem[];
  meta?: Record<string, any>;
}

interface BOMPreviewSnapshot {
  version: string;
  product_type_id: string;
  bom_template_id: string | null;
  price_basis: 'msrp' | 'dealer';
  currency: string;
  totals: {
    roll_msrp_total: number;
    bom_total: number;
    accessories_total: number;
    labor_pct: number;
    labor_amount: number;
    total_msrp: number;
    roll_total_cost: number;
    bom_total_cost: number;
  };
  items: BOMSnapshotItem[];
}

// Legacy breakdown line type (for fallback)
interface BOMBreakdownLine {
  role: string;
  sku: string | null;
  name: string | null;
  qty: number;
  uom: string;
  unitPrice: number;
  totalPrice: number;
  source: 'selected' | 'template' | 'child';
  isChild?: boolean;
  parentRole?: string;
}

interface ReviewStepProps {
  config: ProductConfig;
  onUpdate: (updates: Partial<ProductConfig>) => void;
  quoteId?: string; // Optional quote ID (kept for compatibility)
}

export default function ReviewStep({ config, onUpdate }: ReviewStepProps) {
  const { activeOrganizationId } = useOrganizationContext();
  const [fabricData, setFabricData] = useState<{
    sku?: string;
    collection_name?: string;
    variant_name?: string;
  } | null>(null);
  const [loadingFabric, setLoadingFabric] = useState(false);
  
  // BOM Breakdown state
  const [breakdownLines, setBreakdownLines] = useState<BOMBreakdownLine[]>([]);
  const [loadingBreakdown, setLoadingBreakdown] = useState(false);
  const [showBreakdown, setShowBreakdown] = useState(true); // Toggle visibility

  // ✅ NEW: Get BOM preview snapshot from ConfiguredProduct (if available)
  const bomPreviewSnapshot = (config as any).bom_preview_snapshot as BOMPreviewSnapshot | undefined;
  const hasValidSnapshot = bomPreviewSnapshot?.version === '1' && 
    Array.isArray(bomPreviewSnapshot?.items) && 
    bomPreviewSnapshot.items.length > 0;

  // Get variant ID from config (supports different product types)
  const getVariantId = () => {
    if ('variantId' in config && config.variantId) {
      return config.variantId;
    }
    if ('fabric' in config && config.fabric?.variantId) {
      return config.fabric.variantId;
    }
    if ('frontFabric' in config && config.frontFabric?.variantId) {
      return config.frontFabric.variantId;
    }
    return null;
  };

  // Load fabric data from CatalogItems
  useEffect(() => {
    const loadFabricData = async () => {
      const variantId = getVariantId();
      if (!variantId || !activeOrganizationId) {
        setFabricData(null);
        return;
      }

      try {
        setLoadingFabric(true);
        const { data: catalogItem, error } = await supabase
          .from('CatalogItems')
          .select('sku, collection_name, variant_name')
          .eq('id', variantId)
          .eq('organization_id', activeOrganizationId)
          .eq('is_active', true) // Use is_active instead of deleted
          .maybeSingle();

        if (error) {
          // Format error to avoid [circular] reference
          const errorMsg = error?.message || error?.error_description || error?.hint || 'Error loading fabric data';
          const errorCode = error?.code ? ` (${error.code})` : '';
          console.error('Error loading fabric data:', errorMsg + errorCode);
          // Don't block - just show no fabric data
          setFabricData(null);
          return;
        }

        if (catalogItem) {
          setFabricData({
            sku: catalogItem.sku || undefined,
            collection_name: catalogItem.collection_name || undefined,
            variant_name: catalogItem.variant_name || undefined,
          });
        } else {
          setFabricData(null);
        }
      } catch (err: any) {
        // Format error to avoid [circular] reference
        const errorMsg = err?.message || err?.error_description || err?.hint || 'Error loading fabric data';
        console.error('Error loading fabric data:', errorMsg);
        // Don't block - just show no fabric data
        setFabricData(null);
      } finally {
        setLoadingFabric(false);
      }
    };

    loadFabricData();
  }, [config, activeOrganizationId]);

  // Load BOM breakdown from template components
  // Try bom_template_id first, then fall back to _hardware_filtered_templates if single match
  const explicitBomTemplateId = (config as any).bom_template_id;
  const filteredTemplates = (config as any)._hardware_filtered_templates as string[] | undefined;
  
  // Resolve the template ID: explicit > single filtered > null
  const bomTemplateId = explicitBomTemplateId 
    || (filteredTemplates && filteredTemplates.length === 1 ? filteredTemplates[0] : null);
  
  const hasMultipleCandidates = !explicitBomTemplateId && filteredTemplates && filteredTemplates.length > 1;

  // ✅ NEW: Convert snapshot items to breakdown lines (no DB queries needed!)
  const snapshotBreakdownLines = useMemo((): BOMBreakdownLine[] => {
    if (!hasValidSnapshot || !bomPreviewSnapshot) return [];

    const lines: BOMBreakdownLine[] = [];
    
    const processItem = (item: BOMSnapshotItem, isChild = false, parentRole?: string) => {
      lines.push({
        role: item.role,
        sku: item.sku,
        name: item.name,
        qty: item.qty,
        uom: item.uom,
        unitPrice: item.unit_price,
        totalPrice: item.line_total,
        source: item.selected ? 'selected' : isChild ? 'child' : 'template',
        isChild,
        parentRole,
      });

      // Process nested children
      if (item.children && item.children.length > 0) {
        item.children.forEach(child => processItem(child, true, item.role));
      }
    };

    bomPreviewSnapshot.items.forEach(item => processItem(item));
    return lines;
  }, [hasValidSnapshot, bomPreviewSnapshot]);

  // Calculate total from snapshot or legacy breakdown
  const snapshotTotal = useMemo(() => {
    if (hasValidSnapshot && bomPreviewSnapshot?.totals) {
      // Use the calculated total from snapshot
      return bomPreviewSnapshot.totals.total_msrp;
    }
    return null;
  }, [hasValidSnapshot, bomPreviewSnapshot]);
  
  useEffect(() => {
    // ✅ If we have a valid snapshot, use it directly (no queries needed)
    if (hasValidSnapshot) {
      setBreakdownLines(snapshotBreakdownLines);
      setLoadingBreakdown(false);
      return;
    }
    
    // Fallback: load from DB
    const loadBreakdown = async () => {
      if (!bomTemplateId || !activeOrganizationId) {
        setBreakdownLines([]);
        return;
      }

      try {
        setLoadingBreakdown(true);

        // 1. Get all parent components from BOMComponents
        const { data: components, error: componentsError } = await supabase
          .from('BOMComponents')
          .select(`
            id,
            component_role,
            component_item_id,
            qty_type,
            qty_value,
            qty_delta_mm,
            uom,
            parent_component_id
          `)
          .eq('bom_template_id', bomTemplateId)
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .eq('archived', false)
          .order('sort_order', { ascending: true });

        if (componentsError) throw componentsError;
        if (!components || components.length === 0) {
          setBreakdownLines([]);
          return;
        }

        // 2. Build map of selected items from config
        const selectedItems: Record<string, string | null> = {
          bottom_bar: (config as any).bottom_bar_item_id || null,
          headbox: (config as any).headbox_item_id || null,
          side_channel: (config as any).side_channel_item_id || null,
          bottom_channel: (config as any).bottom_channel_item_id || null,
          motor: (config as any).motor_item_id || null,
          drive: (config as any).drive_item_id || null,
          tube: (config as any).tube_item_id || null,
        };

        // 3. Collect all catalog item IDs we need to fetch
        const catalogItemIds = new Set<string>();
        
        // Add fabric/variant ID
        const variantId = getVariantId();
        if (variantId) {
          catalogItemIds.add(variantId);
        }
        
        // Add parent components (selected or default)
        components.forEach((c: any) => {
          const role = (c.component_role || '').toLowerCase();
          const selectedId = selectedItems[role];
          if (selectedId) {
            catalogItemIds.add(selectedId);
          }
          // Always add component_item_id for both parents and children
          if (c.component_item_id) {
            catalogItemIds.add(c.component_item_id);
          }
        });

        if (catalogItemIds.size === 0) {
          setBreakdownLines([]);
          return;
        }

        // 4. Fetch CatalogItems info
        const { data: catalogItems, error: itemsError } = await supabase
          .from('CatalogItems')
          .select('id, sku, name, unit_of_measure')
          .in('id', Array.from(catalogItemIds))
          .eq('organization_id', activeOrganizationId);

        if (itemsError) throw itemsError;

        const itemMap = new Map<string, { sku: string; name: string; uom: string }>();
        (catalogItems || []).forEach((item: any) => {
          itemMap.set(item.id, {
            sku: item.sku || '',
            name: item.name || item.sku || '',
            uom: item.unit_of_measure || 'ea',
          });
        });

        // 5. Fetch MSRP prices from CatalogItemsMSRP
        const { data: msrpData, error: msrpError } = await supabase
          .from('CatalogItemsMSRP')
          .select('catalog_item_id, msrp, total_cost')
          .in('catalog_item_id', Array.from(catalogItemIds))
          .eq('organization_id', activeOrganizationId);

        if (msrpError) {
          console.warn('Error loading MSRP data:', msrpError.message);
        }

        const priceMap = new Map<string, { msrp: number; cost: number }>();
        (msrpData || []).forEach((row: any) => {
          priceMap.set(row.catalog_item_id, {
            msrp: Number(row.msrp) || 0,
            cost: Number(row.total_cost) || 0,
          });
        });

        // 6. Calculate dimensions for qty calculation
        const widthMm = Number((config as any).width_mm) || 0;
        const heightMm = Number((config as any).height_mm) || 0;
        const widthM = widthMm / 1000;
        const heightM = heightMm / 1000;

        // 7. Build breakdown lines - process parents first, then children
        const lines: BOMBreakdownLine[] = [];
        const parentComponents = components.filter((c: any) => !c.parent_component_id);
        const childComponents = components.filter((c: any) => c.parent_component_id);
        
        // Build a map of parent component ID to role for child display
        const parentIdToRole = new Map<string, string>();
        parentComponents.forEach((p: any) => {
          parentIdToRole.set(p.id, p.component_role || 'unknown');
        });

        // Helper function to calculate qty
        const calculateQty = (comp: any): number => {
          let qty = Number(comp.qty_value) || 1;
          const qtyType = comp.qty_type || 'fixed';
          const deltaMm = Number(comp.qty_delta_mm) || 0;

          if (qtyType === 'per_width' || qtyType === 'width') {
            qty = Math.max(0, (widthMm + deltaMm) / 1000);
          } else if (qtyType === 'per_height' || qtyType === 'height') {
            qty = Math.max(0, (heightMm + deltaMm) / 1000);
          } else if (qtyType === 'per_m2' || qtyType === 'area') {
            qty = Math.max(0, widthM * heightM);
          }
          return qty;
        };

        // Process parent components
        parentComponents.forEach((comp: any) => {
          const role = (comp.component_role || '').toLowerCase();
          const selectedId = selectedItems[role];
          const itemId = selectedId || comp.component_item_id;

          if (!itemId) return; // Skip if no item

          const itemInfo = itemMap.get(itemId);
          const priceInfo = priceMap.get(itemId);
          const qty = calculateQty(comp);
          const unitPrice = priceInfo?.msrp || 0;
          const totalPrice = qty * unitPrice;

          lines.push({
            role: comp.component_role || 'unknown',
            sku: itemInfo?.sku || null,
            name: itemInfo?.name || null,
            qty: Math.round(qty * 1000) / 1000,
            uom: comp.uom || itemInfo?.uom || 'ea',
            unitPrice,
            totalPrice: Math.round(totalPrice * 100) / 100,
            source: selectedId ? 'selected' : 'template',
            isChild: false,
          });

          // Add children of this parent immediately after
          const children = childComponents.filter((c: any) => c.parent_component_id === comp.id);
          children.forEach((child: any) => {
            const childItemId = child.component_item_id;
            if (!childItemId) return;

            const childItemInfo = itemMap.get(childItemId);
            const childPriceInfo = priceMap.get(childItemId);
            const childQty = calculateQty(child);
            const childUnitPrice = childPriceInfo?.msrp || 0;
            const childTotalPrice = childQty * childUnitPrice;

            lines.push({
              role: child.component_role || 'child',
              sku: childItemInfo?.sku || null,
              name: childItemInfo?.name || null,
              qty: Math.round(childQty * 1000) / 1000,
              uom: child.uom || childItemInfo?.uom || 'ea',
              unitPrice: childUnitPrice,
              totalPrice: Math.round(childTotalPrice * 100) / 100,
              source: 'child',
              isChild: true,
              parentRole: comp.component_role,
            });
          });
        });

        // Add fabric line if exists (variantId was captured above)
        if (variantId) {
          const fabricPrice = priceMap.get(variantId);
          const fabricItem = itemMap.get(variantId);
          const fabricQty = widthM * heightM; // m²

          lines.unshift({
            role: 'fabric',
            sku: fabricData?.sku || fabricItem?.sku || null,
            name: fabricData?.variant_name || fabricItem?.name || 'Fabric',
            qty: Math.round(fabricQty * 1000) / 1000,
            uom: 'm²',
            unitPrice: fabricPrice?.msrp || 0,
            totalPrice: Math.round((fabricQty * (fabricPrice?.msrp || 0)) * 100) / 100,
            source: 'selected',
          });
        }

        setBreakdownLines(lines);
      } catch (err: any) {
        console.error('Error loading BOM breakdown:', err?.message || err);
        setBreakdownLines([]);
      } finally {
        setLoadingBreakdown(false);
      }
    };

    loadBreakdown();
  }, [bomTemplateId, activeOrganizationId, config, fabricData, hasValidSnapshot, snapshotBreakdownLines]);

  // Calculate totals - prefer snapshot total if available
  const breakdownTotal = useMemo(() => {
    // Use snapshot total if available (more accurate, includes all costs)
    if (snapshotTotal !== null) {
      return snapshotTotal;
    }
    // Fallback: sum of breakdown lines
    return breakdownLines.reduce((sum, line) => sum + line.totalPrice, 0);
  }, [breakdownLines, snapshotTotal]);

  // Get snapshot totals breakdown for display
  const snapshotTotals = hasValidSnapshot ? bomPreviewSnapshot?.totals : null;

  // Get dimensions display
  const getDimensionsDisplay = () => {
    const width_mm = (config as any).width_mm;
    const height_mm = (config as any).height_mm;
    if (width_mm && height_mm) {
      return `${width_mm.toFixed(0)} x ${height_mm.toFixed(0)} mm`;
    }
    return 'Not set';
  };

  const dimensionsDisplay = getDimensionsDisplay();
  const hasFabricData = fabricData && (fabricData.sku || fabricData.collection_name || fabricData.variant_name);

  return (
    <div className="max-w-4xl mx-auto">
      <div className="bg-white rounded-lg border border-gray-200 p-6 space-y-6">
        <div>
          <Label className="text-lg font-semibold mb-4 block">CONFIGURED PRODUCT</Label>
          
          <div className="space-y-4">
            {/* Fabric Technical Data Section */}
            {hasFabricData && (
              <div className="mb-4 pb-4 border-b border-gray-200">
                <h3 className="text-sm font-semibold text-gray-700 mb-3">FABRIC TECHNICAL DATA</h3>
                <div className="grid grid-cols-2 gap-4 text-sm">
                  {fabricData.sku && (
                    <div>
                      <span className="font-medium text-gray-700">SKU:</span>
                      <span className="ml-2 text-gray-900">{fabricData.sku}</span>
                    </div>
                  )}
                  {fabricData.collection_name && (
                    <div>
                      <span className="font-medium text-gray-700">Collection:</span>
                      <span className="ml-2 text-gray-900">{fabricData.collection_name}</span>
                    </div>
                  )}
                  {fabricData.variant_name && (
                    <div>
                      <span className="font-medium text-gray-700">Variant:</span>
                      <span className="ml-2 text-gray-900">{fabricData.variant_name}</span>
                    </div>
                  )}
                </div>
              </div>
            )}

            {/* Product Specifications Section */}
            <div>
              <h3 className="text-sm font-semibold text-gray-700 mb-3">PRODUCT SPECIFICATIONS</h3>
              <div className="grid grid-cols-2 gap-4 text-sm">
                <div>
                  <span className="font-medium text-gray-700">Position:</span>
                  <span className="ml-2 text-gray-900">{config.position || 'Not selected'}</span>
                </div>
                <div>
                  <span className="font-medium text-gray-700">Product Type:</span>
                  <span className="ml-2 text-gray-900">{config.productType || 'Not selected'}</span>
                </div>
                <div>
                  <span className="font-medium text-gray-700">Mounting:</span>
                  <span className="ml-2 text-gray-900">{(config as any).mountingCassette || (config as any).mountingType || 'Not selected'}</span>
                </div>
                <div>
                  <span className="font-medium text-gray-700">Dimensions:</span>
                  <span className="ml-2 text-gray-900">{dimensionsDisplay}</span>
                </div>
                <div>
                  <span className="font-medium text-gray-700">Film Type:</span>
                  <span className="ml-2 text-gray-900">{(config as any).filmType || 'Not selected'}</span>
                </div>
                <div>
                  <span className="font-medium text-gray-700">Guiding:</span>
                  <span className="ml-2 text-gray-900">{(config as any).guidingProfile || 'Not selected'}</span>
                </div>
                <div>
                  <span className="font-medium text-gray-700">Fixing:</span>
                  <span className="ml-2 text-gray-900">{(config as any).fixingType || 'Not selected'}</span>
                </div>
                <div>
                  <span className="font-medium text-gray-700">Accessories:</span>
                  <span className="ml-2 text-gray-900">
                    {config.accessories?.length || 0} items
                  </span>
                </div>
                {(config as any).drive_type || (config as any).operatingSystem ? (
                  <div>
                    <span className="font-medium text-gray-700">Drive Type:</span>
                    <span className="ml-2 text-gray-900">{(config as any).drive_type || (config as any).operatingSystem || 'Not selected'}</span>
                  </div>
                ) : null}
                {(config as any).hardware_color || (config as any).hardwareColor ? (
                  <div>
                    <span className="font-medium text-gray-700">Hardware Color:</span>
                    <span className="ml-2 text-gray-900">{(config as any).hardware_color || (config as any).hardwareColor || 'Not selected'}</span>
                  </div>
                ) : null}
                {(config as any).bottom_rail_type ? (
                  <div>
                    <span className="font-medium text-gray-700">Bottom Rail Type:</span>
                    <span className="ml-2 text-gray-900">{(config as any).bottom_rail_type || 'Not selected'}</span>
                  </div>
                ) : null}
                {(config as any).cassette !== undefined ? (
                  <div>
                    <span className="font-medium text-gray-700">Cassette:</span>
                    <span className="ml-2 text-gray-900">{(config as any).cassette ? 'Yes' : 'No'}</span>
                  </div>
                ) : null}
                {(config as any).side_channel !== undefined ? (
                  <div>
                    <span className="font-medium text-gray-700">Side Channel:</span>
                    <span className="ml-2 text-gray-900">{(config as any).side_channel ? 'Yes' : 'No'}</span>
                    {(config as any).side_channel && (config as any).side_channel_type ? (
                      <div className="mt-1">
                        <span className="font-medium text-gray-700">Side Channel Type:</span>
                        <span className="ml-2 text-gray-900">{(config as any).side_channel_type}</span>
                      </div>
                    ) : null}
                  </div>
                ) : null}
              </div>
            </div>
          </div>
        </div>
        
        {/* Debug Info (DEV only) */}
        {import.meta.env.DEV && (
          <details className="mt-4 p-3 bg-gray-50 rounded-lg text-xs">
            <summary className="cursor-pointer text-gray-500 font-medium">
              Debug Info (DEV)
            </summary>
            <pre className="mt-2 text-gray-600 overflow-auto max-h-40">
              {JSON.stringify({
                bom_template_id: bomTemplateId,
                _hardware_filtered_templates: (config as any)._hardware_filtered_templates?.length,
              }, null, 2)}
            </pre>
          </details>
        )}
        
        {/* BOM Breakdown Section */}
        <div className="mt-6 pt-6 border-t border-gray-200">
          <div 
            className="flex items-center justify-between cursor-pointer"
            onClick={() => setShowBreakdown(!showBreakdown)}
          >
            <h3 className="text-sm font-semibold text-gray-700 flex items-center gap-2">
                BOM COMPONENT BREAKDOWN
                {hasValidSnapshot && (
                  <span className="px-1.5 py-0.5 text-xs bg-green-100 text-green-700 rounded font-normal">
                    Snapshot
                  </span>
                )}
              </h3>
            <button className="p-1 hover:bg-gray-100 rounded">
              {showBreakdown ? (
                <ChevronUp className="w-4 h-4 text-gray-500" />
              ) : (
                <ChevronDown className="w-4 h-4 text-gray-500" />
              )}
            </button>
          </div>
          
          {showBreakdown && (
            <div className="mt-4">
              {/* Multiple template candidates - can't show breakdown yet */}
              {hasMultipleCandidates ? (
                <div className="text-sm text-amber-600 bg-amber-50 p-3 rounded-lg">
                  Multiple BOM templates match your selection ({filteredTemplates?.length} candidates). 
                  Final breakdown will be calculated when you add to quote.
                </div>
              ) : !bomTemplateId ? (
                <div className="text-sm text-gray-500">
                  No BOM template resolved yet. Complete your selections to see breakdown.
                </div>
              ) : loadingBreakdown ? (
                <div className="text-sm text-gray-500">Loading component breakdown...</div>
              ) : breakdownLines.length > 0 ? (
                <div className="overflow-x-auto">
                  <table className="min-w-full divide-y divide-gray-200 text-sm">
                    <thead className="bg-gray-50">
                      <tr>
                        <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Component
                        </th>
                        <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          SKU
                        </th>
                        <th className="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Qty
                        </th>
                        <th className="px-3 py-2 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">
                          UOM
                        </th>
                        <th className="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Unit Price
                        </th>
                        <th className="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Total
                        </th>
                      </tr>
                    </thead>
                    <tbody className="bg-white divide-y divide-gray-200">
                      {breakdownLines.map((line, idx) => (
                        <tr 
                          key={idx} 
                          className={
                            line.source === 'selected' 
                              ? 'bg-blue-50' 
                              : line.isChild 
                                ? 'bg-gray-50' 
                                : ''
                          }
                        >
                          <td className="px-3 py-2 whitespace-nowrap">
                            <div className={`flex items-center ${line.isChild ? 'pl-4' : ''}`}>
                              {line.isChild && (
                                <span className="text-gray-400 mr-1">└</span>
                              )}
                              <span className={`capitalize ${line.isChild ? 'text-gray-600 text-sm' : 'font-medium text-gray-900'}`}>
                                {line.role.replace(/_/g, ' ')}
                              </span>
                              {line.source === 'selected' && (
                                <span className="ml-2 px-1.5 py-0.5 text-xs bg-blue-100 text-blue-700 rounded">
                                  Selected
                                </span>
                              )}
                              {line.isChild && (
                                <span className="ml-2 px-1.5 py-0.5 text-xs bg-gray-200 text-gray-600 rounded">
                                  Child
                                </span>
                              )}
                            </div>
                            {line.name && line.name !== line.sku && (
                              <div className={`text-xs text-gray-500 ${line.isChild ? 'pl-6' : ''}`}>{line.name}</div>
                            )}
                          </td>
                          <td className={`px-3 py-2 whitespace-nowrap ${line.isChild ? 'text-gray-500' : 'text-gray-600'}`}>
                            {line.sku || '-'}
                          </td>
                          <td className={`px-3 py-2 whitespace-nowrap text-right ${line.isChild ? 'text-gray-600' : 'text-gray-900'}`}>
                            {line.qty.toFixed(3)}
                          </td>
                          <td className="px-3 py-2 whitespace-nowrap text-center text-gray-500">
                            {line.uom}
                          </td>
                          <td className="px-3 py-2 whitespace-nowrap text-right text-gray-600">
                            ${line.unitPrice.toFixed(2)}
                          </td>
                          <td className="px-3 py-2 whitespace-nowrap text-right font-medium text-gray-900">
                            ${line.totalPrice.toFixed(2)}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                    <tfoot className="bg-gray-100">
                      {/* Show detailed breakdown if snapshot totals available */}
                      {snapshotTotals ? (
                        <>
                          <tr className="border-t border-gray-300">
                            <td colSpan={5} className="px-3 py-1 text-right text-sm text-gray-600">
                              Roll/Fabric:
                            </td>
                            <td className="px-3 py-1 text-right text-gray-700">
                              ${(snapshotTotals.roll_msrp_total || 0).toFixed(2)}
                            </td>
                          </tr>
                          <tr>
                            <td colSpan={5} className="px-3 py-1 text-right text-sm text-gray-600">
                              BOM Components:
                            </td>
                            <td className="px-3 py-1 text-right text-gray-700">
                              ${(snapshotTotals.bom_total || 0).toFixed(2)}
                            </td>
                          </tr>
                          {(snapshotTotals.accessories_total || 0) > 0 && (
                            <tr>
                              <td colSpan={5} className="px-3 py-1 text-right text-sm text-gray-600">
                                Accessories:
                              </td>
                              <td className="px-3 py-1 text-right text-gray-700">
                                ${snapshotTotals.accessories_total.toFixed(2)}
                              </td>
                            </tr>
                          )}
                          {(snapshotTotals.labor_amount || 0) > 0 && (
                            <tr>
                              <td colSpan={5} className="px-3 py-1 text-right text-sm text-gray-600">
                                Labor ({snapshotTotals.labor_pct || 0}%):
                              </td>
                              <td className="px-3 py-1 text-right text-gray-700">
                                ${snapshotTotals.labor_amount.toFixed(2)}
                              </td>
                            </tr>
                          )}
                          <tr className="border-t border-gray-400">
                            <td colSpan={5} className="px-3 py-2 text-right font-semibold text-gray-700">
                              Total MSRP:
                            </td>
                            <td className="px-3 py-2 text-right font-bold text-gray-900">
                              ${(snapshotTotals.total_msrp || 0).toFixed(2)}
                            </td>
                          </tr>
                        </>
                      ) : (
                        <tr>
                          <td colSpan={5} className="px-3 py-2 text-right font-semibold text-gray-700">
                            Subtotal (BOM):
                          </td>
                          <td className="px-3 py-2 text-right font-bold text-gray-900">
                            ${breakdownTotal.toFixed(2)}
                          </td>
                        </tr>
                      )}
                    </tfoot>
                  </table>
                </div>
              ) : (
                <div className="text-sm text-gray-500">
                  No component breakdown available for this template.
                </div>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

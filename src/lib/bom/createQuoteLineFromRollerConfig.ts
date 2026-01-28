/**
 * Create QuoteLine from Roller BOM Configuration
 * 
 * Handles the complete flow:
 * 1. Create/Update QuoteLine with all data
 * 2. Save configuration options as QuoteLineComponents (kind='option')
 * 3. Generate BOMInstance using slots + selections
 */

import { supabase } from '../supabase/client';
import { RollerBOMConfigState } from './types';
import { calculateQuoteLinePrice } from '../pricing';

export interface CreateQuoteLineFromRollerConfigParams {
  organizationId: string;
  quoteId: string;
  config: RollerBOMConfigState & {
    fabric_catalog_item_id?: string | null;
    collection_name?: string | null;
    variant_name?: string | null;
    quantity?: number;
  };
  customerType?: string; // For pricing tier
  costSettings?: any; // Cost settings for pricing
  editingLineId?: string | null; // If editing existing line
}

export interface CreateQuoteLineResult {
  quoteLineId: string;
  bomInstanceId: string | null;
}

export async function createQuoteLineFromRollerConfig(
  params: CreateQuoteLineFromRollerConfigParams
): Promise<CreateQuoteLineResult> {
  const { organizationId, quoteId, config, customerType = 'VIP', costSettings, editingLineId } = params;

  // Validate required fields
  if (!config.fabric_catalog_item_id) {
    throw new Error('Fabric selection is required');
  }

  if (!config.width_mm || !config.height_mm) {
    throw new Error('Width and height measurements are required');
  }

  if (!config.product_type_id) {
    throw new Error('Product type is required');
  }

  // Get catalog item details
  const { data: catalogItem, error: catalogError } = await supabase
    .from('CatalogItems')
    .select('id, sku, name, collection_name, variant_name, cost_exw, unit_of_measure')
    .eq('id', config.fabric_catalog_item_id)
    .eq('is_active', true)
    .maybeSingle();

  if (catalogError || !catalogItem) {
    throw new Error('Catalog item not found or inactive');
  }

  // Get MSRP (from CatalogItemsMSRP cache or CatalogItems.msrp)
  const { data: msrpData } = await supabase
    .from('CatalogItemsMSRP')
    .select('msrp_sale_out')
    .eq('catalog_item_id', config.fabric_catalog_item_id)
    .or(`organization_id.eq.${organizationId},organization_id.is.null`)
    .maybeSingle();

  const msrpSaleOut = msrpData?.msrp_sale_out || 0;

  if (!msrpSaleOut || msrpSaleOut === 0) {
    throw new Error(`Catalog item ${catalogItem.sku} does not have MSRP. Please define MSRP before adding to quote.`);
  }

  // Calculate pricing
  const width_m = config.width_mm / 1000;
  const height_m = config.height_mm / 1000;
  const quantity = config.quantity || 1;
  const computedQty = width_m * height_m; // Area-based for fabric

  const pricingResult = calculateQuoteLinePrice(
    {
      msrp: msrpSaleOut,
      cost_exw: catalogItem.cost_exw || null,
      labor_cost_per_unit: null,
      shipping_cost_per_unit: null,
      freight_cost: null,
      handling_cost: null,
      import_tax_pct: null,
      default_margin_pct: null,
    },
    customerType,
    costSettings || null,
    null // categoryMargin
  );

  const netUnitPrice = pricingResult.unitPrice;
  const lineTotal = netUnitPrice * computedQty;

  // Build QuoteLine data
  const quoteLineData: any = {
    quote_id: quoteId,
    organization_id: organizationId,
    catalog_item_id: config.fabric_catalog_item_id,
    quantity,
    width_m,
    height_m,
    collection_name: config.collection_name || catalogItem.collection_name,
    variant_name: config.variant_name || catalogItem.variant_name,
    product_type_id: config.product_type_id,
    computed_qty: computedQty,
    // Pricing snapshots
    list_unit_price_snapshot: msrpSaleOut,
    unit_price_snapshot: netUnitPrice,
    line_total: lineTotal,
    unit_cost_snapshot: catalogItem.cost_exw || 0,
    total_unit_cost_snapshot: pricingResult.totalUnitCost,
    discount_pct_used: pricingResult.discountPct,
    customer_type_snapshot: customerType,
    price_basis: pricingResult.priceBasis,
    margin_pct_used:
      pricingResult.totalUnitCost > 0 && netUnitPrice > 0
        ? ((netUnitPrice - pricingResult.totalUnitCost) / netUnitPrice) * 100
        : null,
    measure_basis_snapshot: 'area',
  };

  let finalLineId: string;

  if (editingLineId) {
    // Update existing line
    const { error: updateError } = await supabase
      .from('QuoteLines')
      .update(quoteLineData)
      .eq('id', editingLineId)
      .eq('organization_id', organizationId);

    if (updateError) {
      throw new Error(updateError.message || 'Error updating quote line');
    }

    finalLineId = editingLineId;
  } else {
    // Create new line
    const { data: newLine, error: insertError } = await supabase
      .from('QuoteLines')
      .insert(quoteLineData)
      .select('id')
      .single();

    if (insertError || !newLine?.id) {
      throw new Error(insertError?.message || 'Error creating quote line');
    }

    finalLineId = newLine.id;
  }

  // Save configuration options as QuoteLineComponents (kind='option')
  try {
    // Soft-delete previous options
    await supabase
      .from('QuoteLineComponents')
      .update({ deleted: true })
      .eq('quote_line_id', finalLineId)
      .eq('organization_id', organizationId)
      .eq('kind', 'option');

    // Build options array
    const configOptions: any[] = [];

    // Headbox type
    configOptions.push({
      organization_id: organizationId,
      quote_line_id: finalLineId,
      kind: 'option',
      component_role: 'headbox_type',
      payload: { headbox_type: config.headbox_type },
      source: 'configured_component',
      catalog_item_id: null,
      deleted: false,
    });

    // System size
    configOptions.push({
      organization_id: organizationId,
      quote_line_id: finalLineId,
      kind: 'option',
      component_role: 'system_size',
      payload: { system_size: config.system_size },
      source: 'configured_component',
      catalog_item_id: null,
      deleted: false,
    });

    // Side channel mode
    configOptions.push({
      organization_id: organizationId,
      quote_line_id: finalLineId,
      kind: 'option',
      component_role: 'side_channel_mode',
      payload: { side_channel_mode: config.side_channel_mode },
      source: 'configured_component',
      catalog_item_id: null,
      deleted: false,
    });

    // Operating system
    configOptions.push({
      organization_id: organizationId,
      quote_line_id: finalLineId,
      kind: 'option',
      component_role: 'operating_system',
      payload: { operating_system: config.operating_system },
      source: 'configured_component',
      catalog_item_id: null,
      deleted: false,
    });

    // Bottom bar wrapped
    if (config.bottom_bar_wrapped) {
      configOptions.push({
        organization_id: organizationId,
        quote_line_id: finalLineId,
        kind: 'option',
        component_role: 'bottom_bar_wrapped',
        payload: { bottom_bar_wrapped: true },
        source: 'configured_component',
        catalog_item_id: null,
        deleted: false,
      });
    }

    // Insert options
    if (configOptions.length > 0) {
      const { error: optionsError } = await supabase
        .from('QuoteLineComponents')
        .insert(configOptions);

      if (optionsError) {
        console.error('[createQuoteLineFromRollerConfig] Error saving options:', optionsError);
        // Don't fail - options are supplementary
      }
    }
  } catch (optionsError) {
    console.warn('[createQuoteLineFromRollerConfig] Failed to save options:', optionsError);
    // Don't fail the whole operation
  }

  // Save parent SKU selections (kind='selection')
  try {
    // Soft-delete previous selections
    await supabase
      .from('QuoteLineComponents')
      .update({ deleted: true })
      .eq('quote_line_id', finalLineId)
      .eq('organization_id', organizationId)
      .eq('kind', 'selection');

    const selections: any[] = [];

    if (config.drive_item_id) {
      selections.push({
        organization_id: organizationId,
        quote_line_id: finalLineId,
        kind: 'selection',
        component_role: 'drive',
        catalog_item_id: config.drive_item_id,
        source: 'configured_component',
        deleted: false,
      });
    }

    if (config.motor_item_id) {
      selections.push({
        organization_id: organizationId,
        quote_line_id: finalLineId,
        kind: 'selection',
        component_role: 'motor',
        catalog_item_id: config.motor_item_id,
        source: 'configured_component',
        deleted: false,
      });
    }

    if (config.headbox_item_id) {
      selections.push({
        organization_id: organizationId,
        quote_line_id: finalLineId,
        kind: 'selection',
        component_role: 'headbox',
        catalog_item_id: config.headbox_item_id,
        source: 'configured_component',
        deleted: false,
      });
    }

    if (config.bottom_bar_item_id) {
      selections.push({
        organization_id: organizationId,
        quote_line_id: finalLineId,
        kind: 'selection',
        component_role: 'bottom_bar',
        catalog_item_id: config.bottom_bar_item_id,
        source: 'configured_component',
        deleted: false,
      });
    }

    if (config.side_channel_item_id) {
      selections.push({
        organization_id: organizationId,
        quote_line_id: finalLineId,
        kind: 'selection',
        component_role: 'side_channel',
        catalog_item_id: config.side_channel_item_id,
        source: 'configured_component',
        deleted: false,
      });
    }

    if (config.bottom_channel_item_id) {
      selections.push({
        organization_id: organizationId,
        quote_line_id: finalLineId,
        kind: 'selection',
        component_role: 'bottom_channel',
        catalog_item_id: config.bottom_channel_item_id,
        source: 'configured_component',
        deleted: false,
      });
    }

    if (config.tube_item_id) {
      selections.push({
        organization_id: organizationId,
        quote_line_id: finalLineId,
        kind: 'selection',
        component_role: 'tube',
        catalog_item_id: config.tube_item_id,
        source: 'configured_component',
        deleted: false,
      });
    }

    if (selections.length > 0) {
      const { error: selectionsError } = await supabase
        .from('QuoteLineComponents')
        .insert(selections);

      if (selectionsError) {
        console.error('[createQuoteLineFromRollerConfig] Error saving selections:', selectionsError);
      }
    }
  } catch (selectionsError) {
    console.warn('[createQuoteLineFromRollerConfig] Failed to save selections:', selectionsError);
  }

  // Generate BOM Instance using slots + selections
  let bomInstanceId: string | null = null;

  try {
    const { data, error } = await supabase.rpc('generate_bom_from_slots', {
      p_org_id: organizationId,
      p_quote_line_id: finalLineId,
      p_product_type_id: config.product_type_id,
    });

    if (error) {
      console.error('[createQuoteLineFromRollerConfig] BOM generation failed:', error);
    } else {
      bomInstanceId = data || null;

      // ✅ AGREGAR ACCESORIOS AL BOM
      // Si se generó BOM exitosamente, agregar líneas para accesorios
      if (bomInstanceId) {
        try {
          // Obtener accesorios de la quote line
          const { data: accessories } = await supabase
            .from('QuoteLineComponents')
            .select('catalog_item_id, qty')
            .eq('organization_id', organizationId)
            .eq('quote_line_id', finalLineId)
            .or('source.eq.accessory,component_role.eq.accessory')
            .eq('deleted', false);

          if (accessories && accessories.length > 0) {
            // Obtener detalles de catalog items y MSRP
            const accessoryIds = accessories.map((acc: { catalog_item_id: string }) => acc.catalog_item_id).filter(Boolean);
            if (accessoryIds.length > 0) {
              const { data: catalogItems } = await supabase
                .from('CatalogItems')
                .select('id, sku, name, unit_of_measure, cost_exw')
                .in('id', accessoryIds)
                .eq('is_active', true);

              // Obtener MSRP para los precios (aunque no se guarda en BOMInstanceLines, se usa para cálculos)
              const { data: msrpData } = await supabase
                .from('CatalogItemsMSRP')
                .select('catalog_item_id, msrp_sale_out')
                .in('catalog_item_id', accessoryIds)
                .or(`organization_id.eq.${organizationId},organization_id.is.null`);

              // Crear mapa de MSRP
              const msrpMap = new Map<string, number>();
              msrpData?.forEach((msrp: { catalog_item_id: string; msrp_sale_out: number | null }) => {
                if (msrp.catalog_item_id && msrp.msrp_sale_out != null) {
                  msrpMap.set(msrp.catalog_item_id, Number(msrp.msrp_sale_out));
                }
              });

              // Insertar líneas de accesorios en BOMInstanceLines
              const bomLines = accessories.map((accessory: { catalog_item_id: string; qty?: number }) => {
                const catalogItem = catalogItems?.find((ci: { id: string }) => ci.id === accessory.catalog_item_id);
                if (!catalogItem) return null;

                return {
                  organization_id: organizationId,
                  bom_instance_id: bomInstanceId,
                  resolved_part_id: accessory.catalog_item_id,
                  part_role: 'accessory',
                  qty: accessory.qty || 1,
                  uom: catalogItem.unit_of_measure || 'each',
                  unit_cost_exw: catalogItem.cost_exw || 0,
                  deleted: false,
                };
              }).filter(Boolean);

              if (bomLines.length > 0) {
                const { error: insertError } = await supabase
                  .from('BOMInstanceLines')
                  .insert(bomLines);

                if (insertError) {
                  console.error('[createQuoteLineFromRollerConfig] Error adding accessories to BOM:', insertError);
                } else {
                  console.log(`[createQuoteLineFromRollerConfig] Added ${bomLines.length} accessory lines to BOM`);
                }
              }
            }
          }
        } catch (accessoryError) {
          console.error('[createQuoteLineFromRollerConfig] Error adding accessories to BOM:', accessoryError);
          // Don't fail the whole operation
        }
      }
    }
  } catch (bomError) {
    console.error('[createQuoteLineFromRollerConfig] BOM generation failed:', bomError);
    // Don't fail the whole operation - BOM is supplementary
  }

  return {
    quoteLineId: finalLineId,
    bomInstanceId,
  };
}

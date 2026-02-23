/**
 * @deprecated DEPRECATED - Use commitConfiguredProductToQuoteLine instead
 * 
 * This file is kept for backward compatibility but should NOT be used.
 * The new flow uses:
 * - commit_configured_product_to_quote_line RPC
 * - ConfiguredProducts.bom_preview_snapshot as source of truth
 * - No BOMInstances are created
 * 
 * Original description:
 * Servicio para crear QuoteLine con snapshots completos desde ConfiguredProduct.
 * Implementa el flujo: ConfiguredProduct (vivo) -> QuoteLine (snapshot congelado)
 */

import { supabase } from '../supabase/client';
import { recalculateConfiguredProductTotals, getConfiguredProduct } from '../bom/createConfiguredProductPreview';
import { getBomInstanceLines } from '../bom/bomInstance';

export interface CreateQuoteLineFromConfiguredProductParams {
  organizationId: string;
  quoteId: string;
  configuredProductId: string;
  quantity?: number;
  discountPct?: number;
  bom_template_id?: string | null; // ✅ CRITICAL: bom_template_id para crear BOMInstance
  // Otros campos opcionales de QuoteLine
  [key: string]: any;
}

export interface CreateQuoteLineFromConfiguredProductResult {
  quoteLineId: string;
  rollCostSnapshot: number;
  bomCostSnapshot: number;
  rollMsrpSnapshot: number;
  bomMsrpSnapshot: number;
  msrp: number;
  totalCost: number;
  netPrice: number;
}

/**
 * @deprecated Los costos ahora se calculan en calculate_configured_product_totals
 * y se guardan en ConfiguredProducts.roll_total_cost y bom_total_cost
 * 
 * Esta función se mantiene por compatibilidad pero ya no se usa.
 */
async function calculateRollCost(
  organizationId: string,
  configuredProduct: any
): Promise<number> {
  // ✅ Usar roll_total_cost desde ConfiguredProducts si está disponible
  if (configuredProduct.roll_total_cost !== undefined) {
    return Number(configuredProduct.roll_total_cost) || 0;
  }
  
  // Fallback (no debería llegar aquí si calculate_configured_product_totals se ejecutó)
  return 0;
}

/**
 * @deprecated Los costos ahora se calculan en calculate_configured_product_totals
 * y se guardan en ConfiguredProducts.bom_total_cost
 * 
 * Esta función se mantiene por compatibilidad pero ya no se usa.
 */
async function calculateBomCost(
  organizationId: string,
  bomInstanceId: string | null
): Promise<number> {
  // ✅ Esta función ya no se usa, los costos vienen de ConfiguredProducts.bom_total_cost
  return 0;
}

/**
 * Create QuoteLine from ConfiguredProduct with snapshots
 * 
 * Flujo:
 * 1. Validar IDs
 * 2. Recalcular ConfiguredProducts (server-side)
 * 3. Leer ConfiguredProducts ya recalculado
 * 4. Calcular costos (roll_cost, bom_cost)
 * 5. Insertar QuoteLines con snapshots
 * 6. Opcional: actualizar ConfiguredProducts.quote_line_id
 */
export async function createQuoteLineFromConfiguredProduct(
  params: CreateQuoteLineFromConfiguredProductParams
): Promise<CreateQuoteLineFromConfiguredProductResult> {
  const {
    organizationId,
    quoteId,
    configuredProductId,
    quantity = 1,
    discountPct = 0,
    bom_template_id,
    ...otherFields
  } = params;
  
  // ✅ GUARDRAIL: Validar IDs requeridos
  if (!organizationId) {
    throw new Error('organizationId is required');
  }
  if (!quoteId) {
    throw new Error('quoteId is required');
  }
  if (!configuredProductId) {
    throw new Error('configuredProductId is required');
  }
  
  // ✅ DEBUG: Log parámetros críticos
  if (import.meta.env.DEV) {
    console.debug('[createQuoteLineFromConfiguredProduct] Starting', {
      quoteId,
      configuredProductId,
      bom_template_id,
      organizationId,
    });
  }

  // ✅ Validaciones ya se hicieron arriba

  // 2. ✅ FLUJO UNIFICADO: ConfiguredProduct es OPCIONAL (solo para preview/draft)
  // Si existe, usarlo para obtener datos iniciales; si no, crear QuoteLine directamente
  let configuredProduct: any = null;
  
  if (configuredProductId) {
    // Recalcular ConfiguredProducts (server-side) si existe
    // Esto actualiza roll_msrp_total, bom_total, roll_plus_bom_total, total_msrp
    await recalculateConfiguredProductTotals(configuredProductId);

    // Leer ConfiguredProducts ya recalculado
    configuredProduct = await getConfiguredProduct(configuredProductId);
    if (!configuredProduct) {
      console.warn(`[createQuoteLineFromConfiguredProduct] ConfiguredProduct ${configuredProductId} not found, continuing without it`);
    }
  }

  // 4. ✅ REMOVIDO: No buscar BOMInstance aquí porque aún no existe
  // El BOMInstance se creará DESPUÉS de crear QuoteLine (paso 10)
  // Esto asegura que siempre tenga quote_line_id (requerido por constraint)

  // 5. Obtener snapshots de MSRP y costos
  // ✅ Si ConfiguredProduct existe, usar sus valores calculados
  // ✅ Si no existe, usar valores iniciales (se actualizarán después de crear BOMInstance)
  const rollMsrpSnapshot = configuredProduct ? (Number(configuredProduct.roll_msrp_total) || 0) : 0;
  const bomMsrpSnapshot = configuredProduct ? (Number(configuredProduct.bom_total) || 0) : 0;
  const msrp = configuredProduct ? (Number(configuredProduct.unit_msrp_total ?? configuredProduct.total_msrp ?? configuredProduct.msrp_product_subtotal) || 0) : 0;
  
  // ✅ Usar costos reales desde ConfiguredProducts (si existe)
  const rollCostSnapshot = configuredProduct ? (Number(configuredProduct.roll_total_cost) || 0) : 0;
  const bomCostSnapshot = configuredProduct ? (Number(configuredProduct.bom_total_cost) || 0) : 0;
  const totalCost = rollCostSnapshot + bomCostSnapshot;
  
  // ✅ Obtener labor_pct si existe (para snapshot)
  // Nota: labor_amount no se guarda en QuoteLines, solo labor_pct
  const laborPctSnapshot = configuredProduct?.labor_pct ? Number(configuredProduct.labor_pct) : null;

  // 7. Calcular net_price (aplicar descuento)
  const netPrice = msrp * (1 - (discountPct / 100));

  // 8. Preparar datos para QuoteLine
  // ✅ Filtrar campos no válidos que puedan causar errores de schema cache (PGRST204)
  // Excluir 'metadata', 'fabricItemId' (no existe en QuoteLines), 'drop_m' (legacy; usar fabric_drop)
  const { metadata: _, fabricItemId: __, drop_m: ___dropM, ...filteredOtherFields } = otherFields;
  
  // ✅ Obtener medidas y otros datos desde ConfiguredProduct (si existe) o desde otherFields
  const productTypeId = configuredProduct?.product_type_id || (otherFields as any).product_type_id;
  const widthMm = configuredProduct?.width_mm || (otherFields as any).width_mm;
  const heightMm = configuredProduct?.height_mm || (otherFields as any).height_mm;
  
  const rollCatalogItemId =
    configuredProduct?.roll_catalog_item_id ||
    (otherFields as any).catalog_item_id ||
    (otherFields as any).fabricItemId ||
    null;

  const quoteLineData: any = {
    organization_id: organizationId,
    quote_id: quoteId,
    product_type: productTypeId ? 'configured' : null,
    quantity: quantity,
    width_m: widthMm ? Number(widthMm) / 1000 : null,
    height_m: heightMm ? Number(heightMm) / 1000 : null,
    discount_pct: discountPct,
    // Roll / fabric item (QuoteLines usa catalog_item_id)
    ...(rollCatalogItemId ? { catalog_item_id: rollCatalogItemId } : {}),
    // ✅ CRITICAL: Guardar bom_template_id en QuoteLines
    ...(bom_template_id ? { bom_template_id } : {}),
    // Snapshots iniciales (se actualizarán después de crear BOMInstance)
    roll_cost_snapshot: rollCostSnapshot,
    bom_cost_snapshot: bomCostSnapshot,
    roll_msrp_snapshot: rollMsrpSnapshot,
    bom_msrp_snapshot: bomMsrpSnapshot,
    // Labor snapshot (QuoteLines tiene labor_pct, pero no labor_amount)
    ...(laborPctSnapshot !== null && { labor_pct: laborPctSnapshot }),
    // Totales iniciales (se actualizarán después de crear BOMInstance)
    total_cost: totalCost,
    msrp: msrp, // ✅ Ya incluye labor (si ConfiguredProduct existe)
    net_price: netPrice,
    // Metadata fields (not the column)
    pricing_locked: false, // ✅ Se bloqueará después de actualizar con snapshots finales
    last_priced_at: new Date().toISOString(),
    pricing_version: 1,
    // Otros campos opcionales (filtrados)
    ...filteredOtherFields,
  };

  // 9. ✅ CRÍTICO: Insertar QuoteLine PRIMERO (obtener quote_line_id)
  // ✅ FLUJO UNIFICADO: QuoteLine → BOMInstance → Recalcular → Update QuoteLine
  const { data: newQuoteLine, error: insertError } = await supabase
    .from('QuoteLines')
    .insert(quoteLineData)
    .select('id')
    .single();

  if (insertError) {
    console.error('[createQuoteLineFromConfiguredProduct] ❌ Error creating QuoteLine:', insertError);
    throw new Error(`Failed to create QuoteLine: ${insertError.message || 'Unknown error'}`);
  }

  // ✅ GUARDRAIL CRÍTICO: Verificar que QuoteLine se insertó y retornó ID
  if (!newQuoteLine?.id) {
    const errorMsg = 'Failed to create QuoteLine: INSERT succeeded but no ID returned. This is a critical error.';
    console.error('[createQuoteLineFromConfiguredProduct] ❌', errorMsg, {
      quoteLineData,
      insertError,
      newQuoteLine,
    });
    throw new Error(errorMsg);
  }

  const quoteLineId = newQuoteLine.id;
  
  if (import.meta.env.DEV) {
    console.log('[createQuoteLineFromConfiguredProduct] ✅ QuoteLine created successfully:', {
      quoteLineId,
      quoteId,
      organizationId,
    });
  }
  
  // ✅ CRITICAL: Actualizar bom_template_id si no se guardó en el insert
  // (puede que no esté en el schema cache aún, así que lo actualizamos explícitamente)
  if (bom_template_id) {
    try {
      const { error: updateBomTemplateError } = await supabase
        .from('QuoteLines')
        .update({ bom_template_id })
        .eq('id', quoteLineId)
        .eq('organization_id', organizationId);
      
      if (updateBomTemplateError) {
        // Si falla, puede ser que la columna no exista o no tengamos permisos
        // No fallar el flujo completo, solo loguear
        if (import.meta.env.DEV) {
          console.warn('[createQuoteLineFromConfiguredProduct] Could not update bom_template_id:', updateBomTemplateError);
        }
      } else {
        if (import.meta.env.DEV) {
          console.debug('[createQuoteLineFromConfiguredProduct] ✅ bom_template_id updated in QuoteLine', {
            quoteLineId,
            bom_template_id,
          });
        }
      }
    } catch (updateErr) {
      // No fallar el flujo si no se puede actualizar bom_template_id
      if (import.meta.env.DEV) {
        console.warn('[createQuoteLineFromConfiguredProduct] Error updating bom_template_id (non-fatal):', updateErr);
      }
    }
  }

  // 10. ✅ CRÍTICO: Crear BOMInstance DESPUÉS de tener quote_line_id
  // ✅ FLUJO: QuoteLine (con bom_template_id) → BOMInstance (con quote_line_id NOT NULL) → Recalcular → Update QuoteLine
  // ✅ GUARDRAIL: Solo crear BOMInstance si tenemos bom_template_id
  let bomInstanceId: string | null = null;
  let finalPricing: {
    rollMsrp: number;
    bomMsrp: number;
    totalMsrp: number;
    rollCost: number;
    bomCost: number;
    totalCost: number;
  } | null = null;
  
  if (bom_template_id) {
    // ✅ GUARDRAIL: Mutex para evitar doble creación si operation_type cambia rápido
    const bomCreationKey = `bom_creation:${configuredProductId}:${quoteLineId}`;
    const existingCreation = (window as any)[bomCreationKey];
    
    if (existingCreation) {
      if (import.meta.env.DEV) {
        console.warn('[createQuoteLineFromConfiguredProduct] ⚠️ BOMInstance creation already in progress, waiting...');
      }
      try {
        await existingCreation;
      } catch (err) {
        // Continue with new creation attempt
      }
    }

    const bomCreationPromise = (async () => {
      try {
        if (import.meta.env.DEV) {
          console.debug('[createQuoteLineFromConfiguredProduct] Creating BOMInstance:', {
            quote_id: quoteId,
            quote_line_id: quoteLineId,
            configured_product_id: configuredProductId,
            bom_template_id,
            product_type_id: configuredProduct.product_type_id,
            organizationId,
          });
        }

        const { data: bomInstanceData, error: bomError } = await supabase.rpc(
          'create_bom_instance_for_configured_product',
          {
            p_org_id: organizationId,
            p_quote_line_id: quoteLineId,  // ✅ REQUERIDO - siempre NOT NULL
            p_configured_product_id: configuredProductId,
            p_product_type_id: configuredProduct.product_type_id || null,
          }
        );

        if (bomError) {
          console.error('[createQuoteLineFromConfiguredProduct] ❌ Error creating BOMInstance:', bomError);
          throw new Error(`Failed to create BOMInstance: ${bomError.message}`);
        }

        // ✅ GUARDRAIL: Verificar que BOMInstance se creó
        if (!bomInstanceData) {
          throw new Error('BOMInstance creation returned no data');
        }

        bomInstanceId = bomInstanceData || null;
        
        if (import.meta.env.DEV) {
          console.log('[createQuoteLineFromConfiguredProduct] ✅ BOMInstance created successfully:', {
            quote_line_id: quoteLineId,
            bom_instance_id: bomInstanceId,
            bom_template_id,
          });
        }
        
        // ✅ CRITICAL: Recalcular ConfiguredProduct totals DESPUÉS de crear BOMInstance
        // Esto asegura que bom_total incluya los componentes correctos (motor o drive según operation_type)
        await recalculateConfiguredProductTotals(configuredProductId);
        
        // Leer ConfiguredProduct actualizado con totales correctos (si existe)
        if (configuredProductId) {
          const updatedConfiguredProduct = await getConfiguredProduct(configuredProductId);
          if (updatedConfiguredProduct) {
            finalPricing = {
              rollMsrp: Number(updatedConfiguredProduct.roll_msrp_total) || 0,
              bomMsrp: Number(updatedConfiguredProduct.bom_total) || 0,
              totalMsrp: Number(updatedConfiguredProduct.total_msrp) || 0,
              rollCost: Number(updatedConfiguredProduct.roll_total_cost) || 0,
              bomCost: Number(updatedConfiguredProduct.bom_total_cost) || 0,
              totalCost: Number(updatedConfiguredProduct.roll_total_cost || 0) + Number(updatedConfiguredProduct.bom_total_cost || 0),
            };
          }
        } else {
          // Si no hay ConfiguredProduct, calcular desde BOMInstance directamente
          // (esto requeriría una query adicional, por ahora usar valores iniciales)
          if (import.meta.env.DEV) {
            console.warn('[createQuoteLineFromConfiguredProduct] No ConfiguredProduct, using initial pricing values');
          }
        }
        
        if (import.meta.env.DEV) {
          console.debug('[createQuoteLineFromConfiguredProduct] ✅ Recalculated ConfiguredProduct totals after BOMInstance creation', finalPricing);
        }
      } catch (bomErr: any) {
        console.error('[createQuoteLineFromConfiguredProduct] ❌ Exception creating BOMInstance:', bomErr);
        throw bomErr;
      }
    })();

    (window as any)[bomCreationKey] = bomCreationPromise;

    try {
      await bomCreationPromise;
    } catch (bomErr: any) {
      // ⚠️ No fallar el flujo completo si BOMInstance falla, pero registrar error claramente
      console.error('[createQuoteLineFromConfiguredProduct] ❌ BOMInstance creation failed, but QuoteLine was created:', bomErr);
      if (import.meta.env.DEV) {
        console.warn('[createQuoteLineFromConfiguredProduct] QuoteLine exists but BOMInstance creation failed. QuoteLine ID:', quoteLineId);
      }
    } finally {
      delete (window as any)[bomCreationKey];
    }
  } else {
    // ⚠️ Advertir si no hay bom_template_id
    if (import.meta.env.DEV) {
      console.warn('[createQuoteLineFromConfiguredProduct] ⚠️ No bom_template_id provided - BOMInstance will not be created', {
        quoteLineId,
        configuredProductId,
        organizationId,
      });
    }
  }

  // 11. ✅ ACTUALIZAR QuoteLine con snapshots finales (después de recalcular)
  // ✅ Solo actualizar si tenemos pricing final calculado
  if (finalPricing && quoteLineId) {
    try {
      const pricing = finalPricing as { rollMsrp: number; bomMsrp: number; totalMsrp: number; rollCost: number; bomCost: number; totalCost: number };
      const { error: updateError } = await supabase
        .from('QuoteLines')
        .update({
          roll_msrp_snapshot: pricing.rollMsrp,
          bom_msrp_snapshot: pricing.bomMsrp,
          msrp: pricing.totalMsrp,
          roll_cost_snapshot: pricing.rollCost,
          bom_cost_snapshot: pricing.bomCost,
          total_cost: pricing.totalCost,
          pricing_locked: true, // ✅ Bloquear pricing después de actualizar con snapshots finales
          last_priced_at: new Date().toISOString(),
        })
        .eq('id', quoteLineId)
        .eq('organization_id', organizationId);

      if (updateError) {
        console.warn('[createQuoteLineFromConfiguredProduct] ⚠️ Could not update QuoteLine with final pricing:', updateError);
      } else {
        if (import.meta.env.DEV) {
          console.log('[createQuoteLineFromConfiguredProduct] ✅ QuoteLine updated with final pricing snapshots', {
            quoteLineId,
            finalPricing,
          });
        }
      }
    } catch (updateErr) {
      console.warn('[createQuoteLineFromConfiguredProduct] ⚠️ Error updating QuoteLine with final pricing (non-fatal):', updateErr);
    }
  } else if (quoteLineId && !finalPricing) {
    // Si no hay pricing final pero sí QuoteLine, mantener valores iniciales
    if (import.meta.env.DEV) {
      console.log('[createQuoteLineFromConfiguredProduct] ℹ️ No final pricing calculated, QuoteLine created with initial values');
    }
  }

  // quote_line_id ya no existe en ConfiguredProducts; la relación es QuoteLines.configured_product_id -> ConfiguredProducts

  if (import.meta.env.DEV) {
    console.log('[createQuoteLineFromConfiguredProduct] Success:', {
      quoteLineId: newQuoteLine.id,
      bomInstanceId,
      rollCostSnapshot,
      bomCostSnapshot,
      rollMsrpSnapshot,
      bomMsrpSnapshot,
      msrp,
      totalCost,
      netPrice,
    });
  }

  return {
    quoteLineId: newQuoteLine.id,
    rollCostSnapshot,
    bomCostSnapshot,
    rollMsrpSnapshot,
    bomMsrpSnapshot,
    msrp,
    totalCost,
    netPrice,
  };
}

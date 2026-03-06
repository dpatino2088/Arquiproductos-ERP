/**
 * matchBOMTemplate.ts
 * 
 * Función de matching automático de BOM Templates.
 * Compara la configuración final del producto con los templates disponibles
 * y selecciona el template que coincida exactamente.
 * 
 * CRITERIOS DE MATCHING (Solo roles padres):
 * - product_type_id (obligatorio, exacto)
 * - hardware_color (obligatorio, exacto)
 * - bottom_bar_sku (obligatorio, exacto)
 * - headbox_sku (opcional, pero si existe filtra)
 * - side_channel_sku (opcional, pero si existe filtra)
 * - bottom_channel_sku (opcional, pero si existe filtra)
 * - operation_type (obligatorio, motor/manual)
 * - tube_sku (obligatorio, exacto)
 * 
 * NOTA: Los SKUs vienen de los propios templates, así que SIEMPRE debería
 * haber un match exacto. Si no hay match, se muestra un WARNING.
 */

import { supabase } from '../supabase/client';
import { normalizeSku } from './normalize';

/** Normaliza SKU para comparación: case-insensitive, trimmed
 * NO quita guiones ni espacios ya que los datos vienen de la misma fuente (DB)
 */
function normalizeSkuForMatch(sku: string | null | undefined): string {
  if (!sku) return '';
  return sku.trim().toLowerCase();
}

// ===== INTERFACES =====

export interface MatchConfig {
  organization_id: string;
  product_type_id: string;
  /** Número de paños (1-3). Filtro aplicado ANTES de color. Default 1. */
  panel_count?: number | null;
  hardware_color?: string | null;
  bottom_bar_sku?: string | null;
  tube_sku?: string | null;
  operation_type?: 'motor' | 'manual' | null;
  headbox_sku?: string | null;
  side_channel_sku?: string | null;
  bottom_channel_sku?: string | null;
  motor_sku?: string | null;
  drive_sku?: string | null;
  manufacturer?: string | null;
  drive_side?: 'left' | 'right' | null;
  installation_location?: 'ceiling' | 'wall' | null;
  preFilteredTemplateIds?: string[] | null;
}

export interface MatchResult {
  template_id: string | null;
  template_name: string | null;
  matched: boolean;
  warning?: string;
  matchScore?: number;
  debug?: {
    candidatesCount: number;
    matchedCriteria: string[];
    unmatchedCriteria: string[];
  };
}

// ===== HELPER FUNCTIONS =====

function normalizeColor(color: string | null | undefined): string | null {
  if (!color) return null;
  const trimmed = color.trim();
  return trimmed.charAt(0).toUpperCase() + trimmed.slice(1).toLowerCase();
}

function safeErr(e: any): Record<string, any> {
  return {
    message: e?.message,
    code: e?.code,
    details: e?.details,
    hint: e?.hint,
  };
}

// ===== MAIN FUNCTION =====

/**
 * Busca y retorna el BOM Template que coincida exactamente con la configuración.
 * 
 * @param config - Configuración completa del producto
 * @returns MatchResult con el template_id si hay match, o warning si no
 */
export async function matchBOMTemplate(config: MatchConfig): Promise<MatchResult> {
  const {
    organization_id,
    product_type_id,
    panel_count: configPanelCount,
    hardware_color,
    bottom_bar_sku,
    tube_sku,
    operation_type,
    headbox_sku,
    side_channel_sku,
    bottom_channel_sku,
    motor_sku,
    drive_sku,
    manufacturer: configManufacturer,
    drive_side: configDriveSide,
    installation_location: configInstallLocation,
    preFilteredTemplateIds,
  } = config;
  const panel_count = Math.min(3, Math.max(1, configPanelCount ?? 1));

  const uniquePreFiltered = preFilteredTemplateIds
    ? Array.from(new Set(preFilteredTemplateIds.filter(Boolean)))
    : null;

  // ✅ Si hay templates pre-filtrados y solo queda 1, usarlo directamente.
  // Si quedan >1, NO escoger “a dedo”: seguimos con matching exacto.
  if (uniquePreFiltered && uniquePreFiltered.length === 1) {
    const templateId = uniquePreFiltered[0];

    const { data: templateInfo } = await supabase
      .from('BOMTemplates')
      .select('id, name, code')
      .eq('id', templateId)
      .single();

    if (import.meta.env.DEV) {
      console.log('[matchBOMTemplate] ✅ Using pre-filtered template (only 1 remaining):', {
        templateId,
        templateName: templateInfo?.name || templateInfo?.code,
      });
    }

    return {
      template_id: templateId,
      template_name: templateInfo?.name || templateInfo?.code || null,
      matched: true,
      matchScore: 100,
      debug: {
        candidatesCount: 1,
        matchedCriteria: ['pre-filtered-to-single-template'],
        unmatchedCriteria: [],
      },
    };
  }

  // Validar campos mínimos obligatorios
  if (!organization_id || !product_type_id) {
    return {
      template_id: null,
      template_name: null,
      matched: false,
      warning: 'Missing required fields: organization_id and product_type_id are required',
      debug: {
        candidatesCount: 0,
        matchedCriteria: [],
        unmatchedCriteria: ['Missing organization_id or product_type_id'],
      },
    };
  }

  // ✅ Si hay templates pre-filtrados pero más de 1, usarlos como base
  const hasPreFiltered = uniquePreFiltered && uniquePreFiltered.length > 0;

  const normalizedColor = hardware_color ? normalizeColor(hardware_color) : null;
  const normalizedBottomBarSku = normalizeSku(bottom_bar_sku);
  const normalizedTubeSku = normalizeSku(tube_sku);
  const normalizedHeadboxSku = headbox_sku ? normalizeSku(headbox_sku) : null;
  const normalizedSideChannelSku = side_channel_sku ? normalizeSku(side_channel_sku) : null;
  const normalizedBottomChannelSku = bottom_channel_sku ? normalizeSku(bottom_channel_sku) : null;
  const normalizedMotorSku = motor_sku ? normalizeSku(motor_sku) : null;
  const normalizedDriveSku = drive_sku ? normalizeSku(drive_sku) : null;

  if (import.meta.env.DEV) {
    console.log('[matchBOMTemplate] Starting match with config:', {
      organization_id,
      product_type_id,
      hardware_color: normalizedColor ?? '(not set)',
      bottom_bar_sku: normalizedBottomBarSku,
      tube_sku: normalizedTubeSku,
      operation_type,
      motor_sku: normalizedMotorSku ?? '(not set)',
      drive_sku: normalizedDriveSku ?? '(not set)',
      headbox_sku: normalizedHeadboxSku,
      side_channel_sku: normalizedSideChannelSku,
      bottom_channel_sku: normalizedBottomChannelSku,
      preFilteredTemplateIds: uniquePreFiltered?.length ?? 0,
    });
  }

  try {
    // PASO 1: Obtener templates base
    // Si hay templates pre-filtrados, usarlos; sino, buscar por product_type y color
    type TemplateMeta = {
      id: string; name: string | null; code: string; product_type_id: string;
      hardware_color: string | null; manufacturer: string | null; drive_type: string | null;
      drive_side: string | null; installation_location: string | null;
    };
    let templates: TemplateMeta[] = [];

    if (hasPreFiltered) {
      const { data: preFilteredTemplates, error: preFilteredError } = await supabase
        .from('BOMTemplates')
        .select('id, name, code, product_type_id, hardware_color, manufacturer, drive_type, drive_side, installation_location')
        .in('id', uniquePreFiltered!)
        .eq('is_active', true)
        .eq('archived', false)
        .eq('deleted', false);

      if (preFilteredError) {
        console.error('[matchBOMTemplate] Error fetching pre-filtered templates:', safeErr(preFilteredError));
      } else {
        templates = preFilteredTemplates || [];
      }

      if (import.meta.env.DEV) {
        console.log('[matchBOMTemplate] Using pre-filtered templates:', templates.length);
      }
    }

    if (templates.length === 0) {
      let templatesQuery = supabase
        .from('BOMTemplates')
        .select('id, name, code, product_type_id, hardware_color, manufacturer, drive_type, drive_side, installation_location')
        .eq('organization_id', organization_id)
        .eq('product_type_id', product_type_id)
        .eq('is_active', true)
        .eq('archived', false)
        .eq('deleted', false)
        .lte('panel_count_min', panel_count)
        .gte('panel_count_max', panel_count);

      const { data: templatesRaw, error: templatesError } = await templatesQuery;

      if (templatesError) {
        console.error('[matchBOMTemplate] Error fetching templates:', safeErr(templatesError));
        return {
          template_id: null,
          template_name: null,
          matched: false,
          warning: `Error fetching templates: ${templatesError.message}`,
        };
      }

      if (!templatesRaw || templatesRaw.length === 0) {
        console.warn('[matchBOMTemplate] No templates found for product_type', product_type_id, normalizedColor ? `and hardware_color=${normalizedColor}` : '(color not filtered)');
        return {
          template_id: null,
          template_name: null,
          matched: false,
          warning: `No templates found for product_type_id=${product_type_id}` + (normalizedColor ? ` and hardware_color=${normalizedColor}` : ''),
          debug: {
            candidatesCount: 0,
            matchedCriteria: [],
            unmatchedCriteria: ['No base templates found'],
          },
        };
      }

      // If hardware_color was provided, prefer exact match (case-insensitive), else keep all.
      if (normalizedColor) {
        const exact = templatesRaw.filter((t: any) => normalizeColor((t as any).hardware_color) === normalizedColor);
        templates = exact.length > 0 ? exact : templatesRaw;
      } else {
        templates = templatesRaw;
      }
    }

    if (import.meta.env.DEV) {
      console.log('[matchBOMTemplate] Base templates found:', templates.length);
    }

    // PASO 2: Obtener slots (BOMTemplateSlots) de estos templates
    // IMPORTANT: En schema v7, el matching se basa en BOMTemplateSlots (no BOMComponents).
    const templateIds = templates.map(t => t.id);
    
    const { data: allSlots, error: slotsError } = await supabase
      .from('BOMTemplateSlots')
      .select('bom_template_id, item_role, catalog_item_id')
      .eq('organization_id', organization_id)
      .in('bom_template_id', templateIds)
      .eq('deleted', false)
      .eq('archived', false);

    if (slotsError) {
      console.error('[matchBOMTemplate] Error fetching template slots:', safeErr(slotsError));
      return {
        template_id: null,
        template_name: null,
        matched: false,
        warning: `Error fetching template slots: ${slotsError.message}`,
      };
    }

    // PASO 3: Obtener SKUs de CatalogItems para los slots
    const catalogItemIds = [...new Set(
      (allSlots || []).map((s: { catalog_item_id?: string }) => s.catalog_item_id).filter(Boolean)
    )] as string[];

    let catalogSkuMap = new Map<string, string>();
    if (catalogItemIds.length > 0) {
      const { data: catalogItems } = await supabase
        .from('CatalogItems')
        .select('id, sku')
        .eq('organization_id', organization_id)
        .eq('is_active', true)
        .in('id', catalogItemIds);

      catalogItems?.forEach((item: { id: string; sku: string }) => {
        if (item.sku) {
          catalogSkuMap.set(item.id, normalizeSku(item.sku) || '');
        }
      });
    }

    // PASO 4: Agrupar slots por template
    const componentsByTemplate = new Map<string, Array<{
      role: string;
      sku: string | null;
    }>>();

    (allSlots || []).forEach((slot: { bom_template_id: string; item_role?: string; catalog_item_id?: string }) => {
      const templateId = slot.bom_template_id;
      const role = (slot.item_role || '').toLowerCase().trim();
      const sku = slot.catalog_item_id ? catalogSkuMap.get(slot.catalog_item_id) || null : null;

      if (!componentsByTemplate.has(templateId)) {
        componentsByTemplate.set(templateId, []);
      }
      componentsByTemplate.get(templateId)!.push({ role, sku });
    });

    // Alias for compatibility with existing code
    const slotsByTemplate = componentsByTemplate;

    // PASO 5: Evaluar cada template
    type TemplateScore = {
      id: string;
      name: string;
      score: number;
      matchedCriteria: string[];
      unmatchedCriteria: string[];
    };

    const templateScores: TemplateScore[] = [];

    for (const template of templates) {
      const slots = slotsByTemplate.get(template.id) || [];
      const matchedCriteria: string[] = [];
      const unmatchedCriteria: string[] = [];
      let score = 0;

      // Helpers: comparar por rol exacto (dump usa item_role exacto)
      const roleMatches = (slotRole: string, targetRole: string) => slotRole === targetRole;

      const hasSkuForRole = (targetRole: string, expectedSku: string) => {
        const b = normalizeSkuForMatch(expectedSku);
        if (!b) return false;
        return slots.some((s) => {
          if (!roleMatches(s.role, targetRole)) return false;
          const a = normalizeSkuForMatch(s.sku);
          return a.length > 0 && a === b;
        });
      };

      const hasAnySlotRole = (targetRole: string): boolean => {
        return slots.some((s) => roleMatches(s.role, targetRole));
      };

      // Criterio 1: bottom_bar (obligatorio)
      const bottomBarSku = normalizedBottomBarSku ?? '';
      if (hasSkuForRole('bottom_bar', bottomBarSku)) {
        score++;
        matchedCriteria.push(`bottom_bar:${bottomBarSku}`);
      } else {
        unmatchedCriteria.push(`bottom_bar expected:${bottomBarSku}`);
      }

      // Criterio 2: tube (obligatorio)
      const tubeSku = normalizedTubeSku ?? '';
      if (hasSkuForRole('tube', tubeSku)) {
        score++;
        matchedCriteria.push(`tube:${tubeSku}`);
      } else {
        unmatchedCriteria.push(`tube expected:${tubeSku}`);
      }

      // Criterio 3: operation_type (obligatorio)
      const hasMotor = hasAnySlotRole('motor');
      const hasDrive = hasAnySlotRole('drive');
      
      if (operation_type === 'motor') {
        // In DB matcher, exclusivity is evaluated against the selected opposite SKU.
        // If drive_sku is not provided, do not reject templates just for having a 'drive' slot.
        const hasConflictingDriveSku = normalizedDriveSku ? hasSkuForRole('drive', normalizedDriveSku) : false;

        if (hasMotor && !hasConflictingDriveSku) {
          score += 10; // ✅ AUMENTADO: Dar MUCHO peso a operation_type correcto
          matchedCriteria.push('operation_type:motor');
          
          // Verificar motor_sku si está definido
          if (normalizedMotorSku) {
            if (hasSkuForRole('motor', normalizedMotorSku)) {
              score += 10; // ✅ AUMENTADO: Dar MUCHO peso al SKU exacto de motor
              matchedCriteria.push(`motor_sku:${normalizedMotorSku}`);
            } else {
              unmatchedCriteria.push(`motor_sku expected:${normalizedMotorSku}`);
              score -= 20; // ✅ AUMENTADO: Penalizar fuertemente si no coincide el motor_sku
            }
          }
        } else {
          unmatchedCriteria.push(`operation_type expected:motor hasMotor:${hasMotor} conflictingDriveSku:${hasConflictingDriveSku}`);
          if (hasConflictingDriveSku) score -= 50;
        }
      } else if (operation_type === 'manual') {
        const hasConflictingMotorSku = normalizedMotorSku ? hasSkuForRole('motor', normalizedMotorSku) : false;

        if (hasDrive && !hasConflictingMotorSku) {
          score += 10; // ✅ AUMENTADO: Dar MUCHO peso a operation_type correcto
          matchedCriteria.push('operation_type:manual');
          
          // Verificar drive_sku si está definido
          if (normalizedDriveSku) {
            if (hasSkuForRole('drive', normalizedDriveSku)) {
              score += 10; // ✅ AUMENTADO: Dar MUCHO peso al SKU exacto de drive
              matchedCriteria.push(`drive_sku:${normalizedDriveSku}`);
            } else {
              unmatchedCriteria.push(`drive_sku expected:${normalizedDriveSku}`);
              score -= 20; // ✅ AUMENTADO: Penalizar fuertemente si no coincide el drive_sku
            }
          }
        } else {
          unmatchedCriteria.push(`operation_type expected:manual hasDrive:${hasDrive} conflictingMotorSku:${hasConflictingMotorSku}`);
          if (hasConflictingMotorSku) score -= 50;
        }
      }

      // Criterio 4: headbox (opcional pero filtra si existe)
      if (normalizedHeadboxSku) {
        if (hasSkuForRole('headbox', normalizedHeadboxSku)) {
          score++;
          matchedCriteria.push(`headbox:${normalizedHeadboxSku}`);
        } else {
          unmatchedCriteria.push(`headbox expected:${normalizedHeadboxSku}`);
        }
      }

      // Criterio 5: side_channel (opcional pero filtra si existe)
      if (normalizedSideChannelSku) {
        if (hasSkuForRole('side_channel', normalizedSideChannelSku)) {
          score++;
          matchedCriteria.push(`side_channel:${normalizedSideChannelSku}`);
        } else {
          unmatchedCriteria.push(`side_channel expected:${normalizedSideChannelSku}`);
        }
      }

      // Criterio 6: bottom_channel (opcional pero filtra si existe)
      if (normalizedBottomChannelSku) {
        if (hasSkuForRole('bottom_channel', normalizedBottomChannelSku)) {
          score++;
          matchedCriteria.push(`bottom_channel:${normalizedBottomChannelSku}`);
        } else {
          unmatchedCriteria.push(`bottom_channel expected:${normalizedBottomChannelSku}`);
        }
      }

      // Criterio 7: manufacturer (template-level, strong filter)
      if (configManufacturer && template.manufacturer) {
        if (template.manufacturer.toLowerCase() === configManufacturer.toLowerCase()) {
          score += 5;
          matchedCriteria.push(`manufacturer:${configManufacturer}`);
        } else {
          score -= 20;
          unmatchedCriteria.push(`manufacturer expected:${configManufacturer} got:${template.manufacturer}`);
        }
      }

      // Criterio 8: drive_side (template-level, null means both)
      if (configDriveSide && template.drive_side) {
        if (template.drive_side === configDriveSide) {
          score += 3;
          matchedCriteria.push(`drive_side:${configDriveSide}`);
        } else {
          score -= 15;
          unmatchedCriteria.push(`drive_side expected:${configDriveSide} got:${template.drive_side}`);
        }
      } else if (configDriveSide && !template.drive_side) {
        score += 1;
        matchedCriteria.push(`drive_side:any(template=null)`);
      }

      // Criterio 9: installation_location (template-level, null means both)
      if (configInstallLocation && template.installation_location) {
        if (template.installation_location === configInstallLocation) {
          score += 5;
          matchedCriteria.push(`installation_location:${configInstallLocation}`);
        } else {
          score -= 20;
          unmatchedCriteria.push(`installation_location expected:${configInstallLocation} got:${template.installation_location}`);
        }
      } else if (configInstallLocation && !template.installation_location) {
        score += 1;
        matchedCriteria.push(`installation_location:any(template=null)`);
      }

      templateScores.push({
        id: template.id,
        name: template.name || template.code,
        score,
        matchedCriteria,
        unmatchedCriteria,
      });
    }

    // PASO 6: Ordenar por score y seleccionar el mejor
    // Si hay empate, usar el ID del template como tiebreaker (orden lexicográfico)
    templateScores.sort((a, b) => {
      if (b.score !== a.score) return b.score - a.score;
      return a.id.localeCompare(b.id); // Tiebreaker: ID lexicográfico
    });

    if (import.meta.env.DEV) {
      console.log('[matchBOMTemplate] Template scores (sorted):', templateScores.map(t => ({
        id: t.id,
        name: t.name,
        score: t.score,
        matched: t.matchedCriteria,
        unmatched: t.unmatchedCriteria
      })));
    }

    let maxExpectedScore = 1 + 1 + 10; // bottom_bar + tube + operation_type
    if (normalizedHeadboxSku) maxExpectedScore++;
    if (normalizedSideChannelSku) maxExpectedScore++;
    if (normalizedBottomChannelSku) maxExpectedScore++;
    if (normalizedMotorSku || normalizedDriveSku) maxExpectedScore += 10;
    if (configManufacturer) maxExpectedScore += 5;
    if (configDriveSide) maxExpectedScore += 3;
    if (configInstallLocation) maxExpectedScore += 5;

    const bestMatch = templateScores[0];
    
    // ✅ Detectar empates y advertir
    const tiedScores = templateScores.filter(t => t.score === bestMatch.score);
    if (tiedScores.length > 1 && import.meta.env.DEV) {
      console.warn(`[matchBOMTemplate] ⚠️ TIE: ${tiedScores.length} templates with score ${bestMatch.score}:`, 
        tiedScores.map(t => ({ id: t.id, name: t.name }))
      );
    }

    if (!bestMatch || bestMatch.score === 0) {
      console.warn('[matchBOMTemplate] ⚠️ WARNING: No exact template match found!');
      return {
        template_id: null,
        template_name: null,
        matched: false,
        warning: 'No template matches the configuration. This should not happen since SKUs come from templates.',
        matchScore: 0,
        debug: {
          candidatesCount: templates.length,
          matchedCriteria: [],
          unmatchedCriteria: ['No matching template found'],
        },
      };
    }

    // Verificar si es match exacto
    const isExactMatch = bestMatch.unmatchedCriteria.length === 0;

    if (!isExactMatch) {
      console.warn('[matchBOMTemplate] ⚠️ WARNING: No exact match found, using closest match:', {
        templateId: bestMatch.id,
        templateName: bestMatch.name,
        score: bestMatch.score,
        maxExpected: maxExpectedScore,
        matched: bestMatch.matchedCriteria,
        unmatched: bestMatch.unmatchedCriteria,
      });
    } else {
      if (import.meta.env.DEV) {
        console.log('[matchBOMTemplate] ✅ Exact match found:', {
          templateId: bestMatch.id,
          templateName: bestMatch.name,
          score: bestMatch.score,
        });
      }
    }

    return {
      template_id: bestMatch.id,
      template_name: bestMatch.name,
      matched: isExactMatch,
      warning: isExactMatch ? undefined : `Closest match used (score: ${bestMatch.score}/${maxExpectedScore}). Unmatched: ${bestMatch.unmatchedCriteria.join(', ')}`,
      matchScore: bestMatch.score,
      debug: {
        candidatesCount: templates.length,
        matchedCriteria: bestMatch.matchedCriteria,
        unmatchedCriteria: bestMatch.unmatchedCriteria,
      },
    };

  } catch (error: any) {
    console.error('[matchBOMTemplate] Unexpected error:', safeErr(error));
    return {
      template_id: null,
      template_name: null,
      matched: false,
      warning: `Unexpected error: ${error?.message || 'Unknown error'}`,
    };
  }
}

/**
 * Versión síncrona para uso en validación (solo valida estructura, no hace query)
 */
export function validateMatchConfig(config: Partial<MatchConfig>): { valid: boolean; missing: string[] } {
  const required: (keyof MatchConfig)[] = [
    'organization_id',
    'product_type_id',
    'bottom_bar_sku',
    'tube_sku',
    'operation_type',
  ];

  const missing = required.filter(field => !config[field]);

  return {
    valid: missing.length === 0,
    missing,
  };
}

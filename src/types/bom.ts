/**
 * BOM Types
 * 
 * Tipos TypeScript para BOMInstances y BOMInstanceLines.
 * Modelo A: BOMInstances SIEMPRE se crea desde QuoteLine (quote_line_id es NOT NULL).
 */

export interface BOMInstance {
  id: string;
  organization_id: string;
  quote_line_id: string; // NOT NULL - siempre requerido
  bom_template_id: string; // NOT NULL
  configured_product_id?: string | null; // Opcional, nunca requerido
  deleted: boolean;
  created_at: string;
  updated_at: string;
}

export interface BOMInstanceLine {
  id: string;
  organization_id: string;
  bom_instance_id: string; // FK a BOMInstances
  bom_component_id?: string | null;
  resolved_part_id?: string | null; // FK a CatalogItems, puede ser NULL
  part_role: string; // NOT NULL
  qty: number; // NOT NULL
  uom: string; // NOT NULL
  cut_length_mm?: number | null;
  cut_width_mm?: number | null;
  cut_height_mm?: number | null;
  unit_cost_exw?: number | null;
  total_cost_exw?: number | null;
  deleted: boolean;
  created_at: string;
  // NOTA: Las siguientes columnas NO existen en el schema real:
  // - category_code (se obtiene de CatalogItems)
  // - resolved_sku (se obtiene de CatalogItems)
  // - unit_msrp (se obtiene de CatalogItemsMSRP)
  // - total_msrp (se calcula)
  // - description (se obtiene de CatalogItems)
  // - calc_notes (no existe)
}

/**
 * Parámetros para getOrCreateBomInstanceForQuoteLine
 */
export interface GetOrCreateBomInstanceParams {
  organizationId: string;
  quoteLineId: string;
  bomTemplateId?: string | null; // Opcional
}

/**
 * Parámetros para upsertBomLine
 */
export interface UpsertBomLineParams {
  bomInstanceId: string;
  organizationId: string;
  line: {
    id?: string;
    part_role: string;
    resolved_part_id?: string | null;
    bom_component_id?: string | null;
    qty: number;
    uom: string;
    cut_length_mm?: number | null;
    cut_width_mm?: number | null;
    cut_height_mm?: number | null;
    unit_cost_exw?: number | null;
    total_cost_exw?: number | null;
  };
}

/**
 * Parámetros para upsertBomLines (múltiples líneas)
 */
export interface UpsertBomLinesParams {
  bomInstanceId: string;
  organizationId: string;
  lines: Array<{
    id?: string;
    part_role: string;
    resolved_part_id?: string | null;
    bom_component_id?: string | null;
    qty: number;
    uom: string;
    cut_length_mm?: number | null;
    cut_width_mm?: number | null;
    cut_height_mm?: number | null;
    unit_cost_exw?: number | null;
    total_cost_exw?: number | null;
  }>;
}

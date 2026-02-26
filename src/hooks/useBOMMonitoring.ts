import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';

export interface BOMHealthStatus {
  orphan_assembly_children: number;
  duplicate_items: number;
  missing_qty_uom: number;
  missing_parent: number;
  total_issues: number;
  is_healthy: boolean;
}

export interface BOMInstanceDataLine {
  bom_line_id: string;
  catalog_item_id: string;
  resolved_sku: string | null;
  part_role: string | null;
  qty: number;
  uom: string;
  category_code: string | null;
  source: string;
  parent_part_id: string | null;
  unit_cost_exw: number;
  total_cost_exw: number;
  unit_msrp: number;
  total_msrp: number;
}

export interface BOMInstanceData {
  bom_instance_id: string;
  organization_id: string;
  sales_order_id: string | null;
  bom_template_id: string | null;
  bom_created_at: string;
  labor_cost: number;
  total_cost_with_labor: number;
  total_msrp_with_labor: number;
  // Lines data
  lines: BOMInstanceDataLine[];
  // Summary stats
  total_lines: number;
  unique_items: number;
  bom_component_lines: number;
  quote_line_component_lines: number;
  assembly_child_lines: number;
  total_qty: number;
  total_cost_exw: number;
  total_msrp: number;
}

export interface UseBOMMonitoringResult {
  bomInstance: BOMInstanceData | null;
  healthStatus: BOMHealthStatus | null;
  loading: boolean;
  error: string | null;
  refetch: () => Promise<void>;
}

/**
 * Hook to monitor BOM health for a specific BOM Instance
 * Reads exclusively from vw_bom_instance_flat
 * Uses bom_instance_id as pivot (obtained from saleOrderId)
 */
export function useBOMMonitoring(saleOrderId?: string | null): UseBOMMonitoringResult {
  const { activeOrganizationId } = useOrganizationContext();
  const [bomInstance, setBomInstance] = useState<BOMInstanceData | null>(null);
  const [healthStatus, setHealthStatus] = useState<BOMHealthStatus | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchMonitoringData = async () => {
    if (!activeOrganizationId || !saleOrderId) {
      setBomInstance(null);
      setHealthStatus(null);
      setLoading(false);
      return;
    }

    try {
      setLoading(true);
      setError(null);

      // Step 1: Get the latest BomInstance for this SaleOrder
      // Following the same pattern as useManufacturingMaterials
      const { data: saleOrderLines, error: solError } = await supabase
        .from('SaleOrderLines')
        .select('id')
        .eq('sales_order_id', saleOrderId)
        .eq('organization_id', activeOrganizationId)
        .eq('deleted', false);

      if (solError) throw solError;
      if (!saleOrderLines || saleOrderLines.length === 0) {
        setBomInstance(null);
        setHealthStatus(null);
        setLoading(false);
        return;
      }

      const saleOrderLineIds = saleOrderLines.map((sol: { id: string }) => sol.id);

      // Get ALL BOMInstances for these SaleOrderLines (not just one)
      // Following the same pattern as useManufacturingMaterials
      // ✅ FIX: Order by generated_at DESC, then created_at DESC to get the most recent BOM
      const { data: bomInstances, error: bomError } = await supabase
        .from('vw_bom_instances_safe')
        .select('id, organization_id, sales_order_line_id_safe, labor_cost, total_cost_with_labor, total_msrp_with_labor, created_at, generated_at, bom_template_id')
        .in('sales_order_line_id_safe', saleOrderLineIds)
        .eq('organization_id', activeOrganizationId)
        .eq('deleted', false)
        .order('generated_at', { ascending: false, nullsFirst: false })
        .order('created_at', { ascending: false }); // Fallback to created_at if generated_at is null

      if (bomError) throw bomError;
      if (!bomInstances || bomInstances.length === 0) {
        setBomInstance(null);
        setHealthStatus(null);
        setLoading(false);
        return;
      }

      // ✅ FIX: Filter to only the most recent BOMInstance per SaleOrderLine
      // Since SQL already orders DESC, we just take the first match per sales_order_line_id
      const bomInstancesByLine = new Map<string, typeof bomInstances[0]>();

      for (const bi of bomInstances) {
        if (bi.sales_order_line_id_safe) {
          // If not already in map, add it (it's the most recent for this line since SQL is sorted DESC)
          if (!bomInstancesByLine.has(bi.sales_order_line_id_safe)) {
            bomInstancesByLine.set(bi.sales_order_line_id_safe, bi);
          }
        } else {
          // If no sales_order_line_id_safe, include it anyway (shouldn't happen)
          bomInstancesByLine.set(bi.id, bi);
        }
      }

      const uniqueBomInstances = Array.from(bomInstancesByLine.values());

      // ✅ FIX: Get the MOST RECENT BOMInstance from all unique instances
      // Use generated_at ?? created_at for comparison
      const mostRecentBomInstance = uniqueBomInstances.sort((a, b) => {
        const dateA = new Date(a.generated_at || a.created_at || 0).getTime();
        const dateB = new Date(b.generated_at || b.created_at || 0).getTime();
        return dateB - dateA; // DESC
      })[0];

      if (!mostRecentBomInstance) {
        setBomInstance(null);
        setHealthStatus(null);
        setLoading(false);
        return;
      }

      const bomInstanceId = mostRecentBomInstance.id;

      // Step 2: Read ALL data from vw_bom_instance_flat for this bom_instance_id
      const { data: bomLines, error: linesError } = await supabase
        .from('vw_bom_instance_flat')
        .select('*')
        .eq('bom_instance_id', bomInstanceId)
        .order('part_role', { ascending: true });

      if (linesError) throw linesError;

      // Step 3: Build BOM Instance Data
      type FlatRow = { bom_line_id: string; catalog_item_id: string; resolved_sku: string | null; part_role: string | null; qty: number; uom: string; category_code: string | null; source: string; parent_part_id: string | null; unit_cost_exw: number; total_cost_exw: number; unit_msrp: number; total_msrp: number; sales_order_id?: string | null };
      const lines: BOMInstanceDataLine[] = (bomLines || []).map((line: FlatRow) => ({
        bom_line_id: line.bom_line_id,
        catalog_item_id: line.catalog_item_id,
        resolved_sku: line.resolved_sku,
        part_role: line.part_role,
        qty: Number(line.qty) || 0,
        uom: line.uom || '',
        category_code: line.category_code,
        source: line.source || 'bom_component',
        parent_part_id: line.parent_part_id,
        unit_cost_exw: Number(line.unit_cost_exw) || 0,
        total_cost_exw: Number(line.total_cost_exw) || 0,
        unit_msrp: Number(line.unit_msrp) || 0,
        total_msrp: Number(line.total_msrp) || 0,
      }));

      // Calculate summary stats from lines
      const uniqueItems = new Set(lines.map((l: BOMInstanceDataLine) => l.catalog_item_id)).size;
      const bomComponentLines = lines.filter((l: BOMInstanceDataLine) => l.source === 'bom_component').length;
      const quoteLineComponentLines = lines.filter((l: BOMInstanceDataLine) => l.source === 'quote_line_component').length;
      const assemblyChildLines = lines.filter((l: BOMInstanceDataLine) => l.source === 'assembly_child').length;
      const totalQty = lines.reduce((sum: number, l: BOMInstanceDataLine) => sum + l.qty, 0);
      const totalCostExw = lines.reduce((sum: number, l: BOMInstanceDataLine) => sum + l.total_cost_exw, 0);
      const totalMsrpSaleOut = lines.reduce((sum: number, l: BOMInstanceDataLine) => sum + l.total_msrp, 0);

      if (!bomInstances || bomInstances.length === 0) {
        throw new Error('No BOM instances found');
      }

      const firstBomInstance = bomInstances[0]!;

      const bomInstanceData: BOMInstanceData = {
        bom_instance_id: bomInstanceId,
        organization_id: firstBomInstance.organization_id,
        sales_order_id: bomLines && bomLines.length > 0 ? bomLines[0]?.sales_order_id ?? null : null,
        bom_template_id: firstBomInstance.bom_template_id,
        bom_created_at: firstBomInstance.created_at,
        labor_cost: Number(firstBomInstance.labor_cost) || 0,
        total_cost_with_labor: Number(firstBomInstance.total_cost_with_labor) || 0,
        total_msrp_with_labor: Number(firstBomInstance.total_msrp_with_labor) || 0,
        lines,
        total_lines: lines.length,
        unique_items: uniqueItems,
        bom_component_lines: bomComponentLines,
        quote_line_component_lines: quoteLineComponentLines,
        assembly_child_lines: assemblyChildLines,
        total_qty: totalQty,
        total_cost_exw: totalCostExw,
        total_msrp: totalMsrpSaleOut,
      };

      setBomInstance(bomInstanceData);

      // Step 4: Calculate Health Checks directly from lines (no RPC, no endpoints)
      // All checks are based on vw_bom_instance_flat data for this specific bom_instance_id
      
      // Orphan Assembly Children
      const orphanChildren = lines.filter(
        (l: BOMInstanceDataLine) => l.source === 'assembly_child' && !l.parent_part_id
      ).length;

      // Duplicate Items (same catalog_item_id + same parent_part_id in same BOM)
      const duplicateMap = new Map<string, number>();
      lines.forEach((line: BOMInstanceDataLine) => {
        const key = `${line.catalog_item_id}_${line.parent_part_id || 'null'}_${line.part_role || 'null'}_${line.uom}`;
        duplicateMap.set(key, (duplicateMap.get(key) || 0) + 1);
      });
      const duplicates = Array.from(duplicateMap.values()).filter(count => count > 1).length;

      // Missing Qty/UOM
      const missingQtyUom = lines.filter(
        (l: BOMInstanceDataLine) => !l.qty || !l.uom || l.uom.trim() === ''
      ).length;

      // Missing Parent (assembly_child where parent doesn't exist in same BOM)
      const catalogItemIds = new Set(lines.map((l: BOMInstanceDataLine) => l.catalog_item_id));
      const missingParent = lines.filter(
        (l: BOMInstanceDataLine) => l.source === 'assembly_child' 
          && l.parent_part_id 
          && !catalogItemIds.has(l.parent_part_id)
      ).length;

      const totalIssues = orphanChildren + duplicates + missingQtyUom + missingParent;

      setHealthStatus({
        orphan_assembly_children: orphanChildren,
        duplicate_items: duplicates,
        missing_qty_uom: missingQtyUom,
        missing_parent: missingParent,
        total_issues: totalIssues,
        is_healthy: totalIssues === 0,
      });

    } catch (err: any) {
      console.error('Error in useBOMMonitoring:', err);
      setError(err.message || 'Failed to fetch BOM monitoring data');
      setBomInstance(null);
      setHealthStatus(null);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchMonitoringData();
  }, [activeOrganizationId, saleOrderId]);

  return {
    bomInstance,
    healthStatus,
    loading,
    error,
    refetch: fetchMonitoringData,
  };
}

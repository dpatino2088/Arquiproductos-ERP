import { useState, useEffect, useCallback } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';
import { useAuth } from './useAuth';
import { normalizeUUID } from '../utils/uuid';

// ============================================================================
// TYPES
// ============================================================================

export type ManufacturingOrderStatus =
  | 'draft'
  | 'confirmed'
  | 'procurement'
  | 'materials_ready'
  | 'in_production'
  | 'quality_check'
  | 'ready_for_pickup'
  | 'delivered'
  | 'completed'
  | 'cancelled';
export type ManufacturingOrderPriority = 'low' | 'normal' | 'high' | 'urgent';

export interface ManufacturingOrder {
  id: string;
  organization_id: string;
  sales_order_id: string;
  sales_order_line_id?: string | null;
  manufacturing_order_no: string;
  status: ManufacturingOrderStatus;
  priority: ManufacturingOrderPriority;
  mo_type?: string | null;
  product_id?: string | null;
  product_name?: string | null;
  configuration?: Record<string, any> | null;
  quantity?: number | null;
  dealer_id?: string | null;
  parent_mo_id?: string | null;
  claim_id?: string | null;
  notes?: string | null;
  internal_notes?: string | null;
  released_at?: string | null;
  planned_start_at?: string | null;
  planned_end_at?: string | null;
  production_started_at?: string | null;
  completed_at?: string | null;
  delivered_at?: string | null;
  created_at: string;
  updated_at: string;
  deleted: boolean;
  archived?: boolean;
  created_by?: string | null;
  SalesOrders?: {
    id: string;
    sales_order_no: string;
    customer_id: string;
    total_amount?: number;
    dealer_id?: string;
    expected_delivery_date?: string | null;
    DirectoryCustomers?: {
      id: string;
      customer_name: string;
    };
    Dealers?: {
      dealer_name: string;
      dealer_no?: string | null;
    };
  };
}

export interface ManufacturingMaterial {
  bom_instance_line_id: string;
  bom_instance_id: string;
  category_code: string;
  catalog_item_id: string;
  sku: string;
  item_name: string;
  part_role: string;
  uom: string;
  qty: number;
  total_qty: number;
  unit_cost_exw?: number;
  total_cost_exw: number;
  unit_msrp?: number;
  total_msrp?: number;
  cut_length_mm?: number | null;
  cut_width_mm?: number | null;
  cut_height_mm?: number | null;
  calc_notes?: string | null;
  product_width_mm?: number | null;
  product_height_mm?: number | null;
  excluded?: boolean;
}

export interface CutJob {
  id: string;
  organization_id: string;
  manufacturing_order_id: string;
  status: 'draft' | 'planned' | 'in_progress' | 'completed';
  created_at: string;
  updated_at: string;
  deleted: boolean;
}

export interface CutJobLine {
  id: string;
  cut_job_id: string;
  bom_instance_line_id: string;
  resolved_sku: string | null;
  part_role: string | null;
  qty: number;
  cut_length_mm: number | null;
  cut_width_mm: number | null;
  cut_height_mm: number | null;
  uom: string;
  notes: string | null;
  created_at: string;
  deleted: boolean;
}

export interface BomInstanceTotals {
  totalLaborCost: number;
  totalCostWithLabor: number;
  totalMSRPWithLabor: number;
}

// ============================================================================
// HOOK: useManufacturingOrders
// ============================================================================

/**
 * Hook para obtener ManufacturingOrders
 * Scope operativo por organization_id.
 * Opcionalmente permite filtrar por dealer_id explícito.
 *
 * @param dealerId - Opcional: filtra por ese dealer_id; null/undefined/'all' = todos los dealers
 */
export function useManufacturingOrders(dealerId?: string | null) {
  const [manufacturingOrders, setManufacturingOrders] = useState<ManufacturingOrder[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshTrigger, setRefreshTrigger] = useState(0);
  const { activeOrganizationId } = useOrganizationContext();

  const refetch = () => {
    setRefreshTrigger(prev => prev + 1);
  };

  useEffect(() => {
    async function fetchManufacturingOrders() {
      if (!activeOrganizationId) {
        setLoading(false);
        setManufacturingOrders([]);
        setError(null);
        return;
      }

      try {
        setLoading(true);
        setError(null);

        if (import.meta.env.DEV) {
          console.log('🔍 useManufacturingOrders: Fetching ManufacturingOrders for organization:', activeOrganizationId);
        }

        const scopedDealerId =
          dealerId && dealerId !== 'all'
            ? dealerId
            : null;

        let salesOrderIds: string[] | null = null;
        if (scopedDealerId) {
          const { data: salesOrdersData } = await supabase
            .from('SalesOrders')
            .select('id')
            .eq('organization_id', activeOrganizationId)
            .eq('dealer_id', scopedDealerId)
            .eq('deleted', false);

          salesOrderIds = (salesOrdersData ?? []).map((so: { id: string }) => so.id);
        }

        // First, try without JOINs to see if basic query works
        let basicQuery = supabase
          .from('ManufacturingOrders')
          .select('*')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false);

        if (salesOrderIds !== null) {
          if (salesOrderIds.length === 0) {
            // No hay SalesOrders para este company, retornar vacío
            setManufacturingOrders([]);
            setLoading(false);
            return;
          }
          basicQuery = basicQuery.in('sales_order_id', salesOrderIds);
        }

        const { data: basicData, error: basicError } = await basicQuery
          .order('created_at', { ascending: false });

        if (basicError) {
          if (import.meta.env.DEV) {
            console.error('❌ Error fetching ManufacturingOrders (basic query):', basicError);
          }
          throw basicError;
        }

        if (import.meta.env.DEV) {
          console.log('✅ useManufacturingOrders: Found', basicData?.length || 0, 'ManufacturingOrders (basic query)');
          console.log('   Statuses:', basicData?.map((mo: any) => mo.status) || []);
        }

        // Now try with JOINs
        let queryWithJoins = supabase
          .from('ManufacturingOrders')
          .select(`
            *,
            SalesOrders:sales_order_id (
              id,
              sales_order_no,
              customer_id,
              total_amount,
              expected_delivery_date,
              DirectoryCustomers:customer_id (
                id,
                customer_name
              ),
              Dealers:dealer_id (
                dealer_name,
                dealer_no
              )
            )
          `)
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false);

        if (salesOrderIds !== null && salesOrderIds.length > 0) {
          queryWithJoins = queryWithJoins.in('sales_order_id', salesOrderIds);
        }

        const { data, error: queryError } = await queryWithJoins
          .order('created_at', { ascending: false });

        if (queryError) {
          if (import.meta.env.DEV) {
            console.warn('⚠️ Error fetching ManufacturingOrders with JOINs:', queryError);
            console.log('📋 Using basic data without JOINs');
          }
          // Use basic data if JOINs fail
          setManufacturingOrders(basicData || []);
          return;
        }

        if (import.meta.env.DEV) {
          console.log('✅ useManufacturingOrders: Found', data?.length || 0, 'ManufacturingOrders (with JOINs)');
          if (scopedDealerId && data && data.length > 0) {
            console.log('   Filtered by dealer_id:', scopedDealerId);
          } else if (scopedDealerId && (!data || data.length === 0)) {
            console.warn('   No ManufacturingOrders found for dealer_id:', scopedDealerId);
          }
        }

        setManufacturingOrders(data || []);
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading manufacturing orders';
        setError(errorMessage);
      } finally {
        setLoading(false);
      }
    }

    fetchManufacturingOrders();
  }, [activeOrganizationId, dealerId, refreshTrigger]);

  return { manufacturingOrders, loading, error, refetch };
}

// ============================================================================
// HOOK: useManufacturingOrder
// ============================================================================

export function useManufacturingOrder(moId: string | null) {
  const [manufacturingOrder, setManufacturingOrder] = useState<ManufacturingOrder | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshTrigger, setRefreshTrigger] = useState(0);
  const { activeOrganizationId } = useOrganizationContext();

  const refetch = () => {
    setRefreshTrigger(prev => prev + 1);
  };

  useEffect(() => {
    async function fetchManufacturingOrder() {
      // Normalize UUID before use
      const safeMoId = normalizeUUID(moId);
      
      if (!activeOrganizationId || !safeMoId) {
        if (import.meta.env.DEV && moId && !safeMoId) {
          console.warn('⚠️ Invalid moId after normalization in useManufacturingOrder:', moId);
        }
        setLoading(false);
        setManufacturingOrder(null);
        setError(null);
        return;
      }

      try {
        setLoading(true);
        setError(null);

        const { data, error: queryError } = await supabase
          .from('ManufacturingOrders')
          .select(`
            *,
            SalesOrders:sales_order_id (
              id,
              sales_order_no,
              customer_id,
              total_amount,
              DirectoryCustomers:customer_id (
                id,
                customer_name
              ),
              Dealers:dealer_id (
                dealer_name,
                dealer_no
              )
            )
          `)
          .eq('id', safeMoId)
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .single();

        if (queryError) throw queryError;

        setManufacturingOrder(data);
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading manufacturing order';
        setError(errorMessage);
      } finally {
        setLoading(false);
      }
    }

    fetchManufacturingOrder();
  }, [activeOrganizationId, moId, refreshTrigger]);

  return { manufacturingOrder, loading, error, refetch };
}

// ============================================================================
// HOOK: useManufacturingMaterials
// ============================================================================

export interface UseManufacturingMaterialsResult {
  materials: ManufacturingMaterial[];
  bomTotals: BomInstanceTotals;
  loading: boolean;
  error: string | null;
  refetch: () => void;
  hasBomInstances: boolean;
  hasBomLines: boolean;
  debugCounts: {
    bomInstances: number;
    bomLines: number;
  };
}

export function useManufacturingMaterials(manufacturingOrderId: string): UseManufacturingMaterialsResult {
  const [materials, setMaterials] = useState<ManufacturingMaterial[]>([]);
  const [bomTotals, setBomTotals] = useState<BomInstanceTotals>({
    totalLaborCost: 0,
    totalCostWithLabor: 0,
    totalMSRPWithLabor: 0,
  });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [bomInstancesCount, setBomInstancesCount] = useState(0);
  const [bomLinesCount, setBomLinesCount] = useState(0);
  const { activeOrganizationId } = useOrganizationContext();

  const fetchMaterials = useCallback(async () => {
      // Normalize UUID before use
      const safeManufacturingOrderId = normalizeUUID(manufacturingOrderId);
      
      if (!activeOrganizationId || !safeManufacturingOrderId) {
        if (import.meta.env.DEV && manufacturingOrderId && !safeManufacturingOrderId) {
          console.warn('⚠️ Invalid manufacturingOrderId after normalization:', manufacturingOrderId);
        }
        setLoading(false);
        setMaterials([]);
        setError(null);
        return;
      }

      try {
        setLoading(true);
        setError(null);

        if (import.meta.env.DEV) {
          console.log('🔍 useManufacturingMaterials: Fetching BOM for manufacturingOrderId:', safeManufacturingOrderId, 'organization:', activeOrganizationId);
        }

        // Fetch MO quantity so we can multiply per-unit BOM lines
        const { data: moRow } = await supabase
          .from('ManufacturingOrders')
          .select('quantity')
          .eq('id', safeManufacturingOrderId)
          .single();
        const moQty = Math.max(1, Number(moRow?.quantity ?? 1));

        const { data: bomInstances, error: bomError } = await supabase
          .from('BOMInstances')
          .select('id, organization_id, quote_line_id, sales_order_line_id')
          .eq('manufacturing_order_id', safeManufacturingOrderId)
          .eq('deleted', false);

        if (bomError) throw bomError;
        
        if (import.meta.env.DEV) {
          console.log('📊 useManufacturingMaterials: Found', bomInstances?.length || 0, 'BOMInstances');
        }
        
        const bomInstancesCount = bomInstances?.length || 0;
        setBomInstancesCount(bomInstancesCount);
        
        if (import.meta.env.DEV) {
          console.log('📊 useManufacturingMaterials: Found', bomInstancesCount, 'BOMInstances');
        }
        
        if (!bomInstances || bomInstances.length === 0) {
          if (import.meta.env.DEV) {
            console.warn('⚠️ useManufacturingMaterials: No BOMInstances found for manufacturingOrderId:', manufacturingOrderId);
          }
          setMaterials([]);
          setBomLinesCount(0);
          setLoading(false);
          return;
        }

        const bomInstanceIds = bomInstances.map((bi: { id: string }) => bi.id);

        // Get BOMInstanceLines for these BOMInstances
        // Solo seleccionar columnas que existen en BOMInstanceLines
        const { data: bomLines, error: linesError } = await supabase
          .from('BOMInstanceLines')
          .select(`
            id,
            bom_instance_id,
            resolved_part_id,
            part_role,
            qty,
            uom,
            unit_cost_exw,
            total_cost_exw,
            unit_msrp,
            total_msrp,
            cut_length_mm,
            cut_width_mm,
            cut_height_mm,
            organization_id,
            excluded
          `)
          .in('bom_instance_id', bomInstanceIds)
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false);

        if (linesError) throw linesError;
        
        const bomLinesCount = bomLines?.length || 0;
        setBomLinesCount(bomLinesCount);
        
        if (import.meta.env.DEV) {
          console.log('📊 useManufacturingMaterials: Found', bomLinesCount, 'BOMInstanceLines');
        }

        // Fetch product dimensions from SaleOrderLines via BOMInstances
        const solIds = [...new Set(
          bomInstances
            .map((bi: any) => bi.sales_order_line_id)
            .filter(Boolean)
        )];
        const biDimsMap = new Map<string, { width_mm: number | null; height_mm: number | null }>();
        if (solIds.length > 0) {
          const { data: solRows } = await supabase
            .from('SaleOrderLines')
            .select('id, width_m, height_m')
            .in('id', solIds);
          if (solRows) {
            const solMap = new Map<string, { width_m?: number; height_m?: number }>(
              solRows.map((s: { id: string; width_m?: number; height_m?: number }) => [s.id, s])
            );
            for (const bi of bomInstances) {
              const sol = (bi as any).sales_order_line_id ? solMap.get((bi as any).sales_order_line_id) : null;
              biDimsMap.set(bi.id, {
                width_mm: sol?.width_m != null ? Math.round(sol.width_m * 1000) : null,
                height_mm: sol?.height_m != null ? Math.round(sol.height_m * 1000) : null,
              });
            }
          }
        }

        const catalogItemIds = [...new Set(
          bomLines
            ?.map((line: any) => line.resolved_part_id)
            .filter((id: string | null) => id !== null) || []
        )];

        let catalogItemsMap = new Map<string, any>();
        if (catalogItemIds.length > 0) {
          const { data: catalogItems } = await supabase
            .from('CatalogItems')
            .select('id, sku, name')
            .in('id', catalogItemIds)
            .eq('organization_id', activeOrganizationId);

          if (catalogItems) {
            catalogItemsMap = new Map(catalogItems.map((item: any) => [item.id, item]));
          }
        }

        const materialsList: ManufacturingMaterial[] = bomLines?.map((line: any) => {
          const catalogItem = line.resolved_part_id ? catalogItemsMap.get(line.resolved_part_id) : null;
          const dims = biDimsMap.get(line.bom_instance_id);

          const perUnitQty = Number(line.qty) || 0;
          return {
            bom_instance_line_id: line.id,
            bom_instance_id: line.bom_instance_id,
            category_code: line.part_role || 'accessory',
            catalog_item_id: line.resolved_part_id || '',
            sku: catalogItem?.sku || 'N/A',
            item_name: catalogItem?.name || 'N/A',
            part_role: line.part_role || 'accessory',
            uom: line.uom || 'ea',
            qty: perUnitQty * moQty,
            total_qty: perUnitQty * moQty,
            unit_cost_exw: line.unit_cost_exw ? Number(line.unit_cost_exw) : undefined,
            total_cost_exw: (Number(line.total_cost_exw) || 0) * moQty,
            unit_msrp: line.unit_msrp ? Number(line.unit_msrp) : undefined,
            total_msrp: (Number(line.total_msrp) || 0) * moQty,
            cut_length_mm: line.cut_length_mm ? Number(line.cut_length_mm) : null,
            cut_width_mm: line.cut_width_mm ? Number(line.cut_width_mm) : null,
            cut_height_mm: line.cut_height_mm ? Number(line.cut_height_mm) : null,
            calc_notes: null,
            product_width_mm: dims?.width_mm ?? null,
            product_height_mm: dims?.height_mm ?? null,
            excluded: !!line.excluded,
          };
        }) || [];

        const totalCost = materialsList.reduce((sum, m) => sum + (m.total_cost_exw || 0), 0);
        const totalMSRP = materialsList.reduce((sum, m) => sum + (m.total_msrp || 0), 0);

        setMaterials(materialsList);

        setBomTotals({
          totalLaborCost: 0,
          totalCostWithLabor: totalCost,
          totalMSRPWithLabor: totalMSRP,
        });
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading materials';
        setError(errorMessage);
      } finally {
        setLoading(false);
      }
  }, [activeOrganizationId, manufacturingOrderId]);

  useEffect(() => {
    fetchMaterials();
  }, [fetchMaterials]);

  const refetch = useCallback(() => {
    return fetchMaterials();
  }, [fetchMaterials]);

  return { 
    materials, 
    bomTotals, 
    loading, 
    error, 
    refetch,
    hasBomInstances: bomInstancesCount > 0,
    hasBomLines: bomLinesCount > 0,
    debugCounts: {
      bomInstances: bomInstancesCount,
      bomLines: bomLinesCount,
    },
  };
}

// ============================================================================
// HOOK: useCreateManufacturingOrder
// ============================================================================

export function useCreateManufacturingOrder() {
  const [isCreating, setIsCreating] = useState(false);
  const { activeOrganizationId } = useOrganizationContext();
  const { user } = useAuth();

  const createManufacturingOrder = async (moData: {
    sales_order_id: string;
    planned_start_at?: string;
    planned_end_at?: string;
    priority?: ManufacturingOrderPriority;
    notes?: string;
  }) => {
    if (!activeOrganizationId) {
      throw new Error('No organization selected');
    }

    setIsCreating(true);
    try {
      if (!user?.id) {
        throw new Error('User not authenticated');
      }

      const { data: rpcData, error: rpcError } = await supabase.rpc('create_manufacturing_order', {
        p_sales_order_id: moData.sales_order_id,
        p_user_id: user.id,
        p_sales_order_line_id: null,
        p_user_name: user.name ?? user.email ?? null,
      });
      if (rpcError) throw rpcError;

      const rpcResult = (rpcData ?? null) as { mo_id?: string; mo_number?: string; error?: string } | null;
      const moId = rpcResult?.mo_id ?? null;
      if (!moId) {
        throw new Error(rpcResult?.error || 'Failed to create Manufacturing Order');
      }

      const patchPayload: Record<string, unknown> = {};
      if (moData.priority !== undefined) patchPayload.priority = moData.priority;
      if (moData.planned_start_at !== undefined) patchPayload.planned_start_at = moData.planned_start_at || null;
      if (moData.planned_end_at !== undefined) patchPayload.planned_end_at = moData.planned_end_at || null;
      if (moData.notes !== undefined) patchPayload.notes = moData.notes || null;
      if (Object.keys(patchPayload).length > 0) {
        const { error: updateError } = await supabase
          .from('ManufacturingOrders')
          .update(patchPayload)
          .eq('id', moId)
          .eq('organization_id', activeOrganizationId);
        if (updateError) throw updateError;
      }

      const { data: created, error: loadError } = await supabase
        .from('ManufacturingOrders')
        .select('*')
        .eq('id', moId)
        .eq('organization_id', activeOrganizationId)
        .single();
      if (loadError) {
        throw loadError;
      }
      return created;
    } finally {
      setIsCreating(false);
    }
  };

  return { createManufacturingOrder, isCreating };
}

// ============================================================================
// HOOK: useUpdateManufacturingOrder
// ============================================================================

export function useUpdateManufacturingOrder() {
  const [isUpdating, setIsUpdating] = useState(false);
  const { activeOrganizationId } = useOrganizationContext();

  const updateManufacturingOrder = async (
    moId: string,
    updates: {
      status?: ManufacturingOrderStatus;
      priority?: ManufacturingOrderPriority;
      notes?: string | null;
      internal_notes?: string | null;
      planned_start_at?: string | null;
      planned_end_at?: string | null;
    }
  ) => {
    if (!activeOrganizationId) {
      throw new Error('No organization selected');
    }

    setIsUpdating(true);
    try {
      const payload: Record<string, unknown> = { updated_at: new Date().toISOString() };
      if (updates.status !== undefined) payload.status = updates.status;
      if (updates.priority !== undefined) payload.priority = updates.priority;
      if (updates.notes !== undefined) payload.notes = updates.notes;
      if (updates.internal_notes !== undefined) payload.internal_notes = updates.internal_notes;
      if (updates.planned_start_at !== undefined) payload.planned_start_at = updates.planned_start_at;
      if (updates.planned_end_at !== undefined) payload.planned_end_at = updates.planned_end_at;

      const { error, count } = await supabase
        .from('ManufacturingOrders')
        .update(payload)
        .eq('id', moId)
        .eq('organization_id', activeOrganizationId)
        .select('id', { count: 'exact', head: true });

      if (error) {
        throw error;
      }

      if (count === 0) {
        throw new Error('Update failed: no rows matched (check RLS permissions)');
      }

      return { id: moId, ...updates };
    } finally {
      setIsUpdating(false);
    }
  };

  return { updateManufacturingOrder, isUpdating };
}

// ============================================================================
// HOOK: useMoMaterialReadiness
// ============================================================================

export type MoMaterialReadinessStatus = 'complete' | 'incomplete';

export interface MoMaterialReadiness {
  status: MoMaterialReadinessStatus;
  hasShortage: boolean;
}

export function useMoMaterialReadiness(moId: string | null): {
  readiness: MoMaterialReadiness | null;
  loading: boolean;
  error: string | null;
  refetch: () => void;
} {
  const [readiness, setReadiness] = useState<MoMaterialReadiness | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchReadiness = useCallback(async () => {
    const safeMoId = normalizeUUID(moId);
    if (!safeMoId) {
      setReadiness(null);
      setLoading(false);
      setError(null);
      return;
    }
    setLoading(true);
    setError(null);
    try {
      const { data, error: err } = await supabase.rpc('get_mo_material_readiness', { p_mo_id: safeMoId });
      if (err) throw err;
      const payload = data as { ok?: boolean; status?: string; has_shortage?: boolean } | null;
      if (payload?.ok && payload.status) {
        setReadiness({
          status: payload.status as MoMaterialReadinessStatus,
          hasShortage: Boolean(payload.has_shortage),
        });
      } else {
        setReadiness({ status: 'incomplete', hasShortage: true });
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Error loading material readiness');
      setReadiness(null);
    } finally {
      setLoading(false);
    }
  }, [moId]);

  useEffect(() => {
    fetchReadiness();
  }, [fetchReadiness]);

  return { readiness, loading, error, refetch: fetchReadiness };
}

// ============================================================================
// HOOK: useTransitionMOStatus
// ============================================================================

export function useTransitionMOStatus() {
  const [isTransitioning, setIsTransitioning] = useState(false);
  const queryClient = useQueryClient();
  const { activeOrganizationId } = useOrganizationContext();

  const transitionStatus = useCallback(
    async (moId: string, newStatus: string, userId: string, userName?: string) => {
      setIsTransitioning(true);
      try {
        const { data, error } = await supabase.rpc('transition_mo_status', {
          p_mo_id: moId,
          p_new_status: newStatus,
          p_user_id: userId,
          p_user_name: userName ?? null,
        });
        if (error) throw error;
        const result = data as { ok?: boolean; error?: string; from?: string; to?: string };
        if (result?.ok === false && result?.error) throw new Error(result.error);
        if (activeOrganizationId) {
          queryClient.invalidateQueries({ queryKey: ['material-demand', activeOrganizationId] });
        }
        queryClient.invalidateQueries({ queryKey: ['inventory-allocations'] });
        return data as { ok: boolean; from: string; to: string };
      } finally {
        setIsTransitioning(false);
      }
    },
    [queryClient, activeOrganizationId]
  );

  return { transitionStatus, isTransitioning };
}

// ============================================================================
// HOOK: useCutList
// ============================================================================

export function useCutList(manufacturingOrderId: string | null) {
  const [cutJob, setCutJob] = useState<CutJob | null>(null);
  const [cutJobLines, setCutJobLines] = useState<CutJobLine[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshTrigger, setRefreshTrigger] = useState(0);
  const { activeOrganizationId } = useOrganizationContext();

  const refetch = () => {
    setRefreshTrigger(prev => prev + 1);
  };

  useEffect(() => {
    async function fetchCutList() {
      // Normalize UUID before use
      const safeManufacturingOrderId = normalizeUUID(manufacturingOrderId);
      
      if (!activeOrganizationId || !safeManufacturingOrderId) {
        if (import.meta.env.DEV && manufacturingOrderId && !safeManufacturingOrderId) {
          console.warn('⚠️ Invalid manufacturingOrderId after normalization in useCutList:', manufacturingOrderId);
        }
        setLoading(false);
        setCutJob(null);
        setCutJobLines([]);
        setError(null);
        return;
      }

      try {
        setLoading(true);
        setError(null);

        // Fetch CutJob
        const { data: cutJobData, error: cutJobError } = await supabase
          .from('CutJobs')
          .select('*')
          .eq('manufacturing_order_id', safeManufacturingOrderId)
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .single();

        if (cutJobError && cutJobError.code !== 'PGRST116') {
          // PGRST116 = no rows returned (expected if cut list not generated yet)
          throw cutJobError;
        }

        if (cutJobData) {
          setCutJob(cutJobData);

          // Fetch CutJobLines
          const { data: linesData, error: linesError } = await supabase
            .from('CutJobLines')
            .select('*')
            .eq('cut_job_id', cutJobData.id)
            .eq('deleted', false)
            .order('part_role', { ascending: true })
            .order('resolved_sku', { ascending: true });

          if (linesError) throw linesError;

          setCutJobLines(linesData || []);
        } else {
          setCutJob(null);
          setCutJobLines([]);
        }
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error loading cut list';
        setError(errorMessage);
        if (import.meta.env.DEV) {
          console.error('Error loading cut list:', err);
        }
      } finally {
        setLoading(false);
      }
    }

    fetchCutList();
  }, [activeOrganizationId, manufacturingOrderId, refreshTrigger]);

  return { cutJob, cutJobLines, loading, error, refetch };
}

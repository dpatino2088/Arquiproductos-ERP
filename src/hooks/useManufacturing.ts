import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';
import { useActiveDealer } from './useActiveDealer';
import { normalizeUUID } from '../utils/uuid';

// ============================================================================
// TYPES
// ============================================================================

export type ManufacturingOrderStatus = 'draft' | 'planned' | 'in_production' | 'quality_check' | 'ready_for_pickup' | 'delivered' | 'completed' | 'cancelled';
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
  notes?: string | null;
  internal_notes?: string | null;
  released_at?: string | null;
  planned_start_at?: string | null;
  planned_end_at?: string | null;
  scheduled_start_date?: string | null;
  scheduled_end_date?: string | null;
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
    DirectoryCustomers?: {
      id: string;
      customer_name: string;
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
 * Filtra por organization_id Y dealer_id (vía SalesOrders -> Quotes)
 *
 * @param dealerId - Opcional: filtra solo por ese dealer_id
 */
export function useManufacturingOrders(dealerId?: string | null) {
  const [manufacturingOrders, setManufacturingOrders] = useState<ManufacturingOrder[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshTrigger, setRefreshTrigger] = useState(0);
  const { activeOrganizationId } = useOrganizationContext();
  const { activeDealerId } = useActiveDealer();

  const effectiveDealerId = dealerId ?? activeDealerId;

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

        let salesOrderIds: string[] | null = null;
        if (effectiveDealerId) {
          const { data: salesOrdersData } = await supabase
            .from('SalesOrders')
            .select('id, quote_id')
            .eq('organization_id', activeOrganizationId)
            .eq('deleted', false);

          if (salesOrdersData && salesOrdersData.length > 0) {
            const quoteIds = salesOrdersData.map((so: { quote_id?: string }) => so.quote_id).filter((id: string | undefined): id is string => !!id);
            if (quoteIds.length > 0) {
              const { data: quotesData } = await supabase
                .from('Quotes')
                .select('id')
                .in('id', quoteIds)
                .eq('dealer_id', effectiveDealerId)
                .eq('deleted', false);

              if (quotesData) {
                const validQuoteIds = new Set(quotesData.map((q: { id: string }) => q.id));
                salesOrderIds = salesOrdersData
                  .filter((so: { quote_id?: string; id: string }) => so.quote_id && validQuoteIds.has(so.quote_id))
                  .map((so: { id: string }) => so.id);
              }
            }
          }
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
              DirectoryCustomers:customer_id (
                id,
                customer_name
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
          if (effectiveDealerId && data && data.length > 0) {
            console.log('   Filtered by dealer_id:', effectiveDealerId);
          } else if (effectiveDealerId && (!data || data.length === 0)) {
            console.warn('   No ManufacturingOrders found for dealer_id:', effectiveDealerId);
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
  }, [activeOrganizationId, effectiveDealerId, refreshTrigger]);

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

        const { data: bomInstances, error: bomError } = await supabase
          .from('BOMInstances')
          .select('id, organization_id, quote_line_id')
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
            cut_length_mm,
            cut_width_mm,
            cut_height_mm,
            organization_id
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

        // Obtener CatalogItems para resolved_part_id
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
          
          return {
            bom_instance_line_id: line.id,
            bom_instance_id: line.bom_instance_id,
            category_code: line.part_role || 'accessory',
            catalog_item_id: line.resolved_part_id || '',
            sku: catalogItem?.sku || 'N/A',
            item_name: catalogItem?.name || 'N/A',
            part_role: line.part_role || 'accessory',
            uom: line.uom || 'ea',
            qty: Number(line.qty) || 0,
            total_qty: Number(line.qty) || 0,
            unit_cost_exw: line.unit_cost_exw ? Number(line.unit_cost_exw) : undefined,
            total_cost_exw: Number(line.total_cost_exw) || 0,
            unit_msrp: undefined, // No existe en BOMInstanceLines, se puede calcular desde CatalogItems si es necesario
            total_msrp: undefined, // No existe en BOMInstanceLines, se puede calcular desde CatalogItems si es necesario
            cut_length_mm: line.cut_length_mm ? Number(line.cut_length_mm) : null,
            cut_width_mm: line.cut_width_mm ? Number(line.cut_width_mm) : null,
            cut_height_mm: line.cut_height_mm ? Number(line.cut_height_mm) : null,
            calc_notes: null, // No existe en BOMInstanceLines
          };
        }) || [];

        // Calcular totales desde las líneas
        const totalCost = materialsList.reduce((sum, m) => sum + (m.total_cost_exw || 0), 0);

        setMaterials(materialsList);
        
        setBomTotals({
          totalLaborCost: 0, // No existe en BOMInstances, se puede calcular desde otra fuente si es necesario
          totalCostWithLabor: totalCost, // Usar total de líneas
          totalMSRPWithLabor: 0, // No existe en BOMInstances, se puede calcular desde CatalogItems si es necesario
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

  const ensureBOMGenerated = async (manufacturingOrderId: string, manufacturingOrderNo?: string | null) => {
    const { data: bomResult, error: bomError } = await supabase.rpc('generate_bom_for_manufacturing_order', {
      p_manufacturing_order_id: manufacturingOrderId,
    });
    if (bomError) {
      throw new Error(`MO created, but BOM generation failed for ${manufacturingOrderNo ?? manufacturingOrderId}: ${bomError.message}`);
    }
    const bomOk = Boolean((bomResult as { ok?: boolean } | null)?.ok);
    if (!bomOk) {
      const errors = (bomResult as { errors?: string[] } | null)?.errors ?? [];
      throw new Error(
        `MO created, but BOM generation failed for ${manufacturingOrderNo ?? manufacturingOrderId}: ${errors.join('; ') || 'Unknown error'}`
      );
    }
  };

  const createManufacturingOrder = async (moData: {
    sales_order_id: string;
    planned_start_at?: string;
    planned_end_at?: string;
    scheduled_start_date?: string;
    scheduled_end_date?: string;
    priority?: ManufacturingOrderPriority;
    notes?: string;
  }) => {
    if (!activeOrganizationId) {
      throw new Error('No organization selected');
    }

    setIsCreating(true);
    try {
      // Generate manufacturing order number
      let moNumber: string;
      try {
        const { data: counterValue, error: counterError } = await supabase.rpc('get_next_counter_value', {
          p_organization_id: activeOrganizationId,
          p_key: 'manufacturing_order',
        });

        if (!counterError && counterValue !== null && counterValue !== undefined) {
          moNumber = 'MO-' + String(counterValue).padStart(6, '0');
        } else {
          const timestamp = Date.now();
          moNumber = `MO-TEMP-${timestamp}`;
        }
      } catch (err) {
        const timestamp = Date.now();
        moNumber = `MO-TEMP-${timestamp}`;
      }

      const plannedPayload = {
        organization_id: activeOrganizationId,
        sales_order_id: moData.sales_order_id,
        manufacturing_order_no: moNumber,
        status: 'draft',
        priority: moData.priority || 'normal',
        planned_start_at: moData.planned_start_at || null,
        planned_end_at: moData.planned_end_at || null,
        notes: moData.notes || null,
        deleted: false,
        archived: false,
      };

      const primary = await supabase
        .from('ManufacturingOrders')
        .insert(plannedPayload)
        .select()
        .single();

      if (!primary.error) {
        await ensureBOMGenerated(primary.data.id, primary.data.manufacturing_order_no);
        return primary.data;
      }

      const primaryMessage = String((primary.error as { message?: string })?.message ?? '').toLowerCase();
      const missingPlannedColumns = primaryMessage.includes('planned_start_at') || primaryMessage.includes('planned_end_at');
      if (!missingPlannedColumns) {
        throw primary.error;
      }

      const fallbackPayload = {
        organization_id: activeOrganizationId,
        sales_order_id: moData.sales_order_id,
        manufacturing_order_no: moNumber,
        status: 'draft',
        priority: moData.priority || 'normal',
        scheduled_start_date: moData.planned_start_at ?? moData.scheduled_start_date ?? null,
        scheduled_end_date: moData.planned_end_at ?? moData.scheduled_end_date ?? null,
        notes: moData.notes || null,
        deleted: false,
        archived: false,
      };

      const fallback = await supabase
        .from('ManufacturingOrders')
        .insert(fallbackPayload)
        .select()
        .single();

      if (fallback.error) throw fallback.error;
      await ensureBOMGenerated(fallback.data.id, fallback.data.manufacturing_order_no);
      return fallback.data;
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
      scheduled_start_date?: string | null;
      scheduled_end_date?: string | null;
    }
  ) => {
    if (!activeOrganizationId) {
      throw new Error('No organization selected');
    }

    setIsUpdating(true);
    try {
      const basePayload = {
        ...updates,
        updated_at: new Date().toISOString(),
      };

      const { data, error } = await supabase
        .from('ManufacturingOrders')
        .update(basePayload)
        .eq('id', moId)
        .eq('organization_id', activeOrganizationId)
        .select()
        .single();

      if (!error) {
        return data;
      }

      // Backward compatibility: some databases still use scheduled_* fields.
      const message = String((error as { message?: string })?.message ?? '').toLowerCase();
      const hasPlannedKeys = Object.prototype.hasOwnProperty.call(updates, 'planned_start_at')
        || Object.prototype.hasOwnProperty.call(updates, 'planned_end_at');
      const missingPlannedColumns = message.includes('planned_start_at') || message.includes('planned_end_at');
      if (!hasPlannedKeys || !missingPlannedColumns) {
        throw error;
      }

      const fallbackPayload = {
        ...basePayload,
        scheduled_start_date: updates.planned_start_at ?? null,
        scheduled_end_date: updates.planned_end_at ?? null,
      };
      delete (fallbackPayload as Record<string, unknown>).planned_start_at;
      delete (fallbackPayload as Record<string, unknown>).planned_end_at;

      const { data: fallbackData, error: fallbackError } = await supabase
        .from('ManufacturingOrders')
        .update(fallbackPayload)
        .eq('id', moId)
        .eq('organization_id', activeOrganizationId)
        .select()
        .single();

      if (fallbackError) {
        const fallbackMessage = String((fallbackError as { message?: string })?.message ?? '').toLowerCase();
        const missingScheduledColumns = fallbackMessage.includes('scheduled_start_date') || fallbackMessage.includes('scheduled_end_date');
        if (missingScheduledColumns) {
          throw new Error('Could not save schedule. Missing schedule columns in ManufacturingOrders; run schedule migration.');
        }
        throw fallbackError;
      }
      return fallbackData;
    } finally {
      setIsUpdating(false);
    }
  };

  return { updateManufacturingOrder, isUpdating };
}

// ============================================================================
// HOOK: useTransitionMOStatus
// ============================================================================

export function useTransitionMOStatus() {
  const [isTransitioning, setIsTransitioning] = useState(false);

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
        return data as { ok: boolean; from: string; to: string };
      } finally {
        setIsTransitioning(false);
      }
    },
    []
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

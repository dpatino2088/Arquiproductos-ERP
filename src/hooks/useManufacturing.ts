import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';
import { normalizeUUID } from '../utils/uuid';

// ============================================================================
// TYPES
// ============================================================================

export type ManufacturingOrderStatus = 'draft' | 'planned' | 'in_production' | 'completed' | 'cancelled';
export type ManufacturingOrderPriority = 'low' | 'normal' | 'high' | 'urgent';

export interface ManufacturingOrder {
  id: string;
  organization_id: string;
  sales_order_id: string;
  manufacturing_order_no: string;
  status: ManufacturingOrderStatus;
  priority: ManufacturingOrderPriority;
  scheduled_start_date?: string | null;
  scheduled_end_date?: string | null;
  actual_start_date?: string | null;
  actual_end_date?: string | null;
  notes?: string | null;
  metadata?: Record<string, any> | null;
  created_at: string;
  updated_at: string;
  deleted: boolean;
  archived: boolean;
  created_by?: string | null;
  updated_by?: string | null;
  SaleOrders?: {
    id: string;
    sale_order_no: string;
    customer_id: string;
    total?: number;
    currency?: string;
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
  unit_msrp_sale_out?: number;
  total_msrp_sale_out?: number;
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

export function useManufacturingOrders() {
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

        // First, try without JOINs to see if basic query works
        const { data: basicData, error: basicError } = await supabase
          .from('ManufacturingOrders')
          .select('*')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
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
        const { data, error: queryError } = await supabase
          .from('ManufacturingOrders')
          .select(`
            *,
            SalesOrders:sales_order_id (
              id,
              sale_order_no,
              customer_id,
              total,
              currency,
              DirectoryCustomers:customer_id (
                id,
                customer_name
              )
            )
          `)
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
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
  }, [activeOrganizationId, refreshTrigger]);

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
              sale_order_no,
              customer_id,
              total,
              currency,
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

import { normalizeUUID } from '../utils/uuid';

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

        // Get BomInstances for this manufacturing_order_id
        const { data: bomInstances, error: bomError } = await supabase
          .from('BomInstances')
          .select('id, organization_id, labor_cost, total_cost_with_labor, total_msrp_sale_out_with_labor')
          .eq('manufacturing_order_id', safeManufacturingOrderId)
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false);

        if (bomError) throw bomError;
        
        if (import.meta.env.DEV) {
          console.log('📊 useManufacturingMaterials: Found', bomInstances?.length || 0, 'BomInstances');
        }
        
        const bomInstancesCount = bomInstances?.length || 0;
        setBomInstancesCount(bomInstancesCount);
        
        if (import.meta.env.DEV) {
          console.log('📊 useManufacturingMaterials: Found', bomInstancesCount, 'BomInstances');
        }
        
        if (!bomInstances || bomInstances.length === 0) {
          if (import.meta.env.DEV) {
            console.warn('⚠️ useManufacturingMaterials: No BomInstances found for manufacturingOrderId:', manufacturingOrderId);
          }
          setMaterials([]);
          setBomLinesCount(0);
          setLoading(false);
          return;
        }

        const bomInstanceIds = bomInstances.map(bi => bi.id);
        
        const totalLaborCost = bomInstances.reduce((sum, bi) => sum + (Number(bi.labor_cost) || 0), 0);
        const totalCostWithLabor = bomInstances.reduce((sum, bi) => sum + (Number(bi.total_cost_with_labor) || 0), 0);
        const totalMSRPWithLabor = bomInstances.reduce((sum, bi) => sum + (Number(bi.total_msrp_sale_out_with_labor) || 0), 0);

        // Get BomInstanceLines for these BomInstances
        const { data: bomLines, error: linesError } = await supabase
          .from('BomInstanceLines')
          .select(`
            id,
            bom_instance_id,
            category_code,
            resolved_part_id,
            resolved_sku,
            part_role,
            qty,
            uom,
            unit_cost_exw,
            total_cost_exw,
            unit_msrp_sale_out,
            total_msrp_sale_out,
            description,
            cut_length_mm,
            cut_width_mm,
            cut_height_mm,
            calc_notes,
            organization_id
          `)
          .in('bom_instance_id', bomInstanceIds)
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false);

        if (linesError) throw linesError;
        
        const bomLinesCount = bomLines?.length || 0;
        setBomLinesCount(bomLinesCount);
        
        if (import.meta.env.DEV) {
          console.log('📊 useManufacturingMaterials: Found', bomLinesCount, 'BomInstanceLines');
        }

        const materialsList: ManufacturingMaterial[] = bomLines?.map((line: any) => ({
          bom_instance_line_id: line.id,
          bom_instance_id: line.bom_instance_id,
          category_code: line.category_code || 'accessory',
          catalog_item_id: line.resolved_part_id || '',
          sku: line.resolved_sku || 'N/A',
          item_name: line.description || 'N/A',
          part_role: line.part_role || line.category_code || 'accessory',
          uom: line.uom || 'ea',
          qty: Number(line.qty) || 0,
          total_qty: Number(line.qty) || 0,
          unit_cost_exw: line.unit_cost_exw ? Number(line.unit_cost_exw) : undefined,
          total_cost_exw: Number(line.total_cost_exw) || 0,
          unit_msrp_sale_out: line.unit_msrp_sale_out ? Number(line.unit_msrp_sale_out) : undefined,
          total_msrp_sale_out: line.total_msrp_sale_out ? Number(line.total_msrp_sale_out) : undefined,
          cut_length_mm: line.cut_length_mm ? Number(line.cut_length_mm) : null,
          cut_width_mm: line.cut_width_mm ? Number(line.cut_width_mm) : null,
          cut_height_mm: line.cut_height_mm ? Number(line.cut_height_mm) : null,
          calc_notes: line.calc_notes || null,
        })) || [];

        setMaterials(materialsList);
        
        setBomTotals({
          totalLaborCost,
          totalCostWithLabor,
          totalMSRPWithLabor,
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

  const createManufacturingOrder = async (moData: {
    sales_order_id: string;
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

      const { data, error } = await supabase
        .from('ManufacturingOrders')
        .insert({
          organization_id: activeOrganizationId,
          sales_order_id: moData.sales_order_id,
          manufacturing_order_no: moNumber,
          status: 'draft',
          priority: moData.priority || 'normal',
          scheduled_start_date: moData.scheduled_start_date || null,
          scheduled_end_date: moData.scheduled_end_date || null,
          notes: moData.notes || null,
          deleted: false,
          archived: false,
        })
        .select()
        .single();

      if (error) throw error;
      return data;
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
      scheduled_start_date?: string | null;
      scheduled_end_date?: string | null;
      actual_start_date?: string | null;
      actual_end_date?: string | null;
      notes?: string | null;
    }
  ) => {
    if (!activeOrganizationId) {
      throw new Error('No organization selected');
    }

    setIsUpdating(true);
    try {
      const { data, error } = await supabase
        .from('ManufacturingOrders')
        .update({
          ...updates,
          updated_at: new Date().toISOString(),
        })
        .eq('id', moId)
        .eq('organization_id', activeOrganizationId)
        .select()
        .single();

      if (error) throw error;
      return data;
    } finally {
      setIsUpdating(false);
    }
  };

  return { updateManufacturingOrder, isUpdating };
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

import { useState, useEffect, useMemo } from 'react';
import { supabase } from '../lib/supabase/client';
import type { InventoryAvailabilityRow } from '../types/inventory';

export type UseInventoryAvailabilityArgs = {
  organizationId?: string | null;
  warehouseId?: string | null;
  catalogItemIds: string[];
};

export type UseInventoryAvailabilityResult = {
  map: Record<string, InventoryAvailabilityRow>;
  rows: InventoryAvailabilityRow[];
  loading: boolean;
  error: string | null;
};

/**
 * Fetch inventory availability from view public.inventory_availability.
 * Query only when organizationId, warehouseId and catalogItemIds are present.
 * Returns map by catalog_item_id for easy row lookup. Informative only — do NOT persist in QuoteLine.
 */
export function useInventoryAvailability({
  organizationId,
  warehouseId,
  catalogItemIds,
}: UseInventoryAvailabilityArgs): UseInventoryAvailabilityResult {
  const uniqueIds = useMemo(() => {
    const set = new Set<string>();
    for (const id of catalogItemIds) {
      if (id) set.add(id);
    }
    return Array.from(set);
  }, [catalogItemIds]);

  const [rows, setRows] = useState<InventoryAvailabilityRow[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const shouldQuery =
    !!organizationId && !!warehouseId && uniqueIds.length > 0;

  useEffect(() => {
    if (!shouldQuery) {
      setRows([]);
      setLoading(false);
      setError(null);
      return;
    }

    let cancelled = false;
    setLoading(true);
    setError(null);

    (async () => {
      try {
        const { data, error: e } = await supabase
          .from('inventory_availability')
          .select('*')
          .eq('organization_id', organizationId!)
          .eq('warehouse_id', warehouseId!)
          .in('catalog_item_id', uniqueIds);

        if (cancelled) return;
        if (e) {
          setError(e.message);
          setRows([]);
          return;
        }
        setRows((data ?? []) as InventoryAvailabilityRow[]);
      } catch (err) {
        if (cancelled) return;
        setError(err instanceof Error ? err.message : 'Failed to load availability');
        setRows([]);
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [organizationId, warehouseId, shouldQuery, uniqueIds.join(',')]);

  const map = useMemo(() => {
    const out: Record<string, InventoryAvailabilityRow> = {};
    for (const row of rows) {
      if (row.catalog_item_id) out[row.catalog_item_id] = row;
    }
    return out;
  }, [rows]);

  return { map, rows, loading, error };
}

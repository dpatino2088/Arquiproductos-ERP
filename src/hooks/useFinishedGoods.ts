import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';

export interface FinishedGoodLine {
  mo_line_id: string;
  manufacturing_order_id: string;
  sales_order_line_id: string | null;
  quantity: number;
  delivery_status: string;
  delivered_qty: number;
  delivered_at: string | null;
  organization_id: string;
  manufacturing_order_no: string;
  mo_status: string;
  sales_order_id: string | null;
  product_name: string | null;
  released_at: string | null;
  sales_order_no: string | null;
  customer_name: string | null;
  line_description: string | null;
  product_type: string | null;
  area: string | null;
  position: string | null;
  catalog_item_name: string | null;
  catalog_item_sku: string | null;
}

export interface FinishedGoodsGroup {
  manufacturing_order_id: string;
  manufacturing_order_no: string;
  sales_order_no: string | null;
  sales_order_id: string | null;
  customer_name: string | null;
  product_name: string | null;
  released_at: string | null;
  mo_status: string;
  lines: FinishedGoodLine[];
  totalLines: number;
  deliveredLines: number;
  readyLines: number;
}

export function useFinishedGoods() {
  const { activeOrganizationId } = useOrganizationContext();
  const [groups, setGroups] = useState<FinishedGoodsGroup[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const fetch = useCallback(async () => {
    if (!activeOrganizationId) { setGroups([]); return; }
    setLoading(true);
    setError(null);
    try {
      const { data, error: err } = await supabase
        .from('finished_goods_stock')
        .select('*')
        .eq('organization_id', activeOrganizationId)
        .order('released_at', { ascending: false });

      if (err) throw new Error(err.message);

      const byMO = new Map<string, FinishedGoodLine[]>();
      for (const row of (data ?? []) as FinishedGoodLine[]) {
        const key = row.manufacturing_order_id;
        if (!byMO.has(key)) byMO.set(key, []);
        byMO.get(key)!.push(row);
      }

      const result: FinishedGoodsGroup[] = [];
      for (const [moId, lines] of byMO) {
        const first = lines[0];
        result.push({
          manufacturing_order_id: moId,
          manufacturing_order_no: first.manufacturing_order_no,
          sales_order_no: first.sales_order_no,
          sales_order_id: first.sales_order_id,
          customer_name: first.customer_name,
          product_name: first.product_name,
          released_at: first.released_at,
          mo_status: first.mo_status,
          lines,
          totalLines: lines.length,
          deliveredLines: lines.filter((l) => l.delivery_status === 'delivered').length,
          readyLines: lines.filter((l) => l.delivery_status === 'ready').length,
        });
      }

      setGroups(result);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load finished goods');
    } finally {
      setLoading(false);
    }
  }, [activeOrganizationId]);

  useEffect(() => { fetch(); }, [fetch]);

  return { groups, loading, error, refetch: fetch };
}

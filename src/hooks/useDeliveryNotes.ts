import { useState, useCallback } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';
import { generateNextSequentialNumber } from '../lib/sequential-numbers';

export interface DeliveryNoteLine {
  id: string;
  delivery_note_id: string;
  mo_line_id: string;
  quantity_delivered: number;
  checked: boolean;
  checked_at: string | null;
  notes: string | null;
  mo_line?: {
    quantity: number;
    sales_order_line_id: string | null;
    SaleOrderLine?: {
      description: string | null;
      product_type: string | null;
      area: string | null;
      position: string | null;
      collection_name: string | null;
      variant_name: string | null;
      drive_type: string | null;
      width_m: number | null;
      height_m: number | null;
      CatalogItems?: { name: string; sku: string } | null;
    } | null;
  };
}

export interface DeliveryNote {
  id: string;
  organization_id: string;
  manufacturing_order_id: string;
  delivery_number: string;
  status: string;
  delivered_by_user_id: string | null;
  delivered_by_name: string | null;
  received_by_name: string | null;
  notes: string | null;
  created_at: string;
  completed_at: string | null;
}

export function useCreateDeliveryNote() {
  const { activeOrganizationId } = useOrganizationContext();
  const [isCreating, setIsCreating] = useState(false);

  const createDeliveryNote = useCallback(async (moId: string, userId: string, userName?: string) => {
    if (!activeOrganizationId) throw new Error('No organization selected');
    setIsCreating(true);
    try {
      const deliveryNumber = await generateNextSequentialNumber(
        'DN', 'DeliveryNotes', 'delivery_number', activeOrganizationId,
      );

      const { data: dn, error: dnErr } = await supabase
        .from('DeliveryNotes')
        .insert({
          organization_id: activeOrganizationId,
          manufacturing_order_id: moId,
          delivery_number: deliveryNumber,
          status: 'pending',
          delivered_by_user_id: userId,
          delivered_by_name: userName ?? null,
        })
        .select('id')
        .single();

      if (dnErr) throw new Error(dnErr.message);

      const { data: readyLines, error: rlErr } = await supabase
        .from('ManufacturingOrderLines')
        .select('id, quantity')
        .eq('manufacturing_order_id', moId)
        .eq('deleted', false)
        .eq('delivery_status', 'ready');

      if (rlErr) throw new Error(rlErr.message);

      if (readyLines && readyLines.length > 0) {
        const lines = readyLines.map((ml: any) => ({
          delivery_note_id: dn.id,
          mo_line_id: ml.id,
          quantity_delivered: ml.quantity,
          checked: false,
        }));
        const { error: lErr } = await supabase
          .from('DeliveryNoteLines')
          .insert(lines);
        if (lErr) throw new Error(lErr.message);
      }

      return { id: dn.id, delivery_number: deliveryNumber };
    } finally {
      setIsCreating(false);
    }
  }, [activeOrganizationId]);

  return { createDeliveryNote, isCreating };
}

export function useDeliveryNote(deliveryNoteId: string | null) {
  const [deliveryNote, setDeliveryNote] = useState<DeliveryNote | null>(null);
  const [lines, setLines] = useState<DeliveryNoteLine[]>([]);
  const [loading, setLoading] = useState(false);
  const [pendingLineUpdates, setPendingLineUpdates] = useState(0);

  const fetch = useCallback(async () => {
    if (!deliveryNoteId) return;
    setLoading(true);
    try {
      const { data: dn } = await supabase
        .from('DeliveryNotes')
        .select('*')
        .eq('id', deliveryNoteId)
        .eq('deleted', false)
        .single();

      if (dn) setDeliveryNote(dn as DeliveryNote);

      const { data: dnLines } = await supabase
        .from('DeliveryNoteLines')
        .select('*')
        .eq('delivery_note_id', deliveryNoteId)
        .order('created_at');

      if (dnLines && dnLines.length > 0) {
        const molIds = dnLines.map((l: any) => l.mo_line_id);
        const { data: mols } = await supabase
          .from('ManufacturingOrderLines')
          .select('id, quantity, sales_order_line_id')
          .in('id', molIds);

        const solIds = [...new Set((mols ?? []).map((m: any) => m.sales_order_line_id).filter(Boolean))];
        let solMap = new Map<string, any>();
        if (solIds.length > 0) {
          const { data: sols } = await supabase
            .from('SaleOrderLines')
            .select('id, description, product_type, area, position, collection_name, variant_name, width_m, height_m, catalog_item_id, quote_line_id')
            .in('id', solIds);
          if (sols) {
            const catIds = [...new Set(sols.map((s: any) => s.catalog_item_id).filter(Boolean))];
            let catMap = new Map<string, any>();
            if (catIds.length > 0) {
              const { data: cats } = await supabase.from('CatalogItems').select('id, name, sku').in('id', catIds);
              if (cats) catMap = new Map(cats.map((c: any) => [c.id, c]));
            }

            const qlIds = [...new Set(sols.map((s: any) => s.quote_line_id).filter(Boolean))];
            let qlMap = new Map<string, string>();
            if (qlIds.length > 0) {
              const { data: qls } = await supabase.from('QuoteLines').select('id, drive_type').in('id', qlIds);
              if (qls) qlMap = new Map(qls.map((q: any) => [q.id, q.drive_type]));
            }

            const ptCodes = [...new Set(sols.map((s: any) => s.product_type).filter(Boolean))];
            let ptNameMap = new Map<string, string>();
            if (ptCodes.length > 0) {
              const { data: pts } = await supabase
                .from('ProductTypes')
                .select('code, name')
                .in('code', ptCodes);
              if (pts) ptNameMap = new Map(pts.map((p: any) => [p.code, p.name]));
            }

            solMap = new Map(sols.map((s: any) => [s.id, {
              ...s,
              product_type: ptNameMap.get(s.product_type) ?? s.product_type ?? null,
              drive_type: s.quote_line_id ? qlMap.get(s.quote_line_id) ?? null : null,
              CatalogItems: s.catalog_item_id ? catMap.get(s.catalog_item_id) ?? null : null,
            }]));
          }
        }

        const molMap = new Map((mols ?? []).map((m: any) => [m.id, {
          ...m,
          SaleOrderLine: solMap.get(m.sales_order_line_id) ?? null,
        }]));

        setLines(dnLines.map((l: any) => ({
          ...l,
          mo_line: molMap.get(l.mo_line_id) ?? null,
        })));
      }
    } finally {
      setLoading(false);
    }
  }, [deliveryNoteId]);

  const toggleLine = useCallback(async (lineId: string, checked: boolean) => {
    const now = new Date().toISOString();
    const prevLine = lines.find((l) => l.id === lineId);

    setLines((prev) => prev.map((l) => l.id === lineId ? { ...l, checked, checked_at: checked ? now : null } : l));
    setPendingLineUpdates((n) => n + 1);
    try {
      const { error } = await supabase
        .from('DeliveryNoteLines')
        .update({ checked, checked_at: checked ? now : null })
        .eq('id', lineId);
      if (error) throw error;
    } catch (e) {
      // Revert optimistic update on failure so UI stays aligned with DB state.
      setLines((prev) =>
        prev.map((l) =>
          l.id === lineId
            ? {
                ...l,
                checked: prevLine?.checked ?? false,
                checked_at: prevLine?.checked_at ?? null,
              }
            : l
        )
      );
      throw e;
    } finally {
      setPendingLineUpdates((n) => Math.max(0, n - 1));
    }
  }, [lines]);

  const completeDelivery = useCallback(async (receivedByName: string, notes?: string) => {
    if (!deliveryNoteId) return null;

    if (receivedByName) {
      await supabase
        .from('DeliveryNotes')
        .update({ received_by_name: receivedByName, notes: notes ?? null, updated_at: new Date().toISOString() })
        .eq('id', deliveryNoteId);
    }

    const { data, error } = await supabase.rpc('complete_delivery_note', {
      p_delivery_note_id: deliveryNoteId,
    });

    if (error) throw new Error(error.message);
    const result = data as any;
    if (result && !result.ok) throw new Error(result.error || 'Failed to complete delivery');
    return result;
  }, [deliveryNoteId]);

  return { deliveryNote, lines, loading, refetch: fetch, toggleLine, completeDelivery, isUpdatingLine: pendingLineUpdates > 0 };
}

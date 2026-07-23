import { useState, useCallback } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';
import { generateNextSequentialNumber } from '../lib/sequential-numbers';

export interface DeliveryNoteLine {
  id: string;
  delivery_note_id: string;
  mo_line_id: string | null;
  sale_order_line_id: string | null;
  so_accessory_id: string | null;
  line_type: 'product' | 'supply' | 'accessory';
  quantity_delivered: number;
  checked: boolean;
  checked_at: string | null;
  notes: string | null;
  manufacturing_order_no?: string | null;
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
  supply_line?: {
    description: string | null;
    product_type: string | null;
    quantity: number;
    catalog_item_name: string | null;
    catalog_item_sku: string | null;
  } | null;
  accessory?: {
    catalog_item_name: string | null;
    catalog_item_sku: string | null;
    qty: number;
  } | null;
}

export interface DeliveryNote {
  id: string;
  organization_id: string;
  manufacturing_order_id: string | null;
  sales_order_id: string | null;
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

  const createDeliveryNote = useCallback(async (
    params: { moId?: string; salesOrderId?: string },
    userId: string,
    userName?: string,
  ) => {
    if (!activeOrganizationId) throw new Error('No organization selected');
    const { moId, salesOrderId } = params;
    if (!moId && !salesOrderId) throw new Error('moId or salesOrderId required');
    setIsCreating(true);
    try {
      let resolvedSoId = salesOrderId ?? null;

      if (!resolvedSoId && moId) {
        const { data: mo } = await supabase
          .from('ManufacturingOrders')
          .select('sales_order_id')
          .eq('id', moId)
          .single();
        resolvedSoId = mo?.sales_order_id ?? null;
      }

      // Idempotency: never create a second draft for the same order. If a
      // pending Delivery Note already exists (e.g. the create screen mounted
      // twice, or the user re-entered the flow), reuse it instead of spawning
      // a duplicate with a colliding number.
      {
        let existingQuery = supabase
          .from('DeliveryNotes')
          .select('id, delivery_number')
          .eq('organization_id', activeOrganizationId)
          .eq('status', 'pending')
          .eq('deleted', false)
          .order('created_at', { ascending: true })
          .limit(1);
        existingQuery = resolvedSoId
          ? existingQuery.eq('sales_order_id', resolvedSoId)
          : existingQuery.eq('manufacturing_order_id', moId ?? '');
        const { data: existing } = await existingQuery;
        const found = Array.isArray(existing) ? existing[0] : null;
        if (found) {
          return { id: found.id as string, delivery_number: found.delivery_number as string };
        }
      }

      const deliveryNumber = await generateNextSequentialNumber(
        'DN', 'DeliveryNotes', 'delivery_number', activeOrganizationId,
      );

      // Enforce the delivery gate at creation time: a Delivery Note cannot even be
      // started unless the Sales Order is fully invoiced and settled (or has an
      // active override). This mirrors complete_delivery_note so the invoice/payment
      // rules apply before any dispatch is prepared.
      if (resolvedSoId) {
        const { data: gateRows } = await supabase.rpc('get_sales_order_delivery_gate', {
          p_sales_order_id: resolvedSoId,
        });
        const gate = Array.isArray(gateRows) ? gateRows[0] : gateRows;
        if (gate && gate.delivery_allowed === false) {
          const balance = Number(gate.balance_due ?? 0);
          const fully = Boolean(gate.fully_invoiced);
          throw new Error(
            !fully
              ? 'Cannot create a Delivery Note: the sales order is not fully invoiced yet.'
              : `Cannot create a Delivery Note: balance due is $${balance.toFixed(2)}. The order must be fully paid or have a delivery override.`,
          );
        }
      }

      const { data: dn, error: dnErr } = await supabase
        .from('DeliveryNotes')
        .insert({
          organization_id: activeOrganizationId,
          sales_order_id: resolvedSoId,
          manufacturing_order_id: moId ?? null,
          delivery_number: deliveryNumber,
          status: 'pending',
          delivered_by_user_id: userId,
          delivered_by_name: userName ?? null,
        })
        .select('id')
        .single();

      if (dnErr) throw new Error(dnErr.message);

      const dnLines: any[] = [];

      if (salesOrderId) {
        // MO-backed lines (manufactured products)
        const { data: mos } = await supabase
          .from('ManufacturingOrders')
          .select('id')
          .eq('sales_order_id', salesOrderId)
          .eq('deleted', false)
          .in('status', ['ready_for_pickup', 'delivered']);

        if (mos && mos.length > 0) {
          const moIds = mos.map((m: any) => m.id);
          const { data: readyLines } = await supabase
            .from('ManufacturingOrderLines')
            .select('id, quantity')
            .in('manufacturing_order_id', moIds)
            .eq('deleted', false)
            .eq('delivery_status', 'ready');

          if (readyLines) {
            for (const ml of readyLines) {
              dnLines.push({
                delivery_note_id: dn.id,
                mo_line_id: ml.id,
                quantity_delivered: ml.quantity,
                checked: false,
                line_type: 'product',
              });
            }
          }
        }

        // Supply-only lines (catalog / window film)
        const { data: ptRows } = await supabase
          .from('ProductTypes')
          .select('code, fulfillment_type')
          .eq('organization_id', activeOrganizationId);
        const supplyOnlyCodes = new Set<string>();
        (ptRows ?? []).forEach((pt: any) => {
          if (pt.fulfillment_type === 'supply_only') supplyOnlyCodes.add(pt.code);
        });

        if (supplyOnlyCodes.size > 0) {
          const { data: supplyLines } = await supabase
            .from('SaleOrderLines')
            .select('id, quantity, product_type, catalog_item_id')
            .eq('sales_order_id', salesOrderId)
            .eq('deleted', false)
            .in('delivery_status', ['pending', 'ready']);

          // Physical readiness: a supply line linked to a product can only be
          // delivered once it is physically available (reserved from stock or
          // received against the SO). Service-style lines without a linked product
          // (e.g. Shipping) are non-physical and always deliverable.
          const { data: allocRows } = await supabase
            .from('InventoryAllocations')
            .select('catalog_item_id, allocated_qty, status')
            .eq('sales_order_id', salesOrderId)
            .eq('status', 'reserved');
          const reservedByItem = new Map<string, number>();
          for (const a of (allocRows ?? []) as { catalog_item_id: string; allocated_qty: number }[]) {
            reservedByItem.set(a.catalog_item_id, (reservedByItem.get(a.catalog_item_id) ?? 0) + Number(a.allocated_qty ?? 0));
          }

          if (supplyLines) {
            for (const sl of supplyLines as { id: string; quantity: number; product_type: string | null; catalog_item_id: string | null }[]) {
              if (!supplyOnlyCodes.has(sl.product_type ?? '')) continue;
              // Gate physical goods on availability; allow non-physical/service lines.
              if (sl.catalog_item_id) {
                const reserved = reservedByItem.get(sl.catalog_item_id) ?? 0;
                if (reserved < Number(sl.quantity ?? 0) - 1e-6) continue; // not yet available -> backorder
              }
              dnLines.push({
                delivery_note_id: dn.id,
                sale_order_line_id: sl.id,
                quantity_delivered: sl.quantity,
                checked: false,
                line_type: 'supply',
              });
            }
          }
        }
      } else if (moId) {
        const { data: readyLines } = await supabase
          .from('ManufacturingOrderLines')
          .select('id, quantity')
          .eq('manufacturing_order_id', moId)
          .eq('deleted', false)
          .eq('delivery_status', 'ready');

        if (readyLines) {
          for (const ml of readyLines) {
            dnLines.push({
              delivery_note_id: dn.id,
              mo_line_id: ml.id,
              quantity_delivered: ml.quantity,
              checked: false,
            });
          }
        }
      }

      // Nothing physically ready to deliver: don't leave an empty delivery note behind.
      if (salesOrderId && dnLines.length === 0) {
        await supabase.from('DeliveryNotes').delete().eq('id', dn.id);
        throw new Error('Nothing is ready to deliver yet: no manufactured or received items are available for this order.');
      }

      if (dnLines.length > 0) {
        const { error: lErr } = await supabase
          .from('DeliveryNoteLines')
          .insert(dnLines);
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
        const productLines = dnLines.filter((l: any) => l.mo_line_id);
        const supplyLines = dnLines.filter((l: any) => l.line_type === 'supply' && l.sale_order_line_id);
        const accessoryLineIds = dnLines.filter((l: any) => l.so_accessory_id).map((l: any) => l.so_accessory_id);

        // Resolve product lines (MOLines → SOLines → CatalogItems)
        const molIds = productLines.map((l: any) => l.mo_line_id);
        let molMap = new Map<string, any>();
        let moNoMap = new Map<string, string>();

        if (molIds.length > 0) {
          const { data: mols } = await supabase
            .from('ManufacturingOrderLines')
            .select('id, quantity, sales_order_line_id, manufacturing_order_id')
            .in('id', molIds);

          const moIds = [...new Set((mols ?? []).map((m: any) => m.manufacturing_order_id).filter(Boolean))];
          if (moIds.length > 0) {
            const { data: mosData } = await supabase
              .from('ManufacturingOrders')
              .select('id, manufacturing_order_no')
              .in('id', moIds);
            if (mosData) moNoMap = new Map(mosData.map((m: any) => [m.id, m.manufacturing_order_no]));
          }

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

          molMap = new Map((mols ?? []).map((m: any) => [m.id, {
            ...m,
            SaleOrderLine: solMap.get(m.sales_order_line_id) ?? null,
            manufacturing_order_no: moNoMap.get(m.manufacturing_order_id) ?? null,
          }]));
        }

        // Resolve accessory lines (SaleOrderAccessories → CatalogItems)
        let accMap = new Map<string, any>();
        if (accessoryLineIds.length > 0) {
          const { data: accessories } = await supabase
            .from('SaleOrderAccessories')
            .select('id, catalog_item_id, qty')
            .in('id', accessoryLineIds);

          if (accessories) {
            const accCatIds = [...new Set(accessories.map((a: any) => a.catalog_item_id).filter(Boolean))];
            let accCatMap = new Map<string, any>();
            if (accCatIds.length > 0) {
              const { data: cats } = await supabase.from('CatalogItems').select('id, name, sku').in('id', accCatIds);
              if (cats) accCatMap = new Map(cats.map((c: any) => [c.id, c]));
            }
            accMap = new Map(accessories.map((a: any) => [a.id, {
              catalog_item_name: accCatMap.get(a.catalog_item_id)?.name ?? null,
              catalog_item_sku: accCatMap.get(a.catalog_item_id)?.sku ?? null,
              qty: a.qty,
            }]));
          }
        }

        // Resolve supply lines (SaleOrderLines → CatalogItems)
        let supplyMap = new Map<string, any>();
        if (supplyLines.length > 0) {
          const supplySolIds = supplyLines.map((l: any) => l.sale_order_line_id);
          const { data: sols } = await supabase
            .from('SaleOrderLines')
            .select('id, description, product_type, quantity, catalog_item_id')
            .in('id', supplySolIds);

          if (sols) {
            const supplyCatIds = [...new Set(sols.map((s: any) => s.catalog_item_id).filter(Boolean))];
            let supplyCatMap = new Map<string, any>();
            if (supplyCatIds.length > 0) {
              const { data: cats } = await supabase.from('CatalogItems').select('id, name, sku').in('id', supplyCatIds);
              if (cats) supplyCatMap = new Map(cats.map((c: any) => [c.id, c]));
            }

            const ptCodes = [...new Set(sols.map((s: any) => s.product_type).filter(Boolean))];
            let ptNameMap = new Map<string, string>();
            if (ptCodes.length > 0) {
              const { data: pts } = await supabase.from('ProductTypes').select('code, name').in('code', ptCodes);
              if (pts) ptNameMap = new Map(pts.map((p: any) => [p.code, p.name]));
            }

            supplyMap = new Map(sols.map((s: any) => [s.id, {
              description: s.description,
              product_type: ptNameMap.get(s.product_type) ?? s.product_type ?? null,
              quantity: s.quantity,
              catalog_item_name: supplyCatMap.get(s.catalog_item_id)?.name ?? null,
              catalog_item_sku: supplyCatMap.get(s.catalog_item_id)?.sku ?? null,
            }]));
          }
        }

        setLines(dnLines.map((l: any) => {
          const molData = l.mo_line_id ? molMap.get(l.mo_line_id) : null;
          return {
            ...l,
            line_type: l.line_type ?? (l.so_accessory_id ? 'accessory' : 'product'),
            manufacturing_order_no: molData?.manufacturing_order_no ?? null,
            mo_line: molData ? { ...molData } : null,
            supply_line: l.sale_order_line_id ? supplyMap.get(l.sale_order_line_id) ?? null : null,
            accessory: l.so_accessory_id ? accMap.get(l.so_accessory_id) ?? null : null,
          };
        }));
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

  const toggleAllLines = useCallback(async (checked: boolean) => {
    if (!deliveryNoteId) return;
    const now = new Date().toISOString();
    const prev = lines;
    // Optimistic: flip every line at once.
    setLines((p) => p.map((l) => ({ ...l, checked, checked_at: checked ? now : null })));
    setPendingLineUpdates((n) => n + 1);
    try {
      const { error } = await supabase
        .from('DeliveryNoteLines')
        .update({ checked, checked_at: checked ? now : null })
        .eq('delivery_note_id', deliveryNoteId);
      if (error) throw error;
    } catch (e) {
      setLines(prev); // revert to the exact previous state on failure
      throw e;
    } finally {
      setPendingLineUpdates((n) => Math.max(0, n - 1));
    }
  }, [deliveryNoteId, lines]);

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

  return { deliveryNote, lines, loading, refetch: fetch, toggleLine, toggleAllLines, completeDelivery, isUpdatingLine: pendingLineUpdates > 0 };
}

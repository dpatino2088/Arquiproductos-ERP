import { useEffect, useState, useCallback, useRef } from 'react';
import { router } from '../../lib/router';
import { supabase } from '../../lib/supabase/client';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useFilteredMfgSubmodules } from './manufacturingSubmodules';
import { useAuth } from '../../hooks/useAuth';
import { useUIStore } from '../../stores/ui-store';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useCreateDeliveryNote, useDeliveryNote } from '../../hooks/useDeliveryNotes';
import { useManufacturingOrder } from '../../hooks/useManufacturing';
import StatusBadge from '../../components/shared/StatusBadge';
import { ArrowLeft, CheckCircle2, Circle, Truck, Package, FileText, Download } from 'lucide-react';
import { formatDate } from '../../lib/utils';
import { generateDeliveryNotePDF } from '../../lib/pdf/generateDeliveryNotePDF';
import type { DeliveryNotePDFLine, DeliveryNotePDFData, DeliveryNotePDFOptions } from '../../lib/pdf/generateDeliveryNotePDF';
import { getAppUsersDisplayNames } from '../../lib/appUsersDisplayNames';

const STORAGE_BUCKET = 'mo-attachments';

export default function DeliveryNoteDetail() {
  const filteredSubmodules = useFilteredMfgSubmodules();
  const { registerSubmodules } = useSubmoduleNav();
  const { user } = useAuth();
  const { activeOrganizationId } = useOrganizationContext();
  const addNotification = useUIStore((s) => s.addNotification);
  const { createDeliveryNote, isCreating } = useCreateDeliveryNote();

  const pathParts = window.location.pathname.split('/');
  const pathId = pathParts[pathParts.length - 1];
  const isExistingDN = pathId && pathId !== 'new' && !pathId.includes('?');

  const [deliveryNoteId, setDeliveryNoteId] = useState<string | null>(isExistingDN ? pathId : null);
  const [receivedBy, setReceivedBy] = useState('');
  const [deliveryNotes, setDeliveryNotes] = useState('');
  const [completing, setCompleting] = useState(false);
  const [pdfUrl, setPdfUrl] = useState<string | null>(null);
  const [resolvedOrderInfo, setResolvedOrderInfo] = useState<{
    soNo: string | null; moNo: string | null; claimNo: string | null;
    claimDetail: string | null; customerName: string | null;
  } | null>(null);

  const { deliveryNote, lines, loading, refetch, toggleLine, toggleAllLines, completeDelivery, isUpdatingLine } = useDeliveryNote(deliveryNoteId);

  const params = new URLSearchParams(window.location.search);
  const moIdParam = params.get('mo_id');
  const soIdParam = params.get('so_id');

  const { manufacturingOrder: mo } = useManufacturingOrder(moIdParam ?? deliveryNote?.manufacturing_order_id ?? null);

  useEffect(() => {
    if (mo) return;
    const soId = deliveryNote?.sales_order_id ?? soIdParam;
    if (!soId) return;
    (async () => {
      const { data: soData } = await supabase
        .from('SalesOrders')
        .select('sales_order_no, DirectoryCustomers:customer_id(customer_name)')
        .eq('id', soId)
        .single();
      const { data: moData } = await supabase
        .from('ManufacturingOrders')
        .select('manufacturing_order_no, claim_id')
        .eq('sales_order_id', soId)
        .eq('deleted', false)
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle();
      let claimNo: string | null = null;
      let claimDetail: string | null = null;
      if (moData?.claim_id) {
        const { data: claimData } = await supabase
          .from('ServiceClaims')
          .select('claim_no, claim_type, resolution_type, description')
          .eq('id', moData.claim_id)
          .single();
        claimNo = claimData?.claim_no ?? null;
        if (claimData) {
          const typeLabels: Record<string, string> = {
            defect: 'Mfg. Defect', damage: 'Damage', wrong_size: 'Wrong Size',
            wrong_color: 'Wrong Color', missing_parts: 'Missing Parts', other: 'Other',
          };
          const resLabels: Record<string, string> = {
            repair: 'Repair', replace: 'Replacement', credit: 'Credit', none: '',
          };
          const parts: string[] = [];
          if (claimData.claim_type) parts.push(typeLabels[claimData.claim_type] ?? claimData.claim_type);
          if (claimData.resolution_type && claimData.resolution_type !== 'none')
            parts.push(resLabels[claimData.resolution_type] ?? claimData.resolution_type);
          if (claimData.description) parts.push(claimData.description);
          claimDetail = parts.join(' — ') || null;
        }
      }
      setResolvedOrderInfo({
        soNo: (soData as any)?.sales_order_no ?? null,
        moNo: moData?.manufacturing_order_no ?? null,
        claimNo,
        claimDetail,
        customerName: (soData as any)?.DirectoryCustomers?.customer_name ?? null,
      });
    })();
  }, [mo, deliveryNote?.sales_order_id, soIdParam]);

  useEffect(() => {
    registerSubmodules('Manufacturing', filteredSubmodules);
  }, [registerSubmodules, filteredSubmodules]);

  const creatingRef = useRef(false);
  useEffect(() => {
    // Wait for the organization context to hydrate before creating; otherwise
    // createDeliveryNote throws "No organization selected". The ref guards against
    // React double-invoking the effect and creating two notes.
    if (
      !deliveryNoteId &&
      user?.id &&
      activeOrganizationId &&
      (moIdParam || soIdParam) &&
      !creatingRef.current
    ) {
      creatingRef.current = true;
      createDeliveryNote(
        { moId: moIdParam ?? undefined, salesOrderId: soIdParam ?? undefined },
        user.id,
        user.name,
      )
        .then((result) => {
          setDeliveryNoteId(result.id);
          addNotification({ type: 'success', title: 'Delivery Note Created', message: result.delivery_number });
        })
        .catch((e) => {
          creatingRef.current = false; // allow a retry on transient failure
          addNotification({ type: 'error', title: 'Error', message: e.message });
        });
    }
  }, [moIdParam, soIdParam, deliveryNoteId, user?.id, activeOrganizationId]);

  useEffect(() => { if (deliveryNoteId) refetch(); }, [deliveryNoteId, refetch]);

  const checkedCount = lines.filter((l) => l.checked).length;
  const totalCount = lines.length;
  const allChecked = totalCount > 0 && checkedCount === totalCount;
  const someChecked = checkedCount > 0;
  const isCompleted = deliveryNote?.status === 'completed' || deliveryNote?.status === 'partial';

  const handleToggleAll = useCallback(() => {
    if (isCompleted || totalCount === 0) return;
    void toggleAllLines(!allChecked).catch((e: unknown) => {
      addNotification({
        type: 'error',
        title: 'Error',
        message: e instanceof Error ? e.message : 'Failed to update delivery lines',
      });
    });
  }, [isCompleted, totalCount, allChecked, toggleAllLines, addNotification]);

  const loadLogoOptions = useCallback(async (): Promise<DeliveryNotePDFOptions> => {
    let organizationName = 'Arquiproductos';
    if (activeOrganizationId) {
      const { data: orgData } = await supabase
        .from('Organizations').select('name').eq('id', activeOrganizationId).maybeSingle();
      organizationName = (orgData as { name?: string } | null)?.name ?? 'Arquiproductos';
    }
    const tryLogo = async (path: string): Promise<string | undefined> => {
      try {
        const res = await fetch(path, { cache: 'no-store' });
        if (!res.ok) return undefined;
        const blob = await res.blob();
        return await new Promise<string>((resolve, reject) => {
          const reader = new FileReader();
          reader.onloadend = () => resolve(reader.result as string);
          reader.onerror = reject;
          reader.readAsDataURL(blob);
        });
      } catch { return undefined; }
    };
    let logoPngBase64: string | undefined;
    for (const p of ['/images/Arquiproductos.png', '/images/arquiproductos.png', '/images/Arquiproductos.jpg']) {
      logoPngBase64 = await tryLogo(p);
      if (logoPngBase64) break;
    }
    let logoWidthPx = 100, logoHeightPx = 100;
    if (logoPngBase64) {
      const dims = await new Promise<{ w: number; h: number }>((resolve) => {
        const img = new Image();
        img.onload = () => resolve({ w: img.naturalWidth, h: img.naturalHeight });
        img.onerror = () => resolve({ w: 100, h: 100 });
        img.src = logoPngBase64!;
      });
      logoWidthPx = dims.w; logoHeightPx = dims.h;
    }
    return { logoPngBase64, logoWidthPx, logoHeightPx, organizationName };
  }, [activeOrganizationId]);

  const buildPDF = useCallback(async () => {
    if (!deliveryNote) return null;

    let deliveredByDisplay = deliveryNote.delivered_by_name;
    if (deliveryNote.delivered_by_user_id) {
      const names = await getAppUsersDisplayNames([deliveryNote.delivered_by_user_id]);
      deliveredByDisplay = names.get(deliveryNote.delivered_by_user_id) ?? deliveredByDisplay;
    }

    const customerName = mo?.SalesOrders?.DirectoryCustomers?.customer_name
      ?? resolvedOrderInfo?.customerName ?? null;

    const pdfData: DeliveryNotePDFData = {
      delivery_number: deliveryNote.delivery_number,
      status: deliveryNote.status as 'completed' | 'partial' | 'pending',
      mo_number: mo?.manufacturing_order_no ?? resolvedOrderInfo?.moNo ?? null,
      so_number: mo?.SalesOrders?.sales_order_no ?? resolvedOrderInfo?.soNo ?? null,
      claim_no: resolvedOrderInfo?.claimNo ?? null,
      claim_detail: resolvedOrderInfo?.claimDetail ?? null,
      delivered_by: deliveredByDisplay,
      received_by: deliveryNote.received_by_name,
      notes: deliveryNote.notes,
      completed_at: deliveryNote.completed_at,
      created_at: deliveryNote.created_at,
      checked_count: lines.filter((l) => l.checked).length,
      total_count: lines.length,
      customer_name: customerName,
      contact_name: deliveryNote.received_by_name,
    };

    const pdfLines: DeliveryNotePDFLine[] = lines.map((l) => {
      if (l.line_type === 'accessory') {
        return {
          product_name: l.accessory?.catalog_item_name ?? 'Accessory',
          area: null,
          position: null,
          measurements: null,
          product_type: 'Accessory',
          qty: l.quantity_delivered,
          checked: l.checked,
        };
      }
      if (l.line_type === 'supply') {
        return {
          product_name: l.supply_line?.catalog_item_name ?? l.supply_line?.description ?? 'Supply Item',
          area: null,
          position: null,
          measurements: l.supply_line?.catalog_item_sku ? `SKU: ${l.supply_line.catalog_item_sku}` : null,
          product_type: l.supply_line?.product_type ?? 'Supply',
          qty: l.quantity_delivered,
          checked: l.checked,
        };
      }
      const sol = l.mo_line?.SaleOrderLine;
      const descParts: string[] = [];
      const collVar = sol?.collection_name && sol?.variant_name
        ? `${sol.collection_name} - ${sol.variant_name}`
        : sol?.collection_name ?? sol?.variant_name ?? '';
      const skuPart = sol?.CatalogItems?.sku ? ` (${sol.CatalogItems.sku})` : '';
      if (collVar) descParts.push(`${collVar}${skuPart}`);
      if (sol?.drive_type) {
        descParts.push(sol.drive_type === 'motor' ? 'Motorized' : sol.drive_type === 'manual' ? 'Manual' : sol.drive_type);
      }
      const productName = descParts.length > 0 ? descParts.join('\n') : (sol?.CatalogItems?.name ?? sol?.description ?? 'Item');
      const meas = sol?.width_m && sol?.height_m
        ? `${Math.round(Number(sol.width_m) * 1000)} x ${Math.round(Number(sol.height_m) * 1000)}`
        : null;
      return {
        product_name: productName,
        area: sol?.area ?? null,
        position: sol?.position ?? null,
        measurements: meas,
        product_type: sol?.product_type ?? null,
        qty: l.quantity_delivered,
        checked: l.checked,
      };
    });

    const logoOpts = await loadLogoOptions();
    return generateDeliveryNotePDF(pdfData, pdfLines, logoOpts);
  }, [deliveryNote, mo, lines, loadLogoOptions, resolvedOrderInfo]);

  const uploadPdfToAttachments = useCallback(async (pdfBlob: Blob, fileName: string) => {
    if (!deliveryNote || !activeOrganizationId || !user) return;
    const moId = deliveryNote.manufacturing_order_id;
    const subPath = moId ? `mo/${moId}` : `so/${deliveryNote.sales_order_id ?? 'orphan'}`;
    const filePath = `${activeOrganizationId}/${subPath}/${Date.now()}-${fileName}`;
    try {
      const { error: uploadErr } = await supabase.storage
        .from(STORAGE_BUCKET)
        .upload(filePath, pdfBlob, { cacheControl: '3600', upsert: false, contentType: 'application/pdf' });
      if (uploadErr) throw uploadErr;
      if (moId) {
        const { error: insertErr } = await supabase
          .from('manufacturing_order_attachments')
          .insert({
            manufacturing_order_id: moId,
            organization_id: activeOrganizationId,
            file_name: fileName,
            file_path: filePath,
            file_size: pdfBlob.size,
            content_type: 'application/pdf',
            uploaded_by: user.id,
          });
        if (insertErr) throw insertErr;
      }
    } catch (err: unknown) {
      console.error('Failed to upload delivery PDF:', err);
    }
  }, [deliveryNote, activeOrganizationId, user]);

  const handleComplete = useCallback(async () => {
    if (!someChecked) return;
    setCompleting(true);
    try {
      const result = await completeDelivery(receivedBy, deliveryNotes);
      addNotification({
        type: 'success',
        title: 'Delivery Completed',
        message: `${result.checked_count}/${result.total_count} lines delivered${result.mo_delivered ? ' — MO marked as Delivered' : ''}`,
      });
      await refetch();

      try {
        const doc = await buildPDF();
        if (doc && deliveryNote) {
          const blob = doc.output('blob');
          const fileName = `${deliveryNote.delivery_number}.pdf`;
          const url = URL.createObjectURL(blob);
          setPdfUrl(url);
          await uploadPdfToAttachments(blob, fileName);
          addNotification({ type: 'success', title: 'PDF Generated', message: 'Delivery note PDF saved to MO attachments.' });
        }
      } catch (pdfErr: unknown) {
        console.error('PDF generation/upload failed:', pdfErr);
      }
    } catch (e: unknown) {
      addNotification({ type: 'error', title: 'Error', message: e instanceof Error ? e.message : 'Failed' });
    } finally {
      setCompleting(false);
    }
  }, [someChecked, receivedBy, deliveryNotes, completeDelivery, refetch, addNotification, buildPDF, uploadPdfToAttachments, deliveryNote]);

  if (loading || isCreating) {
    return (
      <div className="space-y-4 p-6">
        <div className="animate-pulse space-y-4">
          <div className="h-8 bg-gray-200 rounded w-48" />
          <div className="h-64 bg-gray-200 rounded" />
        </div>
      </div>
    );
  }

  if (!deliveryNote && !isCreating && !moIdParam && !soIdParam) {
    return (
      <div className="p-6">
        <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4 text-sm text-yellow-800">
          No delivery note specified. Go to Finished Goods to create one.
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <button
            type="button"
            onClick={() => router.navigate('/manufacturing/finished-goods')}
            className="p-1 text-gray-500 hover:text-gray-900 hover:bg-gray-100 rounded"
          >
            <ArrowLeft className="w-5 h-5" />
          </button>
          <div>
            <h2 className="text-lg font-bold text-gray-900">
              {deliveryNote?.delivery_number ?? 'Creating...'}
            </h2>
            <div className="flex items-center gap-2 text-sm text-gray-500">
              {mo && (
                <>
                  <button
                    type="button"
                    onClick={() => router.navigate(`/manufacturing/manufacturing-orders/${mo.id}`)}
                    className="text-primary hover:underline"
                  >
                    {mo.manufacturing_order_no}
                  </button>
                  {mo.product_name && <span>· {mo.product_name}</span>}
                </>
              )}
            </div>
          </div>
        </div>
        <div className="flex items-center gap-2">
          {deliveryNote && (
            <span className={`inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium ${
              deliveryNote.status === 'completed' ? 'bg-green-100 text-green-800' :
              deliveryNote.status === 'partial' ? 'bg-amber-100 text-amber-800' :
              'bg-gray-100 text-gray-600'
            }`}>
              {deliveryNote.status === 'completed' ? 'Completed' :
               deliveryNote.status === 'partial' ? 'Partial Delivery' : 'Pending'}
            </span>
          )}
        </div>
      </div>

      {/* Lines with checkboxes */}
      <div className="rounded-lg border border-gray-200 bg-white overflow-hidden">
        <div className="px-4 py-3 bg-gray-50 border-b border-gray-200 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Package className="w-4 h-4 text-gray-500" />
            <span className="text-sm font-medium text-gray-700">Delivery Lines</span>
          </div>
          <div className="flex items-center gap-3">
            {!isCompleted && totalCount > 0 && (
              <button
                type="button"
                onClick={handleToggleAll}
                disabled={isUpdatingLine}
                className="inline-flex items-center gap-1.5 px-2.5 py-1 text-xs font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50 disabled:opacity-50"
              >
                {allChecked ? (
                  <CheckCircle2 className="w-3.5 h-3.5 text-green-600" />
                ) : (
                  <Circle className="w-3.5 h-3.5 text-gray-400" />
                )}
                {allChecked ? 'Deselect all' : 'Select all'}
              </button>
            )}
            <span className="text-xs text-gray-500">
              {checkedCount}/{totalCount} checked
            </span>
          </div>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b">
              <tr>
                <th className="px-3 py-2 w-10 text-center">
                  {!isCompleted && totalCount > 0 && (
                    <input
                      type="checkbox"
                      aria-label="Select all lines"
                      className="rounded border-gray-300 cursor-pointer"
                      checked={allChecked}
                      ref={(el) => { if (el) el.indeterminate = someChecked && !allChecked; }}
                      onChange={handleToggleAll}
                      disabled={isUpdatingLine}
                    />
                  )}
                </th>
                <th className="px-3 py-2 text-left font-medium text-gray-600 text-xs">Area</th>
                <th className="px-3 py-2 text-center font-medium text-gray-600 text-xs">Position</th>
                <th className="px-3 py-2 text-left font-medium text-gray-600 text-xs">Description</th>
                <th className="px-3 py-2 text-left font-medium text-gray-600 text-xs">Measurements</th>
                <th className="px-3 py-2 text-center font-medium text-gray-600 text-xs">Product type</th>
                <th className="px-3 py-2 text-right font-medium text-gray-600 text-xs">Qty</th>
                <th className="px-3 py-2 text-center font-medium text-gray-600 text-xs">Status</th>
              </tr>
            </thead>
            <tbody>
              {lines.length === 0 ? (
                <tr><td colSpan={8} className="px-4 py-8 text-center text-gray-500">No lines</td></tr>
              ) : (
                lines.map((line) => {
                  const isAccessory = line.line_type === 'accessory';
                  const isSupply = line.line_type === 'supply';
                  const sol = line.mo_line?.SaleOrderLine;

                  let descParts: string[] = [];
                  if (isAccessory) {
                    descParts = [line.accessory?.catalog_item_name ?? 'Accessory'];
                    if (line.accessory?.catalog_item_sku) {
                      descParts[0] += ` (${line.accessory.catalog_item_sku})`;
                    }
                  } else if (isSupply) {
                    const name = line.supply_line?.catalog_item_name ?? line.supply_line?.description ?? 'Supply Item';
                    descParts = [name];
                    if (line.supply_line?.catalog_item_sku) {
                      descParts.push(line.supply_line.catalog_item_sku);
                    }
                  } else {
                    const collVar = sol?.collection_name && sol?.variant_name
                      ? `${sol.collection_name} - ${sol.variant_name}`
                      : sol?.collection_name ?? sol?.variant_name ?? '';
                    const skuTag = sol?.CatalogItems?.sku ? ` (${sol.CatalogItems.sku})` : '';
                    if (collVar) descParts.push(`${collVar}${skuTag}`);
                    if (sol?.drive_type) {
                      descParts.push(sol.drive_type === 'motor' ? 'Motorized' : sol.drive_type === 'manual' ? 'Manual' : sol.drive_type);
                    }
                    if (descParts.length === 0) {
                      descParts.push(sol?.CatalogItems?.name ?? sol?.description ?? 'Item');
                    }
                  }

                  const rowBg = line.checked
                    ? 'bg-green-50/50'
                    : isAccessory
                      ? 'bg-amber-50/30'
                      : isSupply
                        ? 'bg-blue-50/30'
                        : '';

                  return (
                    <tr
                      key={line.id}
                      className={`border-t hover:bg-gray-50 ${rowBg}`}
                    >
                      <td className="px-3 py-3 text-center">
                        <button
                          type="button"
                          onClick={() => {
                            if (isCompleted) return;
                            void toggleLine(line.id, !line.checked).catch((e: unknown) => {
                              addNotification({
                                type: 'error',
                                title: 'Error',
                                message: e instanceof Error ? e.message : 'Failed to update delivery line',
                              });
                            });
                          }}
                          disabled={isCompleted || isUpdatingLine}
                          className="disabled:opacity-50"
                        >
                          {line.checked ? (
                            <CheckCircle2 className="w-5 h-5 text-green-600" />
                          ) : (
                            <Circle className="w-5 h-5 text-gray-300" />
                          )}
                        </button>
                      </td>
                      <td className="px-3 py-3 text-gray-700">
                        {isAccessory ? (
                          <span className="inline-flex items-center px-1.5 py-0.5 rounded text-[10px] font-medium bg-amber-100 text-amber-700">ACC</span>
                        ) : isSupply ? (
                          <span className="inline-flex items-center px-1.5 py-0.5 rounded text-[10px] font-medium bg-blue-100 text-blue-700">SUPPLY</span>
                        ) : (
                          sol?.area ?? '—'
                        )}
                      </td>
                      <td className="px-3 py-3 text-center text-gray-700">
                        {(isAccessory || isSupply) ? '—' : (sol?.position ?? '—')}
                      </td>
                      <td className="px-3 py-3">
                        {descParts.map((part, i) => (
                          <div key={i} className={i === 0 ? 'font-medium text-gray-900' : 'text-xs text-gray-500'}>{part}</div>
                        ))}
                        {!isAccessory && !isSupply && line.manufacturing_order_no && (
                          <div className="text-[10px] text-gray-400 mt-0.5">{line.manufacturing_order_no}</div>
                        )}
                      </td>
                      <td className="px-3 py-3 text-gray-600 text-sm tabular-nums">
                        {!isAccessory && !isSupply && sol?.width_m && sol?.height_m
                          ? `${Math.round(Number(sol.width_m) * 1000)} x ${Math.round(Number(sol.height_m) * 1000)}`
                          : '—'}
                      </td>
                      <td className="px-3 py-3 text-center text-gray-600 text-xs">
                        {isAccessory ? 'Accessory' : isSupply ? (line.supply_line?.product_type ?? 'Supply') : (sol?.product_type ?? '—')}
                      </td>
                      <td className="px-3 py-3 text-right tabular-nums">{line.quantity_delivered}</td>
                      <td className="px-3 py-3 text-center">
                        {line.checked ? (
                          <span className="text-xs text-green-700 font-medium">Checked</span>
                        ) : (
                          <span className="text-xs text-gray-400">Pending</span>
                        )}
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Completion section */}
      {!isCompleted && lines.length > 0 && (
        <div className="rounded-lg border border-gray-200 bg-white p-4 space-y-4">
          <h3 className="text-sm font-semibold text-gray-900">Complete Delivery</h3>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-xs font-medium text-gray-600 mb-1">Received by</label>
              <input
                type="text"
                value={receivedBy}
                onChange={(e) => setReceivedBy(e.target.value)}
                placeholder="Name of person receiving goods..."
                className="w-full px-3 py-2 text-sm border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-200"
              />
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-600 mb-1">Notes</label>
              <input
                type="text"
                value={deliveryNotes}
                onChange={(e) => setDeliveryNotes(e.target.value)}
                placeholder="Optional delivery notes..."
                className="w-full px-3 py-2 text-sm border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-200"
              />
            </div>
          </div>

          {!allChecked && someChecked && (
            <div className="flex items-center gap-2 px-3 py-2 rounded-md bg-amber-50 border border-amber-100 text-xs text-amber-700">
              <span className="inline-block w-1.5 h-1.5 rounded-full bg-amber-400" />
              {checkedCount} of {totalCount} lines checked. This will be recorded as a partial delivery.
            </div>
          )}

          <div className="flex items-center gap-3">
            <button
              type="button"
              onClick={handleComplete}
              disabled={!someChecked || completing || isUpdatingLine}
              className="inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-primary rounded-lg hover:bg-primary/90 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <Truck className="w-4 h-4" />
              {completing
                ? 'Processing...'
                : isUpdatingLine
                ? 'Saving lines...'
                : allChecked
                ? 'Complete Delivery'
                : `Deliver ${checkedCount} of ${totalCount} lines`}
            </button>
            <button
              type="button"
              onClick={() => router.navigate('/manufacturing/finished-goods')}
              className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50"
            >
              Cancel
            </button>
          </div>
        </div>
      )}

      {/* Completed info */}
      {isCompleted && (
        <div className={`rounded-lg border p-4 ${
          deliveryNote?.status === 'completed' ? 'border-green-200 bg-green-50' : 'border-amber-200 bg-amber-50'
        }`}>
          <div className={`flex items-center gap-2 text-sm font-medium ${
            deliveryNote?.status === 'completed' ? 'text-green-800' : 'text-amber-800'
          }`}>
            {deliveryNote?.status === 'completed' ? (
              <CheckCircle2 className="w-4 h-4" />
            ) : (
              <Package className="w-4 h-4" />
            )}
            {deliveryNote?.status === 'completed' ? 'All lines delivered' : 'Partial delivery completed'}
          </div>
          <div className="mt-2 text-xs text-gray-600 space-y-1">
            {deliveryNote?.received_by_name && <div>Received by: {deliveryNote.received_by_name}</div>}
            {deliveryNote?.completed_at && <div>Completed: {formatDate(deliveryNote.completed_at)}</div>}
            {deliveryNote?.notes && <div>Notes: {deliveryNote.notes}</div>}
          </div>
          <div className="mt-3 flex items-center gap-2">
            <button
              type="button"
              className="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium text-blue-700 bg-blue-100 hover:bg-blue-200 rounded-md transition"
              onClick={async () => {
                const doc = await buildPDF();
                if (!doc) return;
                const blob = doc.output('blob');
                const url = URL.createObjectURL(blob);
                setPdfUrl(url);
                window.open(url, '_blank');
              }}
            >
              <FileText className="w-3.5 h-3.5" />
              View PDF
            </button>
            <button
              type="button"
              className="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium text-gray-700 bg-gray-100 hover:bg-gray-200 rounded-md transition"
              onClick={async () => {
                const doc = await buildPDF();
                if (!doc || !deliveryNote) return;
                doc.save(`${deliveryNote.delivery_number}.pdf`);
              }}
            >
              <Download className="w-3.5 h-3.5" />
              Download PDF
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

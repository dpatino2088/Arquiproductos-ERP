import { useState, useEffect, useCallback, useMemo } from 'react';
import { supabase } from '../../lib/supabase/client';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useAuth } from '../../hooks/useAuth';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useUIStore } from '../../stores/ui-store';
import { useCostSettings } from '../../hooks/useCosts';
import { generateNextInvoiceNumber } from '../../lib/sequential-numbers';
import { router } from '../../lib/router';
import { getReturnToFromCurrentQuery, navigateBackContextual, withReturnTo } from '../../lib/navigation/returnTo';
import { ArrowLeft, Plus, Trash2 } from 'lucide-react';
import { usePermissions } from '../../hooks/usePermissions';
import { FINANCIAL_GROUP_TABS } from './financialSubmodules';

interface DealerOption {
  id: string;
  dealer_name: string;
  dealer_no: string | null;
  dealer_email: string | null;
  dealer_phone: string | null;
  identification_number: string | null;
  billing_same_as_location: boolean;
  street_address_line_1: string | null;
  street_address_line_2: string | null;
  city: string | null;
  state: string | null;
  zip_code: string | null;
  country: string | null;
  billing_street_address_line_1: string | null;
  billing_street_address_line_2: string | null;
  billing_city: string | null;
  billing_state: string | null;
  billing_zip_code: string | null;
  billing_country: string | null;
  is_tax_retention_agent: boolean | null;
  tax_retention_rate: number | null;
}

interface InvoiceLine {
  key: string;
  description: string;
  qty: number;
  unit_price: number;
  base_subtotal: number;
  billing_percent: number;
  billing_amount: number;
}

interface SalesOrderOption {
  id: string;
  sales_order_no: string;
  subtotal: number | null;
  total_amount: number | null;
  tax_amount: number | null;
  status: string | null;
}

type SoPrefillSource = 'billable_remaining' | 'so_total_fallback';

function getQueryParam(name: string): string | null {
  const url = new URL(window.location.href);
  return url.searchParams.get(name);
}

function formatAddress(d: DealerOption): string {
  const useBilling = !d.billing_same_as_location;
  const street1 = useBilling ? d.billing_street_address_line_1 : d.street_address_line_1;
  const street2 = useBilling ? d.billing_street_address_line_2 : d.street_address_line_2;
  const city = useBilling ? d.billing_city : d.city;
  const state = useBilling ? d.billing_state : d.state;
  const zip = useBilling ? d.billing_zip_code : d.zip_code;
  const country = useBilling ? d.billing_country : d.country;
  const parts: string[] = [];
  if (street1) parts.push(street1);
  if (street2) parts.push(street2);
  const cityLine = [city, state, zip].filter(Boolean).join(', ');
  if (cityLine) parts.push(cityLine);
  if (country) parts.push(country);
  return parts.join('\n') || '—';
}

let lineKeyCounter = 0;
function newLineKey(): string {
  return `line-${++lineKeyCounter}-${Date.now()}`;
}

function safeNumber(value: unknown, fallback = 0): number {
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

export default function InvoiceNew() {
  const { activeOrganizationId } = useOrganizationContext();
  const { user } = useAuth();
  const { registerSubmodules } = useSubmoduleNav();
  const addNotification = useUIStore((s) => s.addNotification);
  const { hasAnyPermission } = usePermissions();
  const canCreateInvoice = hasAnyPermission([
    'financials.invoices.write',
  ]);
  const { settings: costSettings } = useCostSettings();
  const defaultTaxPct = costSettings?.tax_pct ?? 0.07;
  const [taxExempt, setTaxExempt] = useState(false);
  const [soTaxPct, setSoTaxPct] = useState<number | null>(null);
  const appliedTaxPct = taxExempt ? 0 : (soTaxPct ?? defaultTaxPct);

  const [invoiceNumber, setInvoiceNumber] = useState('');
  const [dealers, setDealers] = useState<DealerOption[]>([]);
  const [selectedDealerId, setSelectedDealerId] = useState('');
  const [dealerSearch, setDealerSearch] = useState('');
  const [showDealerDropdown, setShowDealerDropdown] = useState(false);
  const [issueDate, setIssueDate] = useState(() => new Date().toISOString().slice(0, 10));
  const [dueDate, setDueDate] = useState(() => {
    const d = new Date();
    d.setDate(d.getDate() + 30);
    return d.toISOString().slice(0, 10);
  });
  const [currency, setCurrency] = useState('USD');
  const [notes, setNotes] = useState('');
  const [lines, setLines] = useState<InvoiceLine[]>([{
    key: newLineKey(),
    description: '',
    qty: 1,
    unit_price: 0,
    base_subtotal: 0,
    billing_percent: 100,
    billing_amount: 0,
  }]);
  const [salesOrderId, setSalesOrderId] = useState<string | null>(null);
  const [salesOrderNo, setSalesOrderNo] = useState<string | null>(null);
  const [salesOrders, setSalesOrders] = useState<SalesOrderOption[]>([]);
  const [loadingSalesOrders, setLoadingSalesOrders] = useState(false);
  const [saving, setSaving] = useState(false);
  const [loadingSO, setLoadingSO] = useState(false);
  const [prefillInfo, setPrefillInfo] = useState<{
    source: SoPrefillSource;
    targetAmount: number;
    billableRemaining: number;
    soTaxPct: number;
  } | null>(null);
  const listPath = '/financials/invoices';
  const queryReturnTo = getReturnToFromCurrentQuery();

  useEffect(() => { registerSubmodules('Financials', FINANCIAL_GROUP_TABS); }, [registerSubmodules]);

  useEffect(() => {
    if (!activeOrganizationId) return;
    generateNextInvoiceNumber(activeOrganizationId).then(setInvoiceNumber);
  }, [activeOrganizationId]);

  useEffect(() => {
    if (!activeOrganizationId) return;
    supabase
      .from('Dealers')
      .select('id, dealer_name, dealer_no, dealer_email, dealer_phone, identification_number, billing_same_as_location, street_address_line_1, street_address_line_2, city, state, zip_code, country, billing_street_address_line_1, billing_street_address_line_2, billing_city, billing_state, billing_zip_code, billing_country, is_tax_retention_agent, tax_retention_rate')
      .eq('organization_id', activeOrganizationId)
      .eq('deleted', false)
      .eq('status', 'active')
      .order('dealer_name', { ascending: true })
      .then(({ data }: { data: DealerOption[] | null }) => { if (data) setDealers(data); });
  }, [activeOrganizationId]);

  const createCustomLine = useCallback((): InvoiceLine => ({
    key: newLineKey(),
    description: '',
    qty: 1,
    unit_price: 0,
    base_subtotal: 0,
    billing_percent: 100,
    billing_amount: 0,
  }), []);

  const loadFromSalesOrder = useCallback(async (soId: string) => {
    if (!activeOrganizationId) return;
    setLoadingSO(true);
    try {
      const [soRes, linesRes, summaryRes] = await Promise.all([
        supabase
          .from('SalesOrders')
          .select('id, sales_order_no, dealer_id, total_amount, subtotal, tax_amount, exempt_tax')
          .eq('id', soId)
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .single(),
        supabase
          .from('SaleOrderLines')
          .select('description, collection_name, variant_name, product_type, quantity, unit_price, line_total, CatalogItems:catalog_item_id (name, sku, manufacturer)')
          .eq('sales_order_id', soId)
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .order('line_number', { ascending: true, nullsFirst: false }),
        supabase
          .from('sales_order_financial_summary')
          .select('balance_due, total_invoiced')
          .eq('sales_order_id', soId)
          .maybeSingle(),
      ]);
      if (soRes.error) throw soRes.error;
      const so = soRes.data;
      setSalesOrderId(so.id);
      setSalesOrderNo(so.sales_order_no);
      setSelectedDealerId(so.dealer_id);

      const isExempt = Boolean((so as any).exempt_tax);
      setTaxExempt(isExempt);

      const soTotal = Math.max(0, safeNumber(so.total_amount, safeNumber(so.subtotal, 0)));
      const soSubtotal = Math.max(0, safeNumber(so.subtotal, 0));
      const soTaxAmount = Math.max(0, safeNumber(so.tax_amount, 0));

      const effectiveSoTaxPct = isExempt ? 0 : (soSubtotal > 0 ? soTaxAmount / soSubtotal : 0);
      setSoTaxPct(effectiveSoTaxPct);

      const summaryTotalInvoiced = summaryRes.data
        ? Math.max(0, safeNumber((summaryRes.data as { total_invoiced?: number | null }).total_invoiced, 0))
        : 0;
      const billableRemainingTotal = Math.max(0, Number((soTotal - summaryTotalInvoiced).toFixed(2)));
      const billableRemainingSubtotal = effectiveSoTaxPct > 0
        ? Math.max(0, Number((billableRemainingTotal / (1 + effectiveSoTaxPct)).toFixed(2)))
        : billableRemainingTotal;
      const targetInvoiceAmount = summaryRes.data ? billableRemainingSubtotal : Math.max(0, soSubtotal);
      const prefillSource: SoPrefillSource = summaryRes.data ? 'billable_remaining' : 'so_total_fallback';
      setPrefillInfo({
        source: prefillSource,
        targetAmount: targetInvoiceAmount,
        billableRemaining: billableRemainingTotal,
        soTaxPct: effectiveSoTaxPct,
      });
      const roundToCents = (value: number) => Number(value.toFixed(2));

      const mappedLines: InvoiceLine[] = [];
      if (!linesRes.error && linesRes.data && linesRes.data.length > 0) {
        const soLines = linesRes.data as Array<Record<string, unknown>>;
        const productTypeLabels: Record<string, string> = {
          roller: 'Roller Shade',
          drapery: 'Drapery',
          catalog: 'Catalog',
          blind: 'Blind',
          curtain: 'Curtain',
          shutter: 'Shutter',
        };
        for (const l of soLines) {
          const item = l.CatalogItems as { name?: string; sku?: string; manufacturer?: string } | null | undefined;
          const name = item?.name || String(l.description || l.collection_name || l.variant_name || 'Item');
          const sku = item?.sku ? ` (${item.sku})` : '';
          const ptRaw = String(l.product_type || '').toLowerCase();
          const ptLabel = productTypeLabels[ptRaw] || (ptRaw ? ptRaw.charAt(0).toUpperCase() + ptRaw.slice(1) : '');
          const mfr = item?.manufacturer ? ` | ${item.manufacturer}` : '';
          const descParts = [ptLabel, `${name}${mfr}${sku}`].filter(Boolean);
          const qty = Math.max(1, safeNumber(l.quantity, 1));
          const unit = Math.max(0, safeNumber(l.unit_price, 0));
          const lineSubtotal = Math.max(0, safeNumber(l.line_total, qty * unit));
          mappedLines.push({
            key: newLineKey(),
            description: descParts.join(' - '),
            qty,
            unit_price: unit,
            base_subtotal: lineSubtotal,
            billing_percent: 100,
            billing_amount: lineSubtotal,
          });
        }
      }

      if (mappedLines.length === 0) {
        const soLabel = so.sales_order_no?.startsWith('SO-') ? so.sales_order_no : `SO-${so.sales_order_no}`;
        setLines([{
          key: newLineKey(),
          description: `Balance due ${soLabel}`,
          qty: 1,
          unit_price: roundToCents(targetInvoiceAmount),
          base_subtotal: roundToCents(targetInvoiceAmount),
          billing_percent: targetInvoiceAmount > 0 ? 100 : 0,
          billing_amount: roundToCents(targetInvoiceAmount),
        }]);
        return;
      }

      const soSubtotalBase = mappedLines.reduce((sum, line) => sum + Math.max(0, line.base_subtotal), 0);
      const effectiveTarget = (soSubtotalBase > 0 && targetInvoiceAmount > 0 && targetInvoiceAmount >= soSubtotalBase * 0.99)
        ? soSubtotalBase
        : targetInvoiceAmount;
      let allocated = 0;
      const lastIndex = mappedLines.length - 1;
      const rebalancedLines = mappedLines.map((line, idx) => {
        const qty = Math.max(1, safeNumber(line.qty, 1));
        let billingAmount = 0;
        if (effectiveTarget > 0) {
          if (soSubtotalBase > 0) {
            if (idx === lastIndex) {
              billingAmount = roundToCents(Math.max(0, effectiveTarget - allocated));
            } else {
              const weightedAmount = roundToCents((effectiveTarget * Math.max(0, line.base_subtotal)) / soSubtotalBase);
              const available = roundToCents(Math.max(0, effectiveTarget - allocated));
              billingAmount = Math.min(weightedAmount, available);
              allocated = roundToCents(allocated + billingAmount);
            }
          } else if (idx === 0) {
            billingAmount = roundToCents(effectiveTarget);
          }
        }

        const unitPrice = Number((billingAmount / qty).toFixed(6));
        const billingPercent = line.base_subtotal > 0
          ? Number(Math.max(0, Math.min(100, (billingAmount / line.base_subtotal) * 100)).toFixed(2))
          : (billingAmount > 0 ? 100 : 0);

        return {
          ...line,
          qty,
          unit_price: unitPrice,
          billing_amount: billingAmount,
          billing_percent: billingPercent,
        };
      });

      setLines(rebalancedLines);
    } catch (e) {
      console.error('Failed to load SO:', e);
      addNotification({ type: 'error', title: 'Error', message: 'Failed to load sales order data' });
    } finally {
      setLoadingSO(false);
    }
  }, [activeOrganizationId, addNotification, createCustomLine]);

  useEffect(() => {
    const soId = getQueryParam('sales_order_id');
    if (soId) loadFromSalesOrder(soId);
  }, [loadFromSalesOrder]);

  const selectedDealer = useMemo(
    () => dealers.find((d) => d.id === selectedDealerId) ?? null,
    [dealers, selectedDealerId]
  );

  const filteredDealers = useMemo(() => {
    if (!dealerSearch.trim()) return dealers;
    const s = dealerSearch.toLowerCase();
    return dealers.filter((d) =>
      d.dealer_name.toLowerCase().includes(s) || d.dealer_no?.toLowerCase().includes(s)
    );
  }, [dealers, dealerSearch]);

  useEffect(() => {
    if (!activeOrganizationId || !selectedDealerId) {
      setSalesOrders([]);
      return;
    }
    setLoadingSalesOrders(true);
    supabase
      .from('SalesOrders')
      .select('id, sales_order_no, subtotal, total_amount, tax_amount, status')
      .eq('organization_id', activeOrganizationId)
      .eq('dealer_id', selectedDealerId)
      .eq('deleted', false)
      .in('status', ['draft', 'confirmed', 'in_production', 'on_hold', 'delivered'])
      .order('created_at', { ascending: false })
      .then(({ data, error }: { data: SalesOrderOption[] | null; error: unknown }) => {
        if (error) {
          if (import.meta.env.DEV) console.warn('[InvoiceNew] sales orders fetch error:', error);
          setSalesOrders([]);
        } else {
          setSalesOrders(data ?? []);
        }
      })
      .finally(() => setLoadingSalesOrders(false));
  }, [activeOrganizationId, selectedDealerId]);

  useEffect(() => {
    if (!salesOrderId) return;
    const exists = salesOrders.some((so) => so.id === salesOrderId);
    if (!exists && !loadingSalesOrders) {
      setSalesOrderId(null);
      setSalesOrderNo(null);
      setPrefillInfo(null);
      setLines([createCustomLine()]);
    }
  }, [salesOrderId, salesOrders, loadingSalesOrders, createCustomLine]);

  const { subtotal, taxTotal, total } = useMemo(() => {
    let sub = 0;
    let tax = 0;
    for (const l of lines) {
      const lineSub = l.qty * l.unit_price;
      sub += lineSub;
      tax += lineSub * appliedTaxPct;
    }
    return { subtotal: sub, taxTotal: tax, total: sub + tax };
  }, [lines, appliedTaxPct]);

  const retentionPreview = useMemo(() => {
    if (!selectedDealer?.is_tax_retention_agent || taxTotal <= 0) return null;
    const rate = selectedDealer.tax_retention_rate ?? 0.5;
    const amount = Number((taxTotal * rate).toFixed(2));
    if (amount <= 0) return null;
    return { amount, rate, net: Number((total - amount).toFixed(2)) };
  }, [selectedDealer, taxTotal, total]);

  const fmt = (v: number) =>
    new Intl.NumberFormat('en-US', { style: 'currency', currency }).format(v);

  const updateLine = (key: string, field: keyof InvoiceLine, value: string | number) => {
    setLines((prev) => prev.map((l) => {
      if (l.key !== key) return l;
      const next = { ...l, [field]: value } as InvoiceLine;
      if (field === 'qty' || field === 'unit_price') {
        const subtotalValue = Math.max(0, Number(next.qty) * Number(next.unit_price));
        next.billing_amount = subtotalValue;
        if (next.base_subtotal > 0) {
          const pct = (subtotalValue / next.base_subtotal) * 100;
          next.billing_percent = Math.max(1, Math.min(100, Number(pct.toFixed(2))));
        } else {
          next.billing_percent = 100;
        }
      }
      return next;
    }));
  };

  const removeLine = (key: string) => {
    setLines((prev) => prev.length > 1 ? prev.filter((l) => l.key !== key) : prev);
  };

  const addLine = () => {
    setLines((prev) => [...prev, createCustomLine()]);
  };

  const handleSalesOrderSelect = async (soId: string) => {
    if (!soId) {
      setSalesOrderId(null);
      setSalesOrderNo(null);
      setPrefillInfo(null);
      setSoTaxPct(null);
      setLines([createCustomLine()]);
      return;
    }
    await loadFromSalesOrder(soId);
  };

  const handleLinePercentChange = (key: string, value: string) => {
    const parsed = Number(value);
    setLines((prev) => prev.map((line) => {
      if (line.key !== key) return line;
      if (!Number.isFinite(parsed)) {
        return line;
      }
      const boundedPercent = Math.max(1, Math.min(100, parsed));
      if (line.base_subtotal <= 0) {
        return { ...line, billing_percent: boundedPercent, billing_amount: 0 };
      }
      const billedAmount = Number(((line.base_subtotal * boundedPercent) / 100).toFixed(2));
      const nextQty = Math.max(1, line.qty);
      return {
        ...line,
        billing_percent: boundedPercent,
        billing_amount: billedAmount,
        unit_price: Number((billedAmount / nextQty).toFixed(6)),
      };
    }));
  };

  const handleLineAmountChange = (key: string, value: string) => {
    const parsed = Number(value);
    setLines((prev) => prev.map((line) => {
      if (line.key !== key) return line;
      if (!Number.isFinite(parsed) || parsed < 0) {
        return line;
      }
      const boundedAmount = Math.max(0, parsed);
      const nextQty = Math.max(1, line.qty);
      const percent = line.base_subtotal > 0 ? (boundedAmount / line.base_subtotal) * 100 : 100;
      const boundedPercent = Math.max(1, Math.min(100, percent));
      const normalizedAmount = line.base_subtotal > 0
        ? Number(((line.base_subtotal * boundedPercent) / 100).toFixed(2))
        : boundedAmount;
      return {
        ...line,
        billing_amount: normalizedAmount,
        billing_percent: Number(boundedPercent.toFixed(2)),
        unit_price: Number((normalizedAmount / nextQty).toFixed(6)),
      };
    }));
  };

  const handleSave = async () => {
    if (!activeOrganizationId || !selectedDealerId || !invoiceNumber) {
      addNotification({ type: 'error', title: 'Validation', message: 'Please select a dealer and ensure an invoice number is generated.' });
      return;
    }
    const validLines = lines.filter((l) => l.description.trim() && l.qty > 0);
    if (validLines.length === 0) {
      addNotification({ type: 'error', title: 'Validation', message: 'Add at least one valid line (description and qty > 0).' });
      return;
    }
    const preSaveTaxRate = taxExempt ? 0 : (prefillInfo?.soTaxPct ?? soTaxPct ?? defaultTaxPct);
    const preSaveTotal = Number((subtotal + subtotal * preSaveTaxRate).toFixed(2));
    if (salesOrderId && prefillInfo && preSaveTotal > Number((prefillInfo.billableRemaining + 0.02).toFixed(2))) {
      addNotification({
        type: 'error',
        title: 'Validation',
        message: `Invoice total (${fmt(preSaveTotal)}) exceeds SO uninvoiced amount (${fmt(prefillInfo.billableRemaining)}).`,
      });
      return;
    }
    setSaving(true);
    try {
      const taxRate = taxExempt ? 0 : (prefillInfo?.soTaxPct ?? soTaxPct ?? defaultTaxPct);
      const finalSubtotal = Number(subtotal.toFixed(2));
      const finalTax = Number((finalSubtotal * taxRate).toFixed(2));
      const finalTotal = Number((finalSubtotal + finalTax).toFixed(2));

      const lineRows = validLines.map((l, i) => {
        const lineSub = Number((l.qty * l.unit_price).toFixed(2));
        const lineTax = Number((lineSub * taxRate).toFixed(2));
        return {
          sort_order: i + 1,
          description: l.description.trim(),
          qty: l.qty,
          unit_price: l.unit_price,
          tax_pct: Number(taxRate.toFixed(6)),
          line_subtotal: lineSub,
          line_tax: lineTax,
          line_total: lineSub + lineTax,
        };
      });

      // Atomic create: invoice + lines in one DB transaction.
      const { data: createdInvoiceId, error: createErr } = await supabase.rpc('create_dealer_invoice_with_lines', {
        p_organization_id: activeOrganizationId,
        p_dealer_id: selectedDealerId,
        p_sales_order_id: salesOrderId,
        p_invoice_number: invoiceNumber,
        p_issue_date: issueDate,
        p_due_date: dueDate || null,
        p_currency_code: currency,
        p_subtotal: finalSubtotal,
        p_tax_total: finalTax,
        p_total: finalTotal,
        p_notes: notes.trim() || null,
        p_lines: lineRows,
      });
      if (createErr) throw createErr;
      if (!createdInvoiceId || typeof createdInvoiceId !== 'string') {
        throw new Error('Failed to create invoice');
      }

      // Panama ITBMS retention: if the dealer is a withholding agent and the
      // invoice has tax, record the retained portion as a retention note so the
      // withheld amount is not treated as an outstanding balance.
      if (selectedDealer?.is_tax_retention_agent && finalTax > 0) {
        try {
          const { data: retResult, error: retErr } = await supabase.rpc('create_tax_retention_note', {
            p_invoice_id: createdInvoiceId,
          });
          if (retErr) throw retErr;
          const res = retResult as { ok?: boolean; amount?: number } | null;
          if (res?.ok && res.amount) {
            addNotification({
              type: 'success',
              title: 'Retención registrada',
              message: `Nota de Retención de Impuesto por ${fmt(Number(res.amount))} generada.`,
            });
          }
        } catch (retErr: unknown) {
          const rMsg = retErr instanceof Error ? retErr.message : 'No se pudo registrar la retención';
          addNotification({ type: 'error', title: 'Retención', message: rMsg });
        }
      }

      addNotification({ type: 'success', title: 'Invoice Created', message: `Invoice ${invoiceNumber} saved as draft.` });
      const detailPath = queryReturnTo
        ? withReturnTo(`/financials/invoices/${createdInvoiceId}`, queryReturnTo)
        : `/financials/invoices/${createdInvoiceId}`;
      router.navigate(detailPath);
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : 'Failed to create invoice';
      addNotification({ type: 'error', title: 'Error', message: msg });
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="min-h-screen" style={{ backgroundColor: 'var(--gray-200)' }}>
      {/* Header */}
      <div className="flex justify-center py-4 shrink-0">
        <div className="flex items-center gap-4 w-full max-w-6xl mx-auto px-4 md:px-6">
          <button
            type="button"
            onClick={() => router.navigate(listPath)}
            className="p-1 -ml-1 text-gray-600 hover:text-gray-900 hover:bg-gray-100 rounded transition-colors"
          >
            <ArrowLeft className="w-5 h-5" />
          </button>
          <div className="flex-1 min-w-0">
            <h1 className="text-xl font-bold text-gray-900 truncate">New Invoice</h1>
            <p className="text-sm text-gray-500 truncate">
              {salesOrderNo ? `From ${salesOrderNo}` : 'Create a new dealer invoice'}
            </p>
          </div>
          <div className="flex items-center gap-2 shrink-0">
            {queryReturnTo && (
              <button
                type="button"
                onClick={() =>
                  navigateBackContextual(router, {
                    queryReturnTo,
                    fallback: listPath,
                  })
                }
                className="px-3 py-1.5 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
              >
                Back
              </button>
            )}
            <button
              type="button"
              onClick={() => router.navigate(listPath)}
              className="px-3 py-1.5 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
            >
              Cancel
            </button>
            <button
              type="button"
              onClick={handleSave}
              disabled={saving || !selectedDealerId || !canCreateInvoice}
              className="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium text-white bg-primary rounded-lg hover:bg-primary/90 disabled:opacity-50 transition-colors"
            >
              {saving ? 'Saving...' : 'Save as Draft'}
            </button>
          </div>
        </div>
      </div>

      {/* Content */}
      <div className="flex-1 min-w-0 overflow-auto pb-6">
        <div className="w-full max-w-6xl mx-auto px-4 md:px-6 space-y-6">

          {loadingSO && (
            <div className="bg-blue-50 border border-blue-200 rounded-lg p-4 text-center">
              <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-primary mx-auto mb-2" />
              <p className="text-sm text-blue-700">Loading sales order data...</p>
            </div>
          )}

          {/* Two-card header */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {/* Bill To card */}
            <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm">
              <h3 className="text-sm font-semibold text-gray-900 mb-3">Bill To</h3>

              {/* Dealer selector */}
              <div className="relative mb-4">
                <label className="block text-xs font-medium text-gray-500 mb-1">Dealer *</label>
                {selectedDealer ? (
                  <div className="flex items-center justify-between px-3 py-2 border border-gray-200 rounded-lg bg-gray-50">
                    <span className="text-sm font-medium text-gray-900">{selectedDealer.dealer_name}</span>
                    <button
                      type="button"
                      onClick={() => {
                        setSelectedDealerId('');
                        setDealerSearch('');
                        setSalesOrderId(null);
                        setSalesOrderNo(null);
                        setPrefillInfo(null);
                        setLines([createCustomLine()]);
                      }}
                      className="text-xs text-gray-500 hover:text-gray-700"
                    >
                      Change
                    </button>
                  </div>
                ) : (
                  <>
                    <input
                      type="text"
                      placeholder="Search dealers..."
                      value={dealerSearch}
                      onChange={(e) => { setDealerSearch(e.target.value); setShowDealerDropdown(true); }}
                      onFocus={() => setShowDealerDropdown(true)}
                      className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary/20"
                    />
                    {showDealerDropdown && filteredDealers.length > 0 && (
                      <div className="absolute z-20 mt-1 w-full bg-white border border-gray-200 rounded-lg shadow-lg max-h-48 overflow-y-auto">
                        {filteredDealers.map((d) => (
                          <button
                            key={d.id}
                            type="button"
                            onClick={() => {
                              setSelectedDealerId(d.id);
                              setShowDealerDropdown(false);
                              setDealerSearch('');
                              setSalesOrderId(null);
                              setSalesOrderNo(null);
                              setPrefillInfo(null);
                              setLines([createCustomLine()]);
                            }}
                            className="w-full text-left px-3 py-2 text-sm hover:bg-gray-50 border-b border-gray-100 last:border-0"
                          >
                            <span className="font-medium">{d.dealer_name}</span>
                            {d.dealer_no && <span className="ml-2 text-gray-400">#{d.dealer_no}</span>}
                          </button>
                        ))}
                      </div>
                    )}
                  </>
                )}
              </div>
              <div className="mb-4">
                <label className="block text-xs font-medium text-gray-500 mb-1">SO #</label>
                <select
                  value={salesOrderId ?? ''}
                  onChange={(e) => void handleSalesOrderSelect(e.target.value)}
                  disabled={!selectedDealerId || loadingSalesOrders}
                  className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 disabled:bg-gray-50 disabled:text-gray-500"
                >
                  <option value="">
                    {!selectedDealerId
                      ? 'Select dealer first'
                      : loadingSalesOrders
                        ? 'Loading SO list...'
                        : salesOrders.length === 0
                          ? 'No SO available'
                          : 'Select SO #'}
                  </option>
                  {salesOrders.map((so) => (
                    <option key={so.id} value={so.id}>
                      {so.sales_order_no}
                    </option>
                  ))}
                </select>
                {salesOrderNo && (
                  <div className="mt-2 space-y-1">
                    <p className="text-xs text-gray-500">Reference: {salesOrderNo}</p>
                    {prefillInfo && (
                      <p className="text-xs text-gray-500">
                        Prefill source:{' '}
                        {prefillInfo.source === 'billable_remaining'
                          ? 'SO billable remaining'
                          : 'SO subtotal (pre-tax) fallback'}
                        {' '}({fmt(prefillInfo.targetAmount)}). Billable remaining: {fmt(prefillInfo.billableRemaining)}.
                      </p>
                    )}
                  </div>
                )}
              </div>

              {/* Dealer billing info */}
              {selectedDealer && (
                <dl className="space-y-2 text-sm">
                  {selectedDealer.identification_number && (
                    <div className="flex justify-between">
                      <dt className="text-gray-500">Tax ID</dt>
                      <dd className="font-mono text-gray-900">{selectedDealer.identification_number}</dd>
                    </div>
                  )}
                  <div>
                    <dt className="text-gray-500 mb-0.5">Billing Address</dt>
                    <dd className="text-gray-900 whitespace-pre-line text-xs leading-relaxed">{formatAddress(selectedDealer)}</dd>
                  </div>
                  {selectedDealer.dealer_email && (
                    <div className="flex justify-between">
                      <dt className="text-gray-500">Email</dt>
                      <dd className="text-gray-900">{selectedDealer.dealer_email}</dd>
                    </div>
                  )}
                  {selectedDealer.dealer_phone && (
                    <div className="flex justify-between">
                      <dt className="text-gray-500">Phone</dt>
                      <dd className="text-gray-900">{selectedDealer.dealer_phone}</dd>
                    </div>
                  )}
                </dl>
              )}
            </div>

            {/* Invoice Details card */}
            <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm">
              <h3 className="text-sm font-semibold text-gray-900 mb-3">Invoice Details</h3>
              <div className="space-y-3">
                <div>
                  <label className="block text-xs font-medium text-gray-500 mb-1">Invoice #</label>
                  <input
                    type="text"
                    value={invoiceNumber}
                    readOnly
                    className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm bg-gray-50 text-gray-600"
                  />
                </div>
                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="block text-xs font-medium text-gray-500 mb-1">Issue Date</label>
                    <input
                      type="date"
                      value={issueDate}
                      onChange={(e) => setIssueDate(e.target.value)}
                      className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary/20"
                    />
                  </div>
                  <div>
                    <label className="block text-xs font-medium text-gray-500 mb-1">Due Date</label>
                    <input
                      type="date"
                      value={dueDate}
                      onChange={(e) => setDueDate(e.target.value)}
                      className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary/20"
                    />
                  </div>
                </div>
                <div>
                  <label className="block text-xs font-medium text-gray-500 mb-1">Currency</label>
                  <select
                    value={currency}
                    onChange={(e) => setCurrency(e.target.value)}
                    className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary/20"
                  >
                    <option value="USD">USD</option>
                    <option value="EUR">EUR</option>
                    <option value="GBP">GBP</option>
                  </select>
                </div>
                <div>
                  <label className="block text-xs font-medium text-gray-500 mb-1">Notes</label>
                  <textarea
                    value={notes}
                    onChange={(e) => setNotes(e.target.value)}
                    rows={2}
                    className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 resize-none"
                    placeholder="Internal notes..."
                  />
                </div>
                <label className="inline-flex items-center gap-2 text-sm text-gray-700">
                  <input
                    type="checkbox"
                    checked={taxExempt}
                    onChange={(e) => setTaxExempt(e.target.checked)}
                    className="h-4 w-4 rounded border-gray-300 text-primary focus:ring-primary/20"
                  />
                  Tax Exempt (0%)
                </label>
              </div>
            </div>
          </div>

          {/* Lines table + Summary below (after table) */}
          <div className="space-y-4">
          <div className="rounded-lg border border-gray-200 overflow-hidden bg-white">
            <div className="px-4 py-2 border-b border-gray-200 bg-gray-50 text-xs text-gray-600">
              Tax: {taxExempt ? 'Exempt (0.00%)' : soTaxPct != null ? `Inherited from SO (${(soTaxPct * 100).toFixed(2)}%)` : `From Cost Settings (${(defaultTaxPct * 100).toFixed(2)}%)`}
            </div>
            <table className="w-full text-sm">
              <thead className="bg-gray-50 border-b border-gray-200">
                <tr>
                  <th className="px-4 py-3 text-left font-medium text-gray-700 text-xs w-8">#</th>
                  <th className="px-4 py-3 text-left font-medium text-gray-700 text-xs">Description</th>
                  <th className="px-4 py-3 text-right font-medium text-gray-700 text-xs w-28">%</th>
                  <th className="px-4 py-3 text-right font-medium text-gray-700 text-xs w-28">Amount</th>
                  <th className="px-4 py-3 text-right font-medium text-gray-700 text-xs w-20">Qty</th>
                  <th className="px-4 py-3 text-right font-medium text-gray-700 text-xs w-28">Unit Price</th>
                  <th className="px-4 py-3 text-right font-medium text-gray-700 text-xs w-28">Total</th>
                  <th className="px-4 py-3 text-center font-medium text-gray-700 text-xs w-10">
                    <button
                      type="button"
                      onClick={addLine}
                      className="inline-flex items-center justify-center w-6 h-6 rounded-full bg-primary text-white hover:bg-primary/90 transition-colors"
                      title="Add line"
                    >
                      <Plus className="w-3.5 h-3.5" />
                    </button>
                  </th>
                </tr>
              </thead>
              <tbody>
                {lines.map((line, idx) => {
                  const lineSub = line.qty * line.unit_price;
                  return (
                    <tr key={line.key} className="border-t hover:bg-gray-50">
                      <td className="px-4 py-3 text-center text-gray-400 tabular-nums">{idx + 1}</td>
                      <td className="px-4 py-3">
                        <input
                          type="text"
                          value={line.description}
                          onChange={(e) => updateLine(line.key, 'description', e.target.value)}
                          placeholder="Item description..."
                          className="w-full px-2 py-1 border border-gray-200 rounded text-sm focus:outline-none focus:ring-2 focus:ring-primary/20"
                        />
                      </td>
                      <td className="px-4 py-3">
                        <input
                          type="number"
                          min={1}
                          max={100}
                          step={0.01}
                          value={line.billing_percent}
                          onChange={(e) => handleLinePercentChange(line.key, e.target.value)}
                          className="w-full px-2 py-1 border border-gray-200 rounded text-sm text-right focus:outline-none focus:ring-2 focus:ring-primary/20"
                        />
                      </td>
                      <td className="px-4 py-3">
                        <input
                          type="number"
                          min={0}
                          step={0.01}
                          value={line.billing_amount}
                          onChange={(e) => handleLineAmountChange(line.key, e.target.value)}
                          className="w-full px-2 py-1 border border-gray-200 rounded text-sm text-right focus:outline-none focus:ring-2 focus:ring-primary/20"
                        />
                      </td>
                      <td className="px-4 py-3">
                        <input
                          type="number"
                          min={1}
                          value={line.qty}
                          onChange={(e) => updateLine(line.key, 'qty', Math.max(1, Number(e.target.value)))}
                          className="w-full px-2 py-1 border border-gray-200 rounded text-sm text-right focus:outline-none focus:ring-2 focus:ring-primary/20"
                        />
                      </td>
                      <td className="px-4 py-3">
                        <input
                          type="number"
                          min={0}
                          step={0.01}
                          value={line.unit_price}
                          onChange={(e) => updateLine(line.key, 'unit_price', Math.max(0, Number(e.target.value)))}
                          className="w-full px-2 py-1 border border-gray-200 rounded text-sm text-right focus:outline-none focus:ring-2 focus:ring-primary/20"
                        />
                      </td>
                      <td className="px-4 py-3 text-right font-mono font-medium">{fmt(lineSub)}</td>
                      <td className="px-4 py-3 text-center">
                        <button
                          type="button"
                          onClick={() => removeLine(line.key)}
                          disabled={lines.length <= 1}
                          className="p-1 text-gray-400 hover:text-red-500 disabled:opacity-30 transition-colors"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
            <div className="flex justify-end">
            <div className="w-full lg:w-[22rem] rounded-lg border border-gray-200 bg-white p-6 shadow-sm">
              <h3 className="text-sm font-semibold text-gray-900 mb-3">Summary Total</h3>
              <dl className="space-y-2 text-sm">
                <div className="flex justify-between">
                  <dt className="text-gray-500">Subtotal</dt>
                  <dd className="font-mono text-gray-900">{fmt(subtotal)}</dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-gray-500">Tax</dt>
                  <dd className="font-mono text-gray-900">{fmt(taxTotal)}</dd>
                </div>
                <div className="flex justify-between border-t pt-2">
                  <dt className="text-sm font-semibold text-gray-700">Total</dt>
                  <dd className="font-mono font-bold text-gray-900">{fmt(total)}</dd>
                </div>
                {retentionPreview && (
                  <>
                    <div className="flex justify-between text-amber-700">
                      <dt>Retención ITBMS ({Math.round(retentionPreview.rate * 100)}%)</dt>
                      <dd className="font-mono">−{fmt(retentionPreview.amount)}</dd>
                    </div>
                    <div className="flex justify-between border-t pt-2">
                      <dt className="text-sm font-semibold text-gray-700">Saldo a cobrar (neto)</dt>
                      <dd className="font-mono font-bold text-gray-900">{fmt(retentionPreview.net)}</dd>
                    </div>
                    <p className="text-xs text-gray-500 pt-1">
                      Se generará automáticamente una Nota de Retención de Impuesto. El saldo retenido no se cobrará.
                    </p>
                  </>
                )}
              </dl>
            </div>
            </div>
          </div>

        </div>
      </div>
    </div>
  );
}

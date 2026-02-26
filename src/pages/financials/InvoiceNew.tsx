import { useState, useEffect, useCallback, useMemo } from 'react';
import { supabase } from '../../lib/supabase/client';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useAuth } from '../../hooks/useAuth';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useUIStore } from '../../stores/ui-store';
import { useCostSettings } from '../../hooks/useCosts';
import { generateNextInvoiceNumber } from '../../lib/sequential-numbers';
import { router } from '../../lib/router';
import { ArrowLeft, Plus, Trash2, FileText, DollarSign } from 'lucide-react';

const FINANCIAL_SUBMODULES = [
  { id: 'invoices', label: 'Invoices', href: '/financials/invoices', icon: FileText },
  { id: 'payments', label: 'Payments', href: '/financials/payments', icon: DollarSign },
];

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
}

interface InvoiceLine {
  key: string;
  description: string;
  qty: number;
  unit_price: number;
  tax_pct: number;
}

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

export default function InvoiceNew() {
  const { activeOrganizationId } = useOrganizationContext();
  const { user } = useAuth();
  const { registerSubmodules } = useSubmoduleNav();
  const addNotification = useUIStore((s) => s.addNotification);
  const { settings: costSettings } = useCostSettings();
  const defaultTaxPct = costSettings?.tax_pct ?? 0.07;

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
  const [lines, setLines] = useState<InvoiceLine[]>([{ key: newLineKey(), description: '', qty: 1, unit_price: 0, tax_pct: defaultTaxPct }]);
  const [salesOrderId, setSalesOrderId] = useState<string | null>(null);
  const [salesOrderNo, setSalesOrderNo] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [loadingSO, setLoadingSO] = useState(false);

  useEffect(() => { registerSubmodules('Financials', FINANCIAL_SUBMODULES); }, [registerSubmodules]);

  useEffect(() => {
    if (!activeOrganizationId) return;
    generateNextInvoiceNumber(activeOrganizationId).then(setInvoiceNumber);
  }, [activeOrganizationId]);

  useEffect(() => {
    if (!activeOrganizationId) return;
    supabase
      .from('Dealers')
      .select('id, dealer_name, dealer_no, dealer_email, dealer_phone, identification_number, billing_same_as_location, street_address_line_1, street_address_line_2, city, state, zip_code, country, billing_street_address_line_1, billing_street_address_line_2, billing_city, billing_state, billing_zip_code, billing_country')
      .eq('organization_id', activeOrganizationId)
      .eq('deleted', false)
      .eq('status', 'active')
      .order('dealer_name', { ascending: true })
      .then(({ data }: { data: DealerOption[] | null }) => { if (data) setDealers(data); });
  }, [activeOrganizationId]);

  const loadFromSalesOrder = useCallback(async (soId: string) => {
    if (!activeOrganizationId) return;
    setLoadingSO(true);
    try {
      const [soRes, linesRes] = await Promise.all([
        supabase
          .from('SalesOrders')
          .select('id, sales_order_no, dealer_id, total_amount, subtotal, tax_amount')
          .eq('id', soId)
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .single(),
        supabase
          .from('SaleOrderLines')
          .select('description, collection_name, variant_name, quantity, unit_price, line_total, CatalogItems:catalog_item_id (item_name, sku)')
          .eq('sales_order_id', soId)
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .order('line_number', { ascending: true, nullsFirst: false }),
      ]);
      if (soRes.error) throw soRes.error;
      const so = soRes.data;
      setSalesOrderId(so.id);
      setSalesOrderNo(so.sales_order_no);
      setSelectedDealerId(so.dealer_id);

      if (!linesRes.error && linesRes.data && linesRes.data.length > 0) {
        const soLines = linesRes.data as any[];
        const soTotal = so.subtotal ?? so.total_amount ?? 0;
        const soTax = so.tax_amount ?? 0;
        const effectiveTaxPct = soTotal > 0 ? soTax / soTotal : defaultTaxPct;

        setLines(soLines.map((l) => {
          const name = l.CatalogItems?.item_name || l.description || l.collection_name || l.variant_name || 'Item';
          const sku = l.CatalogItems?.sku ? ` (${l.CatalogItems.sku})` : '';
          return {
            key: newLineKey(),
            description: `${name}${sku}`,
            qty: l.quantity ?? 1,
            unit_price: l.unit_price ?? 0,
            tax_pct: effectiveTaxPct,
          };
        }));
      }
    } catch (e) {
      console.error('Failed to load SO:', e);
      addNotification({ type: 'error', title: 'Error', message: 'Failed to load sales order data' });
    } finally {
      setLoadingSO(false);
    }
  }, [activeOrganizationId, defaultTaxPct, addNotification]);

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

  const { subtotal, taxTotal, total } = useMemo(() => {
    let sub = 0;
    let tax = 0;
    for (const l of lines) {
      const lineSub = l.qty * l.unit_price;
      sub += lineSub;
      tax += lineSub * l.tax_pct;
    }
    return { subtotal: sub, taxTotal: tax, total: sub + tax };
  }, [lines]);

  const fmt = (v: number) =>
    new Intl.NumberFormat('en-US', { style: 'currency', currency }).format(v);

  const updateLine = (key: string, field: keyof InvoiceLine, value: string | number) => {
    setLines((prev) => prev.map((l) => l.key === key ? { ...l, [field]: value } : l));
  };

  const removeLine = (key: string) => {
    setLines((prev) => prev.length > 1 ? prev.filter((l) => l.key !== key) : prev);
  };

  const addLine = () => {
    setLines((prev) => [...prev, { key: newLineKey(), description: '', qty: 1, unit_price: 0, tax_pct: defaultTaxPct }]);
  };

  const handleSave = async () => {
    if (!activeOrganizationId || !selectedDealerId || !invoiceNumber) {
      addNotification({ type: 'error', title: 'Validation', message: 'Please select a dealer and ensure an invoice number is generated.' });
      return;
    }
    if (lines.every((l) => !l.description.trim())) {
      addNotification({ type: 'error', title: 'Validation', message: 'Add at least one line with a description.' });
      return;
    }
    setSaving(true);
    try {
      const { data: inv, error: invErr } = await supabase
        .from('DealerInvoices')
        .insert({
          organization_id: activeOrganizationId,
          dealer_id: selectedDealerId,
          sales_order_id: salesOrderId,
          invoice_number: invoiceNumber,
          status: 'draft',
          issue_date: issueDate,
          due_date: dueDate || null,
          currency_code: currency,
          subtotal,
          tax_total: taxTotal,
          total,
          notes: notes.trim() || null,
          deleted: false,
        })
        .select('id')
        .single();
      if (invErr) throw invErr;

      const validLines = lines.filter((l) => l.description.trim());
      if (validLines.length > 0) {
        const lineRows = validLines.map((l, i) => ({
          invoice_id: inv.id,
          sort_order: i + 1,
          description: l.description.trim(),
          qty: l.qty,
          unit_price: l.unit_price,
          tax_pct: l.tax_pct,
          line_subtotal: l.qty * l.unit_price,
          line_tax: l.qty * l.unit_price * l.tax_pct,
          line_total: l.qty * l.unit_price * (1 + l.tax_pct),
        }));
        const { error: linesErr } = await supabase.from('DealerInvoiceLines').insert(lineRows);
        if (linesErr) throw linesErr;
      }

      addNotification({ type: 'success', title: 'Invoice Created', message: `Invoice ${invoiceNumber} saved as draft.` });
      router.navigate(`/financials/invoices/${inv.id}`);
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
            onClick={() => router.navigate('/financials/invoices')}
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
            <button
              type="button"
              onClick={() => router.navigate('/financials/invoices')}
              className="px-3 py-1.5 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
            >
              Cancel
            </button>
            <button
              type="button"
              onClick={handleSave}
              disabled={saving || !selectedDealerId}
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
                    {!salesOrderId && (
                      <button
                        type="button"
                        onClick={() => { setSelectedDealerId(''); setDealerSearch(''); }}
                        className="text-xs text-gray-500 hover:text-gray-700"
                      >
                        Change
                      </button>
                    )}
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
                            onClick={() => { setSelectedDealerId(d.id); setShowDealerDropdown(false); setDealerSearch(''); }}
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
                {salesOrderNo && (
                  <div>
                    <label className="block text-xs font-medium text-gray-500 mb-1">Sales Order</label>
                    <input
                      type="text"
                      value={salesOrderNo}
                      readOnly
                      className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm bg-gray-50 text-gray-600"
                    />
                  </div>
                )}
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
              </div>
            </div>
          </div>

          {/* Lines table */}
          <div className="rounded-lg border border-gray-200 overflow-hidden bg-white">
            <table className="w-full text-sm">
              <thead className="bg-gray-50 border-b border-gray-200">
                <tr>
                  <th className="px-4 py-3 text-left font-medium text-gray-700 text-xs w-8">#</th>
                  <th className="px-4 py-3 text-left font-medium text-gray-700 text-xs">Description</th>
                  <th className="px-4 py-3 text-right font-medium text-gray-700 text-xs w-20">Qty</th>
                  <th className="px-4 py-3 text-right font-medium text-gray-700 text-xs w-28">Unit Price</th>
                  <th className="px-4 py-3 text-right font-medium text-gray-700 text-xs w-20">Tax %</th>
                  <th className="px-4 py-3 text-right font-medium text-gray-700 text-xs w-24">Tax</th>
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
                  const lineTax = lineSub * line.tax_pct;
                  const lineTotal = lineSub + lineTax;
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
                      <td className="px-4 py-3">
                        <input
                          type="number"
                          min={0}
                          max={1}
                          step={0.01}
                          value={line.tax_pct}
                          onChange={(e) => updateLine(line.key, 'tax_pct', Math.max(0, Math.min(1, Number(e.target.value))))}
                          className="w-full px-2 py-1 border border-gray-200 rounded text-sm text-right focus:outline-none focus:ring-2 focus:ring-primary/20"
                        />
                      </td>
                      <td className="px-4 py-3 text-right font-mono text-gray-600">{fmt(lineTax)}</td>
                      <td className="px-4 py-3 text-right font-mono font-medium">{fmt(lineTotal)}</td>
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
              <tfoot className="bg-gray-50 border-t">
                <tr>
                  <td colSpan={5} />
                  <td className="px-4 py-3 text-right text-xs font-medium text-gray-500">Subtotal</td>
                  <td className="px-4 py-3 text-right font-mono text-gray-900">{fmt(subtotal)}</td>
                  <td />
                </tr>
                <tr>
                  <td colSpan={5} />
                  <td className="px-4 py-3 text-right text-xs font-medium text-gray-500">Tax</td>
                  <td className="px-4 py-3 text-right font-mono text-gray-900">{fmt(taxTotal)}</td>
                  <td />
                </tr>
                <tr className="border-t">
                  <td colSpan={5} />
                  <td className="px-4 py-3 text-right text-sm font-semibold text-gray-700">Total</td>
                  <td className="px-4 py-3 text-right font-mono font-bold text-gray-900">{fmt(total)}</td>
                  <td />
                </tr>
              </tfoot>
            </table>
          </div>

        </div>
      </div>
    </div>
  );
}

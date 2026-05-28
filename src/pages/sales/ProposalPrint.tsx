/**
 * Print view for Proposals: internal (detail) and customer (simplified).
 * Opens at /sales/proposals/:id/print?mode=internal|customer.
 * Uses window.print(); no server/PDF generation.
 */

import { useMemo, useState, useEffect, useCallback } from 'react';
import { useProposalDetail } from '../../hooks/useProposals';
import type { ProposalLine, QuoteLineSnapshot } from '../../types/proposals';
import { supabase } from '../../lib/supabase/client';
import { Printer } from 'lucide-react';
import { formatDimensionsDisplayCompact } from '../../lib/formatDimensions';
import { formatDate } from '../../lib/utils';
import { useResolvedStorageUrl } from '../../hooks/useResolvedStorageUrl';

function getProposalIdFromPath(): string | null {
  const m = window.location.pathname.match(/\/sales\/proposals\/([^/]+)\/print/);
  return m ? m[1] : null;
}

function getModeFromSearch(): 'internal' | 'customer' {
  const params = new URLSearchParams(window.location.search);
  const mode = params.get('mode')?.toLowerCase();
  return mode === 'customer' ? 'customer' : 'internal';
}

function getQuoteLineBase(ql: { quantity: number; msrp: number | null; unit_msrp: number | null }): number {
  if (ql.msrp != null && ql.msrp > 0) return ql.msrp;
  if (ql.unit_msrp != null && ql.quantity) return ql.unit_msrp * ql.quantity;
  return 0;
}

/** When snapshot exists, use it for base; else use quoteLineInfo (live QuoteLine).
 * Uses line_adjustment_pct: base_total * (1 + adj/100). No override_mode. */
function computeLineTotal(
  line: ProposalLine,
  quoteLineInfo: { quantity: number; msrp: number | null; unit_msrp: number | null } | undefined,
  snapshot?: QuoteLineSnapshot | null
): number {
  if (line.line_type === 'custom') {
    const qty = Number(line.qty) || 0;
    const up = Number(line.unit_price) || 0;
    return qty * up;
  }
  if (line.line_type === 'from_quote') {
    let base: number;
    if (snapshot && (snapshot.base_line_msrp != null || snapshot.base_unit_msrp != null)) {
      base = snapshot.base_line_msrp ?? (snapshot.base_unit_msrp ?? 0) * (snapshot.qty ?? 1);
    } else if (quoteLineInfo) {
      base = getQuoteLineBase(quoteLineInfo);
    } else {
      return 0;
    }
    const adjPct = line.line_adjustment_pct ?? 0;
    return Math.round(base * (1 + adjPct / 100) * 100) / 100;
  }
  return 0;
}

function getProposalLineQty(
  line: ProposalLine,
  quoteLineInfo: { quantity: number; msrp: number | null; unit_msrp: number | null } | undefined,
  snapshot?: QuoteLineSnapshot | null
): number {
  if (line.line_type === 'custom') return Math.max(0, Number(line.qty) || 0);
  const snapQty = Number(snapshot?.qty);
  if (snapQty > 0) return snapQty;
  const quoteQty = Number(quoteLineInfo?.quantity);
  if (quoteQty > 0) return quoteQty;
  const lineQty = Number(line.qty);
  if (lineQty > 0) return lineQty;
  return 1;
}

function formatCurrency(amount: number, currency: string) {
  return new Intl.NumberFormat('en-US', { style: 'currency', currency: currency || 'USD' }).format(amount || 0);
}

function compactMeasurementsNoUnit(source: Parameters<typeof formatDimensionsDisplayCompact>[0]): string {
  const s = formatDimensionsDisplayCompact(source);
  return s === '—' ? '—' : s.replace(/\s*mm\s*$/i, '').trim();
}

/** Tolerant: accessories can be string[], {name,qty}[], or object. Fallback to "—". */
function formatAccessoriesFromSnapshot(accessories: unknown): string {
  if (accessories == null) return '—';
  if (Array.isArray(accessories)) {
    if (accessories.length === 0) return '—';
    const parts = accessories.map((item) => {
      if (typeof item === 'string') return item;
      if (item && typeof item === 'object' && 'name' in item) {
        const name = (item as { name?: string }).name ?? '';
        const qty = (item as { qty?: number }).qty;
        return qty != null ? `${name} (${qty})` : name;
      }
      return String(item);
    });
    return parts.filter(Boolean).join(', ') || '—';
  }
  if (typeof accessories === 'object') {
    const entries = Object.entries(accessories).filter(([, v]) => v != null && v !== '');
    return entries.length > 0 ? entries.map(([k, v]) => `${k}: ${v}`).join(', ') : '—';
  }
  return String(accessories) || '—';
}

function formatAddressBlock(parts: Array<string | null | undefined>): string {
  return parts
    .map((p) => (p ?? '').trim())
    .filter(Boolean)
    .join('\n');
}

export default function ProposalPrint() {
  const proposalId = getProposalIdFromPath();
  const mode = getModeFromSearch();
  const { proposal, lines, addonsMap, quoteLinesMap, configuredProductsMap, quote, customer, contact, dealerLogoUrl, loading, error } =
    useProposalDetail(proposalId);
  const [orgName, setOrgName] = useState<string | null>(null);
  const [dealerInfo, setDealerInfo] = useState<{
    dealer_name?: string | null;
    dealer_email?: string | null;
    dealer_phone?: string | null;
    street_address_line_1?: string | null;
    street_address_line_2?: string | null;
    city?: string | null;
    state?: string | null;
    zip_code?: string | null;
    country?: string | null;
  } | null>(null);

  useEffect(() => {
    if (!proposal?.organization_id) return;
    let cancelled = false;
    (async () => {
      const { data } = await supabase
        .from('Organizations')
        .select('name')
        .eq('id', proposal.organization_id)
        .maybeSingle();
      if (!cancelled && data) setOrgName((data as { name?: string }).name ?? null);
    })();
    return () => { cancelled = true; };
  }, [proposal?.organization_id]);

  useEffect(() => {
    if (!proposal?.dealer_id) {
      setDealerInfo(null);
      return;
    }
    let cancelled = false;
    (async () => {
      const { data } = await supabase
        .from('Dealers')
        .select(
          'dealer_name, dealer_email, dealer_phone, street_address_line_1, street_address_line_2, city, state, zip_code, country'
        )
        .eq('id', proposal.dealer_id)
        .maybeSingle();
      if (cancelled) return;
      setDealerInfo(data as any);
    })();
    return () => { cancelled = true; };
  }, [proposal?.dealer_id]);

  const resolvedLogoUrl = useResolvedStorageUrl(dealerLogoUrl ?? null);
  const [logoError, setLogoError] = useState(false);
  const showLogo = Boolean(resolvedLogoUrl) && !logoError;
  const handleLogoError = useCallback(() => setLogoError(true), []);
  useEffect(() => {
    if (!resolvedLogoUrl) setLogoError(false);
  }, [resolvedLogoUrl]);

  const { totals, lineTotals } = useMemo(() => {
    let totalProduct = 0;
    const lineTotals: number[] = [];
    let installationTotal = 0;
    lines.forEach((line) => {
      const qlInfo = line.quote_line_id ? quoteLinesMap.get(line.quote_line_id) : undefined;
      const snap = line.quote_line_snapshot ?? undefined;
      const material = computeLineTotal(line, qlInfo, snap);
      lineTotals.push(material);
      totalProduct += material;
      const lineQty = getProposalLineQty(line, qlInfo, snap);
      const installationAddons = (addonsMap?.get(line.id) || []).filter((a) => a.addon_type === 'installation');
      installationTotal += installationAddons.reduce((s, a) => s + ((Number(a.sale_amount) || 0) * lineQty), 0);
    });
    const discountPct = proposal?.global_discount_pct ?? 0;
    const discountAmount = totalProduct * (discountPct / 100);
    const installationAmount = proposal?.installation_amount ?? installationTotal ?? 0;
    const subtotal = Math.max(totalProduct - discountAmount, 0) + installationAmount;
    const exemptTax = proposal?.exempt_tax ?? false;
    if (exemptTax) {
      return {
        totals: {
          totalProduct,
          discountAmount,
          installationAmount,
          subtotal,
          taxAmount: 0,
          total: subtotal,
        },
        lineTotals,
      };
    }
    if (proposal?.tax_amount != null && proposal?.total_amount != null) {
      return {
        totals: {
          totalProduct,
          discountAmount,
          installationAmount,
          subtotal,
          taxAmount: proposal.tax_amount,
          total: proposal.total_amount,
        },
        lineTotals,
      };
    }
    const taxPct = 0.07;
    const taxAmount = subtotal * taxPct;
    const total = subtotal + taxAmount;
    return {
      totals: { totalProduct, discountAmount, installationAmount, subtotal, taxAmount, total },
      lineTotals,
    };
  }, [lines, addonsMap, quoteLinesMap, proposal?.subtotal_amount, proposal?.installation_amount, proposal?.discount_amount, proposal?.tax_amount, proposal?.total_amount, proposal?.global_discount_pct, proposal?.exempt_tax]);

  const currency = proposal?.currency || 'USD';

  if (!proposalId) {
    return (
      <div className="p-6">
        <p className="text-gray-600">Proposal ID not found.</p>
      </div>
    );
  }

  if (loading || !proposal) {
    return (
      <div className="p-6 flex items-center justify-center min-h-[200px]">
        <p className="text-gray-500">Loading proposal...</p>
      </div>
    );
  }

  if (error) {
    return (
      <div className="p-6">
        <p className="text-red-600">{error}</p>
      </div>
    );
  }

  return (
    <>
      <style>{`
        @media print {
          .print\\:hidden { display: none !important; }
          .proposal-print-page { box-shadow: none; margin: 0; padding: 12mm; }
          body { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
          @page { size: A4; margin: 15mm; }
        }
        @media screen {
          .proposal-print-page { max-width: 210mm; margin: 0 auto; padding: 16px; min-height: 100vh; }
        }
        .proposal-print-page {
          font-family: system-ui, -apple-system, sans-serif;
          font-size: 12px;
          color: #111;
          line-height: 1.4;
        }
        .proposal-receipt-title { font-size: 28px; font-weight: 700; letter-spacing: -0.02em; }
        .proposal-kv { display: grid; grid-template-columns: 140px 1fr; gap: 10px; }
        .proposal-kv .k { color: #6b7280; }
        .proposal-kv .v { color: #111827; font-weight: 600; }
        .proposal-section-title { font-size: 12px; font-weight: 700; color: #111827; }
        .proposal-address { white-space: pre-line; color: #374151; }
        .proposal-big-total { font-size: 22px; font-weight: 700; margin-top: 16px; }
        .proposal-table thead th { font-size: 10px; text-transform: uppercase; letter-spacing: .06em; color: #374151; }
        .proposal-table tbody td { vertical-align: top; }
      `}</style>

      <div className="proposal-print-page bg-white">
        <div className="print:hidden mb-4 flex items-center justify-between">
          <h1 className="text-lg font-semibold text-gray-800">
            {mode === 'internal' ? 'Proposal (Internal)' : 'Proposal / Propuesta'}
          </h1>
          <button
            type="button"
            onClick={() => window.print()}
            className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 text-sm"
          >
            <Printer className="w-4 h-4" />
            Print
          </button>
        </div>

        {/* Header */}
        <header className="border-b border-gray-200 pb-5 mb-5">
          <div className="flex items-start justify-between gap-6">
            <div className="min-w-0">
              <div className="proposal-receipt-title">{mode === 'internal' ? 'Proposal' : 'Proposal'}</div>
              <div className="mt-3 proposal-kv text-sm">
                <div className="k">Proposal number</div>
                <div className="v">{proposal.proposal_no || proposal.id.slice(0, 8)}</div>
                <div className="k">Quote number</div>
                <div className="v">{quote?.quote_no || '—'}</div>
                <div className="k">Date</div>
                <div className="v">{formatDate(proposal.created_at)}</div>
                <div className="k">Valid until</div>
                <div className="v">{formatDate(proposal.valid_until)}</div>
              </div>
            </div>

            <div className="flex-shrink-0 flex flex-col items-end">
              <div className="logo-slot">
                {showLogo ? (
                  <img
                    id="dealerLogoPrint"
                    src={resolvedLogoUrl ?? ''}
                    alt="Dealer logo"
                    crossOrigin="anonymous"
                    onError={handleLogoError}
                    className="max-w-full max-h-full object-contain"
                  />
                ) : (
                  <div className="flex items-center justify-center w-full h-full text-gray-400 text-xs" aria-hidden>
                    Dealer logo
                  </div>
                )}
              </div>
            </div>
          </div>

          <div className="mt-6 grid grid-cols-2 gap-10 text-sm">
            <div>
              <div className="proposal-section-title">From</div>
              <div className="mt-2 proposal-address">
                {formatAddressBlock([
                  dealerInfo?.dealer_name ?? orgName,
                  dealerInfo?.street_address_line_1,
                  dealerInfo?.street_address_line_2,
                  [dealerInfo?.city, dealerInfo?.state, dealerInfo?.zip_code].filter(Boolean).join(', '),
                  dealerInfo?.country,
                  dealerInfo?.dealer_phone,
                  dealerInfo?.dealer_email,
                ]) || '—'}
              </div>
            </div>
            <div>
              <div className="proposal-section-title">Bill to</div>
              <div className="mt-2 proposal-address">
                {formatAddressBlock([
                  customer?.customer_name,
                  contact?.contact_name,
                  contact?.contact_email,
                  customer?.address ?? null,
                ]) || '—'}
              </div>
            </div>
          </div>

          <div className="proposal-big-total">
            {formatCurrency(totals.total, currency)} total on {formatDate(proposal.created_at)}
          </div>

          {proposal.notes && (
            <div className="mt-2 text-sm text-gray-600">
              <span className="text-gray-500">Notes:</span> {proposal.notes}
            </div>
          )}
        </header>

        {/* Lines table */}
        {mode === 'internal' ? (
          <table className="proposal-table w-full border-collapse text-sm mb-5">
            <thead>
              <tr className="border-b border-gray-200">
                <th className="py-2 pr-2 text-left font-medium w-[28px]">#</th>
                <th className="py-2 px-2 text-left font-medium w-[90px]">Area</th>
                <th className="py-2 px-2 text-left font-medium w-[70px]">Position</th>
                <th className="py-2 px-2 text-left font-medium">Product type</th>
                <th className="py-2 px-2 text-left font-medium">Collection</th>
                <th className="py-2 px-2 text-left font-medium w-[110px]">System drive</th>
                <th className="py-2 px-2 text-left font-medium w-[140px]">Measurements</th>
                <th className="py-2 px-2 text-left font-medium w-[110px]">Accessories</th>
                <th className="py-2 pl-2 text-right font-medium w-[60px]">Qty</th>
                <th className="py-2 pl-2 text-right font-medium w-[90px]">Unit Price</th>
                <th className="py-2 pl-2 text-right font-medium w-[90px]">Total</th>
              </tr>
            </thead>
            <tbody>
              {lines.map((line, index) => {
                const snapFrozen = line.quote_line_snapshot;
                const qlInfo = line.quote_line_id ? quoteLinesMap.get(line.quote_line_id) : undefined;
                const lineTotal = lineTotals[index] ?? 0;
                const qty = line.line_type === 'custom'
                  ? Number(line.qty) || 0
                  : snapFrozen?.qty ?? qlInfo?.quantity ?? 0;
                // Unit price = adjusted (lineTotal/qty); no override display
                const unitPrice = qty > 0 ? lineTotal / qty : 0;
                const baseAmount = unitPrice;
                const snap =
                  snapFrozen
                    ? { measurements: snapFrozen.measurements, accessories: snapFrozen.accessories }
                    : qlInfo?.config_snapshot ??
                      (qlInfo?.configured_product_id ? (configuredProductsMap ?? {})[qlInfo.configured_product_id]?.config_snapshot : undefined);
                const dimensionsSource =
                  snap?.measurements && typeof snap.measurements === 'object'
                    ? snap.measurements
                    : snapFrozen
                      ? { width_m: snapFrozen.width_m, height_m: snapFrozen.height_m }
                      : qlInfo
                        ? { width_m: qlInfo.width_m, height_m: qlInfo.height_m }
                        : null;
                const measurements = dimensionsSource ? compactMeasurementsNoUnit(dimensionsSource) : '—';
                const accessories = snap ? formatAccessoriesFromSnapshot(snap.accessories) : '—';
                const collection = snapFrozen
                  ? [snapFrozen.collection_name, snapFrozen.variant_name].filter(Boolean).join(' - ')
                  : qlInfo
                    ? [qlInfo.collection_name, qlInfo.variant_name].filter(Boolean).join(' - ')
                    : '—';

                if (line.line_type === 'custom') {
                  return (
                    <tr key={line.id} className="border-b border-gray-100">
                      <td className="py-2 pr-2 text-gray-700">{index + 1}</td>
                      <td className="py-2 px-2 text-gray-500">—</td>
                      <td className="py-2 px-2 text-gray-500">—</td>
                      <td className="py-2 px-2">
                        <div className="font-medium text-gray-900">Custom</div>
                        <div className="text-gray-600">{line.description || '—'}{line.custom_category ? ` (${line.custom_category})` : ''}</div>
                      </td>
                      <td className="py-2 px-2 text-gray-500">—</td>
                      <td className="py-2 px-2 text-gray-500">—</td>
                      <td className="py-2 px-2 text-gray-500">{measurements}</td>
                      <td className="py-2 px-2 text-gray-500">{accessories}</td>
                      <td className="py-2 pl-2 text-right">{Number(line.qty) || 0}</td>
                      <td className="py-2 pl-2 text-right">{formatCurrency(baseAmount, currency)}</td>
                      <td className="py-2 pl-2 text-right font-semibold">{formatCurrency(lineTotal, currency)}</td>
                    </tr>
                  );
                }

                return (
                  <tr key={line.id} className="border-b border-gray-100">
                    <td className="py-2 pr-2 text-gray-700">{index + 1}</td>
                    <td className="py-2 px-2">{snapFrozen?.area ?? qlInfo?.area ?? '—'}</td>
                    <td className="py-2 px-2">{snapFrozen?.position ?? qlInfo?.position ?? '—'}</td>
                    <td className="py-2 px-2">
                      <div className="font-medium text-gray-900">{snapFrozen?.product_type ?? qlInfo?.product_type ?? '—'}</div>
                      <div className="text-gray-600">{snapFrozen?.name || snapFrozen?.sku || qlInfo?.name || qlInfo?.sku || '—'}</div>
                    </td>
                    <td className="py-2 px-2">{collection || '—'}</td>
                    <td className="py-2 px-2">{snapFrozen?.drive_type ?? qlInfo?.drive_type ?? '—'}</td>
                    <td className="py-2 px-2">{measurements}</td>
                    <td className="py-2 px-2">{accessories}</td>
                    <td className="py-2 pl-2 text-right">{snapFrozen?.qty ?? qlInfo?.quantity ?? '—'}</td>
                    <td className="py-2 pl-2 text-right">{formatCurrency(baseAmount, currency)}</td>
                    <td className="py-2 pl-2 text-right font-semibold">{formatCurrency(lineTotal, currency)}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        ) : (
          <table className="proposal-table w-full border-collapse text-sm mb-5">
            <thead>
              <tr className="border-b border-gray-200">
                <th className="py-2 pr-2 text-left font-medium w-[28px]">#</th>
                <th className="py-2 px-2 text-left font-medium">Description</th>
                <th className="py-2 pl-2 text-right font-medium w-[70px]">Qty</th>
                <th className="py-2 pl-2 text-right font-medium w-[110px]">Unit price</th>
                <th className="py-2 pl-2 text-right font-medium w-[110px]">Amount</th>
              </tr>
            </thead>
            <tbody>
              {lines.map((line, index) => {
                const snapFrozen = line.quote_line_snapshot;
                const qlInfo = line.quote_line_id ? quoteLinesMap.get(line.quote_line_id) : undefined;
                const lineTotal = lineTotals[index] ?? 0;
                const qty =
                  line.line_type === 'custom'
                    ? Number(line.qty) || 0
                    : snapFrozen?.qty ?? qlInfo?.quantity ?? 0;
                const unitPrice = qty > 0 ? lineTotal / qty : 0;
                const description =
                  line.line_type === 'custom'
                    ? (line.description || '—') + (line.custom_category ? ` (${line.custom_category})` : '')
                    : (snapFrozen?.name || snapFrozen?.sku || qlInfo?.name || qlInfo?.sku || '—') +
                      (snapFrozen?.sku || qlInfo?.sku ? ` (${snapFrozen?.sku ?? qlInfo?.sku ?? ''})` : '');

                return (
                  <tr key={line.id} className="border-b border-gray-100">
                    <td className="py-2 pr-2 text-gray-700">{index + 1}</td>
                    <td className="py-2 px-2">{description}</td>
                    <td className="py-2 pl-2 text-right">{qty}</td>
                    <td className="py-2 pl-2 text-right">{formatCurrency(unitPrice, currency)}</td>
                    <td className="py-2 pl-2 text-right font-semibold">{formatCurrency(lineTotal, currency)}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}

        {/* Totals: Total Product, Discount, Installation, Subtotal, Tax, Total */}
        <div className="flex justify-end">
          <div className="w-64 border border-gray-200 rounded-lg p-3 text-sm">
            <div className="flex justify-between py-1">
              <span className="text-gray-600">Total Product</span>
              <span>{formatCurrency(totals.totalProduct ?? 0, currency)}</span>
            </div>
            {(totals.discountAmount ?? 0) > 0 && (
              <div className="flex justify-between py-1">
                <span className="text-gray-600">Discount {proposal.global_discount_pct != null ? `(${proposal.global_discount_pct}%)` : ''}</span>
                <span>-{formatCurrency(totals.discountAmount ?? 0, currency)}</span>
              </div>
            )}
            {(totals.installationAmount ?? 0) > 0 && (
              <div className="flex justify-between py-1">
                <span className="text-gray-600">Installation</span>
                <span>{formatCurrency(totals.installationAmount ?? 0, currency)}</span>
              </div>
            )}
            <div className="flex justify-between py-1">
              <span className="text-gray-600">Subtotal</span>
              <span>{formatCurrency(totals.subtotal ?? 0, currency)}</span>
            </div>
            {!proposal?.exempt_tax && (
              <div className="flex justify-between py-1">
                <span className="text-gray-600">Tax</span>
                <span>{formatCurrency(totals.taxAmount ?? 0, currency)}</span>
              </div>
            )}
            <div className="flex justify-between py-2 mt-1 border-t border-gray-200 font-semibold">
              <span>Total ({currency})</span>
              <span>{formatCurrency(totals.total, currency)}</span>
            </div>
          </div>
        </div>

        {/* Disclaimer */}
        <div className="mt-6 pt-4 border-t border-gray-100 text-xs text-gray-500">
          {mode === 'customer' && proposal.valid_until && (
            <p>Prices valid until {formatDate(proposal.valid_until)}.</p>
          )}
          {mode === 'internal' && <p>Internal use only.</p>}
        </div>
      </div>
    </>
  );
}

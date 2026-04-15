import { useState, useEffect, useCallback, useMemo } from 'react';
import { supabase } from '../../lib/supabase/client';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useAuth } from '../../hooks/useAuth';
import { useAccessContext } from '../../hooks/useAccessContext';
import { useActiveDealer } from '../../hooks/useActiveDealer';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { router } from '../../lib/router';
import { useUIStore } from '../../stores/ui-store';
import { ArrowLeft, Search, Upload, X, Loader2, CheckSquare, Square, AlertTriangle } from 'lucide-react';
import type { ClaimType, ClaimPriority } from '../../hooks/useServiceClaims';

const SERVICE_SUBMODULES = [
  { id: 'claims', label: 'Claims', href: '/service/claims' },
];

interface SOOption {
  id: string;
  sales_order_no: string;
  dealer_id: string;
  Dealers?: { dealer_name: string } | null;
  status: string;
}

interface SOLineOption {
  id: string;
  line_number: number | null;
  description: string | null;
  product_type: string | null;
  quantity: number;
  unit_price: number | null;
  quote_line_id: string | null;
  configured_product_id: string | null;
}

interface SelectedLine {
  sol: SOLineOption;
  configuredProductId: string | null;
  selected: boolean;
  qtyAffected: number;
  reason: string;
}

const CLAIM_TYPES: { value: ClaimType; label: string }[] = [
  { value: 'defect', label: 'Manufacturing Defect' },
  { value: 'damage', label: 'Shipping / Handling Damage' },
  { value: 'wrong_size', label: 'Wrong Size' },
  { value: 'wrong_color', label: 'Wrong Color' },
  { value: 'missing_parts', label: 'Missing Parts' },
  { value: 'other', label: 'Other' },
];

const PRIORITY_OPTIONS: { value: ClaimPriority; label: string }[] = [
  { value: 'low', label: 'Low' },
  { value: 'medium', label: 'Medium' },
  { value: 'high', label: 'High' },
  { value: 'urgent', label: 'Urgent' },
];

export default function ClaimNew() {
  const { activeOrganizationId } = useOrganizationContext();
  const { user } = useAuth();
  const { isInternal } = useAccessContext();
  const { activeDealerId } = useActiveDealer();
  const { registerSubmodules } = useSubmoduleNav();
  const addNotification = useUIStore((s) => s.addNotification);

  useEffect(() => { registerSubmodules('Service', SERVICE_SUBMODULES); }, [registerSubmodules]);

  // Step 1: SO selection
  const [soSearch, setSOSearch] = useState('');
  const [soOptions, setSOOptions] = useState<SOOption[]>([]);
  const [soLoading, setSOLoading] = useState(false);
  const [selectedSO, setSelectedSO] = useState<SOOption | null>(null);

  // Step 2: Line selection
  const [soLines, setSOLines] = useState<SelectedLine[]>([]);
  const [linesLoading, setLinesLoading] = useState(false);

  // Step 3: Claim details
  const [claimType, setClaimType] = useState<ClaimType>('defect');
  const [priority, setPriority] = useState<ClaimPriority>('medium');
  const [description, setDescription] = useState('');
  const [files, setFiles] = useState<File[]>([]);
  const [submitting, setSubmitting] = useState(false);

  const searchSO = useCallback(async (q: string) => {
    if (!activeOrganizationId || q.length < 2) { setSOOptions([]); return; }
    setSOLoading(true);
    let query = supabase
      .from('SalesOrders')
      .select('id, sales_order_no, dealer_id, status, Dealers:dealer_id (dealer_name)')
      .eq('organization_id', activeOrganizationId)
      .eq('deleted', false)
      .ilike('sales_order_no', `%${q}%`)
      .order('created_at', { ascending: false })
      .limit(15);
    if (!isInternal && activeDealerId) {
      query = query.eq('dealer_id', activeDealerId);
    }
    const { data } = await query;
    setSOOptions((data ?? []) as unknown as SOOption[]);
    setSOLoading(false);
  }, [activeOrganizationId, isInternal, activeDealerId]);

  useEffect(() => {
    const t = setTimeout(() => { if (soSearch.length >= 2) searchSO(soSearch); }, 300);
    return () => clearTimeout(t);
  }, [soSearch, searchSO]);

  const selectSO = useCallback(async (so: SOOption) => {
    setSelectedSO(so);
    setSOSearch('');
    setSOOptions([]);
    setLinesLoading(true);

    const { data: solRows } = await supabase
      .from('SaleOrderLines')
      .select('id, line_number, description, product_type, quantity, unit_price, quote_line_id')
      .eq('sales_order_id', so.id)
      .eq('deleted', false)
      .order('line_number', { ascending: true, nullsFirst: false });

    if (solRows) {
      const qlIds = solRows.map((r: any) => r.quote_line_id).filter(Boolean);
      const cpMap = new Map<string, string>();
      if (qlIds.length > 0) {
        const { data: qls } = await supabase
          .from('QuoteLines')
          .select('id, configured_product_id')
          .in('id', qlIds);
        (qls ?? []).forEach((ql: any) => { if (ql.configured_product_id) cpMap.set(ql.id, ql.configured_product_id); });
      }

      setSOLines(solRows.map((sol: any) => ({
        sol,
        configuredProductId: sol.quote_line_id ? cpMap.get(sol.quote_line_id) ?? null : null,
        selected: false,
        qtyAffected: Number(sol.quantity) || 1,
        reason: '',
      })));
    }
    setLinesLoading(false);
  }, []);

  const toggleLine = (idx: number) => {
    setSOLines((prev) => prev.map((l, i) => i === idx ? { ...l, selected: !l.selected } : l));
  };

  const updateLineQty = (idx: number, qty: number) => {
    setSOLines((prev) => prev.map((l, i) => i === idx ? { ...l, qtyAffected: qty } : l));
  };

  const updateLineReason = (idx: number, reason: string) => {
    setSOLines((prev) => prev.map((l, i) => i === idx ? { ...l, reason } : l));
  };

  const selectedLines = useMemo(() => soLines.filter((l) => l.selected), [soLines]);
  const canSubmit = selectedSO && selectedLines.length > 0 && description.trim().length > 0 && !submitting;

  const handleSubmit = async () => {
    if (!canSubmit || !activeOrganizationId || !user) return;
    setSubmitting(true);

    try {
      const { data: claimData, error: claimErr } = await supabase
        .from('ServiceClaims')
        .insert({
          organization_id: activeOrganizationId,
          dealer_id: selectedSO.dealer_id,
          sales_order_id: selectedSO.id,
          status: 'draft',
          claim_type: claimType,
          priority,
          description: description.trim(),
          reported_by: user.id,
        })
        .select('id')
        .single();

      if (claimErr) throw claimErr;
      const claimId = claimData.id;

      const lineInserts = selectedLines.map((l) => ({
        claim_id: claimId,
        sale_order_line_id: l.sol.id,
        configured_product_id: l.configuredProductId,
        description: l.sol.description,
        qty_affected: l.qtyAffected,
        claim_reason: l.reason || null,
      }));
      const { error: linesErr } = await supabase.from('ServiceClaimLines').insert(lineInserts);
      if (linesErr) console.warn('[ClaimNew] lines insert error:', linesErr);

      if (files.length > 0) {
        for (const file of files) {
          const path = `${activeOrganizationId}/${claimId}/${Date.now()}_${file.name}`;
          const { error: upErr } = await supabase.storage.from('service-claim-attachments').upload(path, file);
          if (!upErr) {
            await supabase.from('ServiceClaimAttachments').insert({
              claim_id: claimId,
              organization_id: activeOrganizationId,
              file_name: file.name,
              file_path: path,
              uploaded_by: user.id,
            });
          }
        }
      }

      addNotification({ type: 'success', title: 'Claim Created', message: 'Claim created successfully' });
      router.navigate(`/service/claims/${claimId}`);
    } catch (err: any) {
      addNotification({ type: 'error', title: 'Error', message: err.message || 'Failed to create claim' });
    } finally {
      setSubmitting(false);
    }
  };

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files) setFiles((prev) => [...prev, ...Array.from(e.target.files!)]);
  };

  const removeFile = (idx: number) => {
    setFiles((prev) => prev.filter((_, i) => i !== idx));
  };

  return (
    <div className="max-w-3xl mx-auto space-y-6">
      <div className="flex items-center gap-3">
        <button onClick={() => router.navigate('/service/claims')} className="p-1.5 rounded-lg hover:bg-gray-100">
          <ArrowLeft className="w-5 h-5 text-gray-500" />
        </button>
        <h1 className="text-lg font-semibold text-gray-900">New Service Claim</h1>
      </div>

      {/* Step 1: Select SO */}
      <div className="bg-white border border-gray-200 rounded-lg p-5 space-y-4">
        <h2 className="text-sm font-semibold text-gray-900 uppercase tracking-wider">1. Sales Order</h2>
        {selectedSO ? (
          <div className="flex items-center justify-between bg-blue-50 rounded-lg px-4 py-3">
            <div>
              <span className="font-semibold text-blue-900">{selectedSO.sales_order_no}</span>
              {selectedSO.Dealers && <span className="ml-2 text-sm text-blue-700">— {selectedSO.Dealers.dealer_name}</span>}
            </div>
            <button onClick={() => { setSelectedSO(null); setSOLines([]); }} className="text-blue-600 hover:text-blue-800 text-sm">Change</button>
          </div>
        ) : (
          <div className="relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
            <input
              type="text"
              placeholder="Search by SO number (e.g. SO-00100)..."
              value={soSearch}
              onChange={(e) => setSOSearch(e.target.value)}
              className="w-full pl-9 pr-3 py-2.5 text-sm border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary"
            />
            {soLoading && <Loader2 className="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 animate-spin text-gray-400" />}
            {soOptions.length > 0 && (
              <div className="absolute z-10 mt-1 w-full bg-white border border-gray-200 rounded-lg shadow-lg max-h-60 overflow-y-auto">
                {soOptions.map((so) => (
                  <button
                    key={so.id}
                    type="button"
                    onClick={() => selectSO(so)}
                    className="w-full text-left px-4 py-2.5 hover:bg-gray-50 text-sm flex items-center justify-between"
                  >
                    <span className="font-medium">{so.sales_order_no}</span>
                    <span className="text-gray-500">{so.Dealers?.dealer_name ?? ''}</span>
                  </button>
                ))}
              </div>
            )}
          </div>
        )}
      </div>

      {/* Step 2: Select affected lines */}
      {selectedSO && (
        <div className="bg-white border border-gray-200 rounded-lg p-5 space-y-4">
          <h2 className="text-sm font-semibold text-gray-900 uppercase tracking-wider">2. Affected Products</h2>
          {linesLoading ? (
            <div className="flex items-center gap-2 py-4 text-sm text-gray-400">
              <Loader2 className="w-4 h-4 animate-spin" /> Loading lines…
            </div>
          ) : soLines.length === 0 ? (
            <p className="text-sm text-gray-500 py-4">No lines found for this order.</p>
          ) : (
            <div className="space-y-2">
              {soLines.map((line, idx) => (
                <div
                  key={line.sol.id}
                  className={`border rounded-lg p-3 transition-colors ${line.selected ? 'border-primary bg-primary/5' : 'border-gray-200 hover:border-gray-300'}`}
                >
                  <div className="flex items-start gap-3">
                    <button type="button" onClick={() => toggleLine(idx)} className="mt-0.5 shrink-0">
                      {line.selected ? <CheckSquare className="w-5 h-5 text-primary" /> : <Square className="w-5 h-5 text-gray-300" />}
                    </button>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center justify-between">
                        <span className="text-sm font-medium text-gray-900 truncate">{line.sol.description || `Line ${line.sol.line_number}`}</span>
                        <span className="text-xs text-gray-500 ml-2 shrink-0">Qty: {line.sol.quantity}</span>
                      </div>
                      {line.sol.product_type && <span className="text-xs text-gray-500">{line.sol.product_type}</span>}
                      {line.selected && (
                        <div className="mt-3 grid grid-cols-2 gap-3">
                          <div>
                            <label className="text-xs text-gray-500 mb-1 block">Qty Affected</label>
                            <input
                              type="number"
                              min={1}
                              max={Number(line.sol.quantity) || 999}
                              value={line.qtyAffected}
                              onChange={(e) => updateLineQty(idx, parseInt(e.target.value) || 1)}
                              className="w-full px-2.5 py-1.5 text-sm border border-gray-200 rounded-lg"
                            />
                          </div>
                          <div>
                            <label className="text-xs text-gray-500 mb-1 block">Reason (optional)</label>
                            <input
                              type="text"
                              value={line.reason}
                              onChange={(e) => updateLineReason(idx, e.target.value)}
                              placeholder="e.g. Fabric torn on left side"
                              className="w-full px-2.5 py-1.5 text-sm border border-gray-200 rounded-lg"
                            />
                          </div>
                        </div>
                      )}
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* Step 3: Claim details */}
      {selectedSO && selectedLines.length > 0 && (
        <div className="bg-white border border-gray-200 rounded-lg p-5 space-y-4">
          <h2 className="text-sm font-semibold text-gray-900 uppercase tracking-wider">3. Claim Details</h2>
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="text-xs text-gray-500 mb-1 block">Claim Type</label>
              <select
                value={claimType}
                onChange={(e) => setClaimType(e.target.value as ClaimType)}
                className="w-full px-3 py-2 text-sm border border-gray-200 rounded-lg"
              >
                {CLAIM_TYPES.map((t) => <option key={t.value} value={t.value}>{t.label}</option>)}
              </select>
            </div>
            <div>
              <label className="text-xs text-gray-500 mb-1 block">Priority</label>
              <select
                value={priority}
                onChange={(e) => setPriority(e.target.value as ClaimPriority)}
                className="w-full px-3 py-2 text-sm border border-gray-200 rounded-lg"
              >
                {PRIORITY_OPTIONS.map((p) => <option key={p.value} value={p.value}>{p.label}</option>)}
              </select>
            </div>
          </div>
          <div>
            <label className="text-xs text-gray-500 mb-1 block">Description *</label>
            <textarea
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              rows={4}
              placeholder="Describe the issue in detail..."
              className="w-full px-3 py-2 text-sm border border-gray-200 rounded-lg resize-none"
            />
          </div>

          {/* Attachments */}
          <div>
            <label className="text-xs text-gray-500 mb-2 block">Attachments (photos, documents)</label>
            <label className="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm border border-gray-200 rounded-lg cursor-pointer hover:bg-gray-50 transition-colors">
              <Upload className="w-4 h-4 text-gray-400" />
              <span className="text-gray-600">Add files</span>
              <input type="file" multiple accept="image/*,.pdf" onChange={handleFileChange} className="sr-only" />
            </label>
            {files.length > 0 && (
              <div className="mt-2 space-y-1">
                {files.map((f, i) => (
                  <div key={i} className="flex items-center gap-2 text-sm text-gray-600">
                    <span className="truncate">{f.name}</span>
                    <button onClick={() => removeFile(i)} className="text-gray-400 hover:text-red-500"><X className="w-3.5 h-3.5" /></button>
                  </div>
                ))}
              </div>
            )}
          </div>

          <div className="flex items-center justify-end gap-3 pt-2 border-t border-gray-100">
            <button
              type="button"
              onClick={() => router.navigate('/service/claims')}
              className="px-4 py-2 text-sm text-gray-600 hover:text-gray-800"
            >
              Cancel
            </button>
            <button
              type="button"
              onClick={handleSubmit}
              disabled={!canSubmit}
              className="inline-flex items-center gap-1.5 px-4 py-2 text-sm font-medium text-white bg-primary rounded-lg hover:bg-primary/90 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            >
              {submitting && <Loader2 className="w-4 h-4 animate-spin" />}
              Create Claim
            </button>
          </div>
        </div>
      )}

      {selectedSO && selectedLines.length === 0 && soLines.length > 0 && (
        <div className="flex items-center gap-2 text-sm text-amber-600 bg-amber-50 rounded-lg px-4 py-3">
          <AlertTriangle className="w-4 h-4 shrink-0" />
          Select at least one affected product line to continue.
        </div>
      )}
    </div>
  );
}

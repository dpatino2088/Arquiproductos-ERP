/**
 * QuoteNew - Create and Edit Quotes
 * Clean implementation from scratch
 */

import React, { useState, useEffect, useMemo, useRef } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { router } from '../../lib/router';
import { supabase } from '../../lib/supabase/client';
import { useUIStore } from '../../stores/ui-store';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useAccessContext } from '../../hooks/useAccessContext';
import { useDirectoryCustomers } from '../../hooks/useDirectoryCustomers';
import { useCreateQuote, useUpdateQuote, useQuoteLines, approveQuote, normalizeStatus } from '../../hooks/useQuotes';
import { QuoteStatus } from '../../types/catalog';
import { Plus, Edit, Trash2, X, Download, GripVertical, Eye, Copy, FileText } from 'lucide-react';
import { useProposalsByQuote, createProposalFromQuote } from '../../hooks/useProposals';
import { useActiveDealer } from '../../hooks/useActiveDealer';
import ProductConfigurator from './ProductConfigurator';
import { ProductConfig } from './product-config/types';
import { normalizeConfiguratorConfig, normalizeConfig } from './product-config/config-contract';
import Input from '../../components/ui/Input';
import Label from '../../components/ui/Label';
import { Select as SelectShadcn, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../../components/ui/SelectShadcn';
import ConfirmDialog from '../../components/ui/ConfirmDialog';
import { generateQuotePDF, type PDFVariant } from '../../lib/pdf/generateQuotePDF';
import { useCostSettings } from '../../hooks/useCosts';
import { useDealerTiers } from '../../hooks/useDealerTiers';
import { calculateQuoteLinePrice, getDealerTierDiscountPct } from '../../lib/pricing';
import { createQuoteLineFromConfiguredProduct } from '../../lib/quotes/createQuoteLineFromConfiguredProduct';
import { finalizeQuoteLineFromConfiguredProduct } from '../../lib/quotes/finalizeQuoteLineFromConfiguredProduct';
import { commitConfiguredProduct } from '../../lib/quotes/commitConfiguredProductToQuoteLine';
import { getConfigFromQuoteLine } from '../../lib/quotes/getConfigFromQuoteLine';
import { createConfiguredProductPreview, recalculateConfiguredProductTotals } from '../../lib/bom/createConfiguredProductPreview';
import DimensionsStackView from '../../components/DimensionsStackView';
import QuoteTermsDisplay from '../../components/sales/QuoteTermsDisplay';
import { resolveDefaultTermsTemplateId, fetchTermsTemplateById } from '../../lib/terms';

// ====================================================
// UTILS: Error Serialization (Safe)
// ====================================================
function safeErr(e: any) {
  return {
    message: e?.message,
    details: e?.details,
    hint: e?.hint,
    code: e?.code,
    status: e?.status,
  };
}

// ====================================================
// UTILS: Product Type Resolution (A)
// ====================================================
const PRODUCT_TYPE_ALIASES: Record<string, string[]> = {
  "roller-shade": ["roller_shade", "roller", "ROLLER", "roller-shade"],
  "dual-shade": ["dual_shade", "dual", "DUAL", "dual-shade"],
  "triple-shade": ["triple_shade", "triple", "TRIPLE", "triple-shade"],
  "drapery": ["drapery", "DRAPERY"],
  "awning": ["awning", "AWNING"],
};

function normalizePT(s: string) {
  return (s || "")
    .trim()
    .toLowerCase()
    .replace(/\s+/g, "_")
    .replace(/-/g, "_");
}

async function resolveProductTypeId(
  supabase: any,
  organizationId: string,
  productTypeRaw: string
): Promise<string | null> {
  // ✅ GUARDRAIL: No consultar sin organizationId
  if (!organizationId) {
    if (import.meta.env.DEV) {
      console.error("❌ resolveProductTypeId: Missing organizationId; cannot resolve ProductTypes.");
    }
    return null;
  }

  if (import.meta.env.DEV) {
    console.log("🔍 resolveProductTypeId DEBUG:", { organizationId, productTypeRaw });
  }

  const norm = normalizePT(productTypeRaw);
  const candidates = [
    ...(PRODUCT_TYPE_ALIASES[productTypeRaw] ?? []),
    norm,
    norm.replace(/_shade$/, ""),      // roller_shade -> roller
    norm.replace(/_shades$/, ""),
    productTypeRaw,
  ].filter(Boolean);

  // ✅ FIX: Soportar registros globales (organization_id NULL)
  // 1) exact/ilike on code
  for (const code of candidates) {
    // exact
    {
      // ✅ FIX: ProductTypes NO tiene columna "deleted"
      const { data, error } = await supabase
        .from("ProductTypes")
        .select("id")
        .or(`organization_id.eq.${organizationId},organization_id.is.null`)
        .eq("code", code)
        .limit(1);

      if (!error && data?.[0]?.id) {
        if (import.meta.env.DEV) {
          console.log("✅ resolveProductTypeId: Found by exact code", { code, id: data[0].id });
        }
        return data[0].id;
      }
    }
    // ilike
    {
      // ✅ FIX: ProductTypes NO tiene columna "deleted"
      const { data, error } = await supabase
        .from("ProductTypes")
        .select("id")
        .or(`organization_id.eq.${organizationId},organization_id.is.null`)
        .ilike("code", code)
        .limit(1);

      if (!error && data?.[0]?.id) {
        if (import.meta.env.DEV) {
          console.log("✅ resolveProductTypeId: Found by ilike code", { code, id: data[0].id });
        }
        return data[0].id;
      }
    }
  }

  // 2) fallback: by name
  for (const name of candidates) {
    // ✅ FIX: ProductTypes NO tiene columna "deleted"
    const { data, error } = await supabase
      .from("ProductTypes")
      .select("id")
      .or(`organization_id.eq.${organizationId},organization_id.is.null`)
      .ilike("name", `%${name.replace(/_/g, " ")}%`)
      .limit(1);
    if (!error && data?.[0]?.id) {
      if (import.meta.env.DEV) {
        console.log("✅ resolveProductTypeId: Found by name", { name, id: data[0].id });
      }
      return data[0].id;
    }
  }

  if (import.meta.env.DEV) {
    console.warn("⚠️ resolveProductTypeId: No match found", { productTypeRaw, candidates });
  }

  return null;
}

/** Build config_snapshot from productConfig for create_configured_product_and_bom_preview (EDIT SAVE). */
function buildConfigSnapshotFromProductConfig(productConfig: any): Record<string, any> {
  const configAny = productConfig;
  const finalNormalizedConfig = normalizeConfig(productConfig as any) as any;
  const panelsList = Array.isArray(configAny.panels) ? configAny.panels : (configAny.panels ? [configAny.panels] : []);
  const panelCount = configAny.measurements?.panel_count ?? (panelsList.length || 1);
  const widthTotalMm = configAny.measurements?.width_total_mm ?? panelsList.reduce((s: number, p: any) => s + (p?.width_mm || 0), 0);
  const measurements = configAny.measurements ?? {
    height_mm: finalNormalizedConfig.height_m ? finalNormalizedConfig.height_m * 1000 : configAny.height_mm ?? null,
    width_total_mm: widthTotalMm,
    panel_count: panelCount,
    panels: (panelsList.length ? panelsList : [{ index: 1, width_mm: configAny.width_mm || 0 }]).map((p: any, i: number) => ({ index: i + 1, width_mm: p?.width_mm ?? 0 })),
    is_interconnected: panelCount > 1,
  };
  const widthMmForBom = panelCount > 1 ? widthTotalMm : (panelsList[0]?.width_mm ?? configAny.width_mm ?? null);
  const pickSku = (cfg: any, keys: string[]): string | null => {
    for (const k of keys) {
      const v = cfg?.[k];
      if (typeof v === 'string' && v.trim().length > 0) return v.trim();
    }
    return null;
  };
  return {
    ...finalNormalizedConfig,
    width_mm: widthMmForBom ?? (finalNormalizedConfig.width_m ? finalNormalizedConfig.width_m * 1000 : null),
    height_mm: finalNormalizedConfig.height_m ? finalNormalizedConfig.height_m * 1000 : (measurements.height_mm ?? configAny.height_mm ?? null),
    measurements,
    hardware_color: (() => {
      const color = finalNormalizedConfig.hardware_color || configAny.hardwareColor || configAny.operatingSystemColor;
      if (!color) return null;
      return String(color).charAt(0).toUpperCase() + String(color).slice(1).toLowerCase();
    })(),
    bottom_bar_item_id: configAny.bottom_bar_item_id || null,
    bottom_bar_sku: pickSku(configAny, ['bottom_bar_sku', 'bottomBarSku', 'bottom_bar']) || null,
    headbox_item_id: (configAny.headbox_item_id === 'NONE' ? null : configAny.headbox_item_id) || null,
    headbox_sku: configAny.headbox_sku ? String(configAny.headbox_sku).trim() : null,
    side_channel_item_id: (configAny.side_channel_item_id === 'NONE' ? null : configAny.side_channel_item_id) || null,
    side_channel_sku: configAny.side_channel_sku ? String(configAny.side_channel_sku).trim() : null,
    bottom_channel_item_id: (configAny.bottom_channel_item_id === 'NONE' ? null : configAny.bottom_channel_item_id) || null,
    bottom_channel_sku: configAny.bottom_channel_sku ? String(configAny.bottom_channel_sku).trim() : null,
    motor_item_id: configAny.motor_item_id || null,
    motor_sku: configAny.motor_sku ? String(configAny.motor_sku).trim() : null,
    drive_item_id: configAny.drive_item_id || null,
    drive_sku: configAny.drive_sku ? String(configAny.drive_sku).trim() : null,
    tube_item_id: configAny.tube_item_id || null,
    tube_sku: pickSku(configAny, ['tube_sku', 'tubeSku', 'tube_type', 'tubeType']) || null,
    operating_type: configAny.operation_type || configAny.drive_type || null,
    roll_catalog_item_id: finalNormalizedConfig.fabric_variant_id || configAny.variantId || configAny.catalogItemId || null,
    quantity: finalNormalizedConfig.quantity || 1,
    fabricDrop: configAny.fabricDrop ?? configAny.fabric_drop ?? null,
    installationType: configAny.installationType ?? configAny.installation_type ?? null,
    installationLocation: configAny.installationLocation ?? configAny.installation_location ?? null,
    drive_side: configAny.driveSide || configAny.drive_side || null,
    opening_direction: configAny.openingDirection || configAny.opening_direction || null,
    manufacturer: configAny.manufacturer || null,
    product_line: configAny.productLine || configAny.product_line || null,
    style_code: configAny.styleCode || configAny.style_code || null,
    force_track_join: configAny.forceTrackJoin ?? configAny.force_track_join ?? false,
    accessories: Array.isArray(configAny.accessories) ? configAny.accessories : (finalNormalizedConfig.accessories || []),
  };
}

// ====================================================
// UTILS: BOM Pricing Calculation (DEPRECATED - Legacy)
// ✅ Las tablas BOMInstances/BOMInstanceLines ya no existen.
// Los precios ahora vienen de ConfiguredProducts.bom_preview_snapshot
// ====================================================
async function priceFromBOMInstance(opts: {
  supabase: any;
  bomInstanceId: string;
  organizationId: string;
}) {
  const { supabase, bomInstanceId } = opts;

  // ✅ DEPRECATED: Esta función ya no se debe usar.
  // Los precios vienen de ConfiguredProducts.bom_preview_snapshot
  if (!bomInstanceId) {
    return { total: 0, totalCost: 0, missingParts: 0, linesCount: 0, pricedCount: 0 };
  }

  // 1) Trae líneas del BOM (puede fallar si tabla no existe)
  const { data: bomLines, error: linesErr } = await supabase
    .from("BOMInstanceLines")
    .select("id, resolved_part_id, qty, part_role")
    .eq("bom_instance_id", bomInstanceId)
    .eq("deleted", false);

  if (linesErr) {
    // ✅ Si la tabla no existe, retornar 0 silenciosamente
    if (linesErr.message?.includes('does not exist') || linesErr.code === '42P01') {
      console.warn('[priceFromBOMInstance] BOMInstanceLines table not found - using snapshot pricing');
      return { total: 0, totalCost: 0, missingParts: 0, linesCount: 0, pricedCount: 0 };
    }
    const errorDetails = safeErr(linesErr);
    throw new Error(errorDetails.message || 'Failed to fetch BOM lines');
  }

  const lines = bomLines ?? [];
  if (lines.length === 0) {
    return { total: 0, totalCost: 0, missingParts: 0, linesCount: 0, pricedCount: 0 };
  }

  const missing = lines.filter((l: any) => !l.resolved_part_id);
  const partIds = Array.from(
    new Set(lines.map((l: any) => l.resolved_part_id).filter(Boolean))
  ) as string[];

  // 2) MSRP map (CatalogItemsMSRP) - ✅ ESTA ES LA TABLA DE PRECIOS DE VENTA
  const msrpMap = new Map<string, number>();
  const costMap = new Map<string, number>();
  const msrpDetails: any[] = []; // Para debug
  
  if (partIds.length > 0) {
    // 2a) Fetch MSRP from CatalogItemsMSRP - ✅ TABLA PRINCIPAL DE PRECIOS
    const { data: msrpRows, error: msrpErr } = await supabase
      .from("CatalogItemsMSRP")
      .select("catalog_item_id, msrp, dealer_price")
      .in("catalog_item_id", partIds);

    if (msrpErr) {
      // ✅ FIX: Convertir error de Supabase a Error simple para evitar [circular]
      const errorDetails = safeErr(msrpErr);
      throw new Error(errorDetails.message || 'Failed to fetch MSRP data');
    }

    (msrpRows ?? []).forEach((r: any) => {
      msrpMap.set(r.catalog_item_id, Number(r.msrp ?? 0));
      msrpDetails.push({
        catalog_item_id: r.catalog_item_id,
        msrp: r.msrp,
        source: 'CatalogItemsMSRP',
      });
    });

    // 2b) Fetch cost_exw from CatalogItems (for all parts)
    // ✅ FIX: CatalogItems NO tiene columna "msrp" (está en CatalogItemsMSRP)
    // ✅ FIX: CatalogItems usa "is_active" (no "deleted")
    const { data: items, error: itemsErr } = await supabase
      .from("CatalogItems")
      .select("id, cost_exw, sku, name")
      .in("id", partIds)
      .eq("is_active", true);

    if (itemsErr) {
      // ✅ FIX: Convertir error de Supabase a Error simple para evitar [circular]
      const errorDetails = safeErr(itemsErr);
      throw new Error(errorDetails.message || 'Failed to fetch catalog items');
    }

    (items ?? []).forEach((it: any) => {
      // ✅ MSRP ya viene de CatalogItemsMSRP (paso 2a), no hay fallback desde CatalogItems
      // Cost: always from CatalogItems.cost_exw
      costMap.set(it.id, Number(it.cost_exw ?? 0));
    });

    // ✅ DEBUG: Mostrar qué items NO tienen MSRP
    const itemsWithoutMsrp = partIds.filter(id => !msrpMap.has(id) || msrpMap.get(id) === 0);
    if (itemsWithoutMsrp.length > 0 && import.meta.env.DEV) {
      console.warn('⚠️ Items sin MSRP en CatalogItemsMSRP:', itemsWithoutMsrp);
    }
  }

  // 3) Calculate totals
  let total = 0;
  let totalCost = 0;
  let pricedCount = 0;
  const pricingBreakdown: any[] = []; // Para debug

  for (const l of lines as any[]) {
    const partId = l.resolved_part_id;
    if (!partId) continue;

    const unitMsrp = Number(msrpMap.get(partId) ?? 0);
    const unitCost = Number(costMap.get(partId) ?? 0);
    const qty = Number(l.qty ?? 0);
    const lineTotal = unitMsrp * qty;

    if (unitMsrp > 0 && qty > 0) pricedCount += 1;
    total += lineTotal;
    totalCost += unitCost * qty;

    pricingBreakdown.push({
      partId,
      partRole: l.part_role,
      qty,
      unitMsrp,
      unitCost,
      lineTotal,
      msrpSource: msrpMap.has(partId) ? 'CatalogItemsMSRP.msrp' : 'MISSING',
    });
  }

  if (import.meta.env.DEV) {
    console.group('💰 DEBUG: BOM Pricing Breakdown');
    console.log('📊 BOM Instance ID:', bomInstanceId);
    console.log('📦 Total Lines:', lines.length);
    console.log('❌ Missing Parts (sin resolved_part_id):', missing.length);
    console.log('✅ Priced Items:', pricedCount);
    console.log('📋 Pricing Breakdown:', pricingBreakdown);
    console.log('💵 Total MSRP (CatalogItemsMSRP.msrp):', total);
    console.log('💵 Total Cost (CatalogItems.cost_exw):', totalCost);
    console.log('📊 MSRP Details:', msrpDetails);
    console.log('📊 MSRP Source Table: CatalogItemsMSRP');
    console.log('📊 MSRP Source Column: msrp');
    console.groupEnd();
  }

  return {
    total,
    totalCost,
    missingParts: missing.length,
    linesCount: lines.length,
    pricedCount,
  };
}

// Format currency
const formatCurrency = (amount: number, currency: string = 'USD') => {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: currency,
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(amount);
};

// Quote status options
const QUOTE_STATUS_OPTIONS = [
  { value: 'draft', label: 'Draft' },
  { value: 'approved', label: 'Approved' },
  { value: 'canceled', label: 'Cancelled' },
] as const;

// Currency options
const CURRENCY_OPTIONS = [
  { value: 'USD', label: 'USD - US Dollar' },
  { value: 'EUR', label: 'EUR - Euro' },
  { value: 'GBP', label: 'GBP - British Pound' },
  { value: 'MXN', label: 'MXN - Mexican Peso' },
  { value: 'CAD', label: 'CAD - Canadian Dollar' },
] as const;

// Schema for Quote - customer_id optional; description, notes, po_number for Dealer
const quoteSchema = z.object({
  quote_no: z.string().min(1, 'Quote number is required'),
  customer_id: z.string().uuid('Invalid customer ID').optional().or(z.literal('')),
  status: z.enum(['draft', 'approved', 'canceled']),
  currency: z.string().min(1, 'Currency is required'),
  description: z.string().optional(),
  notes: z.string().optional(),
  po_number: z.string().optional(),
  exempt_tax: z.boolean().optional(),
});

type QuoteFormValues = z.infer<typeof quoteSchema>;

interface Customer {
  id: string;
  organization_id: string;
  customer_name: string;
  customer_type_name?: string | null; // VIP, Partner, Reseller, Distributor
  primary_contact_id?: string | null;
}

interface Contact {
  id: string;
  contact_name: string;
  email?: string | null;
  primary_phone?: string | null;
  customer_id?: string | null;
}

interface QuoteLineWithRelations {
  id: string;
  quote_id: string;
  catalog_item_id: string;
  qty: number;
  width_m?: number | null;
  height_m?: number | null;
  area?: string | null;
  position?: string | null;
  collection_name?: string | null;
  variant_name?: string | null;
  product_type?: string | null;
  product_type_id?: string | null;
  drive_type?: string | null;
  bottom_rail_type?: string | null;
  cassette?: boolean | null;
  cassette_type?: string | null;
  side_channel?: boolean | null;
  side_channel_type?: string | null;
  hardware_color?: string | null;
  computed_qty: number;
  line_total: number;
  ProductType?: { id: string; name: string } | null;
  CatalogItems?: { id: string; item_name: string; sku: string; uom: string } | null;
}

function CreateProposalButton({ quoteId }: { quoteId: string }) {
  const { proposals, loading, refetch } = useProposalsByQuote(quoteId);
  const { activeDealerId } = useActiveDealer();
  const [creating, setCreating] = useState(false);

  const handleCreate = async () => {
    setCreating(true);
    try {
      const result = await createProposalFromQuote(quoteId, { actingDealerId: activeDealerId ?? null });
      if ('error' in result) {
        useUIStore.getState().addNotification({ type: 'error', title: 'Error', message: result.error });
        return;
      }
      useUIStore.getState().addNotification({ type: 'success', title: 'Proposal created', message: 'Redirecting...' });
      router.navigate(`/sales/proposals/${result.proposalId}`);
    } finally {
      setCreating(false);
    }
  };

  return (
    <div className="flex items-center gap-2">
      <button
        type="button"
        onClick={handleCreate}
        disabled={creating || loading}
        className="flex items-center gap-1.5 px-3 py-1.5 rounded border border-gray-300 bg-white text-gray-700 transition-colors text-sm hover:bg-gray-50 disabled:opacity-50"
      >
        <FileText className="w-4 h-4" />
        Create Proposal
      </button>
    </div>
  );
}

/** Proposals for this Quote — lista y crear, dentro de la página del Quote */
function QuoteProposalsSection({ quoteId }: { quoteId: string }) {
  const { proposals, loading, refetch } = useProposalsByQuote(quoteId);
  const { activeDealerId } = useActiveDealer();
  const [creating, setCreating] = useState(false);

  const handleCreate = async () => {
    setCreating(true);
    try {
      const result = await createProposalFromQuote(quoteId, { actingDealerId: activeDealerId ?? null });
      if ('error' in result) {
        useUIStore.getState().addNotification({ type: 'error', title: 'Error', message: result.error });
        return;
      }
      refetch();
      useUIStore.getState().addNotification({ type: 'success', title: 'Proposal created', message: 'Opening...' });
      router.navigate(`/sales/proposals/${result.proposalId}`);
    } finally {
      setCreating(false);
    }
  };

  const formatMoney = (amount: number | null | undefined, currency = 'USD') =>
    new Intl.NumberFormat('en-US', { style: 'currency', currency }).format(amount ?? 0);

  const formatDate = (s: string | null | undefined) => {
    if (!s) return '—';
    try {
      const d = new Date(s);
      return isNaN(d.getTime()) ? '—' : d.toLocaleDateString();
    } catch {
      return '—';
    }
  };

  return (
    <div className="p-6">
      <div className="flex items-center justify-between mb-4">
        <div>
          <h2 className="text-lg font-semibold text-foreground">Proposals for this Quote</h2>
          <p className="text-sm text-gray-500 mt-1">
            {loading ? 'Loading...' : `${proposals.length} proposal${proposals.length !== 1 ? 's' : ''}`}
          </p>
        </div>
        <button
          type="button"
          onClick={handleCreate}
          disabled={creating || loading}
          className="flex items-center gap-1.5 px-3 py-1.5 rounded border border-gray-300 bg-white text-gray-700 transition-colors text-sm hover:bg-gray-50 disabled:opacity-50"
        >
          <FileText className="w-4 h-4" />
          Create Proposal
        </button>
      </div>
      {loading ? (
        <div className="py-8 text-center text-gray-500 text-sm">Loading proposals...</div>
      ) : proposals.length === 0 ? (
        <div className="py-8 text-center text-gray-500 text-sm border border-dashed border-gray-200 rounded-lg">
          No proposals yet. Create one to send to the customer.
        </div>
      ) : (
        <div className="table-fit-wrapper border border-gray-200 rounded-lg">
          <table className="table-fit w-full text-sm">
            <thead className="bg-gray-50">
              <tr>
                <th className="py-2.5 px-4 text-left font-medium text-gray-700">Proposal No</th>
                <th className="py-2.5 px-4 text-left font-medium text-gray-700">Status</th>
                <th className="py-2.5 px-4 text-right font-medium text-gray-700">Total</th>
                <th className="py-2.5 px-4 text-left font-medium text-gray-700">Date</th>
                <th className="py-2.5 px-4 text-right font-medium text-gray-700 w-20">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {proposals.map((p) => (
                <tr key={p.id} className="hover:bg-gray-50">
                  <td className="py-2.5 px-4 font-medium text-gray-900">{p.proposal_no ?? p.id.slice(0, 8)}</td>
                  <td className="py-2.5 px-4 text-gray-700 capitalize">{p.status}</td>
                  <td className="py-2.5 px-4 text-right text-gray-900">{formatMoney(p.total_amount)}</td>
                  <td className="py-2.5 px-4 text-gray-600">{formatDate(p.created_at)}</td>
                  <td className="py-2.5 px-4 text-right">
                    <button
                      type="button"
                      onClick={() => router.navigate(`/sales/proposals/${p.id}`)}
                      className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600"
                      title="View proposal"
                    >
                      <Eye className="w-4 h-4" />
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

export default function QuoteNew() {
  const { activeOrganizationId } = useOrganizationContext();
  const { userType, isPortal } = useAccessContext();
  const { activeDealerId: filterDealerId } = useActiveDealer();
  const { createQuote, isCreating } = useCreateQuote();
  const { updateQuote, isUpdating } = useUpdateQuote();
  const [quoteId, setQuoteId] = useState<string | null>(null);
  const [quoteData, setQuoteData] = useState<any>(null);
  const { customers: directoryCustomers } = useDirectoryCustomers({ organizationId: activeOrganizationId });
  const customers: Customer[] = useMemo(
    () =>
      directoryCustomers.map((c) => ({
        id: c.id,
        organization_id: c.organization_id,
        customer_name: c.customer_name,
        customer_type_name: c.customer_type_name ?? null,
        primary_contact_id: c.primary_contact_id ?? null,
      })),
    [directoryCustomers]
  );
  const [contacts, setContacts] = useState<Contact[]>([]);
  const [selectedContactId, setSelectedContactId] = useState<string>('');
  const contactsForCustomerIdRef = useRef<string | null>(null);
  const [showConfigurator, setShowConfigurator] = useState(false);
  const [editingLineId, setEditingLineId] = useState<string | null>(null);
  const [draggedLineId, setDraggedLineId] = useState<string | null>(null);
  const [dragOverLineId, setDragOverLineId] = useState<string | null>(null);
  const [previewLineId, setPreviewLineId] = useState<string | null>(null);
  const [isSaving, setIsSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [approveConfirmOpen, setApproveConfirmOpen] = useState(false);
  const [pendingApproveSubmission, setPendingApproveSubmission] = useState<{
    data: QuoteFormValues;
    shouldNavigate: boolean;
  } | null>(null);
  const [initialLineConfig, setInitialLineConfig] = useState<ProductConfig | undefined>(undefined);
  const [dealerInfo, setDealerInfo] = useState<{ id: string; name: string; number: string | null; dealer_tier_id: string | null } | null>(null);
  const configuratorDraftKey = quoteId ? `productConfiguratorDraft:${quoteId}` : null;

  const { lines: quoteLines, loading: loadingLines, error: errorLines, refetch: refetchLines } = useQuoteLines(quoteId);
  const { settings: costSettings } = useCostSettings();
  const { tiers: dealerTiers } = useDealerTiers();

  // Form setup
  const {
    register,
    handleSubmit,
    formState: { errors },
    setValue,
    watch,
  } = useForm<QuoteFormValues>({
    resolver: zodResolver(quoteSchema),
    defaultValues: {
      status: 'draft',
      currency: 'USD',
      description: '',
      notes: '',
      po_number: '',
      exempt_tax: false,
    },
  });

  const selectedCustomerId = watch('customer_id');
  const selectedCustomer = customers.find((c) => c.id === selectedCustomerId);
  const effectiveCustomerIdForContacts = selectedCustomerId || (quoteId && quoteData?.customer_id) || null;
  const effectiveOrgIdForContacts = selectedCustomer?.organization_id ?? activeOrganizationId;

  // Load contacts for selected customer only (single query by customer_id + organization_id; RLS applies)
  useEffect(() => {
    if (!effectiveCustomerIdForContacts || !effectiveOrgIdForContacts) {
      setContacts([]);
      contactsForCustomerIdRef.current = null;
      return;
    }
    let cancelled = false;
    (async () => {
      const { data, error } = await supabase
        .from('DirectoryContacts')
        .select('id, contact_name, contact_email, contact_primary_phone, customer_id')
        .eq('customer_id', effectiveCustomerIdForContacts)
        .eq('organization_id', effectiveOrgIdForContacts)
        .eq('deleted', false)
        .order('contact_name');
      if (cancelled) return;
      if (error) {
        console.error('[QuoteNew] Error loading contacts:', error);
        setContacts([]);
        contactsForCustomerIdRef.current = effectiveCustomerIdForContacts;
        return;
      }
      contactsForCustomerIdRef.current = effectiveCustomerIdForContacts;
      setContacts(
        (data ?? []).map((row: { id: string; contact_name: string; contact_email?: string | null; contact_primary_phone?: string | null; customer_id?: string | null }) => ({
          id: row.id,
          contact_name: row.contact_name ?? '',
          email: row.contact_email ?? null,
          primary_phone: row.contact_primary_phone ?? null,
          customer_id: row.customer_id ?? null,
        }))
      );
    })();
    return () => {
      cancelled = true;
    };
  }, [effectiveCustomerIdForContacts, effectiveOrgIdForContacts]);

  // Clear contact when customer changes and selected contact is not in the new list
  useEffect(() => {
    if (!selectedContactId || contactsForCustomerIdRef.current !== effectiveCustomerIdForContacts || contacts.length === 0) return;
    const found = contacts.some((c) => c.id === selectedContactId);
    if (!found) setSelectedContactId('');
  }, [contacts, selectedContactId, effectiveCustomerIdForContacts]);

  // Check URL for quote_id (edit mode) or line_id (edit line mode)
  useEffect(() => {
    const path = window.location.pathname;
    // Support both legacy and current routes:
    // - /sales/quotes/edit/:id   (legacy)
    // - /sales/quotes/:id/edit   (current)
    const legacyMatch = path.match(/\/sales\/quotes\/edit\/([^/]+)/);
    const currentMatch = path.match(/\/sales\/quotes\/([^/]+)\/edit/);
    const editQuoteId = legacyMatch?.[1] ?? currentMatch?.[1] ?? null;

    const urlParams = new URLSearchParams(window.location.search);
    const queryQuoteId = urlParams.get('quote_id');
    const lineId = urlParams.get('line_id');

    if (editQuoteId) {
      setQuoteId(editQuoteId);
    } else if (queryQuoteId) {
      setQuoteId(queryQuoteId);
      if (lineId) {
        setEditingLineId(lineId);
        // Don't show configurator immediately - wait for line config to load
        // It will be shown when initialLineConfig is set
      }
    }
  }, []);

  // ✅ Persist configurator visibility across tab switches
  useEffect(() => {
    if (!quoteId || !configuratorDraftKey) return;
    if (editingLineId) return; // Do not override edit mode

    try {
      const rawDraft = window.sessionStorage.getItem(configuratorDraftKey);
      if (rawDraft && !showConfigurator) {
        setShowConfigurator(true);
      }
    } catch (err) {
      if (import.meta.env.DEV) {
        console.warn('[QuoteNew] Failed to restore configurator draft', err);
      }
    }
  }, [quoteId, configuratorDraftKey, editingLineId, showConfigurator]);

  // ✅ When tab becomes visible, reopen configurator if draft exists
  useEffect(() => {
    if (!quoteId || !configuratorDraftKey) return;
    if (editingLineId) return;

    const handleVisibility = () => {
      if (document.visibilityState !== 'visible') return;
      try {
        const rawDraft = window.sessionStorage.getItem(configuratorDraftKey);
        if (rawDraft && !showConfigurator) {
          setShowConfigurator(true);
        }
      } catch (err) {
        if (import.meta.env.DEV) {
          console.warn('[QuoteNew] Visibility restore failed', err);
        }
      }
    };

    document.addEventListener('visibilitychange', handleVisibility);
    return () => document.removeEventListener('visibilitychange', handleVisibility);
  }, [quoteId, configuratorDraftKey, editingLineId, showConfigurator]);

  const clearConfiguratorDraft = () => {
    if (!configuratorDraftKey) return;
    try {
      window.sessionStorage.removeItem(configuratorDraftKey);
    } catch (err) {
      if (import.meta.env.DEV) {
        console.warn('[QuoteNew] Failed to clear configurator draft', err);
      }
    }
  };

  // Load quote data when in edit mode
  useEffect(() => {
    const loadQuoteData = async () => {
      if (!quoteId || !activeOrganizationId) return;

      try {
        const { data, error } = await supabase
          .from('Quotes')
          .select('*')
          .eq('id', quoteId)
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .maybeSingle();

        if (error) throw error;

        if (data) {
          setQuoteData(data);
          // Set all values, ensuring quote_no is set first and won't be overwritten
          const quoteNo = (data as any).quote_no || '';
          setValue('quote_no', quoteNo, { shouldValidate: true });
          setValue('customer_id', data.customer_id || '');
          const rawStatus = data.status as string;
          type FormStatus = 'draft' | 'approved' | 'canceled';
          const formStatus: FormStatus = rawStatus === 'rejected' || rawStatus === 'cancelled' || rawStatus === 'sent' ? 'canceled' : (['draft', 'approved', 'canceled'].includes(rawStatus) ? (rawStatus as FormStatus) : 'draft');
          setValue('status', (formStatus === 'canceled' ? 'draft' : formStatus) || 'draft');
          setValue('currency', 'USD'); // Default for UI formatting (not stored in DB)
          setValue('description', (data as any).description ?? '');
          setValue('notes', (data as any).notes ?? '');
          setValue('po_number', (data as any).po_number ?? '');
          setValue('exempt_tax', (data as any).exempt_tax ?? false);
          // Load contact_id if it exists (contact_id DOES exist in Quotes table)
          if (data.contact_id) {
            setSelectedContactId(data.contact_id);
          }
          
          if (data.dealer_id) {
            const { data: dealer, error: dealerError } = await supabase
              .from('Dealers')
              .select('id, dealer_name, dealer_no, dealer_tier_id')
              .eq('id', data.dealer_id)
              .eq('organization_id', activeOrganizationId)
              .eq('deleted', false)
              .maybeSingle();

            if (!dealerError && dealer) {
              setDealerInfo({
                id: dealer.id,
                name: dealer.dealer_name || 'Unknown Dealer',
                number: dealer.dealer_no || null,
                dealer_tier_id: dealer.dealer_tier_id ?? null,
              });
            }
          }
        }
      } catch (err: unknown) {
        const msg =
          err instanceof Error ? err.message
            : typeof err === 'object' && err !== null && 'message' in err
              ? String((err as { message?: unknown }).message)
              : 'Unknown error';
        console.error('Error loading quote:', msg);
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'Error',
          message: msg.includes('Failed to fetch')
            ? 'Failed to load quote data. Check your network connection and Supabase status.'
            : msg || 'Failed to load quote data',
        });
      }
    };

    loadQuoteData();
  }, [quoteId, activeOrganizationId, setValue]);

  // Load dealer info (for ALL users: portal and internal)
  // Reacts to filterDealerId changes (acting-as switcher)
  useEffect(() => {
    const loadDealerInfo = async () => {
      // Skip if editing and dealer already loaded from quote data
      if (quoteId && dealerInfo) return;
      
      if (!activeOrganizationId) {
        setDealerInfo(null);
        return;
      }

      try {
        if (isPortal) {
          // Portal user: get their assigned dealer
          const { data: { user } } = await supabase.auth.getUser();
          if (!user) return;

          const { data: portalUser, error: portalError } = await supabase
            .from('DealerUsers')
            .select('dealer_id')
            .eq('user_id', user.id)
            .eq('deleted', false)
            .in('status', ['active', 'invited'])
            .maybeSingle();

          if (portalError) {
            console.error('Error loading portal user dealer:', portalError);
            return;
          }

          if (portalUser?.dealer_id) {
            const { data: dealer, error: dealerError } = await supabase
              .from('Dealers')
              .select('id, dealer_name, dealer_no, dealer_tier_id')
              .eq('id', portalUser.dealer_id)
              .eq('organization_id', activeOrganizationId)
              .eq('deleted', false)
              .maybeSingle();

            if (dealerError) {
              console.error('Error loading dealer:', dealerError);
              return;
            }

            if (dealer) {
              setDealerInfo({
                id: dealer.id,
                name: dealer.dealer_name || 'Unknown Dealer',
                number: dealer.dealer_no || null,
                dealer_tier_id: dealer.dealer_tier_id ?? null,
              });
            }
          }
        } else {
          // Internal user: use the acting-as dealer (filter) if set, otherwise first dealer
          const targetDealerId = filterDealerId;
          let query = supabase
            .from('Dealers')
            .select('id, dealer_name, dealer_no, dealer_tier_id')
            .eq('organization_id', activeOrganizationId)
            .eq('deleted', false)
            .eq('status', 'active');

          if (targetDealerId) {
            query = query.eq('id', targetDealerId);
          } else {
            query = query.order('created_at', { ascending: true }).limit(1);
          }

          const { data: dealers, error: dealersError } = await query;

          if (dealersError) {
            console.error('Error loading dealers:', dealersError);
            return;
          }

          if (dealers && dealers.length > 0) {
            const dealer = dealers[0];
            setDealerInfo({
              id: dealer.id,
              name: dealer.dealer_name || 'Unknown Dealer',
              number: dealer.dealer_no || null,
              dealer_tier_id: dealer.dealer_tier_id ?? null,
            });
          }
        }
      } catch (err) {
        console.error('Error loading dealer info:', err);
      }
    };

    loadDealerInfo();
  }, [isPortal, activeOrganizationId, filterDealerId]);

  // Generate quote number for new quotes only (not when editing)
  useEffect(() => {
    const generateQuoteNo = async () => {
      // CRITICAL: Don't generate if editing - must preserve existing quote_no
      if (quoteId) {
        // When editing, ensure we keep the existing quote_no from quoteData
        // This will be set by loadQuoteData, but we ensure it's preserved here
        if (quoteData?.quote_no) {
          const currentQuoteNo = watch('quote_no');
          // Only set if it's different (to avoid unnecessary updates)
          if (currentQuoteNo !== quoteData.quote_no) {
            setValue('quote_no', quoteData.quote_no, { shouldValidate: true });
          }
        }
        return; // Never generate new number when editing
      }
      
      // Only generate for new quotes
      if (!activeOrganizationId) return;

      try {
        // Per-dealer sequence: QT-0100, QT-0101... (each dealer has independent QT sequence)
        const { generateNextQuoteNumber } = await import('../../lib/sequential-numbers');
        const dealerIdForSeq = dealerInfo?.id ?? filterDealerId ?? null;
        const quoteNo = await generateNextQuoteNumber(activeOrganizationId, dealerIdForSeq);
        setValue('quote_no', quoteNo, { shouldValidate: true });
      } catch (err) {
        console.error('Error generating quote number:', err);
        const fallbackNo = `QT-${Date.now().toString().slice(-6)}`;
        setValue('quote_no', fallbackNo, { shouldValidate: true });
      }
    };

    // Small delay to ensure quoteData is loaded when editing
    const timeoutId = setTimeout(() => {
      generateQuoteNo();
    }, 100);

    return () => clearTimeout(timeoutId);
  }, [activeOrganizationId, quoteId, setValue, watch, quoteData, dealerInfo?.id, filterDealerId]);

  // Dealer tier discount: aplicado a Quote Lines (mostrar dealer price); Proposals siguen con MSRP
  const dealerDiscountPctForDisplay = useMemo(
    () => getDealerTierDiscountPct(dealerInfo?.dealer_tier_id ?? null, dealerTiers),
    [dealerInfo?.dealer_tier_id, dealerTiers]
  );
  const useDealerPrice = !!dealerInfo;

  // Tax % from CostSettings (DB); default 7% if not set
  const taxPct = costSettings?.tax_pct ?? 0.07;
  const exemptTax = watch('exempt_tax') ?? false;

  // Calculate totals from quote lines: unit × qty (misma lógica que la tabla para que no varíe el unitario al cambiar qty)
  const totals = useMemo(() => {
    const subtotal = quoteLines.reduce((sum, line: any) => {
      const qty = Math.max(1, line.quantity ?? line.qty ?? 1);
      const unitMsrp =
        line.unit_msrp != null && Number(line.unit_msrp) >= 0
          ? Number(line.unit_msrp)
          : (line.msrp != null && qty > 0 ? Number(line.msrp) / qty : (line.roll_msrp_snapshot || 0) + (line.bom_msrp_snapshot || 0));
      const lineTotal = useDealerPrice
        ? unitMsrp * qty * (1 - dealerDiscountPctForDisplay / 100)
        : unitMsrp * qty;
      return sum + lineTotal;
    }, 0);
    const taxAmount = exemptTax ? 0 : Math.round(subtotal * taxPct * 100) / 100;
    const total = exemptTax ? subtotal : subtotal + taxAmount;

    return { subtotal, tax: taxAmount, total };
  }, [quoteLines, useDealerPrice, dealerDiscountPctForDisplay, taxPct, exemptTax]);

  // Handle product configuration completion
  const handleProductConfigComplete = async (productConfig: ProductConfig) => {
    if (!quoteId || !activeOrganizationId) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: 'Quote must be saved first before adding lines',
      });
      return;
    }

    try {
      // Validate required fields for Roller Shade
      if (productConfig.productType === 'roller-shade') {
        // ✅ CRITICAL: Buscar width_m primero (unified contract), luego widthM (legacy), luego calcular desde width_mm
        const width_m = (productConfig as any).width_m || (productConfig as any).widthM || ((productConfig as any).width_mm ? (productConfig as any).width_mm / 1000 : null);
        const height_m = (productConfig as any).height_m || (productConfig as any).heightM || ((productConfig as any).height_mm ? (productConfig as any).height_mm / 1000 : null);
        const driveType = (productConfig as any).operation_type || (productConfig as any).drive_type;
        
        const errors: string[] = [];
        // ✅ DECISIÓN FINAL: tube_type NO es requerido (puede ser NULL, se resuelve del template)
        // ✅ roll NO es requerido (draft permitido sin roll)
        if (!width_m || width_m <= 0) errors.push('Width is required');
        if (!height_m || height_m <= 0) errors.push('Height is required');
        if (!driveType) errors.push('Drive Type is required (Manual or Motor)');
        
        if (errors.length > 0) {
          useUIStore.getState().addNotification({
            type: 'error',
            title: 'Validation Error',
            message: errors.join('. '),
          });
          return;
        }
      }
      
      const configuredProductId = (productConfig as any).configured_product_id;
      const configuredProductTotalsFromConfig = (productConfig as any).configured_product_totals;
      const draftQuoteLineId = (productConfig as any).quote_line_id;
      const isAccessoriesOnly = productConfig.productType === 'accessories';

      // EDIT: no ConfiguredProduct required (we create CP_NEW on save). Accessories-only lines don't use ConfiguredProduct.
      if (!editingLineId && !configuredProductId && !isAccessoriesOnly) {
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'Configuration Error',
          message: 'ConfiguredProduct is required. Please complete the product configuration first.',
        });
        return;
      }

      if (!activeOrganizationId) {
        console.error("❌ Missing organizationId; cannot resolve ProductTypes.");
        useUIStore.getState().addNotification({
          type: "error",
          title: "Org not loaded",
          message: "No organizationId in session/profile. Fix auth profile.",
        });
        return;
      }

      let finalLineId: string | undefined = editingLineId ?? undefined;
      let rollItemId: string | null = null;
      let catalogItem: any = null;
      let collectionName: string | null = null;
      let variantName: string | null = null;
      let productTypeId: string | null = null;
      let width_m: number | null = null;
      let height_m: number | null = null;
      let quantity = 1;
      let normalized: ReturnType<typeof normalizeConfiguratorConfig> | undefined;
      let shouldUseSnapshotService = false;

      // ═══════════════════════════════════════════════════════════════════
      // ACCESSORIES-ONLY: create QuoteLine without ConfiguredProduct (no width, height, fabric, etc.)
      // ═══════════════════════════════════════════════════════════════════
      if (isAccessoriesOnly && !editingLineId && quoteId) {
        const accessoriesList = Array.isArray((productConfig as any).accessories) ? (productConfig as any).accessories : [];
        const totalMsrp = accessoriesList.reduce((sum: number, item: { qty?: number; price?: number }) => {
          const qty = Number(item?.qty) || 1;
          const price = Number(item?.price) || 0;
          return sum + qty * price;
        }, 0);
        const { data: quoteRow } = await supabase
          .from('Quotes')
          .select('dealer_id')
          .eq('id', quoteId)
          .eq('organization_id', activeOrganizationId)
          .maybeSingle();
        // Solo columnas que existen en todas las versiones de QuoteLines (sin metadata si no existe la columna)
        const insertPayload: Record<string, unknown> = {
          organization_id: activeOrganizationId,
          quote_id: quoteId,
          dealer_id: quoteRow?.dealer_id ?? null,
          product_type: 'accessories',
          configured_product_id: null,
          product_type_id: null,
          quantity: 1,
          msrp: totalMsrp > 0 ? totalMsrp : null,
          unit_msrp: totalMsrp > 0 ? totalMsrp : null,
          name: 'Accessories',
          sku: null,
          position: productConfig.position != null ? String(productConfig.position) : null,
          area: productConfig.area ?? null,
        };
        if (accessoriesList.length > 0) {
          insertPayload.metadata = { accessories: accessoriesList };
        }
        let insertResult = await supabase.from('QuoteLines').insert(insertPayload).select('id').single();
        if (insertResult.error && insertResult.error.message?.includes('metadata')) {
          delete insertPayload.metadata;
          insertResult = await supabase.from('QuoteLines').insert(insertPayload).select('id').single();
        }
        const { data: newLine, error: insertError } = insertResult;
        if (insertError) {
          console.error('[QuoteNew] Accessories-only line insert failed', insertError);
          useUIStore.getState().addNotification({
            type: 'error',
            title: 'Error',
            message: insertError.message || 'Failed to add accessories line.',
          });
          return;
        }
        useUIStore.getState().addNotification({
          type: 'success',
          title: 'Success',
          message: 'Accessories line added successfully.',
        });
        refetchLines();
        return;
      }

      // ═══════════════════════════════════════════════════════════════════
      // EDIT SAVE: same QuoteLine + new ConfiguredProduct (CP_NEW). Branch runs first and returns at end.
      // ═══════════════════════════════════════════════════════════════════
      if (editingLineId) {
        // ═══════════════════════════════════════════════════════
        // EDIT SAVE — Backend is source of truth for EVERYTHING.
        // 1. Build snapshot → 2. Backend creates CP_NEW → 3. Read CP_NEW → 4. Copy to QuoteLine → 5. Backend prices it
        // ═══════════════════════════════════════════════════════

        // 0. Guardar unit_msrp y quantity actuales por si solo cambia cantidad (mantener precio unitario)
        const { data: lineBeforeEdit } = await supabase
          .from('QuoteLines')
          .select('quantity, unit_msrp, width_m, height_m')
          .eq('id', editingLineId)
          .eq('organization_id', activeOrganizationId)
          .maybeSingle();
        const prevQuantity = lineBeforeEdit?.quantity ?? 1;
        const prevUnitMsrp = lineBeforeEdit?.unit_msrp != null ? Number(lineBeforeEdit.unit_msrp) : null;
        const prevWidth = lineBeforeEdit?.width_m;
        const prevHeight = lineBeforeEdit?.height_m;

        // 1. Resolve product type
        const productTypeId = productConfig.productTypeId
          || (productConfig.productType ? await resolveProductTypeId(supabase, activeOrganizationId, productConfig.productType) : null);
        if (!productTypeId) {
          useUIStore.getState().addNotification({ type: 'error', title: 'Error', message: 'Product Type not found.' });
          return;
        }

        // 2. Build snapshot and send to backend (createConfiguredProductPreview)
        const configSnapshot = buildConfigSnapshotFromProductConfig(productConfig);
        const previewResult = await createConfiguredProductPreview({
          organization_id: activeOrganizationId,
          product_type_id: productTypeId,
          config_snapshot: configSnapshot,
          quote_id: quoteId || null,
        });
        const cpNewId = previewResult.configured_product_id;

        // 3. Read CP_NEW from backend — this is the ONLY source of truth
        const { data: cpNew } = await supabase
          .from('ConfiguredProducts')
          .select('width_mm, height_mm, roll_catalog_item_id, roll_collection_name, roll_variant_name')
          .eq('id', cpNewId)
          .eq('organization_id', activeOrganizationId)
          .maybeSingle();

        const width_m = cpNew?.width_mm ? Number(cpNew.width_mm) / 1000 : null;
        const height_m = cpNew?.height_mm ? Number(cpNew.height_mm) / 1000 : null;

        if (!width_m || !height_m) {
          console.error('[QuoteNew EDIT] CP_NEW has no dimensions', { cpNewId, cpNew });
          useUIStore.getState().addNotification({
            type: 'error',
            title: 'Invalid Dimensions',
            message: 'Backend returned invalid dimensions. Please check measurements.',
          });
          return;
        }

        // 4. Update QuoteLine — only structural fields, NO pricing
        const updatePayload: Record<string, any> = {
          configured_product_id: cpNewId,
          width_m,
          height_m,
          area: productConfig.area ?? null,
          position: productConfig.position != null ? String(productConfig.position) : null,
          quantity: productConfig.quantity ?? 1,
          fabric_drop: (productConfig as any).fabricDrop ?? (productConfig as any).drop_type ?? null,
          installation_type: (productConfig as any).installationType ?? null,
          installation_location: (productConfig as any).installationLocation ?? null,
        };
        if (cpNew?.roll_catalog_item_id) updatePayload.catalog_item_id = cpNew.roll_catalog_item_id;
        if (cpNew?.roll_collection_name) updatePayload.collection_name = cpNew.roll_collection_name;
        if (cpNew?.roll_variant_name) updatePayload.variant_name = cpNew.roll_variant_name;

        const { error: updateError } = await supabase
          .from('QuoteLines')
          .update(updatePayload)
          .eq('id', editingLineId)
          .eq('organization_id', activeOrganizationId);
        if (updateError) throw updateError;

        // GARANTÍA: asegurar que la línea apunte SIEMPRE al CP recién creado (evita CP viejo al reabrir Edit).
        const { error: linkError } = await supabase
          .from('QuoteLines')
          .update({ configured_product_id: cpNewId })
          .eq('id', editingLineId)
          .eq('organization_id', activeOrganizationId);
        if (linkError) {
          if (import.meta.env.DEV) console.error('[QuoteNew EDIT] configured_product_id update failed', linkError);
          throw linkError;
        }

        rollItemId = cpNew?.roll_catalog_item_id ?? null;
        finalLineId = editingLineId;

        // 5. Sync accessories
        const accessoriesForEdit = (productConfig as any).accessories || [];
        try {
          await supabase.from('QuoteLineComponents').update({ deleted: true }).eq('quote_line_id', editingLineId).eq('organization_id', activeOrganizationId).or('source.eq.accessory,component_role.eq.accessory');
          if (accessoriesForEdit.length > 0) {
            const accessoryIds = accessoriesForEdit.map((a: any) => a.id).filter(Boolean);
            if (accessoryIds.length > 0) {
              const { data: accessoryItems } = await supabase.from('CatalogItems').select('id, item_name, sku, cost_exw, default_margin_pct').in('id', accessoryIds).eq('organization_id', activeOrganizationId).eq('is_active', true);
              const rows = accessoriesForEdit.map((acc: any) => {
                const ci = accessoryItems?.find((item: any) => item.id === acc.id);
                const unitCost = acc.price || ci?.cost_exw || 0;
                return { organization_id: activeOrganizationId, quote_line_id: editingLineId, catalog_item_id: acc.id, qty: acc.qty || 1, unit_cost_exw: unitCost, source: 'accessory', component_role: 'accessory', uom: (ci as any)?.uom || 'ea' };
              });
              if (rows.length > 0) await supabase.from('QuoteLineComponents').insert(rows);
            }
          }
        } catch (e) { if (import.meta.env.DEV) console.warn('Accessories sync error:', e); }

        // 6. Sync pricing from CP_NEW (same source as ADD: commit_configured_product_to_quote_line)
        try {
          const newQty = Math.max(1, productConfig.quantity ?? 1);
          const onlyQuantityChanged =
            prevUnitMsrp != null &&
            prevUnitMsrp > 0 &&
            newQty !== prevQuantity &&
            prevWidth != null &&
            prevHeight != null &&
            Math.abs((width_m ?? 0) - prevWidth) < 1e-6 &&
            Math.abs((height_m ?? 0) - prevHeight) < 1e-6;

          if (onlyQuantityChanged) {
            // Mantener precio unitario: total = unit_msrp × qty (no recalcular desde BOM)
            const newMsrp = prevUnitMsrp * newQty;
            const { error: overrideErr } = await supabase
              .from('QuoteLines')
              .update({ msrp: newMsrp, unit_msrp: prevUnitMsrp, net_price: newMsrp })
              .eq('id', editingLineId)
              .eq('organization_id', activeOrganizationId);
            if (overrideErr && import.meta.env.DEV) {
              console.warn('[QuoteNew EDIT] Override msrp by unit_msrp×qty failed', overrideErr);
            }
          } else {
            const { error: syncErr } = await supabase.rpc('sync_quote_line_pricing_from_configured_product', {
              p_quote_line_id: editingLineId,
            });
            if (syncErr) {
              console.error('[QuoteNew EDIT] sync_quote_line_pricing_from_configured_product failed', syncErr);
              throw syncErr;
            }
            // Persistir unit_msrp tras el sync para que la UI lo use
            const { data: afterSync } = await supabase.from('QuoteLines').select('msrp').eq('id', editingLineId).eq('organization_id', activeOrganizationId).maybeSingle();
            const totalAfter = afterSync?.msrp != null ? Number(afterSync.msrp) : null;
            if (totalAfter != null && totalAfter > 0 && newQty > 0) {
              await supabase.from('QuoteLines').update({ unit_msrp: totalAfter / newQty }).eq('id', editingLineId).eq('organization_id', activeOrganizationId);
            }
          }
        } catch (e) {
          if (import.meta.env.DEV) console.warn('Sync pricing RPC error (non-fatal):', e);
        }

        // 7. Optional: cost engine for QuoteLineCosts / reporting (do not rely on it for msrp)
        try { await supabase.rpc('compute_quote_line_cost', { p_quote_line_id: editingLineId }); } catch (_) {}

        // 8. Done — refetch and close
        useUIStore.getState().addNotification({ type: 'success', title: 'Success', message: 'Quote line updated successfully' });
        await refetchLines();

        if (import.meta.env.DEV) {
          const { data: lineAfter } = await supabase.from('QuoteLines').select('id, configured_product_id, msrp, unit_msrp').eq('id', editingLineId).maybeSingle();
          const cpMatch = lineAfter?.configured_product_id === cpNewId;
          if (!cpMatch) {
            console.error('[QuoteNew EDIT] QuoteLine.configured_product_id mismatch after save. Run: select id, configured_product_id from "QuoteLines" where id = \'' + editingLineId + '\'; expected cp.id = ' + cpNewId);
          } else {
            console.debug('[QuoteNew EDIT] configured_product_id verified', { quote_line_id: editingLineId, configured_product_id: lineAfter?.configured_product_id });
          }
          const { data: cpSnap } = await supabase.from('ConfiguredProducts').select('bom_preview_snapshot').eq('id', cpNewId).maybeSingle();
          const totals = (cpSnap as any)?.bom_preview_snapshot?.totals;
          const snapshotTotalMsrp = totals?.total_msrp ?? totals?.roll_msrp_total + totals?.bom_total;
          console.debug('[QuoteNew EDIT] Pricing check', {
            quote_line_msrp: lineAfter?.msrp,
            quote_line_unit_msrp: lineAfter?.unit_msrp,
            cp_snapshot_total_msrp: snapshotTotalMsrp,
            match: lineAfter?.msrp != null && snapshotTotalMsrp != null,
          });
        }

        setShowConfigurator(false);
        setEditingLineId(null);
        return;
      } else {
      // ✅ OBTENER ConfiguredProduct desde DB - REQUERIDO (ADD path)
      const { data: configuredProductData, error: cpError } = await supabase
        .from('ConfiguredProducts')
        .select('roll_catalog_item_id, roll_sku, roll_collection_name, roll_variant_name, roll_msrp_total, roll_width, width_mm, height_mm, quantity')
        .eq('id', configuredProductId)
        .eq('organization_id', activeOrganizationId)
        .eq('deleted', false)
        .maybeSingle();

      if (cpError) {
        console.error('[QuoteNew] Error loading ConfiguredProduct:', cpError);
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'Configuration Error',
          message: `Failed to load ConfiguredProduct: ${cpError.message}`,
        });
        return;
      }

      if (!configuredProductData) {
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'Configuration Not Found',
          message: `ConfiguredProduct ${configuredProductId} not found. Please reconfigure the product.`,
        });
        return;
      }

      const area = productConfig.area || null;
      const position = productConfig.position || null;
      width_m = (configuredProductData.width_mm ? configuredProductData.width_mm / 1000 : null) || (productConfig as any).width_m || null;
      height_m = (configuredProductData.height_mm ? configuredProductData.height_mm / 1000 : null) || (productConfig as any).height_m || null;
      quantity = configuredProductData.quantity || productConfig.quantity || 1;

      rollItemId = configuredProductData.roll_catalog_item_id || null;
      
      if (import.meta.env.DEV) {
        console.log('[QuoteNew] Loaded ConfiguredProduct data:', {
          configured_product_id: configuredProductId,
          roll_catalog_item_id: rollItemId,
          roll_collection_name: configuredProductData.roll_collection_name,
          roll_variant_name: configuredProductData.roll_variant_name,
        });
      }

      // Obtener CatalogItem y MSRP si hay roll
      catalogItem = null;
      let msrpSaleOut: number | null = null;
      
      if (rollItemId) {
        // Obtener CatalogItem
        const { data: rollData } = await supabase
          .from('CatalogItems')
          .select('collection_name, variant_name, cost_exw, default_margin_pct, uom, item_category_id, sku')
          .eq('id', rollItemId)
          .eq('is_roll', true)
          .or(`organization_id.eq.${activeOrganizationId},organization_id.is.null`)
          .eq('is_active', true)
          .maybeSingle();
        
        catalogItem = rollData || {
          // Usar datos del ConfiguredProduct como fallback si no se encuentra
          collection_name: configuredProductData.roll_collection_name,
          variant_name: configuredProductData.roll_variant_name,
          sku: configuredProductData.roll_sku,
        };

        // Obtener MSRP desde CatalogItemsMSRP
        const { data: msrpCache } = await supabase
          .from('CatalogItemsMSRP')
          .select('msrp')
          .eq('catalog_item_id', rollItemId)
          .or(`organization_id.eq.${activeOrganizationId},organization_id.is.null`)
          .maybeSingle();

        msrpSaleOut = msrpCache?.msrp || null;
      }

      // Get product type ID - CRITICAL: Always try to find product_type_id
      productTypeId = productConfig.productType
        ? await resolveProductTypeId(supabase, activeOrganizationId, productConfig.productType)
        : null;

      if (!productTypeId && productConfig.productType) {
        const msg = `No ProductType match for "${productConfig.productType}". Check ProductTypes.code. OrganizationId: ${activeOrganizationId}`;
        console.error("❌", msg, { 
          productType: productConfig.productType, 
          organizationId: activeOrganizationId 
        });
        useUIStore.getState().addNotification({
          type: "error",
          title: "Product Type Not Found",
          message: msg,
        });
        return; // NO sigas: BOM/pricing dependen de esto
      }

      // ✅ Nuevo flujo: si ya existe quote_line_id (draft), finalizar esa línea
      if (draftQuoteLineId) {
        const bomTemplateId = (productConfig as any).bom_template_id || null;
        try {
          await finalizeQuoteLineFromConfiguredProduct({
            organizationId: activeOrganizationId,
            quoteLineId: draftQuoteLineId,
            configuredProductId,
            quantity,
            discountPct: 0,
            bom_template_id: bomTemplateId,
            product_type_id: productTypeId,
            // Campos clave de QuoteLine
            catalog_item_id: rollItemId || null,
            collection_name: configuredProductData.roll_collection_name || catalogItem?.collection_name || null,
            variant_name: configuredProductData.roll_variant_name || catalogItem?.variant_name || null,
            area,
            position,
            width_m,
            height_m,
            hardware_color: (productConfig as any).hardware_color || (productConfig as any).hardwareColor || null,
            cassette: (productConfig as any).cassette || false,
            side_channel: (productConfig as any).side_channel || false,
            drive_type: (productConfig as any).operation_type || (productConfig as any).drive_type || null,
            tube_type: (productConfig as any).tube_type || null,
            bottom_rail_type: (productConfig as any).bottom_rail_type || null,
          });

          useUIStore.getState().addNotification({
            type: 'success',
            title: 'Success',
            message: 'Quote line finalized successfully',
          });
          refetchLines();
          setShowConfigurator(false);
          setEditingLineId(null);
          setInitialLineConfig(undefined);
          clearConfiguratorDraft();
          return;
        } catch (finalizeError: any) {
          useUIStore.getState().addNotification({
            type: 'error',
            title: 'Finalize Error',
            message: finalizeError?.message || 'Failed to finalize quote line',
          });
          return;
        }
      }
      // ✅ Usar datos del ConfiguredProduct (prioridad) o catalogItem
      collectionName = configuredProductData.roll_collection_name || catalogItem?.collection_name || null;
      variantName = configuredProductData.roll_variant_name || catalogItem?.variant_name || null;

      // Determine measure_basis based on item category
      // Get category code to determine if it's area-based (FABRIC) or linear-based (tube, cassette, etc.)
      let measureBasis: 'area' | 'linear' = 'area'; // Default to area
      let computedQty: number = quantity; // Default fallback
      
      if (catalogItem?.item_category_id) {
        const { data: itemCategory } = await supabase
          .from('ItemCategories')
          .select('code')
          .eq('id', catalogItem.item_category_id)
          .eq('deleted', false)
          .maybeSingle();
        
        if (itemCategory?.code) {
          const categoryCode = itemCategory.code.toUpperCase();
          // FABRIC is area-based (width × height)
          // All other categories (COMP-TUBE, COMP-CASSETTE, COMP-BOTTOM-BAR, COMP-SIDE, etc.) are linear (width only)
          if (categoryCode.includes('FABRIC')) {
            measureBasis = 'area';
            // For area: computed_qty = width_m × height_m
            computedQty = width_m && height_m ? width_m * height_m : quantity;
        } else {
            measureBasis = 'linear';
            // For linear: computed_qty = width_m (or height_m if width is not available)
            computedQty = width_m || height_m || quantity;
        }
        } else {
          // If category not found, default to area calculation
          measureBasis = 'area';
          computedQty = width_m && height_m ? width_m * height_m : quantity;
        }
      } else {
        // If no category, default to area calculation
        measureBasis = 'area';
        computedQty = width_m && height_m ? width_m * height_m : quantity;
      }

      // Discount from dealer's tier (DealerTiers: Platinum/Gold/Silver/Bronze)
      const discountPct = getDealerTierDiscountPct(dealerInfo?.dealer_tier_id ?? null, dealerTiers);
      
      // ✅ Verificar si hay ConfiguredProduct
      const hasConfiguredProduct = !!configuredProductId;
      
      // ✅ PRIORIDAD 1: Si existe ConfiguredProduct, usar roll_plus_bom_total como MSRP
      let listPrice = msrpSaleOut || 0;
      
      if (hasConfiguredProduct && configuredProductId) {
        if (configuredProductTotalsFromConfig?.roll_plus_bom_total) {
          // Usar roll_plus_bom_total desde config si está disponible
          listPrice = configuredProductTotalsFromConfig.roll_plus_bom_total;
        } else {
          // Si no viene en config, obtener desde DB
          const { data: cpData } = await supabase
            .from('ConfiguredProducts')
            .select('roll_plus_bom_total')
            .eq('id', configuredProductId)
            .eq('organization_id', activeOrganizationId)
            .eq('deleted', false)
            .maybeSingle();
          
          if (cpData?.roll_plus_bom_total) {
            listPrice = cpData.roll_plus_bom_total;
          }
        }
      }
      
      // ✅ Si no hay roll ni ConfiguredProduct, list_unit_price_snapshot = 0
      // El precio de roll se calcula aparte cuando exista

        // Calculate net price (dealer tier discount + margin floor)
        const categoryMargin: number | null = null;
      const pricingResult = calculateQuoteLinePrice(
        {
          msrp: msrpSaleOut,
          cost_exw: catalogItem?.cost_exw || null,
          labor_cost_per_unit: null,
          shipping_cost_per_unit: null,
          freight_cost: null,
          handling_cost: null,
          import_tax_pct: null,
          default_margin_pct: catalogItem?.default_margin_pct || null,
        },
        discountPct,
        costSettings || null,
        categoryMargin
      );

      // Net unit price (distributor pays this)
      const netUnitPrice = pricingResult.unitPrice;
      
        // Line total (si no hay roll, será 0)
        const lineTotal = netUnitPrice * computedQty;
        
        // Debug log for pricing calculation
        if (import.meta.env.DEV) {
          console.log('QuoteNew: Pricing calculation', {
            rollItemId: rollItemId || 'none (draft without roll)',
            configured_product_id: configuredProductId,
            sku: catalogItem?.sku || 'N/A',
            measureBasis,
            width_m,
            height_m,
            quantity,
            computedQty,
            listPrice,
            netUnitPrice,
            lineTotal,
            categoryCode: catalogItem?.item_category_id ? 'fetched' : 'none'
          });
        }

      // ✅ NORMALIZE CONFIG using new helper
      normalized = normalizeConfiguratorConfig(productConfig);
      
      // Debug log in development
      if (import.meta.env.DEV) {
        console.log('QuoteNew: Normalized config', {
          rawConfig: productConfig,
          normalized,
          optionsToSave: normalized.options,
        });
      }

      // ✅ QuoteLine completo (después de ejecutar FIX_COMPLETO_BOM_FINAL.sql)
      // ✅ NUEVO: Si viene de ConfiguredProduct, agregar configured_product_id al metadata
      const configuredProductIdForMetadata = (productConfig as any).configured_product_id;
      const configuredProductTotalsForMetadata = (productConfig as any).configured_product_totals;
      
      const quoteLineMetadata: Record<string, any> = {};
      if (configuredProductIdForMetadata) {
        quoteLineMetadata.configured_product_id = configuredProductIdForMetadata;
        if (configuredProductTotalsForMetadata) {
          quoteLineMetadata.configured_product_totals = configuredProductTotalsForMetadata;
        }
      }
      
      const quoteLineData: Record<string, any> = {
        quote_id: quoteId,
        catalog_item_id: rollItemId,
        quantity: quantity,
        width_m,
        height_m,
        area,
        position,
        fabric_drop: (productConfig as any).fabricDrop ?? (productConfig as any).drop_type ?? null,
        installation_type: (productConfig as any).installationType ?? null,
        installation_location: (productConfig as any).installationLocation ?? null,
        sqm: width_m && height_m ? width_m * height_m : null,
        collection_name: collectionName,
        variant_name: variantName,
        product_type: productConfig.productType || null,
        bom_template_id: normalized.quoteLine.bom_template_id,
        hardware_color: normalized.quoteLine.hardware_color,
        cassette: normalized.quoteLine.cassette,
        side_channel: normalized.quoteLine.side_channel,
        drive_type: normalized.quoteLine.drive_type,
        // ✅ Usar roll_plus_bom_total desde ConfiguredProduct como MSRP (MSRP sale_out)
        msrp: listPrice, // listPrice ahora viene de ConfiguredProduct.roll_plus_bom_total
        net_price: netUnitPrice,
        cost_exw: catalogItem?.cost_exw || 0,
        total_cost: pricingResult.totalUnitCost * computedQty,
        discount_pct: pricingResult.discountPct,
        applied_margin_pct: pricingResult.totalUnitCost > 0 && netUnitPrice > 0
          ? ((netUnitPrice - pricingResult.totalUnitCost) / netUnitPrice * 100)
          : null,
        default_margin_pct: catalogItem?.default_margin_pct || null,
        ...(Object.keys(quoteLineMetadata).length > 0 ? { metadata: quoteLineMetadata } : {}),
      };
      // ✅ Solo columnas que existen en QuoteLines (pricing/cost viene de CatalogItemsMSRP y snapshots)
      const allowedQuoteLineFields = new Set([
        'quote_id',
        'catalog_item_id',
        'quantity',
        'width_m',
        'height_m',
        'collection_name',
        'variant_name',
        'bom_template_id', // CRITICAL: para BOMInstances
        'msrp',
        'total_cost',
        'area',
        'position',
        'fabric_drop',
        'installation_type',
        'installation_location',
      ]);
      const sanitizedQuoteLineData = Object.fromEntries(
        Object.entries(quoteLineData).filter(([key]) => allowedQuoteLineFields.has(key))
      );

      finalLineId = undefined; // ADD path: set below (RPC result or newLine.id)

      shouldUseSnapshotService = configuredProductId && !editingLineId;

      if (shouldUseSnapshotService) {
        // ═══════════════════════════════════════════════════════════════════
        // ✅ NUEVA ARQUITECTURA: Usar RPC commit_configured_product_to_quote_line
        // Esta RPC hace TODO en una sola transacción:
        // 1. Valida ConfiguredProduct pertenece a la org
        // 2. Crea QuoteLine con snapshots de precios
        // 3. Crea BOMInstance automáticamente
        // ═══════════════════════════════════════════════════════════════════
        try {
          if (!quoteId) {
            throw new Error('quoteId is required to create QuoteLine');
          }
          
          if (import.meta.env.DEV) {
            console.debug('[QuoteNew] Using commit_configured_product_to_quote_line RPC', {
              organization_id: activeOrganizationId,
              quote_id: quoteId,
              configured_product_id: configuredProductId,
              position: productConfig.position,
              area: productConfig.area,
            });
          }

          // ✅ Asegurar que ConfiguredProducts tenga totales actualizados antes del commit
          // (evita QuoteLine con precio 0 cuando bom_preview_snapshot no está persistido)
          try {
            await recalculateConfiguredProductTotals(configuredProductId);
          } catch (_) {
            // Ignorar: la RPC commit puede recalcular internamente si total es 0
          }

          // ✅ Llamar la nueva RPC (con fallback automático si no existe)
          const result = await commitConfiguredProduct({
            organization_id: activeOrganizationId,
            quote_id: quoteId!,
            configured_product_id: configuredProductId,
            dealer_id: null,
            position: productConfig.position != null ? String(productConfig.position) : null,
            area: productConfig.area != null ? String(productConfig.area) : null,
            fabric_drop: (productConfig as any).fabricDrop ?? (productConfig as any).drop_type ?? null,
            installation_type: (productConfig as any).installationType ?? null,
            installation_location: (productConfig as any).installationLocation ?? null,
          });

          finalLineId = result.quote_line_id;

          // ✅ Precio en QuoteLine: 1) sync desde ConfiguredProduct 2) fallback con valor del Review
          const snapshot = (productConfig as any).bom_preview_snapshot;
          const totalsFromConfig = (productConfig as any).configured_product_totals;
          const totalMsrpFromReview =
            (snapshot?.totals?.total_msrp != null && Number(snapshot.totals.total_msrp) > 0)
              ? Number(snapshot.totals.total_msrp)
              : (totalsFromConfig?.total_msrp != null && Number(totalsFromConfig.total_msrp) > 0)
                ? Number(totalsFromConfig.total_msrp)
                : null;

          if (finalLineId) {
            const { error: syncErr } = await supabase.rpc('sync_quote_line_pricing_from_configured_product', {
              p_quote_line_id: finalLineId,
            });
            if (syncErr) {
              if (import.meta.env.DEV) {
                console.warn('[QuoteNew] sync_quote_line_pricing_from_configured_product:', syncErr);
              }
              // Si sync falla, intentar fallback con el total que vimos en Review
              if (totalMsrpFromReview != null && totalMsrpFromReview > 0) {
                const { error: setErr } = await supabase.rpc('set_quote_line_msrp_from_value', {
                  p_quote_line_id: finalLineId,
                  p_total_msrp: totalMsrpFromReview,
                });
                if (setErr && import.meta.env.DEV) {
                  console.warn('[QuoteNew] set_quote_line_msrp_from_value fallback:', setErr);
                }
              }
            } else if (totalMsrpFromReview != null && totalMsrpFromReview > 0) {
              // Asegurar que el valor del Review quede guardado (por si sync escribió 0)
              await supabase.rpc('set_quote_line_msrp_from_value', {
                p_quote_line_id: finalLineId,
                p_total_msrp: totalMsrpFromReview,
              });
            }
          }

          useUIStore.getState().addNotification({
            type: 'success',
            title: 'Success',
            message: 'Quote line added successfully with BOM',
          });

          if (import.meta.env.DEV) {
            console.log('[QuoteNew] QuoteLine created via RPC:', {
              quoteLineId: result.quote_line_id,
              bomInstanceId: result.bom_instance_id,
            });
          }

          // ✅ La RPC ya creó QuoteLine + BOMInstance + snapshots
          // Refrescar y retornar
          refetchLines();
          return;
        } catch (commitError: any) {
          console.error('[QuoteNew] Error creating QuoteLine via RPC:', commitError);
          useUIStore.getState().addNotification({
            type: 'error',
            title: 'Error',
            message: commitError.message || 'Failed to create quote line',
          });
          return;
        }
      } else {
        // Create new line (legacy flow - sin ConfiguredProduct)
        const { data: newLine, error: insertError } = await supabase
          .from('QuoteLines')
          .insert({
            ...sanitizedQuoteLineData,
            organization_id: activeOrganizationId,
          })
          .select('id')
          .single();

        if (insertError) throw insertError;
        if (!newLine?.id) throw new Error('Failed to create quote line');

        finalLineId = newLine.id;

        useUIStore.getState().addNotification({
          type: 'success',
          title: 'Success',
          message: 'Quote line added successfully',
        });
      }
      } // end else (ADD path)

      // ✅ Guardar roll como QuoteLineComponent (kind='selection', component_role='fabric')
      if (finalLineId && rollItemId) {
        try {
          // Check if catalog item is roll
          const { data: itemCheck } = await supabase
            .from('CatalogItems')
            .select('is_roll')
            .eq('id', rollItemId)
            .or(`organization_id.eq.${activeOrganizationId},organization_id.is.null`)
            .eq('is_active', true)
            .maybeSingle();
          
          if (itemCheck?.is_roll) {
            const fabricRotation = (productConfig as any).fabric_rotation || (productConfig as any).roll_rotation || false;
            const fabricHeatseal = (productConfig as any).fabric_heatseal || (productConfig as any).roll_heatseal || false;
            
            if (fabricRotation || fabricHeatseal) {
              const { data: existingLine } = await supabase
                .from('QuoteLines')
                .select('metadata')
                .eq('id', finalLineId)
                .eq('organization_id', activeOrganizationId)
                .maybeSingle();

              await supabase
                .from('QuoteLines')
                .update({
                  metadata: {
                    ...(existingLine?.metadata || {}),
                    fabric_rotation: fabricRotation,
                    fabric_heatseal: fabricHeatseal,
                  }
                })
                .eq('id', finalLineId)
                .eq('organization_id', activeOrganizationId);
            }
            
            // Call function to upsert roll component (using legacy function name for compatibility)
            await supabase.rpc('upsert_fabric_quote_line_component', {
              p_quote_line_id: finalLineId,
              p_organization_id: activeOrganizationId,
            });
          }
        } catch (rollError) {
          console.warn('Roll component creation failed:', rollError);
          // Don't fail the whole operation if roll component creation fails
        }
      }

      // ============================================
      // ✅ QuoteLineComponents table removed. Options live in QuoteLines (area, position, drive_type)
      // and in ConfiguredProducts.bom_preview_snapshot. Skip writing to QuoteLineComponents.
      // ============================================
      if (finalLineId) {
        try {
          // STEP 1: (no-op) QuoteLineComponents dropped
          void 0;

          // STEP 2: Build configuration options array
          const configOptions: any[] = [];

          // ✅ Build option rows using normalized.options
          const opts = normalized.options;
          
          // Hardware color
          if (opts.hardware_color) {
            configOptions.push({
              organization_id: activeOrganizationId,
              quote_line_id: finalLineId,
              kind: 'option',
              component_role: 'hardware_color',
              payload: { hardware_color: opts.hardware_color },
              source: 'configured_component',
              catalog_item_id: null,
              deleted: false,
            });
          }

          // Drive type
          if (opts.drive_type) {
            configOptions.push({
              organization_id: activeOrganizationId,
              quote_line_id: finalLineId,
              kind: 'option',
              component_role: 'drive_type',
              payload: { drive_type: opts.drive_type },
              source: 'configured_component',
              catalog_item_id: null,
              deleted: false,
            });
          }

          // Cassette
          if (opts.cassette) {
            configOptions.push({
              organization_id: activeOrganizationId,
              quote_line_id: finalLineId,
              kind: 'option',
              component_role: 'cassette',
              payload: opts.cassette,
              source: 'configured_component',
              catalog_item_id: null,
              deleted: false,
            });
          }

          // Side channels (plural to match DB function)
          if (opts.side_channel) {
            configOptions.push({
              organization_id: activeOrganizationId,
              quote_line_id: finalLineId,
              kind: 'option',
              component_role: 'side_channels',
              payload: opts.side_channel,
              source: 'configured_component',
              catalog_item_id: null,
              deleted: false,
            });
          }

          // Bottom rail type
          if (opts.bottom_rail_type) {
            configOptions.push({
              organization_id: activeOrganizationId,
              quote_line_id: finalLineId,
              kind: 'option',
              component_role: 'bottom_rail_type',
              payload: { bottom_rail_type: opts.bottom_rail_type },
              source: 'configured_component',
              catalog_item_id: null,
              deleted: false,
            });
          }

          // Tube type
          if (opts.tube_type) {
            configOptions.push({
              organization_id: activeOrganizationId,
              quote_line_id: finalLineId,
              kind: 'option',
              component_role: 'tube_type',
              payload: { tube_type: opts.tube_type },
              source: 'configured_component',
              catalog_item_id: null,
              deleted: false,
            });
          }

          // Operating system variant removed from UI (do not store)

          // Note: drive_manual and remote_control are not in the normalized options
          // They would be handled separately if needed in the future

          // STEP 3: (skipped) QuoteLineComponents table dropped
          if (configOptions.length > 0 && false) {
            const { error: optionsError } = await supabase
              .from('QuoteLineComponents')
              .insert(configOptions);

            if (optionsError) {
              console.error('Error saving config options:', optionsError);
              throw new Error('Failed to save configuration options');
            }

            if (import.meta.env.DEV) {
              console.log('✅ Saved configuration options:', {
                quoteLineId: finalLineId,
                optionsCount: configOptions.length,
                options: configOptions.map(o => ({ role: o.component_role, payload: o.payload }))
              });
            }
          }

          // ✅ STEP 3.5: Save SKU SELECTIONS (kind='selection') - PARENT components
          // ✅ DECISIÓN FINAL: Guardar SKUs seleccionados incluyendo fabric
          const skuSelections: any[] = [];

          // Fabric (si fue seleccionado)
          const fabricItemId = rollItemId ?? catalogItem?.id ?? null;
          if (fabricItemId) {
            skuSelections.push({
              organization_id: activeOrganizationId,
              quote_line_id: finalLineId,
              kind: 'selection',
              component_role: 'fabric',
              catalog_item_id: fabricItemId,
              payload: { 
                sku: catalogItem?.sku || null,
                collection: collectionName,
                variant: variantName,
              },
              source: 'configured_component',
              deleted: false,
            });
          }

          // Motor
          if ((productConfig as any).motor_item_id) {
            skuSelections.push({
              organization_id: activeOrganizationId,
              quote_line_id: finalLineId,
              kind: 'selection',
              component_role: 'motor',
              catalog_item_id: (productConfig as any).motor_item_id,
              payload: { sku: (productConfig as any).motor_sku || null },
              source: 'configured_component',
              deleted: false,
            });
          }

          // Drive (manual)
          if ((productConfig as any).drive_item_id) {
            skuSelections.push({
              organization_id: activeOrganizationId,
              quote_line_id: finalLineId,
              kind: 'selection',
              component_role: 'drive',
              catalog_item_id: (productConfig as any).drive_item_id,
              payload: { sku: (productConfig as any).drive_sku || null },
              source: 'configured_component',
              deleted: false,
            });
          }

          // Bottom Bar
          if ((productConfig as any).bottom_bar_item_id) {
            skuSelections.push({
              organization_id: activeOrganizationId,
              quote_line_id: finalLineId,
              kind: 'selection',
              component_role: 'bottom_bar',
              catalog_item_id: (productConfig as any).bottom_bar_item_id,
              payload: { sku: (productConfig as any).bottom_bar_sku || null },
              source: 'configured_component',
              deleted: false,
            });
          }

          // Headbox (Cassette)
          if ((productConfig as any).headbox_item_id) {
            skuSelections.push({
              organization_id: activeOrganizationId,
              quote_line_id: finalLineId,
              kind: 'selection',
              component_role: 'headbox',
              catalog_item_id: (productConfig as any).headbox_item_id,
              payload: { sku: (productConfig as any).headbox_sku || null },
              source: 'configured_component',
              deleted: false,
            });
          }

          // Tube
          if ((productConfig as any).tube_item_id) {
            skuSelections.push({
              organization_id: activeOrganizationId,
              quote_line_id: finalLineId,
              kind: 'selection',
              component_role: 'tube',
              catalog_item_id: (productConfig as any).tube_item_id,
              payload: { sku: (productConfig as any).tube_sku || null },
              source: 'configured_component',
              deleted: false,
            });
          }

          // Side Channel
          if ((productConfig as any).side_channel_item_id) {
            skuSelections.push({
              organization_id: activeOrganizationId,
              quote_line_id: finalLineId,
              kind: 'selection',
              component_role: 'side_channel',
              catalog_item_id: (productConfig as any).side_channel_item_id,
              payload: { sku: (productConfig as any).side_channel_sku || null },
              source: 'configured_component',
              deleted: false,
            });
          }

          // Bottom Channel
          if ((productConfig as any).bottom_channel_item_id) {
            skuSelections.push({
              organization_id: activeOrganizationId,
              quote_line_id: finalLineId,
              kind: 'selection',
              component_role: 'bottom_channel',
              catalog_item_id: (productConfig as any).bottom_channel_item_id,
              payload: { sku: (productConfig as any).bottom_channel_sku || null },
              source: 'configured_component',
              deleted: false,
            });
          }

          // Insert SKU selections
          if (skuSelections.length > 0) {
            const { error: selectionsError } = (false && await supabase
              .from('QuoteLineComponents')
              .insert(skuSelections)) || { error: null };

            if (selectionsError) {
              console.error('Error saving SKU selections:', selectionsError);
              throw new Error('Failed to save SKU selections');
            }

            if (import.meta.env.DEV) {
              console.log('✅ Saved SKU selections:', {
                quoteLineId: finalLineId,
                selectionsCount: skuSelections.length,
                selections: skuSelections.map(s => ({ role: s.component_role, itemId: s.catalog_item_id }))
              });
            }
          }

          // ✅ NUEVO: Si se usó el servicio de snapshots, el BOM ya fue creado
          // NO generar BOM manualmente si se usó createQuoteLineFromConfiguredProduct
          if (shouldUseSnapshotService) {
            // El servicio ya creó el BOMInstance y calculó precios
            // Solo refrescar líneas y terminar
            await refetchLines();
            return;
          }

          // ✅ NUEVO: Si viene de ConfiguredProduct, usar totals del preview
          // Skip BOM generation si ya existe configured_product_id
          const configuredProductId = (productConfig as any).configured_product_id;
          const configuredProductTotals = (productConfig as any).configured_product_totals;

          // STEP 4: Generate BOM Instance (using NEW slots-based function)
          // ✅ NUEVO: Usar generate_bom_from_slots() que NO usa heurísticas
          // SIEMPRE generar BOM para QuoteLine (aunque ConfiguredProduct ya lo tenga, QuoteLine necesita su propio BOMInstance)
          if (productTypeId) {
            // ====================================================
            // DEBUG: BOM Template Resolution
            // ====================================================
            if (import.meta.env.DEV) {
              console.group('🔍 DEBUG: BOM Template Resolution');
              
              // 1. Verificar ProductType
              console.log('📋 ProductType:', {
                productTypeId,
                productType: productConfig.productType,
                organizationId: activeOrganizationId,
              });
              
              // 2. Obtener hardware_color (QuoteLineComponents eliminada; fallback null)
              let hardwareColorData: { payload?: { hardware_color?: string } } | null = null;
              const hwRes = await supabase.from('QuoteLineComponents').select('payload').eq('quote_line_id', finalLineId).eq('component_role', 'hardware_color').eq('kind', 'option').eq('deleted', false).maybeSingle();
              if (!hwRes.error) hardwareColorData = hwRes.data;
              
              const hardwareColor = hardwareColorData?.payload?.hardware_color || null;
              console.log('🎨 Hardware Color:', hardwareColor);
              
              // 3. Obtener selecciones SKU del usuario
              let userSelections: { component_role: string; catalog_item_id: string }[] = [];
              const selRes = await supabase.from('QuoteLineComponents').select('component_role, catalog_item_id').eq('quote_line_id', finalLineId).eq('kind', 'selection').eq('deleted', false);
              if (!selRes.error && selRes.data) userSelections = selRes.data;

              console.log('🛒 User SKU Selections:', userSelections || []);
              
              // 4. Listar todos los BOM Templates disponibles
              const { data: availableTemplates } = await supabase
                .from('BOMTemplates')
                .select('id, code, name, color, product_type_id, active, deleted, archived')
                .eq('organization_id', activeOrganizationId)
                .eq('product_type_id', productTypeId)
                .eq('deleted', false)
                .eq('archived', false)
                .eq('active', true);
              
              console.log('📦 Available BOM Templates:', availableTemplates || []);
              
              // 5. Para cada template, ver sus slots
              if (availableTemplates && availableTemplates.length > 0) {
                for (const template of availableTemplates) {
                  const { data: slots } = await supabase
                    .from('BOMTemplateSlots')
                    .select('item_role, required, catalog_item_id')
                    .eq('bom_template_id', template.id)
                    .eq('organization_id', activeOrganizationId);
                  
                  const templateColor = template.color ? template.color.toLowerCase().trim() : null;
                  const userColor = hardwareColor ? hardwareColor.toLowerCase().trim() : null;
                  
                  console.log(`📋 Template ${template.code} (${template.id}):`, {
                    color: template.color,
                    slots: slots || [],
                    slotCount: slots?.length || 0,
                    matchesColor: userColor ? (templateColor === userColor) : true,
                  });
                }
              }
              
              // 6. Llamar a la función de matching y ver qué retorna
              const { data: matchedTemplateId, error: matchError } = await supabase.rpc(
                'select_best_bom_template_for_quote_line',
                {
                  p_org_id: activeOrganizationId,
                  p_product_type_id: productTypeId,
                  p_quote_line_id: finalLineId,
                }
              );
              
              console.log('✅ Matched BOM Template:', {
                templateId: matchedTemplateId,
                error: matchError ? safeErr(matchError) : null,
              });
              
              if (matchedTemplateId) {
                const { data: matchedTemplate } = await supabase
                  .from('BOMTemplates')
                  .select('id, code, name, color, product_type_id')
                  .eq('id', matchedTemplateId)
                  .maybeSingle();
                
                console.log('📋 Matched Template Details:', matchedTemplate);
              } else {
                console.warn('⚠️ NO BOM Template matched!');
              }
              
              console.groupEnd();
            }

            const rpcArgs = {
              p_org_id: activeOrganizationId,
              p_quote_line_id: finalLineId,
              p_product_type_id: productTypeId,
            };

            if (import.meta.env.DEV) {
              console.log("🔧 RPC generate_bom_from_slots args:", rpcArgs);
            }

            const { data: bomInstanceId, error: bomError } = await supabase.rpc(
              'generate_bom_from_slots',
              rpcArgs
            );

            if (bomError) {
              console.error("❌ RPC generate_bom_from_slots failed:", safeErr(bomError));
              
              const errorMsg = 
                (bomError.message ?? "Unknown RPC error") +
                (bomError.details ? ` | ${bomError.details}` : "") +
                (bomError.hint ? ` | Hint: ${bomError.hint}` : "");

              useUIStore.getState().addNotification({
                type: 'error',
                title: 'BOM Generation Failed',
                message: errorMsg,
              });

              // IMPORTANT: stop aquí (si sigues a pricing, vas a 0 o inconsistente)
              return;
            }

            if (import.meta.env.DEV) {
              console.log("✅ RPC generate_bom_from_slots OK:", bomInstanceId);
            }

            if (bomInstanceId) {
              if (import.meta.env.DEV) {
                console.log('✅ BOM Instance created (from slots):', bomInstanceId);
              }

              // STEP 5: Calcular precio total del BOM (C) - Función robusta con fallbacks
              try {
                const pricing = await priceFromBOMInstance({
                  supabase,
                  bomInstanceId,
                  organizationId: activeOrganizationId,
                });

                // (C1) Verificar si hay líneas sin resolved_part_id
                if (pricing.linesCount > 0 && pricing.pricedCount === 0) {
                  useUIStore.getState().addNotification({
                    type: "warning",
                    title: "Pricing is zero",
                    message:
                      `BOM has ${pricing.linesCount} lines, but no priced items. ` +
                      `Missing parts: ${pricing.missingParts}. Check CatalogItemsMSRP for pricing data.`,
                  });
                }

                // ✅ OBTENER DATOS DESDE LA BASE DE DATOS (después de guardar)
                // 1. Obtener QuoteLine con medidas actualizadas
                const { data: savedQuoteLine } = await supabase
                  .from('QuoteLines')
                  .select('width_m, height_m, quantity')
                  .eq('id', finalLineId)
                  .eq('organization_id', activeOrganizationId)
                  .maybeSingle();

                const savedWidth_m = savedQuoteLine?.width_m || width_m || 0;
                const savedHeight_m = savedQuoteLine?.height_m || height_m || 0;
                const savedQuantity = savedQuoteLine?.quantity || quantity || 1;

                // 2. Fabric: usar catalog_item_id de QuoteLine (tabla QuoteLineComponents eliminada)
                // Fabric: QuoteLineComponents eliminada; usar catalog_item_id de QuoteLine
                let savedFabricItemId: string | null = null;
                const fabricRes = await supabase.from('QuoteLineComponents').select('catalog_item_id').eq('quote_line_id', finalLineId).eq('organization_id', activeOrganizationId).eq('kind', 'selection').eq('component_role', 'fabric').eq('deleted', false).maybeSingle();
                if (!fabricRes.error && fabricRes.data?.catalog_item_id) {
                  savedFabricItemId = fabricRes.data.catalog_item_id;
                } else {
                  const { data: ql } = await supabase.from('QuoteLines').select('catalog_item_id').eq('id', finalLineId).maybeSingle();
                  savedFabricItemId = ql?.catalog_item_id || null;
                }

                // 3. Obtener datos del Fabric (si existe)
                let savedCatalogItem: any = null;
                let savedMsrpSaleOut: number | null = null;
                
                if (savedFabricItemId) {
                  const { data: fabricData } = await supabase
                    .from('CatalogItems')
                    .select('collection_name, variant_name, cost_exw, default_margin_pct, uom, item_category_id, sku, labor_pct')
                    .eq('id', savedFabricItemId)
                    .or(`organization_id.eq.${activeOrganizationId},organization_id.is.null`)
                    .eq('is_active', true)
                    .maybeSingle();
                  
                  savedCatalogItem = fabricData;

                  if (savedFabricItemId) {
                    const { data: msrpCache } = await supabase
                      .from('CatalogItemsMSRP')
                      .select('msrp')
                      .eq('catalog_item_id', savedFabricItemId)
                      .or(`organization_id.eq.${activeOrganizationId},organization_id.is.null`)
                      .maybeSingle();

                    savedMsrpSaleOut = msrpCache?.msrp || null;
                  }
                }

                // 4. Accessories: QuoteLineComponents eliminada; usar [] si error
                const accRes = await supabase.from('QuoteLineComponents').select('catalog_item_id, qty, unit_cost_exw').eq('quote_line_id', finalLineId).eq('organization_id', activeOrganizationId).eq('deleted', false).or('source.eq.accessory,component_role.eq.accessory');
                const accessories = (accRes.error ? [] : (accRes.data || []));
                const accessoryIds = accessories
                  .map((acc: any) => acc.catalog_item_id)
                  .filter(Boolean) as string[];

                // 5. Obtener MSRP de Accessories
                let accessoriesMsrpTotal = 0;
                if (accessoryIds.length > 0) {
                  const { data: accessoriesMsrp } = await supabase
                    .from('CatalogItemsMSRP')
                    .select('catalog_item_id, msrp')
                    .in('catalog_item_id', accessoryIds)
                    .or(`organization_id.eq.${activeOrganizationId},organization_id.is.null`);

                  const msrpMap = new Map<string, number>();
                  (accessoriesMsrp || []).forEach((r: any) => {
                    msrpMap.set(r.catalog_item_id, Number(r.msrp ?? 0));
                  });

                  accessories.forEach((acc: any) => {
                    const accMsrp = msrpMap.get(acc.catalog_item_id) || 0;
                    const accQty = acc.qty || 1;
                    accessoriesMsrpTotal += accMsrp * accQty;
                  });
                }

                // ✅ FABRIC PRICE: Fabric MSRP (W del Roll total × H) × quantity
                // Fórmula: width_m × height_m × CatalogItemsMSRP.msrp × quantity
                // ====================================================
                // DEBUG: Fabric Pricing
                // ====================================================
                if (import.meta.env.DEV) {
                  console.group('🧵 DEBUG: Fabric Pricing (from DB)');
                  console.log('📏 Measurements (from QuoteLines):', {
                    width_m: savedWidth_m,
                    height_m: savedHeight_m,
                    quantity: savedQuantity,
                    area: savedWidth_m && savedHeight_m ? savedWidth_m * savedHeight_m : null,
                  });
                  console.log('🛒 Fabric Item (from QuoteLineComponents):', {
                    fabricItemId: savedFabricItemId,
                    catalogItem: savedCatalogItem ? {
                      sku: savedCatalogItem.sku,
                      collection_name: savedCatalogItem.collection_name,
                      variant_name: savedCatalogItem.variant_name,
                    } : null,
                  });
                  console.log('💰 MSRP Source:', {
                    msrpSaleOut: savedMsrpSaleOut,
                    source: 'CatalogItemsMSRP.msrp',
                    table: 'CatalogItemsMSRP',
                    column: 'msrp',
                  });
                }
                
                let fabricMsrpTotal = 0;
                if (savedFabricItemId && savedCatalogItem && savedMsrpSaleOut && savedWidth_m && savedHeight_m) {
                  // ✅ Fabric MSRP sale_out (W del Roll total × H) × quantity
                  // width_m = ancho del rollo total, height_m = altura del producto
                  fabricMsrpTotal = savedWidth_m * savedHeight_m * savedMsrpSaleOut * savedQuantity;
                  
                  if (import.meta.env.DEV) {
                    console.log('🧮 Calculation:', {
                      formula: 'width_m × height_m × msrp × quantity',
                      calculation: `${savedWidth_m} × ${savedHeight_m} × ${savedMsrpSaleOut} × ${savedQuantity}`,
                      result: fabricMsrpTotal,
                    });
                  }
                } else {
                  if (import.meta.env.DEV) {
                    console.warn('⚠️ Missing data for fabric calculation:', {
                      hasFabricItemId: !!savedFabricItemId,
                      hasCatalogItem: !!savedCatalogItem,
                      hasMsrpSaleOut: !!savedMsrpSaleOut,
                      hasWidth: !!savedWidth_m,
                      hasHeight: !!savedHeight_m,
                    });
                  }
                }
                
                if (import.meta.env.DEV) {
                  console.groupEnd();
                }

                // ✅ NUEVO: Si existe ConfiguredProduct, usar sus totals en lugar de recalcular
                // Solo calcular si NO viene de ConfiguredProduct (compatibilidad con legacy)
                const hasConfiguredProduct = !!(productConfig as any)?.configured_product_id;
                const configuredProductTotalsFromConfig = (productConfig as any)?.configured_product_totals;
                
                let finalFabricMsrpTotal = fabricMsrpTotal;
                let finalBomTotal = pricing.total;
                let finalFabricPlusBom = fabricMsrpTotal + pricing.total;
                let finalLaborPct = costSettings?.labor_pct || savedCatalogItem?.labor_pct || 0;
                let finalFabricPlusBomWithLabor: number;
                let finalTotalMSRP: number;

                if (hasConfiguredProduct && configuredProductTotalsFromConfig) {
                  // Usar totals del ConfiguredProduct (ya calculados)
                  // ✅ Usar roll_* (fabric_* columns eliminadas)
                  finalFabricMsrpTotal = configuredProductTotalsFromConfig.roll_msrp_total || fabricMsrpTotal;
                  finalBomTotal = configuredProductTotalsFromConfig.bom_total || pricing.total;
                  finalFabricPlusBom = configuredProductTotalsFromConfig.roll_plus_bom_total || finalFabricPlusBom;
                  finalLaborPct = configuredProductTotalsFromConfig.labor_pct || finalLaborPct;
                  
                  if (import.meta.env.DEV) {
                    console.log('[QuoteNew] Using ConfiguredProduct totals:', {
                      configured_product_id: (productConfig as any).configured_product_id,
                      totals: configuredProductTotalsFromConfig,
                      legacy_calculated: {
                        fabric: fabricMsrpTotal,
                        bom: pricing.total,
                        fabricPlusBom: fabricMsrpTotal + pricing.total,
                      },
                    });
                  }
                } else if (hasConfiguredProduct) {
                  // Si no vienen en config, obtener desde DB
                  const configuredProductId = (productConfig as any).configured_product_id;
                  const { data: cpData } = await supabase
                    .from('ConfiguredProducts')
                    .select('roll_msrp_total, bom_total, roll_plus_bom_total, labor_pct, accessories_total, total_msrp')
                    .eq('id', configuredProductId)
                    .eq('organization_id', activeOrganizationId)
                    .eq('deleted', false)
                    .maybeSingle();

                  if (cpData) {
                    // ✅ Usar roll_* (fabric_* columns eliminadas)
                    finalFabricMsrpTotal = cpData.roll_msrp_total || fabricMsrpTotal;
                    finalBomTotal = cpData.bom_total || pricing.total;
                    finalFabricPlusBom = cpData.roll_plus_bom_total || finalFabricPlusBom;
                    finalLaborPct = cpData.labor_pct || finalLaborPct;
                    
                    if (import.meta.env.DEV) {
                      console.log('[QuoteNew] Loaded ConfiguredProduct totals from DB:', {
                        configured_product_id: configuredProductId,
                        totals: cpData,
                      });
                    }
                  }
                }

                // ✅ PRIMERO: Sumar Fabric + BOM (sin labor)
                // ✅ SEGUNDO: Aplicar labor_pct a la suma (Fabric + BOM) × (1 + labor_pct)
                finalFabricPlusBomWithLabor = finalFabricPlusBom * (1 + (finalLaborPct / 100));
                
                // ✅ TERCERO: Sumar Accessories al final
                // PRECIO FINAL = (Fabric + BOM) × (1 + labor_pct) + Accessories
                finalTotalMSRP = finalFabricPlusBomWithLabor + accessoriesMsrpTotal;

                // Mantener variables legacy para compatibilidad
                const fabricPlusBom = finalFabricPlusBom;
                const fabricPlusBomWithLabor = finalFabricPlusBomWithLabor;
                const totalMSRP = finalTotalMSRP;
                const laborPct = finalLaborPct;
                
                // ✅ Costo total (solo para referencia/márgenes, NO precio de venta)
                const fabricCost = savedCatalogItem?.cost_exw ? savedCatalogItem.cost_exw * savedWidth_m * savedHeight_m * savedQuantity : 0;
                const accessoriesCost = accessories.reduce((sum: number, acc: any) => {
                  return sum + (Number(acc.unit_cost_exw || 0) * (acc.qty || 1));
                }, 0);
                const totalCostValue = pricing.totalCost + fabricCost + accessoriesCost;

                // ====================================================
                // DEBUG: Final Pricing Summary
                // ====================================================
                if (import.meta.env.DEV) {
                  console.group('💵 DEBUG: Final Pricing Summary');
                  console.log('🧵 Fabric MSRP:', {
                    total: fabricMsrpTotal,
                    source: 'CatalogItemsMSRP.msrp',
                    calculation: savedFabricItemId && savedCatalogItem && savedMsrpSaleOut && savedWidth_m && savedHeight_m
                      ? `${savedWidth_m} × ${savedHeight_m} × ${savedMsrpSaleOut} × ${savedQuantity} = ${fabricMsrpTotal}`
                      : 'N/A (missing data)',
                  });
                  console.log('🔧 BOM Pricing:', {
                    baseTotal: pricing.total,
                    source: 'CatalogItemsMSRP.msrp (for each BOM component)',
                  });
                  console.log('💰 Fabric + BOM (before labor):', {
                    fabric: fabricMsrpTotal,
                    bom: pricing.total,
                    total: fabricPlusBom,
                  });
                  console.log('🔧 Labor Applied:', {
                    laborPct,
                    fabricPlusBomWithLabor,
                    calculation: `(${fabricMsrpTotal} + ${pricing.total}) × (1 + ${laborPct}%) = ${fabricPlusBomWithLabor}`,
                  });
                  console.log('🎁 Accessories MSRP:', {
                    total: accessoriesMsrpTotal,
                    count: accessories.length,
                    source: 'CatalogItemsMSRP.msrp',
                    items: accessories.map((acc: any) => ({
                      id: acc.catalog_item_id,
                      qty: acc.qty,
                      msrp: acc.catalog_item_id ? 'from CatalogItemsMSRP' : 'N/A',
                    })),
                  });
                  console.log('💰 Final Price:', {
                    totalMSRP,
                    formula: '(Fabric + BOM) × (1 + labor_pct) + Accessories',
                    calculation: `(${fabricMsrpTotal} + ${pricing.total}) × (1 + ${laborPct}%) + ${accessoriesMsrpTotal} = ${totalMSRP}`,
                    breakdown: {
                      fabric: fabricMsrpTotal,
                      bom: pricing.total,
                      fabricPlusBom: fabricPlusBom,
                      fabricPlusBomWithLabor,
                      accessories: accessoriesMsrpTotal,
                      total: totalMSRP,
                    },
                  });
                  console.log('📊 MSRP Sources:', {
                    fabric: 'CatalogItemsMSRP.msrp',
                    bomComponents: 'CatalogItemsMSRP.msrp',
                    accessories: 'CatalogItemsMSRP.msrp',
                    note: 'Todos los precios de venta vienen de CatalogItemsMSRP.msrp',
                  });
                  console.groupEnd();
                }

                // (C3) IMPORTANT: actualiza QuoteLine con verificación
                // ✅ FÓRMULA: Precio Final = Fabric + (BOM × labor_pct)
                // ✅ Fabric = width_m × height_m × CatalogItemsMSRP.msrp × quantity
                // ✅ BOM con labor = BOM total × (1 + labor_pct / 100)
                // ✅ msrp = precio final de venta al cliente (Fabric + BOM con labor)
                // ✅ NUEVO: Si viene de ConfiguredProduct, usar sus totals (ya calculados)
                // ✅ total_cost = costo base total (solo para referencia/márgenes, NO precio de venta)
                
                // ✅ Precio unitario estable: guardar para que no varíe al cambiar solo cantidad
                const savedQty = Math.max(1, savedQuantity || 1);
                const unitMsrpValue = totalMSRP / savedQty;

                // ✅ NUEVO: Si existe configured_product_id, actualizar metadata
                const updateData: Record<string, any> = {
                  msrp: totalMSRP, // ✅ Precio final de venta al cliente = Fabric + (BOM × labor_pct)
                  unit_msrp: unitMsrpValue, // ✅ Precio unitario (igual para qty 1 o 2)
                  net_price: totalMSRP, // ✅ Precio neto (igual a MSRP en este caso)
                  total_cost: totalCostValue, // ✅ Costo total base (solo para referencia/márgenes, NO precio de venta)
                };
                
                // Agregar configured_product_id al metadata si existe
                if (hasConfiguredProduct) {
                  const currentMetadata = (savedQuoteLine as any)?.metadata || {};
                  const configuredProductIdForUpdate = (productConfig as any).configured_product_id;
                  updateData.metadata = {
                    ...currentMetadata,
                    configured_product_id: configuredProductIdForUpdate,
                    ...(configuredProductTotalsFromConfig ? { configured_product_totals: configuredProductTotalsFromConfig } : {}),
                  };
                }
                
                const { error: updErr } = await supabase
                  .from("QuoteLines")
                  .update(updateData)
                  .eq("id", finalLineId)
                  .eq("organization_id", activeOrganizationId);

                if (updErr) {
                  // ✅ FIX: Usar safeErr para evitar [circular] en logs
                  const errorDetails = safeErr(updErr);
                  console.error("❌ QuoteLines update pricing failed", errorDetails);
                  useUIStore.getState().addNotification({
                    type: "error",
                    title: "Pricing update failed",
                    message: errorDetails.message ?? "Could not update QuoteLine pricing.",
                  });
                  return;
                }

                if (import.meta.env.DEV) {
                  console.log('✅ QuoteLine updated with BOM + Fabric + Accessories pricing:', {
                    msrp: totalMSRP, // ✅ Precio final de venta al cliente
                    totalCost: totalCostValue, // ✅ Costo base (NO precio de venta)
                    quantity: savedQuantity,
                    fabricMsrpTotal, // ✅ Fabric = width_m × height_m × msrp × quantity
                    bomMsrpBase: pricing.total, // ✅ BOM MSRP base (de CatalogItemsMSRP.msrp)
                    fabricPlusBom: fabricPlusBom, // ✅ Fabric + BOM (antes de labor)
                    fabricPlusBomWithLabor, // ✅ (Fabric + BOM) × (1 + labor_pct)
                    accessoriesMsrpTotal, // ✅ Accessories MSRP (de CatalogItemsMSRP.msrp)
                    laborPct, // ✅ Porcentaje de labor aplicado
                    bomCostTotal: pricing.totalCost, // ✅ BOM Cost (de CatalogItems.cost_exw)
                    pricedCount: pricing.pricedCount,
                    missingParts: pricing.missingParts,
                    accessoriesCount: accessories.length,
                  });
                }

                // Refrescar las líneas para mostrar los precios actualizados
                await refetchLines();
              } catch (pricingError) {
                // ✅ FIX: Usar safeErr para evitar [circular] en logs
                const errorDetails = safeErr(pricingError);
                console.error('Error calculating BOM pricing:', errorDetails);
                useUIStore.getState().addNotification({
                  type: 'error',
                  title: 'Pricing Calculation Failed',
                  message: errorDetails.message || 'Line saved but pricing could not be calculated from BOM.',
                });
              }
            }
          }
        } catch (bomError) {
          // ✅ FIX: Usar safeErr para evitar [circular] en logs
          const errorDetails = safeErr(bomError);
          console.warn('BOM generation flow failed:', errorDetails);
          // Don't fail the whole operation if BOM generation fails
        }
      }

      // Save accessories as QuoteLineComponents
      const accessories = (productConfig as any).accessories || [];
      if (finalLineId) {
        try {
          // IMPORTANT: Delete old accessories first (when editing)
          // This prevents duplicates and ensures clean state
          const { error: deleteError } = await supabase.from('QuoteLineComponents').update({ deleted: true }).eq('quote_line_id', finalLineId).eq('organization_id', activeOrganizationId).or('source.eq.accessory,component_role.eq.accessory');

          if (deleteError && !deleteError.message?.includes('does not exist') && import.meta.env.DEV) {
            console.warn('Failed to delete old accessories:', deleteError);
          }

          // Insert new accessories if any
          if (accessories.length > 0) {
            // Get catalog items for accessories to get their names and costs
            const accessoryIds = accessories.map((a: any) => a.id).filter(Boolean);
            if (accessoryIds.length > 0) {
              const { data: accessoryItems } = await supabase
                .from('CatalogItems')
                // ✅ FIX: CatalogItems NO tiene columna "msrp" (está en CatalogItemsMSRP)
                .select('id, item_name, sku, cost_exw, default_margin_pct')
                .in('id', accessoryIds)
                .eq('organization_id', activeOrganizationId)
                .eq('is_active', true);

              // Insert accessories as QuoteLineComponents
              const accessoryComponents = accessories.map((acc: any) => {
                const catalogItem = accessoryItems?.find((item: any) => item.id === acc.id);
                // ✅ FIX: Usar cost_exw en lugar de msrp (msrp está en CatalogItemsMSRP)
                const unitCost = acc.price || catalogItem?.cost_exw || 
                  (catalogItem?.cost_exw ? catalogItem.cost_exw * (1 + (catalogItem.default_margin_pct || 50) / 100) : 0);
                
                return {
                  organization_id: activeOrganizationId,
                  quote_line_id: finalLineId,
                  catalog_item_id: acc.id,
                  qty: acc.qty || 1,
                  unit_cost_exw: unitCost,
                  source: 'accessory',
                  component_role: 'accessory',
                  uom: (catalogItem as any)?.uom || 'ea',
                };
              });

              if (accessoryComponents.length > 0) {
                const { error: accessoryError } = await (async () => {
                  try {
                    return await supabase.from('QuoteLineComponents').insert(accessoryComponents);
                  } catch (e) {
                    return { error: e };
                  }
                })();

                if (accessoryError && import.meta.env.DEV) {
                  console.warn('Failed to save accessories:', accessoryError);
                }
              }
            }
          }
        } catch (accessoryError) {
          console.warn('Error saving accessories:', accessoryError);
        }
      }

      // Compute costs
      if (finalLineId) {
        try {
          await supabase.rpc('compute_quote_line_cost', {
            p_quote_line_id: finalLineId,
          });
        } catch (costError) {
          console.warn('Cost computation failed:', costError);
        }
      }

      // Refresh lines
      await refetchLines();
      setShowConfigurator(false);
      setEditingLineId(null);
    } catch (err: any) {
      // Format error message to avoid [circular] reference
      const errorMessage = err?.message || err?.error_description || err?.hint || 'Failed to save quote line';
      const errorDetails = err?.code ? ` (${err.code})` : '';
      console.error('Error saving quote line:', errorMessage + errorDetails, err);
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: errorMessage + errorDetails,
      });
    }
  };

  // Handle delete line
  const handleDeleteLine = async (lineId: string) => {
    if (!confirm('Are you sure you want to delete this line?')) return;

    try {
      const { error } = await supabase
        .from('QuoteLines')
        .delete()
        .eq('id', lineId)
        .eq('organization_id', activeOrganizationId);

      if (error) throw error;

      await refetchLines();
      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Success',
        message: 'Quote line deleted',
      });
    } catch (err: any) {
      console.error('Error deleting line:', err);
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: err.message || 'Failed to delete quote line',
      });
    }
  };

  // Load initial config for Edit: usa getConfigFromQuoteLine (CP/snapshot + fallback) para que las cards muestren la selección guardada
  useEffect(() => {
    const loadLineConfig = async () => {
      if (!editingLineId || !quoteId || !activeOrganizationId) {
        setInitialLineConfig(undefined);
        return;
      }

      try {
        clearConfiguratorDraft();

        const config = await getConfigFromQuoteLine({
          supabase,
          organizationId: activeOrganizationId,
          lineId: editingLineId,
          forEdit: true,
        });
        if (!config) {
          setInitialLineConfig(undefined);
          return;
        }

        setInitialLineConfig(config);
        if (editingLineId) setShowConfigurator(true);
      } catch (err: any) {
        const errorMessage = err?.message || 'Failed to load quote line configuration';
        if (import.meta.env.DEV) console.error('Error loading line config:', { message: errorMessage, code: err?.code, editingLineId, quoteId });
        useUIStore.getState().addNotification({ type: 'error', title: 'Error loading quote line', message: errorMessage + '. Please try again.' });
        setInitialLineConfig(undefined);
      }
    };

    loadLineConfig();
  }, [editingLineId, quoteId, activeOrganizationId]);

  // Handle edit line
  const handleEditLine = (lineId: string) => {
    setEditingLineId(lineId);
    // Don't show configurator immediately - wait for loadLineConfig to finish
    // The useEffect will show it after config is loaded
  };

  const handleDuplicateLine = async (lineId: string) => {
    if (!activeOrganizationId) return;
    try {
      clearConfiguratorDraft();
      setEditingLineId(null);

      const DEBUG_PREFILL = import.meta.env.DEV && (window as any).__DEBUG_PREFILL === true;
      if (DEBUG_PREFILL) {
        const lineRow = await supabase.from('QuoteLines').select('id, configured_product_id').eq('id', lineId).eq('organization_id', activeOrganizationId).maybeSingle();
        console.log('[QuoteNew DUPLICATE] opening prefill', { quote_line_id: lineId, configured_product_id: lineRow?.data?.configured_product_id ?? null });
      }

      const config = await getConfigFromQuoteLine({
        supabase,
        organizationId: activeOrganizationId,
        lineId,
        forEdit: false,
      });
      if (!config) {
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'Error',
          message: 'Could not load line to duplicate.',
        });
        return;
      }
      const { quote_line_id: _q, configured_product_id: _c, ...prefillConfig } = config as any;
      if (DEBUG_PREFILL) {
        console.log('[QuoteNew DUPLICATE] getConfigFromQuoteLine result keys', {
          hardware_color: (prefillConfig as any).hardware_color,
          bottom_bar_sku: (prefillConfig as any).bottom_bar_sku,
          bottom_bar_item_id: (prefillConfig as any).bottom_bar_item_id,
          _prefill_source: (prefillConfig as any)._prefill_source,
        });
      }
      if (import.meta.env.DEV && !DEBUG_PREFILL) {
        const m = (prefillConfig as any).measurements;
        const panelsList = (prefillConfig as any).panels ?? m?.panels ?? [];
        const sumPanels = Array.isArray(panelsList) ? panelsList.reduce((s: number, p: any) => s + (p?.width_mm ?? 0), 0) : 0;
        console.debug('[QuoteNew] Duplicate prefill config', {
          width_mm: (prefillConfig as any).width_mm,
          height_mm: (prefillConfig as any).height_mm,
          width_total_mm: m?.width_total_mm,
          panel_count: m?.panel_count,
          sumPanelsMm: sumPanels,
          drive_type: (prefillConfig as any).drive_type,
          operation_type: (prefillConfig as any).operation_type,
          tube_item_id: (prefillConfig as any).tube_item_id,
          drive_item_id: (prefillConfig as any).drive_item_id,
          motor_item_id: (prefillConfig as any).motor_item_id,
          hasMeasurements: !!m,
          panelsLength: panelsList?.length ?? 0,
        });
      }
      setInitialLineConfig(prefillConfig as ProductConfig);
      setShowConfigurator(true);
    } catch (e: any) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: e?.message || 'Failed to load line for duplicate.',
      });
    }
  };

  // Reorder quote lines (drag-and-drop)
  const handleDragStart = (_e: React.DragEvent, lineId: string) => {
    setDraggedLineId(lineId);
  };
  const handleDragOver = (e: React.DragEvent, lineId: string) => {
    e.preventDefault();
    if (draggedLineId && draggedLineId !== lineId) setDragOverLineId(lineId);
  };
  const handleDragLeave = () => setDragOverLineId(null);
  const handleDrop = async (e: React.DragEvent, targetLineId: string) => {
    e.preventDefault();
    setDragOverLineId(null);
    if (!draggedLineId || draggedLineId === targetLineId || !quoteId) {
      setDraggedLineId(null);
      return;
    }
    try {
      const draggedIndex = quoteLines.findIndex((l: any) => l.id === draggedLineId);
      const targetIndex = quoteLines.findIndex((l: any) => l.id === targetLineId);
      if (draggedIndex === -1 || targetIndex === -1) {
        setDraggedLineId(null);
        return;
      }
      const reordered = [...quoteLines];
      const [removed] = reordered.splice(draggedIndex, 1);
      if (!removed) {
        setDraggedLineId(null);
        return;
      }
      reordered.splice(targetIndex, 0, removed);
      const updates = reordered.map((line: any, index: number) => ({
        id: String(line.id),
        sort_order: index,
      }));
      const { data, error } = await supabase.rpc('update_quote_line_sort_orders', {
        p_quote_id: quoteId,
        p_updates: updates,
      });
      if (error) {
        if (error.code === '42883' || error.message?.includes('does not exist')) {
          const updatePromises = updates.map((u: { id: string; sort_order: number }) =>
            supabase.from('QuoteLines').update({ sort_order: u.sort_order }).eq('id', u.id).eq('quote_id', quoteId)
          );
          const results = await Promise.all(updatePromises);
          if (results.some((r) => r.error)) throw results.find((r) => r.error)?.error ?? error;
        } else throw error;
      }
      refetchLines();
      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Reordered',
        message: 'Quote line order updated.',
      });
    } catch (err: any) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Reorder failed',
        message: err?.message ?? 'Failed to reorder lines',
      });
    } finally {
      setDraggedLineId(null);
    }
  };

  // Handle PDF download: variant 'dealer' (prices by tier) or 'client' (MSRP + optional discount)
  const handleDownloadPDF = async (variant: PDFVariant, clientDiscountPct: number = 0) => {
    if (!quoteId || !quoteData) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: 'Quote data is not available. Save the quote and try again.',
      });
      return;
    }

    try {
      const { data: orgData } = await supabase
        .from('Organizations')
        .select('name')
        .eq('id', activeOrganizationId)
        .maybeSingle();
      const organizationName = orgData?.name || 'Arquiproductos';

      // PDF uses Proposal format; logo is always Arquiproducto from /images (no dealer logo link)
      const tryLogo = async (path: string): Promise<string | undefined> => {
        try {
          const res = await fetch(path, { cache: 'no-store' });
          if (!res.ok) return undefined;
          const blob = await res.blob();
          return new Promise<string>((resolve, reject) => {
            const reader = new FileReader();
            reader.onloadend = () => resolve(reader.result as string);
            reader.onerror = reject;
            reader.readAsDataURL(blob);
          });
        } catch {
          return undefined;
        }
      };
      const logoPaths = [
        '/images/Arquiproductos.png',
        '/images/arquiproductos.png',
        '/images/Arquiproductos.jpg',
        '/images/arquiproductos.jpg',
      ];
      let logoPngBase64: string | undefined;
      for (const path of logoPaths) {
        logoPngBase64 = await tryLogo(path);
        if (logoPngBase64) break;
      }
      let logoWidthPx = 100;
      let logoHeightPx = 100;
      if (logoPngBase64) {
        try {
          const dims = await new Promise<{ w: number; h: number }>((resolve) => {
            const img = new Image();
            img.onload = () => resolve({ w: img.naturalWidth, h: img.naturalHeight });
            img.onerror = () => resolve({ w: 100, h: 100 });
            img.src = logoPngBase64!;
          });
          logoWidthPx = dims.w;
          logoHeightPx = dims.h;
        } catch {
          // keep defaults
        }
      }

      const sellerName =
        (quoteLines[0] as { quote_created_by?: string } | undefined)?.quote_created_by;

      // Dealer data for PDF left block (Dealer, Dealer User, Phone, Address) and header Dealer No
      let dealerName: string | undefined;
      let dealerNo: string | null = null;
      let dealerUser: string | null = null;
      let dealerPhone: string | null = null;
      let dealerAddress: string | null = null;
      const dealerId = quoteData.dealer_id ?? null;
      if (dealerId) {
        const { data: dealer } = await supabase
          .from('Dealers')
          .select('dealer_name, dealer_no, dealer_phone, street_address_line_1, street_address_line_2, city, state, zip_code, country, primary_contact_id')
          .eq('id', dealerId)
          .maybeSingle();
        if (dealer) {
          dealerName = dealer.dealer_name ?? undefined;
          dealerNo = (dealer as { dealer_no?: string | null }).dealer_no ?? null;
          dealerPhone = dealer.dealer_phone ?? null;
          dealerAddress = [
            dealer.street_address_line_1,
            dealer.street_address_line_2,
            [dealer.city, dealer.state, dealer.zip_code].filter(Boolean).join(', '),
            dealer.country,
          ]
            .filter(Boolean)
            .join('\n') || null;
          if (dealer.primary_contact_id) {
            const { data: pc } = await supabase
              .from('DirectoryContacts')
              .select('contact_name')
              .eq('id', dealer.primary_contact_id)
              .maybeSingle();
            dealerUser = (pc as { contact_name?: string } | null)?.contact_name ?? null;
          }
          if (!dealerUser) dealerUser = sellerName ?? null;
        }
      }
      if (!dealerName) dealerName = organizationName;

      // Resolve Quote Terms for PDF: use saved on quote, else from dealer's default template
      let termsTitle = (quoteData as { terms_title?: string | null }).terms_title ?? undefined;
      let termsContent = (quoteData as { terms_content?: string | null }).terms_content ?? undefined;
      const effectiveDealerIdForTerms = quoteData.dealer_id ?? dealerInfo?.id ?? null;
      if ((!termsTitle && !termsContent) && effectiveDealerIdForTerms && activeOrganizationId) {
        let templateId = await resolveDefaultTermsTemplateId(activeOrganizationId, effectiveDealerIdForTerms, 'quote');
        if (!templateId) {
          templateId = await resolveDefaultTermsTemplateId(activeOrganizationId, effectiveDealerIdForTerms, 'proposal');
        }
        if (templateId) {
          const tpl = await fetchTermsTemplateById(templateId);
          if (tpl) {
            termsTitle = tpl.title ?? undefined;
            termsContent = tpl.content ?? undefined;
          }
        }
      }

      const qty = (line: any) => line.quantity ?? line.qty ?? 1;
      const dealerDiscountPct = variant === 'dealer'
        ? getDealerTierDiscountPct(dealerInfo?.dealer_tier_id ?? null, dealerTiers)
        : 0;

      const pdfLines = quoteLines.map((line: any) => {
        const n = qty(line);
        const msrpLineTotal = line.msrp ?? (line.roll_msrp_snapshot || 0) + (line.bom_msrp_snapshot || 0);
        const lineTotal =
          variant === 'dealer'
            ? msrpLineTotal * (1 - dealerDiscountPct / 100)
            : (line.msrp ?? (line.roll_msrp_snapshot || 0) + (line.bom_msrp_snapshot || 0));
        const accessoriesStr =
          line.Accessories && Array.isArray(line.Accessories) && line.Accessories.length > 0
            ? line.Accessories.map((acc: any) => {
                const name = acc.item_name ?? acc.CatalogItems?.item_name ?? acc.name ?? '—';
                return acc.qty > 1 ? `${name} ×${acc.qty}` : name;
              }).join(', ')
            : null;
        return {
          id: line.id,
          area: line.area,
          position: line.position,
          product_type: line.product_type ?? line.ProductType?.name,
          collection_name: line.collection_name,
          variant_name: line.variant_name,
          drive_type: line.drive_type,
          width_m: line.width_m,
          height_m: line.height_m,
          dimensions_source: {
            width_m: line.width_m,
            height_m: line.height_m,
            width_mm: (line.ConfiguredProduct?.config_snapshot as any)?.width_mm,
            height_mm: (line.ConfiguredProduct?.config_snapshot as any)?.height_mm,
            measurements: (line.ConfiguredProduct?.config_snapshot as any)?.measurements,
            panels: (line.ConfiguredProduct?.config_snapshot as any)?.panels,
          },
          qty: n,
          line_total: lineTotal,
          accessories: accessoriesStr,
          CatalogItems: line.CatalogItems ?? null,
        };
      });

      const doc = generateQuotePDF(
        {
          quote_no: quoteData.quote_no || watch('quote_no'),
          customer_id: quoteData.customer_id || watch('customer_id'),
          status: quoteData.status || watch('status'),
          currency: quoteData.currency || watch('currency'),
          notes: quoteData.description ?? quoteData.notes ?? watch('description'),
          terms_title: termsTitle,
          terms_content: termsContent,
          totals: quoteData.totals ?? {
            subtotal: totals.subtotal,
            tax_total: totals.tax,
            total: totals.total,
          },
          created_at: quoteData.created_at || new Date().toISOString(),
        },
        selectedCustomer ? { customer_name: selectedCustomer.customer_name } : null,
        selectedContact
          ? { contact_name: selectedContact.contact_name, contact_email: selectedContact.email ?? undefined }
          : null,
        pdfLines,
        organizationName,
        {
          variant,
          clientDiscountPct,
          logoPngBase64,
          logoWidthPx,
          logoHeightPx,
          dealerName,
          dealerNo: dealerNo ?? undefined,
          dealerUser,
          dealerPhone,
          dealerAddress,
          sellerName,
          description: quoteData.description ?? watch('description') ?? quoteData.notes ?? undefined,
          projectName: quoteData.description ?? quoteData.notes ?? watch('description') ?? undefined,
          tax_pct: costSettings?.tax_pct ?? 0.07,
          exempt_tax: (quoteData as { exempt_tax?: boolean })?.exempt_tax ?? watch('exempt_tax') ?? false,
        }
      );

      const suffix = variant === 'dealer' ? 'Dealer' : 'Cliente';
      const fileName = `Quote_${quoteData.quote_no || watch('quote_no')}_${suffix}_${new Date().toISOString().split('T')[0]}.pdf`;
      doc.save(fileName);

      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Success',
        message: 'PDF downloaded successfully',
      });
    } catch (err: any) {
      console.error('Error generating PDF:', err);
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: err.message || 'Failed to generate PDF',
      });
    }
  };

  // Preview PDF in new tab (same as Proposal)
  const handlePreviewPDF = async () => {
    if (!quoteId || !quoteData) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: 'Quote data is not available. Save the quote and try again.',
      });
      return;
    }
    try {
      const { data: orgData } = await supabase
        .from('Organizations')
        .select('name')
        .eq('id', activeOrganizationId)
        .maybeSingle();
      const organizationName = orgData?.name || 'Arquiproductos';

      const tryLogo = async (path: string): Promise<string | undefined> => {
        try {
          const res = await fetch(path, { cache: 'no-store' });
          if (!res.ok) return undefined;
          const blob = await res.blob();
          return new Promise<string>((resolve, reject) => {
            const reader = new FileReader();
            reader.onloadend = () => resolve(reader.result as string);
            reader.onerror = reject;
            reader.readAsDataURL(blob);
          });
        } catch {
          return undefined;
        }
      };
      let logoPngBase64: string | undefined;
      for (const path of ['/images/Arquiproductos.png', '/images/arquiproductos.png', '/images/Arquiproductos.jpg']) {
        logoPngBase64 = await tryLogo(path);
        if (logoPngBase64) break;
      }
      let logoWidthPx = 100;
      let logoHeightPx = 100;
      if (logoPngBase64) {
        try {
          const dims = await new Promise<{ w: number; h: number }>((resolve) => {
            const img = new Image();
            img.onload = () => resolve({ w: img.naturalWidth, h: img.naturalHeight });
            img.onerror = () => resolve({ w: 100, h: 100 });
            img.src = logoPngBase64!;
          });
          logoWidthPx = dims.w;
          logoHeightPx = dims.h;
        } catch {}
      }

      const sellerName = (quoteLines[0] as { quote_created_by?: string } | undefined)?.quote_created_by;
      let dealerName: string | undefined;
      let dealerNo: string | null = null;
      let dealerUser: string | null = null;
      let dealerPhone: string | null = null;
      let dealerAddress: string | null = null;
      const dealerId = quoteData.dealer_id ?? null;
      if (dealerId) {
        const { data: dealer } = await supabase
          .from('Dealers')
          .select('dealer_name, dealer_no, dealer_phone, street_address_line_1, street_address_line_2, city, state, zip_code, country, primary_contact_id')
          .eq('id', dealerId)
          .maybeSingle();
        if (dealer) {
          dealerName = dealer.dealer_name ?? undefined;
          dealerNo = (dealer as { dealer_no?: string | null }).dealer_no ?? null;
          dealerPhone = dealer.dealer_phone ?? null;
          dealerAddress = [
            dealer.street_address_line_1,
            dealer.street_address_line_2,
            [dealer.city, dealer.state, dealer.zip_code].filter(Boolean).join(', '),
            dealer.country,
          ]
            .filter(Boolean)
            .join('\n') || null;
          if (dealer.primary_contact_id) {
            const { data: pc } = await supabase
              .from('DirectoryContacts')
              .select('contact_name')
              .eq('id', dealer.primary_contact_id)
              .maybeSingle();
            dealerUser = (pc as { contact_name?: string } | null)?.contact_name ?? null;
          }
          if (!dealerUser) dealerUser = sellerName ?? null;
        }
      }
      if (!dealerName) dealerName = organizationName;

      // Resolve Quote Terms for PDF: use saved on quote, else from dealer's default template
      let termsTitle = (quoteData as { terms_title?: string | null }).terms_title ?? undefined;
      let termsContent = (quoteData as { terms_content?: string | null }).terms_content ?? undefined;
      const effectiveDealerIdForTerms = quoteData.dealer_id ?? dealerInfo?.id ?? null;
      if ((!termsTitle && !termsContent) && effectiveDealerIdForTerms && activeOrganizationId) {
        let templateId = await resolveDefaultTermsTemplateId(activeOrganizationId, effectiveDealerIdForTerms, 'quote');
        if (!templateId) {
          templateId = await resolveDefaultTermsTemplateId(activeOrganizationId, effectiveDealerIdForTerms, 'proposal');
        }
        if (templateId) {
          const tpl = await fetchTermsTemplateById(templateId);
          if (tpl) {
            termsTitle = tpl.title ?? undefined;
            termsContent = tpl.content ?? undefined;
          }
        }
      }

      const qty = (line: any) => line.quantity ?? line.qty ?? 1;
      const dealerDiscountPct = getDealerTierDiscountPct(dealerInfo?.dealer_tier_id ?? null, dealerTiers);
      const pdfLines = quoteLines.map((line: any) => {
        const n = qty(line);
        const msrpLineTotal = line.msrp ?? (line.roll_msrp_snapshot || 0) + (line.bom_msrp_snapshot || 0);
        const lineTotal = msrpLineTotal * (1 - dealerDiscountPct / 100);
        const accessoriesStr =
          line.Accessories && Array.isArray(line.Accessories) && line.Accessories.length > 0
            ? line.Accessories.map((acc: any) => {
                const name = acc.item_name ?? acc.CatalogItems?.item_name ?? acc.name ?? '—';
                return acc.qty > 1 ? `${name} ×${acc.qty}` : name;
              }).join(', ')
            : null;
        return {
          id: line.id,
          area: line.area,
          position: line.position,
          product_type: line.product_type ?? line.ProductType?.name,
          collection_name: line.collection_name,
          variant_name: line.variant_name,
          drive_type: line.drive_type,
          width_m: line.width_m,
          height_m: line.height_m,
          qty: n,
          line_total: lineTotal,
          accessories: accessoriesStr,
          CatalogItems: line.CatalogItems ?? null,
        };
      });

      const doc = generateQuotePDF(
        {
          quote_no: quoteData.quote_no || watch('quote_no'),
          customer_id: quoteData.customer_id || watch('customer_id'),
          status: quoteData.status || watch('status'),
          currency: quoteData.currency || watch('currency'),
          notes: quoteData.description ?? quoteData.notes ?? watch('description'),
          terms_title: termsTitle,
          terms_content: termsContent,
          totals: quoteData.totals ?? { subtotal: totals.subtotal, tax_total: totals.tax, total: totals.total },
          created_at: quoteData.created_at || new Date().toISOString(),
        },
        selectedCustomer ? { customer_name: selectedCustomer.customer_name } : null,
        selectedContact
          ? { contact_name: selectedContact.contact_name, contact_email: selectedContact.email ?? undefined }
          : null,
        pdfLines,
        organizationName,
        {
          variant: 'dealer',
          logoPngBase64,
          logoWidthPx,
          logoHeightPx,
          dealerName,
          dealerNo: dealerNo ?? undefined,
          dealerUser,
          dealerPhone,
          dealerAddress,
          sellerName,
          description: quoteData.description ?? watch('description') ?? quoteData.notes ?? undefined,
          projectName: quoteData.description ?? quoteData.notes ?? watch('description') ?? undefined,
          tax_pct: costSettings?.tax_pct ?? 0.07,
          exempt_tax: (quoteData as { exempt_tax?: boolean })?.exempt_tax ?? watch('exempt_tax') ?? false,
        }
      );

      const blob = doc.output('blob');
      const url = URL.createObjectURL(blob);
      window.open(url, '_blank');
      setTimeout(() => URL.revokeObjectURL(url), 60000);
      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Preview',
        message: 'PDF opened in new tab. You can download from the browser if needed.',
      });
    } catch (err: any) {
      console.error('Error generating PDF preview:', err);
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: (err as Error)?.message || 'Failed to generate PDF preview',
      });
    }
  };

  // Handle form submit
  const onSubmit = async (
    data: QuoteFormValues,
    shouldNavigate: boolean = false,
    skipApproveConfirm: boolean = false
  ) => {
    if (!activeOrganizationId) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: 'No organization selected',
      });
      return;
    }

    setIsSaving(true);
    setSaveError(null);

    try {
      // id, organization_id, quote_no, status, tracking_status, customer_id, contact_id,
      // created_by_user_id, deleted, created_at, updated_at, dealer_id, currency, ...
      const quoteDataPayload: any = {
        quote_no: data.quote_no,
        customer_id: data.customer_id || null,
        contact_id: selectedContactId || null,
        status: data.status,
        organization_id: activeOrganizationId,
        dealer_id: dealerInfo?.id || quoteData?.dealer_id || null,
        description: data.description?.trim() || null,
        notes: data.notes?.trim() || null,
        po_number: data.po_number?.trim() || null,
        exempt_tax: data.exempt_tax ?? false,
      };

      const persistedStatus = normalizeStatus((quoteData as any)?.status);
      const nextStatus = normalizeStatus(quoteDataPayload.status);
      const isTransitioningToApproved = nextStatus === 'approved' && (!quoteId || persistedStatus !== 'approved');
      if (isTransitioningToApproved && !skipApproveConfirm) {
        setPendingApproveSubmission({ data, shouldNavigate });
        setApproveConfirmOpen(true);
        return;
      }

      if (quoteId) {
        // Update existing quote
        // Check if status is changing to 'approved' - use approveQuote function
        const isApproving = isTransitioningToApproved;
        
        // If approving, update other fields FIRST, then approve (safer transaction order)
        if (isApproving) {
          console.log('🔔 QuoteNew: Status changed to approved, using approveQuote function');
          
          // Step 1: Update other fields first (without status)
          const { status, ...safeData } = quoteDataPayload;
          if (Object.keys(safeData).length > 0) {
            await updateQuote(quoteId, safeData);
          }
          
          // Step 2: Approve quote (this triggers the DB trigger)
          await approveQuote(quoteId, activeOrganizationId);
        } else {
          // For non-approval updates, use regular updateQuote
          await updateQuote(quoteId, quoteDataPayload);
        }
        
        useUIStore.getState().addNotification({
          type: 'success',
          title: 'Success',
          message: isApproving ? 'Quote approved successfully' : 'Quote updated successfully',
        });
        
          // Only navigate if shouldNavigate is true
          if (shouldNavigate) {
            router.navigate('/sales/quotes');
          }
      } else {
        // Create new quote
        const created = await createQuote(quoteDataPayload);
        if (created?.id) {
          // Update quoteId state so form knows it's now in edit mode
          setQuoteId(created.id);
          setQuoteData(created);
          
          if (created.dealer_id && !dealerInfo) {
            const { data: dealer } = await supabase
              .from('Dealers')
              .select('id, dealer_name, dealer_no, dealer_tier_id')
              .eq('id', created.dealer_id)
              .eq('organization_id', activeOrganizationId)
              .eq('deleted', false)
              .maybeSingle();

            if (dealer) {
              setDealerInfo({
                id: dealer.id,
                name: dealer.dealer_name || 'Unknown Dealer',
                number: dealer.dealer_no || null,
                dealer_tier_id: dealer.dealer_tier_id ?? null,
              });
            }
          }
          
          useUIStore.getState().addNotification({
            type: 'success',
            title: 'Success',
            message: 'Quote created successfully',
          });
          
          // Only navigate if shouldNavigate is true
          if (shouldNavigate) {
            router.navigate('/sales/quotes');
          }
        }
      }
    } catch (err: any) {
      // Format error message to avoid [circular] reference
      const errorMessage = err?.message || err?.error_description || err?.hint || 'Failed to save quote';
      const errorDetails = err?.code ? ` (${err.code})` : '';
      console.error('Error saving quote:', errorMessage + errorDetails, err);
      setSaveError(errorMessage + errorDetails);
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: errorMessage + errorDetails,
      });
    } finally {
      setIsSaving(false);
    }
  };

  // Wrapper for Save and Close button
  const handleSaveAndClose = async (data: QuoteFormValues) => {
    await onSubmit(data, true); // Pass true to navigate after saving
  };

  const [deleteConfirmOpen, setDeleteConfirmOpen] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);
  const handleDeleteDraftQuote = async () => {
    if (!quoteId || !activeOrganizationId) return;
    setIsDeleting(true);
    try {
      const { error } = await supabase.rpc('soft_delete_quotes', { p_quote_ids: [quoteId] });
      if (error) throw error;
      useUIStore.getState().addNotification({ type: 'success', title: 'Eliminado', message: 'Cotización eliminada correctamente.' });
      router.navigate('/sales/quotes');
    } catch (err: any) {
      useUIStore.getState().addNotification({ type: 'error', title: 'Error', message: err?.message || 'No se pudo eliminar la cotización.' });
    } finally {
      setIsDeleting(false);
      setDeleteConfirmOpen(false);
    }
  };
  const handleCloseApproveConfirm = () => {
    if (isSaving || isUpdating) return;
    setApproveConfirmOpen(false);
    setPendingApproveSubmission(null);
  };
  const handleConfirmApprove = async () => {
    if (!pendingApproveSubmission) return;
    const pending = pendingApproveSubmission;
    setApproveConfirmOpen(false);
    setPendingApproveSubmission(null);
    await onSubmit(pending.data, pending.shouldNavigate, true);
  };

  // Get selected contact (selectedCustomer already defined above for contacts loading)
  const selectedContact = contacts.find(c => c.id === selectedContactId);
  const persistedStatus = normalizeStatus((quoteData as any)?.status);
  const isStatusLocked = Boolean(quoteId && persistedStatus === 'approved');

  return (
    <div className="py-6 min-w-0 max-w-full">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground mb-1">
            {quoteId ? 'Edit Quote' : 'New Quote'}
          </h1>
          <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
            {quoteId ? 'Edit quote information' : 'Create a new quote'}
          </p>
        </div>

        <div className="flex items-center gap-3">
          {quoteId && (
            <button
              type="button"
              onClick={handlePreviewPDF}
              className="flex items-center gap-2 px-3 py-1.5 rounded border border-gray-300 bg-white text-gray-700 transition-colors text-sm hover:bg-gray-50"
              title="Abrir PDF en el navegador"
            >
              <Eye className="w-4 h-4" />
              PDF Dealer
            </button>
          )}
          {quoteId && quoteData?.status === 'draft' && (
            <button
              type="button"
              onClick={() => setDeleteConfirmOpen(true)}
              className="flex items-center gap-1.5 px-3 py-1.5 rounded border border-red-300 bg-white text-red-600 transition-colors text-sm hover:bg-red-50"
              title="Eliminar cotización"
            >
              <Trash2 className="w-3.5 h-3.5" />
              Delete
            </button>
          )}
          <button
            type="button"
            onClick={() => router.navigate('/sales/quotes')}
            className="px-3 py-1.5 rounded border border-gray-300 bg-white text-gray-700 transition-colors text-sm hover:bg-gray-50"
            title="Close"
          >
            Close
          </button>
          <button
            type="button"
            onClick={handleSubmit((data) => onSubmit(data, false))}
            disabled={isSaving || isCreating || isUpdating}
            className="btn-save px-3 py-1.5 rounded text-white transition-colors text-sm hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isSaving || isCreating || isUpdating ? 'Saving...' : 'Save'}
          </button>
          <button
            type="button"
            onClick={handleSubmit(handleSaveAndClose)}
            disabled={isSaving || isCreating || isUpdating}
            className="btn-save-close px-3 py-1.5 rounded text-white transition-colors text-sm hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isSaving || isCreating || isUpdating ? 'Saving...' : 'Save and Close'}
          </button>
          {quoteId && !dealerInfo && <CreateProposalButton quoteId={quoteId} />}
        </div>
      </div>

      {saveError && (
        <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded text-red-700 text-sm">
          {saveError}
        </div>
      )}

      {/* Quote Form */}
      <div className="bg-white border border-gray-200 rounded-lg mb-6">
        {/* Dealer Info Banner: DEALER name, Create Proposal (si quoteId), DEALER NO. a la derecha */}
        {dealerInfo && (
          <div className="bg-gray-50 border-b border-gray-200 px-6 py-4">
            <div className="flex items-center justify-between gap-4">
              <div className="flex items-center gap-2 text-sm">
                <span className="text-gray-500">Dealer:</span>
                <span className="font-semibold text-gray-900">{dealerInfo.name}</span>
                {dealerInfo.number && (
                  <>
                    <span className="text-gray-400" aria-hidden>|</span>
                    <span className="text-gray-500">Dealer No:</span>
                    <span className="font-semibold text-gray-900">{dealerInfo.number}</span>
                  </>
                )}
              </div>
              {quoteId && (
                <div className="flex-shrink-0">
                  <CreateProposalButton quoteId={quoteId} />
                </div>
              )}
            </div>
          </div>
        )}

        {/* Form Fields */}
        <div className="p-6">
          <div className="grid grid-cols-12 gap-4">
            {/* Quote Number | Status | Currency — same row */}
            <div className="col-span-12 md:col-span-6">
              <Label htmlFor="quote_no">Quote Number *</Label>
              <Input
                id="quote_no"
                {...register('quote_no')}
                error={errors.quote_no?.message}
              />
            </div>

            {/* Status */}
            <div className="col-span-12 md:col-span-3">
              <Label htmlFor="status">Status *</Label>
            <SelectShadcn
              value={watch('status') || 'draft'}
              disabled={isStatusLocked}
              onValueChange={(value) => {
                if (isStatusLocked) return;
                const validStatus = value as 'draft' | 'approved' | 'canceled';
                setValue('status', validStatus);
              }}
            >
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {QUOTE_STATUS_OPTIONS.map((option) => (
                  <SelectItem key={option.value} value={option.value}>
                    {option.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </SelectShadcn>
            {isStatusLocked && (
              <p className="mt-1 text-xs text-gray-500">
                Status is locked because this quote is approved.
              </p>
            )}
            </div>

            {/* Currency */}
            <div className="col-span-12 md:col-span-3">
              <Label htmlFor="currency">Currency *</Label>
            <SelectShadcn
              value={watch('currency') || 'USD'}
              onValueChange={(value) => setValue('currency', value)}
            >
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {CURRENCY_OPTIONS.map((option) => (
                  <SelectItem key={option.value} value={option.value}>
                    {option.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </SelectShadcn>
            </div>

            {/* Customer (optional) | Contact (optional) — side by side below */}
            <div className="col-span-12 md:col-span-6">
              <Label htmlFor="customer_id">Customer (optional)</Label>
            <SelectShadcn
              value={watch('customer_id') || 'none'}
              onValueChange={(value) => {
                setValue('customer_id', value === 'none' ? '' : value);
                setSelectedContactId(''); // Reset contact when customer changes
              }}
            >
              <SelectTrigger>
                <SelectValue placeholder="Select customer (optional)" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="none">None</SelectItem>
                {customers.map((customer) => (
                  <SelectItem key={customer.id} value={customer.id}>
                    {customer.customer_name}
                  </SelectItem>
                ))}
              </SelectContent>
            </SelectShadcn>
              {errors.customer_id && (
                <p className="text-red-600 text-xs mt-1">{errors.customer_id.message}</p>
              )}
            </div>

            {/* Contact (optional) */}
            <div className="col-span-12 md:col-span-6">
              <Label htmlFor="contact_id">Contact (optional)</Label>
            <SelectShadcn
              value={selectedContactId || 'none'}
              onValueChange={(value) => setSelectedContactId(value === 'none' ? '' : value)}
              disabled={!effectiveCustomerIdForContacts}
            >
              <SelectTrigger>
                <SelectValue placeholder="Select contact (optional)" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="none">None</SelectItem>
                {contacts.map((contact) => (
                  <SelectItem key={contact.id} value={contact.id}>
                    {contact.contact_name}
                  </SelectItem>
                ))}
              </SelectContent>
            </SelectShadcn>
            </div>

            {/* Description — aligned with Customer (left column), same height as Contact */}
            <div className="col-span-12 md:col-span-6">
              <Label htmlFor="description">Description</Label>
              <textarea
                id="description"
                {...register('description')}
                rows={1}
                className="w-full h-9 min-h-9 resize-none px-2.5 py-1.5 border border-gray-200 rounded text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
                placeholder="Quote description or comments..."
              />
            </div>

            {/* PO: Dealer PO / order tracking number — between Description and Notas */}
            <div className="col-span-12 md:col-span-6">
              <Label htmlFor="po_number">PO</Label>
              <Input
                id="po_number"
                {...register('po_number')}
                placeholder="Dealer PO / order number (optional)"
              />
            </div>

            {/* Notas — aligned with Customer, bottom aligned with Created by (same row as Summary) */}
            <div className="col-span-12 md:col-span-6 flex flex-col gap-1 min-h-0">
              <Label htmlFor="notes">Notas</Label>
              <textarea
                id="notes"
                {...register('notes')}
                className="flex-1 min-h-[8rem] w-full px-3 py-2 border border-gray-200 rounded text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50 resize-y"
                placeholder="Notas adicionales..."
              />
            </div>

            {/* Summary + Created by — lado derecho del Head Form */}
            {quoteId && (
              <div className="col-span-12 md:col-span-4 md:col-start-9 md:row-span-1">
                <div className="w-full max-w-xs ml-auto">
                  <div className="flex items-center gap-2 pb-3 mb-3 border-b border-gray-100">
                    <input
                      type="checkbox"
                      {...register('exempt_tax')}
                      className="rounded border-gray-300"
                    />
                    <Label className="text-sm text-gray-700 cursor-pointer">Exempt Tax</Label>
                  </div>
                  <div className="space-y-2">
                    <div className="flex justify-between text-sm">
                      <span className="text-gray-600">Subtotal:</span>
                      <span className="font-medium">{formatCurrency(totals.subtotal, watch('currency'))}</span>
                    </div>
                    {!exemptTax && (
                      <div className="flex justify-between text-sm">
                        <span className="text-gray-600">Tax{taxPct > 0 ? ` (${Math.round(taxPct * 100)}%)` : ''}:</span>
                        <span className="font-medium">{formatCurrency(totals.tax, watch('currency'))}</span>
                      </div>
                    )}
                    <div className="flex justify-between text-lg font-semibold border-t border-gray-200 pt-2">
                      <span>Total:</span>
                      <span>{formatCurrency(totals.total, watch('currency'))}</span>
                    </div>
                    {quoteLines.length > 0 && (quoteLines[0] as { quote_created_by?: string })?.quote_created_by && (
                      <div className="text-sm text-gray-500 pt-1 border-t border-gray-100">
                        Created by: {(quoteLines[0] as { quote_created_by?: string }).quote_created_by}
                      </div>
                    )}
                  </div>
                </div>
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Quote Lines Section */}
      {quoteId && (
        <div className="bg-white border border-gray-200 rounded-lg overflow-hidden mb-4 min-w-0">
          <div className="py-4 px-6 border-b border-gray-200">
            <div className="flex items-center justify-between">
              <div>
                <h2 className="text-xl font-semibold text-gray-900">Quote Lines</h2>
                <p className="text-sm text-gray-500 mt-1">{quoteLines.length} {quoteLines.length === 1 ? 'line' : 'lines'}</p>
              </div>
              <div className="flex items-center gap-2">
                <button
                  type="button"
                  onClick={() => {
                    setEditingLineId(null);
                    setInitialLineConfig(undefined);
                    setShowConfigurator(true);
                  }}
                  className="flex items-center gap-2 px-4 py-2 bg-primary text-white rounded-lg hover:bg-primary/90 transition-colors text-sm font-medium"
                >
                  <Plus className="w-4 h-4" />
                  Add Line
                </button>
              </div>
            </div>
          </div>

          {loadingLines ? (
            <div className="p-6 text-center text-gray-500">Loading lines...</div>
          ) : errorLines ? (
            <div className="p-6 text-center">
              <p className="text-red-600 mb-2">Error loading lines.</p>
              <p className="text-sm text-gray-500 mb-3">{errorLines}</p>
              <button type="button" onClick={() => refetchLines()} className="text-sm font-medium text-primary hover:underline">
                Retry
              </button>
            </div>
          ) : quoteLines.length === 0 ? (
            <div className="p-6 text-center text-gray-500">No lines added yet. Click "Add Line" to get started.</div>
          ) : (
            <div className="table-fit-wrapper quote-lines-table-wrapper">
              <table className="table-fit w-full quote-lines-table">
                <thead className="bg-gray-50 border-b border-gray-200">
                  <tr>
                    <th className="text-left py-3 px-2 font-medium text-gray-700 text-xs w-10 whitespace-nowrap" style={{ width: '2%' }} title="Drag to reorder"> </th>
                    <th className="text-center py-3 px-2 font-medium text-gray-700 text-xs whitespace-nowrap w-[57px] min-w-[57px] h-[57px] min-h-[57px] align-middle">#</th>
                    <th className="text-left py-3 px-4 font-medium text-gray-700 text-xs whitespace-nowrap" style={{ width: '8%' }}>Area</th>
                    <th className="text-center py-3 px-4 font-medium text-gray-700 text-xs whitespace-nowrap" style={{ width: '6%' }}>Position</th>
                    <th className="text-center py-3 px-4 font-medium text-gray-700 text-xs whitespace-nowrap min-w-[120px]" style={{ width: '10%' }}>Product type</th>
                    <th className="text-center py-3 px-4 font-medium text-gray-700 text-xs whitespace-nowrap" style={{ width: '20%' }}>Description</th>
                    <th className="text-left py-3 px-4 font-medium text-gray-700 text-xs whitespace-nowrap min-w-[100px]" style={{ width: '10%' }}>System Drive</th>
                    <th className="text-center py-3 px-4 font-medium text-gray-700 text-xs whitespace-nowrap min-w-[100px]" style={{ width: '10%' }}>Measurements</th>
                    <th className="text-center py-3 px-4 font-medium text-gray-700 text-xs whitespace-nowrap" style={{ width: '5%' }}>Qty</th>
                    <th className="py-3 px-4 font-medium text-gray-700 text-xs text-center whitespace-nowrap" style={{ width: '8%' }}>{useDealerPrice ? 'Dealer price' : 'MSRP'}</th>
                    <th className="py-3 px-4 font-medium text-gray-700 text-xs text-center whitespace-nowrap" style={{ width: '8%' }}>Total</th>
                    <th className="text-right py-3 px-4 font-medium text-gray-700 text-xs whitespace-nowrap" style={{ width: '9%' }}>Action</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-200">
                  {quoteLines.map((line: any, index: number) => {
                    // Extract data from line
                    const area = line.area ?? null;
                    const position = line.position ?? null;

                    // Debug en DEV
                    if (import.meta.env.DEV && quoteLines.indexOf(line) === 0) {
                      console.log('[QuoteNew] Rendering line:', {
                        id: line.id,
                        area,
                        position,
                        ProductType: line.ProductType,
                        product_type_id: line.product_type_id,
                        collection_name: line.collection_name,
                        variant_name: line.variant_name,
                        drive_type: line.drive_type,
                        width_m: line.width_m,
                        height_m: line.height_m,
                        Accessories: line.Accessories,
                        quantity: line.quantity,
                        msrp: line.msrp,
                      });
                    }
                    
                    const productTypeName = line.ProductType?.name || line.product_type || 'N/A';
                    const collectionDisplay = line.collection_name && line.variant_name
                      ? `${line.collection_name} - ${line.variant_name}`
                      : line.collection_name || line.variant_name || 'N/A';
                    const driveType = line.drive_type;
                    const driveDisplay = driveType === 'motor' ? 'Motorized' : driveType === 'manual' ? 'Manual' : 'N/A';

                    const isDragging = draggedLineId === line.id;
                    const isDragOver = dragOverLineId === line.id;
                    return (
                      <tr
                        key={line.id}
                        draggable
                        onDragStart={(e) => handleDragStart(e, line.id)}
                        onDragOver={(e) => handleDragOver(e, line.id)}
                        onDragLeave={handleDragLeave}
                        onDrop={(e) => handleDrop(e, line.id)}
                        className={`border-b border-gray-100 transition-colors ${
                          isDragging ? 'opacity-50 cursor-grabbing' : 'cursor-grab hover:bg-gray-50'
                        } ${isDragOver ? 'ring-1 ring-inset ring-gray-900' : ''}`}
                      >
                        <td className="py-4 px-2 text-gray-400 w-10" title="Drag to reorder" onClick={(e) => e.stopPropagation()}>
                          <GripVertical className="w-4 h-4" />
                        </td>
                        <td className="py-4 px-2 text-center text-gray-500 text-sm tabular-nums w-[57px] min-w-[57px] h-[57px] min-h-[57px] align-middle">
                          {index + 1}
                        </td>
                        <td className="py-4 px-4 text-gray-700 text-sm whitespace-nowrap text-left">
                          {area != null && String(area).trim() !== '' ? String(area).trim() : '—'}
                        </td>
                        <td className="py-4 px-4 text-gray-700 text-sm text-center whitespace-nowrap">
                          {position != null && String(position).trim() !== '' ? String(position).trim() : '—'}
                        </td>
                        <td className="py-4 px-6 text-gray-900 text-sm font-medium whitespace-nowrap text-center">
                          {productTypeName}
                        </td>
                        <td className="py-4 px-6 text-gray-700 text-sm min-w-0 overflow-hidden text-ellipsis text-center" title={collectionDisplay}>
                          <span className="block truncate">{collectionDisplay}</span>
                        </td>
                        <td className="py-4 px-6 text-gray-700 text-sm text-left whitespace-nowrap">
                          {driveDisplay}
                        </td>
                        <td className="py-4 px-6 text-gray-700 text-sm align-top text-center whitespace-nowrap min-w-[100px]">
                          <div className="w-fit mx-auto">
                            <DimensionsStackView
                              source={{
                                width_m: line.width_m,
                                height_m: line.height_m,
                                width_mm: (line.ConfiguredProduct?.config_snapshot as any)?.width_mm,
                                height_mm: (line.ConfiguredProduct?.config_snapshot as any)?.height_mm,
                                measurements: (line.ConfiguredProduct?.config_snapshot as any)?.measurements,
                                panels: (line.ConfiguredProduct?.config_snapshot as any)?.panels,
                              }}
                            />
                          </div>
                        </td>
                        <td className="py-4 px-6 text-center text-gray-900 text-sm tabular-nums whitespace-nowrap">
                          {/* ✅ FIX: Usar "quantity" (columna correcta en QuoteLines) */}
                          {line.quantity ? line.quantity.toFixed(0) : 'N/A'}
                        </td>
                        {/* Dealer price / MSRP: precio unitario estable (unit_msrp); no debe variar al cambiar solo qty */}
                        <td className="py-4 px-6 text-gray-900 text-sm font-medium tabular-nums whitespace-nowrap text-center">
                          {(() => {
                            const qty = Math.max(1, line.quantity ?? line.qty ?? 1);
                            const unitMsrp =
                              line.unit_msrp != null && Number(line.unit_msrp) >= 0
                                ? Number(line.unit_msrp)
                                : (line.msrp != null && qty > 0 ? Number(line.msrp) / qty : (line.roll_msrp_snapshot || 0) + (line.bom_msrp_snapshot || 0));
                            const unitPrice = useDealerPrice
                              ? unitMsrp * (1 - dealerDiscountPctForDisplay / 100)
                              : unitMsrp;
                            const rollMsrp = line.roll_msrp_snapshot || 0;
                            const bomMsrp = line.bom_msrp_snapshot || 0;
                            const hasDetails = rollMsrp > 0 || bomMsrp > 0;
                            return (
                              <div className="relative group w-full whitespace-nowrap text-center">
                                <span>{formatCurrency(unitPrice, watch('currency'))}</span>
                                {hasDetails && (
                                  <div className="absolute right-0 bottom-full mb-2 hidden group-hover:block z-10 bg-gray-900 text-white text-xs rounded px-2 py-1 whitespace-nowrap shadow-lg">
                                    <div className="text-left">
                                      <div>Roll/Fabric: {formatCurrency(rollMsrp, watch('currency'))}</div>
                                      <div>BOM Components: {formatCurrency(bomMsrp, watch('currency'))}</div>
                                      <div className="border-t border-gray-700 mt-1 pt-1">{useDealerPrice ? 'Dealer unit price (MSRP − tier)' : 'Unit MSRP (from backend)'}</div>
                                    </div>
                                  </div>
                                )}
                              </div>
                            );
                          })()}
                        </td>
                        {/* TOTAL column: siempre unit_price × qty para que sea consistente con el unitario */}
                        <td className="py-4 px-6 text-gray-900 text-sm font-medium tabular-nums whitespace-nowrap text-center">
                          {(() => {
                            const qty = Math.max(1, line.quantity ?? line.qty ?? 1);
                            const unitMsrp =
                              line.unit_msrp != null && Number(line.unit_msrp) >= 0
                                ? Number(line.unit_msrp)
                                : (line.msrp != null && qty > 0 ? Number(line.msrp) / qty : (line.roll_msrp_snapshot || 0) + (line.bom_msrp_snapshot || 0));
                            const lineTotal = useDealerPrice
                              ? unitMsrp * qty * (1 - dealerDiscountPctForDisplay / 100)
                              : unitMsrp * qty;
                            const rollMsrp = line.roll_msrp_snapshot || 0;
                            const bomMsrp = line.bom_msrp_snapshot || 0;
                            const hasDetails = rollMsrp > 0 || bomMsrp > 0;
                            return (
                              <div className="relative group w-full whitespace-nowrap text-center">
                                <span className="font-semibold">{formatCurrency(lineTotal, watch('currency'))}</span>
                                {hasDetails && (
                                  <div className="absolute right-0 bottom-full mb-2 hidden group-hover:block z-10 bg-gray-900 text-white text-xs rounded px-2 py-1 whitespace-nowrap shadow-lg">
                                    <div className="text-left">
                                      <div>Roll/Fabric: {formatCurrency(rollMsrp, watch('currency'))}</div>
                                      <div>BOM Components: {formatCurrency(bomMsrp, watch('currency'))}</div>
                                      <div className="border-t border-gray-700 mt-1 pt-1">{useDealerPrice ? `Dealer line total (qty=${qty})` : `Line total (qty=${qty})`}</div>
                                      <div>{formatCurrency(lineTotal, watch('currency'))}</div>
                                    </div>
                                  </div>
                                )}
                              </div>
                            );
                          })()}
                        </td>
                        <td className="py-4 px-6 whitespace-nowrap">
                          <div className="flex items-center gap-1 justify-end">
                            <button
                              type="button"
                              onClick={() => setPreviewLineId(line.id)}
                              className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600"
                              title="View configured product (customer view)"
                            >
                              <Eye className="w-4 h-4" />
                            </button>
                            <button
                              onClick={() => handleDuplicateLine(line.id)}
                              className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600"
                              title="Duplicar línea"
                            >
                              <Copy className="w-4 h-4" />
                            </button>
                            <button
                              onClick={() => handleEditLine(line.id)}
                              className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600"
                              title="Edit line"
                            >
                              <Edit className="w-4 h-4" />
                            </button>
                            <button
                              onClick={() => handleDeleteLine(line.id)}
                              className="p-1.5 hover:bg-gray-100 rounded transition-colors text-red-600"
                              title="Delete line"
                            >
                              <Trash2 className="w-4 h-4" />
                            </button>
                          </div>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}

      {/* Proposals for this Quote — organizar proposals dentro del quote */}
      {quoteId && (
        <div className="bg-white border border-gray-200 rounded-lg mb-6">
          <QuoteProposalsSection quoteId={quoteId} />
        </div>
      )}

      {/* Terms & Conditions (read-only, from Dealer template) */}
      {quoteId && (
        <div className="mb-6">
          <QuoteTermsDisplay
            orgId={activeOrganizationId}
            dealerId={quoteData?.dealer_id ?? dealerInfo?.id ?? null}
            termsTitle={quoteData?.terms_title ?? undefined}
            termsContent={quoteData?.terms_content ?? undefined}
          />
        </div>
      )}

      {/* Product Configurator Modal */}
      {showConfigurator && quoteId && (
        <div className="fixed inset-0 bg-black bg-opacity-50 z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-lg shadow-xl w-full max-w-6xl max-h-[90vh] overflow-hidden flex flex-col">
            <div className="flex items-center justify-between p-4 border-b">
              <h2 className="text-lg font-semibold">
                {editingLineId ? 'Edit Quote Line' : 'Add Quote Line'}
              </h2>
              <button
                onClick={() => {
                  setShowConfigurator(false);
                  setEditingLineId(null);
                  setInitialLineConfig(undefined);
                  clearConfiguratorDraft();
                }}
                className="p-1 hover:bg-gray-100 rounded transition-colors"
              >
                <X className="w-5 h-5" />
              </button>
            </div>
            <div className="flex-1 overflow-y-auto">
              <ProductConfigurator
                quoteId={quoteId}
                onComplete={handleProductConfigComplete}
                onClose={() => {
                  setShowConfigurator(false);
                  setEditingLineId(null);
                  setInitialLineConfig(undefined);
                  clearConfiguratorDraft();
                }}
                initialConfig={initialLineConfig}
              />
            </div>
          </div>
        </div>
      )}

      {/* Configured Product — Customer view (popup) */}
      {previewLineId && (() => {
        const line = quoteLines.find((l: any) => l.id === previewLineId) as any;
        if (!line) return null;
        const config = line.ConfiguredProduct?.config_snapshot || {};
        const productTypeName = line.ProductType?.name || line.product_type || config.productType || '—';
        const productTypeSlug = (productTypeName || '').toLowerCase().replace(/\s+/g, '-') || '—';
        const driveTypeRaw = line.drive_type ?? config.operatingSystem ?? config.drive_type;
        const driveDisplay = driveTypeRaw === 'motor' || driveTypeRaw === 'motorized' ? 'motorized' : driveTypeRaw === 'manual' ? 'manual' : driveTypeRaw || 'Not selected';
        const dimensionsSource = {
          width_m: line.width_m,
          height_m: line.height_m,
          width_mm: config.width_mm,
          height_mm: config.height_mm,
          measurements: config.measurements,
          panels: config.panels,
        };
        const accessoryCount = line.Accessories?.length ?? 0;
        const accessoriesLabel = accessoryCount === 0 ? '0 items' : `${accessoryCount} item${accessoryCount !== 1 ? 's' : ''}`;
        const hardwareColor = config.hardwareColor ?? config.hardware_color ?? null;
        const hardwareColorDisplay = hardwareColor ? String(hardwareColor).charAt(0).toUpperCase() + String(hardwareColor).slice(1) : 'Not selected';
        const hasCassette = config.headbox_item_id != null || config.cassette === true;
        const hasSideChannel = config.side_channel_item_id != null || config.side_channel === true;
        const mountingParts = [config.installationType ?? line.installation_type, config.installationLocation ?? line.installation_location].filter(Boolean);
        const mountingDisplay = mountingParts.length ? mountingParts.join(' / ') : 'Not selected';
        const qty = line.quantity ?? line.qty ?? 1;
        const unitPrice = line.unit_msrp != null ? Number(line.unit_msrp) : (line.msrp != null && qty > 0 ? Number(line.msrp) / qty : 0);
        const lineTotal = line.msrp != null ? Number(line.msrp) : unitPrice * qty;

        const spec = (label: string, value: string | number | React.ReactNode) => (
          <div key={label} className="flex justify-between gap-4 py-1 text-sm">
            <span className="text-gray-600 shrink-0">{label}</span>
            <span className="text-gray-900 text-right font-medium">{value}</span>
          </div>
        );
        const fabricM2 = (() => {
          const snap = (line.ConfiguredProduct as any)?.bom_preview_snapshot;
          const items = snap?.items;
          if (!Array.isArray(items)) return null;
          const roll = items.find((i: any) => i.kind === 'roll' || i.role === 'fabric');
          return roll?.qty != null ? Number(roll.qty) : null;
        })();

        return (
          <div className="fixed inset-0 bg-black bg-opacity-50 z-50 flex items-center justify-center p-4" onClick={() => setPreviewLineId(null)}>
            <div
              className="bg-white rounded-lg shadow-xl w-full max-w-lg overflow-hidden"
              onClick={(e) => e.stopPropagation()}
            >
              <div className="flex items-center justify-between p-4 border-b border-gray-200">
                <h2 className="text-lg font-semibold text-foreground">Configured Product</h2>
                <button
                  type="button"
                  onClick={() => setPreviewLineId(null)}
                  className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600"
                  aria-label="Close"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>
              <div className="p-6 space-y-6">
                {/* FABRIC TECHNICAL DATA */}
                <div>
                  <h3 className="text-xs font-bold text-gray-700 uppercase tracking-wider mb-3">Fabric technical data</h3>
                  <div className="flex flex-wrap items-baseline justify-between gap-x-4 gap-y-1 text-sm">
                    <div className="space-y-1">
                      <div><span className="text-gray-600">SKU:</span> <span className="text-gray-900 font-medium">{line.CatalogItems?.sku ?? line.sku ?? '—'}</span></div>
                      <div><span className="text-gray-600">Variant:</span> <span className="text-gray-900 font-medium">{line.variant_name ?? '—'}</span></div>
                    </div>
                    <div>
                      <span className="text-gray-600">Description:</span> <span className="text-gray-900 font-medium">{line.collection_name ?? '—'}</span>
                    </div>
                  </div>
                </div>

                {/* PRODUCT SPECIFICATIONS */}
                <div>
                  <h3 className="text-xs font-bold text-gray-700 uppercase tracking-wider mb-3">Product specifications</h3>
                  <div className="grid grid-cols-2 gap-x-8 gap-y-0 text-sm">
                    <div className="space-y-0">
                      {spec('Position', line.position != null && String(line.position).trim() !== '' ? String(line.position).trim() : 'Not selected')}
                      {spec('Mounting', mountingDisplay)}
                      {spec('Film Type', 'Not selected')}
                      {spec('Fixing', 'Not selected')}
                      {spec('Drive Type', driveDisplay)}
                      {spec('Side Channel', hasSideChannel ? 'Yes' : 'No')}
                    </div>
                    <div className="space-y-0">
                      {spec('Product Type', productTypeSlug)}
                      {spec('Dimensions', (
                        <span className="block pb-2 min-h-[1.5rem]">
                          <DimensionsStackView source={dimensionsSource} />
                        </span>
                      ))}
                      {fabricM2 != null && spec('Total tela', `${fabricM2.toFixed(2)} m²`)}
                      {spec('Accessories', accessoriesLabel)}
                      {spec('Hardware Color', hardwareColorDisplay)}
                      {spec('Cassette', hasCassette ? 'Yes' : 'No')}
                    </div>
                  </div>
                </div>

                <div className="border-t border-gray-200 pt-4 flex justify-between items-center">
                  <span className="text-sm text-gray-600">Qty {qty} × {formatCurrency(unitPrice, watch('currency'))}</span>
                  <span className="text-lg font-semibold text-gray-900">{formatCurrency(lineTotal, watch('currency'))}</span>
                </div>
              </div>
            </div>
          </div>
        );
      })()}
      <ConfirmDialog
        isOpen={approveConfirmOpen}
        onClose={handleCloseApproveConfirm}
        onConfirm={() => {
          void handleConfirmApprove();
        }}
        title="Approve quote"
        message="Approving this quote will lock status changes. Continue?"
        confirmText="Approve"
        cancelText="Cancel"
        variant="warning"
        isLoading={isSaving || isUpdating}
      />
      <ConfirmDialog
        isOpen={deleteConfirmOpen}
        onClose={() => setDeleteConfirmOpen(false)}
        onConfirm={handleDeleteDraftQuote}
        title="Eliminar Cotización"
        message={`¿Estás seguro de que deseas eliminar la cotización ${quoteData?.quote_no || ''}? Esta acción no se puede deshacer.`}
        confirmText="Eliminar"
        cancelText="Cancelar"
        variant="danger"
        isLoading={isDeleting}
      />
    </div>
  );
}

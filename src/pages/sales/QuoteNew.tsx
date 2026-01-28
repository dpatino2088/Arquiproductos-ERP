/**
 * QuoteNew - Create and Edit Quotes
 * Clean implementation from scratch
 */

import React, { useState, useEffect, useMemo } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { router } from '../../lib/router';
import { supabase } from '../../lib/supabase/client';
import { useUIStore } from '../../stores/ui-store';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useAccessContext } from '../../hooks/useAccessContext';
import { useCreateQuote, useUpdateQuote, useQuoteLines, approveQuote, normalizeStatus } from '../../hooks/useQuotes';
import { QuoteStatus } from '../../types/catalog';
import { Plus, Edit, Trash2, X, Download } from 'lucide-react';
import ProductConfigurator from './ProductConfigurator';
import { ProductConfig } from './product-config/types';
import { normalizeConfiguratorConfig } from './product-config/config-contract';
import Input from '../../components/ui/Input';
import Label from '../../components/ui/Label';
import { Select as SelectShadcn, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../../components/ui/SelectShadcn';
import { generateQuotePDF } from '../../lib/pdf/generateQuotePDF';
import { useCostSettings } from '../../hooks/useCosts';
import { calculateQuoteLinePrice } from '../../lib/pricing';
import { createQuoteLineFromConfiguredProduct } from '../../lib/quotes/createQuoteLineFromConfiguredProduct';

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

// ====================================================
// UTILS: BOM Pricing Calculation (C)
// ====================================================
async function priceFromBOMInstance(opts: {
  supabase: any;
  bomInstanceId: string;
  organizationId: string;
}) {
  const { supabase, bomInstanceId } = opts;

  // 1) Trae líneas del BOM
  const { data: bomLines, error: linesErr } = await supabase
    .from("BOMInstanceLines")
    .select("id, resolved_part_id, qty, part_role")
    .eq("bom_instance_id", bomInstanceId)
    .eq("deleted", false);

  if (linesErr) {
    // ✅ FIX: Convertir error de Supabase a Error simple para evitar [circular]
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
      .select("catalog_item_id, msrp_sale_out, msrp_sale_in, cost_exw")
      .in("catalog_item_id", partIds);

    if (msrpErr) {
      // ✅ FIX: Convertir error de Supabase a Error simple para evitar [circular]
      const errorDetails = safeErr(msrpErr);
      throw new Error(errorDetails.message || 'Failed to fetch MSRP data');
    }

    (msrpRows ?? []).forEach((r: any) => {
      msrpMap.set(r.catalog_item_id, Number(r.msrp_sale_out ?? 0));
      msrpDetails.push({
        catalog_item_id: r.catalog_item_id,
        msrp_sale_out: r.msrp_sale_out,
        source: 'CatalogItemsMSRP', // ✅ TABLA DE PRECIOS
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
      msrpSource: msrpMap.has(partId) ? 'CatalogItemsMSRP.msrp_sale_out' : 'MISSING',
    });
  }

  if (import.meta.env.DEV) {
    console.group('💰 DEBUG: BOM Pricing Breakdown');
    console.log('📊 BOM Instance ID:', bomInstanceId);
    console.log('📦 Total Lines:', lines.length);
    console.log('❌ Missing Parts (sin resolved_part_id):', missing.length);
    console.log('✅ Priced Items:', pricedCount);
    console.log('📋 Pricing Breakdown:', pricingBreakdown);
    console.log('💵 Total MSRP (CatalogItemsMSRP.msrp_sale_out):', total);
    console.log('💵 Total Cost (CatalogItems.cost_exw):', totalCost);
    console.log('📊 MSRP Details:', msrpDetails);
    console.log('📊 MSRP Source Table: CatalogItemsMSRP');
    console.log('📊 MSRP Source Column: msrp_sale_out');
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
  { value: 'sent', label: 'Sent' },
  { value: 'approved', label: 'Approved' },
  { value: 'rejected', label: 'Rejected' },
] as const;

// Currency options
const CURRENCY_OPTIONS = [
  { value: 'USD', label: 'USD - US Dollar' },
  { value: 'EUR', label: 'EUR - Euro' },
  { value: 'GBP', label: 'GBP - British Pound' },
  { value: 'MXN', label: 'MXN - Mexican Peso' },
  { value: 'CAD', label: 'CAD - Canadian Dollar' },
] as const;

// Schema for Quote - customer_id is now optional
const quoteSchema = z.object({
  quote_no: z.string().min(1, 'Quote number is required'),
  customer_id: z.string().uuid('Invalid customer ID').optional().or(z.literal('')),
  status: z.enum(['draft', 'sent', 'approved', 'rejected']),
  currency: z.string().min(1, 'Currency is required'),
  notes: z.string().optional(),
});

type QuoteFormValues = z.infer<typeof quoteSchema>;

interface Customer {
  id: string;
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

export default function QuoteNew() {
  const { activeOrganizationId } = useOrganizationContext();
  const { userType, isPortal } = useAccessContext();
  const { createQuote, isCreating } = useCreateQuote();
  const { updateQuote, isUpdating } = useUpdateQuote();
  const [quoteId, setQuoteId] = useState<string | null>(null);
  const [quoteData, setQuoteData] = useState<any>(null);
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [contacts, setContacts] = useState<Contact[]>([]);
  const [selectedContactId, setSelectedContactId] = useState<string>('');
  const [showConfigurator, setShowConfigurator] = useState(false);
  const [editingLineId, setEditingLineId] = useState<string | null>(null);
  const [isSaving, setIsSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [initialLineConfig, setInitialLineConfig] = useState<ProductConfig | undefined>(undefined);
  const [companyInfo, setCompanyInfo] = useState<{ id: string; name: string; number: string | null } | null>(null);
  const configuratorDraftKey = quoteId ? `productConfiguratorDraft:${quoteId}` : null;

  const { lines: quoteLines, loading: loadingLines, refetch: refetchLines } = useQuoteLines(quoteId);
  const { settings: costSettings } = useCostSettings(); // Get cost settings for pricing calculations

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
      notes: '',
    },
  });

  // Check URL for quote_id (edit mode) or line_id (edit line mode)
  useEffect(() => {
    const path = window.location.pathname;
    const urlMatch = path.match(/\/sales\/quotes\/edit\/([^/]+)/);
    const editQuoteId = urlMatch ? urlMatch[1] : null;

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
          const status = data.status as QuoteStatus;
          setValue('status', (status === 'cancelled' ? 'draft' : status) || 'draft');
          setValue('currency', 'USD'); // Default for UI formatting (not stored in DB)
          setValue('notes', ''); // Not stored in DB - only for UI
          // Load contact_id if it exists (contact_id DOES exist in Quotes table)
          if (data.contact_id) {
            setSelectedContactId(data.contact_id);
          }
          
          // Load company info from quote.company_id if available
          if (data.company_id) {
            const { data: company, error: companyError } = await supabase
              .from('Companies')
              .select('id, company_name, company_no')
              .eq('id', data.company_id)
              .eq('organization_id', activeOrganizationId)
              .eq('deleted', false)
              .maybeSingle();

            if (!companyError && company) {
              setCompanyInfo({
                id: company.id,
                name: company.company_name || 'Unknown Company',
                number: company.company_no || null,
              });
            }
          }
        }
      } catch (err) {
        console.error('Error loading quote:', err);
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'Error',
          message: 'Failed to load quote data',
        });
      }
    };

    loadQuoteData();
  }, [quoteId, activeOrganizationId, setValue]);

  // Load company info (for ALL users: portal and internal)
  // Only load if not already loaded by loadQuoteData (edit mode)
  useEffect(() => {
    const loadCompanyInfo = async () => {
      // Skip if already loaded (e.g., from edit mode loadQuoteData)
      if (companyInfo) return;
      
      if (!activeOrganizationId) {
        setCompanyInfo(null);
        return;
      }

      try {
        if (isPortal) {
          // Portal user: get their assigned company
          const { data: { user } } = await supabase.auth.getUser();
          if (!user) return;

          const { data: portalUser, error: portalError } = await supabase
            .from('CompanyPortalUsers')
            .select('company_id')
            .eq('user_id', user.id)
            .eq('deleted', false)
            .in('status', ['active', 'invited'])
            .maybeSingle();

          if (portalError) {
            console.error('Error loading portal user company:', portalError);
            return;
          }

          if (portalUser?.company_id) {
            // Fetch full company details
            const { data: company, error: companyError } = await supabase
              .from('Companies')
              .select('id, company_name, company_no')
              .eq('id', portalUser.company_id)
              .eq('organization_id', activeOrganizationId)
              .eq('deleted', false)
              .maybeSingle();

            if (companyError) {
              console.error('Error loading company:', companyError);
              return;
            }

            if (company) {
              setCompanyInfo({
                id: company.id,
                name: company.company_name || 'Unknown Company',
                number: company.company_no || null,
              });
            }
          }
        } else {
          // Internal user: get first active company from organization
          const { data: companies, error: companiesError } = await supabase
            .from('Companies')
            .select('id, company_name, company_no')
            .eq('organization_id', activeOrganizationId)
            .eq('deleted', false)
            .eq('status', 'active')
            .order('created_at', { ascending: true })
            .limit(1);

          if (companiesError) {
            console.error('Error loading companies:', companiesError);
            return;
          }

          if (companies && companies.length > 0) {
            const firstCompany = companies[0];
            setCompanyInfo({
              id: firstCompany.id,
              name: firstCompany.company_name || 'Unknown Company',
              number: firstCompany.company_no || null,
            });
          }
        }
      } catch (err) {
        console.error('Error loading company info:', err);
      }
    };

    loadCompanyInfo();
  }, [isPortal, activeOrganizationId, companyInfo]);

  // Load customers
  useEffect(() => {
    const loadCustomers = async () => {
      if (!activeOrganizationId) return;

      try {
        const { data, error } = await supabase
          .from('DirectoryCustomers')
          .select('id, customer_name, customer_type_name, primary_contact_id')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .order('customer_name');

        if (error) throw error;
        if (data) setCustomers(data);
      } catch (err) {
        console.error('Error loading customers:', err);
      }
    };

    loadCustomers();
  }, [activeOrganizationId]);

  // Load contacts for selected customer
  const selectedCustomerId = watch('customer_id');
  useEffect(() => {
    const loadContacts = async () => {
      if (!selectedCustomerId || !activeOrganizationId) {
        setContacts([]);
        return;
      }

      try {
        const { data, error } = await supabase
          .from('DirectoryContacts')
          .select('id, contact_name, email, primary_phone, customer_id')
          .eq('customer_id', selectedCustomerId)
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .order('contact_name');

        if (error) throw error;
        if (data) setContacts(data);
      } catch (err) {
        console.error('Error loading contacts:', err);
      }
    };

    loadContacts();
  }, [selectedCustomerId, activeOrganizationId]);

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
      
      // Check if quote_no already has a value (from form state)
      const currentQuoteNo = watch('quote_no');
      if (currentQuoteNo && currentQuoteNo.trim() !== '') {
        return; // Already has a value, don't overwrite
      }

      try {
        // Use the utility function to generate next sequential number
        const { generateNextQuoteNumber } = await import('../../lib/sequential-numbers');
        const quoteNo = await generateNextQuoteNumber(activeOrganizationId);
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
  }, [activeOrganizationId, quoteId, setValue, watch, quoteData]);

  // Calculate totals from List Price (MSRP End User) × Quantity
  // This shows the total MSRP value, not the net distributor price
  // Use the same qty that is displayed in the QTY column (line.qty, not computed_qty)
  // Calculate totals from MSRP (precio final de venta al público) × Quantity
  // ✅ FIX: QuoteLines NO tiene "list_unit_price_snapshot" ni "unit_price_snapshot"
  // ✅ Usar "msrp" (precio final de venta al público desde CatalogItemsMSRP.msrp_sale_out)
  // ✅ Usar "quantity" (columna correcta en QuoteLines)
  const totals = useMemo(() => {
    const subtotal = quoteLines.reduce((sum, line) => {
      // ✅ msrp = precio final de venta al público TOTAL (ya incluye cantidad calculada en el BOM)
      const msrpPrice = line.msrp || 0;
      // ✅ quantity = cantidad de unidades de la línea
      const qty = line.quantity || 1;
      // ✅ Total = MSRP total de la línea (ya calculado, incluye cantidad de BOM)
      return sum + (msrpPrice * qty);
    }, 0);
    const tax = 0; // TODO: Calculate tax if needed
    const total = subtotal + tax;

    return { subtotal, tax, total };
  }, [quoteLines]);

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
      
      // ✅ REQUERIR ConfiguredProduct - NO hay flujo legacy
      const configuredProductId = (productConfig as any).configured_product_id;
      const configuredProductTotalsFromConfig = (productConfig as any).configured_product_totals;
      
      if (!configuredProductId) {
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'Configuration Error',
          message: 'ConfiguredProduct is required. Please complete the product configuration first.',
        });
        return;
      }

      // ✅ GUARDRAIL: No consultar ProductTypes sin organizationId
      if (!activeOrganizationId) {
        console.error("❌ Missing organizationId; cannot resolve ProductTypes.");
        useUIStore.getState().addNotification({
          type: "error",
          title: "Org not loaded",
          message: "No organizationId in session/profile. Fix auth profile.",
        });
        return;
      }

      // ✅ OBTENER ConfiguredProduct desde DB - REQUERIDO
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

      // Extract data from ConfiguredProduct
      const area = productConfig.area || null;
      const position = productConfig.position || null;
      const width_m = (configuredProductData.width_mm ? configuredProductData.width_mm / 1000 : null) || (productConfig as any).width_m || null;
      const height_m = (configuredProductData.height_mm ? configuredProductData.height_mm / 1000 : null) || (productConfig as any).height_m || null;
      const quantity = configuredProductData.quantity || productConfig.quantity || 1;

      // ✅ Obtener roll_catalog_item_id desde ConfiguredProduct
      const rollItemId: string | null = configuredProductData.roll_catalog_item_id || null;
      
      if (import.meta.env.DEV) {
        console.log('[QuoteNew] Loaded ConfiguredProduct data:', {
          configured_product_id: configuredProductId,
          roll_catalog_item_id: rollItemId,
          roll_collection_name: configuredProductData.roll_collection_name,
          roll_variant_name: configuredProductData.roll_variant_name,
        });
      }

      // Obtener CatalogItem y MSRP si hay roll
      let catalogItem: any = null;
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
          .select('msrp_sale_out')
          .eq('catalog_item_id', rollItemId)
          .or(`organization_id.eq.${activeOrganizationId},organization_id.is.null`)
          .maybeSingle();
        
        msrpSaleOut = msrpCache?.msrp_sale_out || null;
      }

      // Get product type ID - CRITICAL: Always try to find product_type_id
      // ✅ (A) Usar función robusta de resolución con normalización y fallbacks
      const productTypeId = productConfig.productType
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
      if (rollItemId && catalogItem && (!msrpSaleOut || msrpSaleOut === 0)) {
        useUIStore.getState().addNotification({
          type: 'warning',
          title: 'MSRP Missing',
          message: `Roll ${catalogItem.sku || rollItemId} has no MSRP. Pricing will be calculated from BOM components only.`,
        });
      }

      // ✅ Usar datos del ConfiguredProduct (prioridad) o catalogItem
      const collectionName = configuredProductData.roll_collection_name || catalogItem?.collection_name || null;
      const variantName = configuredProductData.roll_variant_name || catalogItem?.variant_name || null;

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

      // Get customer type for pricing tier (from quote's customer)
      const quoteCustomerId = quoteData?.customer_id || watch('customer_id');
      const quoteCustomer = customers.find(c => c.id === quoteCustomerId);
      const customerType = quoteCustomer?.customer_type_name || 'VIP'; // Default to VIP if not set
      
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

        // Calculate net price for distributor (with tier discounts + margin floor)
        // Si no hay roll, esto devuelve 0
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
        customerType,
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
      const normalized = normalizeConfiguratorConfig(productConfig);
      
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
      const allowedQuoteLineFields = new Set([
        'quote_id',
        'catalog_item_id',
        'quantity',
        'width_m',
        'height_m',
        'sqm',
        'collection_name',
        'variant_name',
        'bom_template_id', // ✅ CRITICAL: Permitir bom_template_id para crear BOMInstances
        'msrp',
        'net_price',
        'cost_exw',
        'total_cost',
        'discount_pct',
        'applied_margin_pct',
        'default_margin_pct',
      ]);
      const sanitizedQuoteLineData = Object.fromEntries(
        Object.entries(quoteLineData).filter(([key]) => allowedQuoteLineFields.has(key))
      );

      let finalLineId = editingLineId;

      // ✅ NUEVO: Si hay configured_product_id y NO está editando, usar servicio con snapshots
      // Nota: configuredProductId ya está declarado arriba (línea 787)
      const shouldUseSnapshotService = configuredProductId && !editingLineId;

      if (shouldUseSnapshotService) {
        // Usar servicio que crea QuoteLine con snapshots completos desde ConfiguredProduct
        try {
          const discountPct = pricingResult.discountPct || 0;
          
          // ✅ CRITICAL: Obtener bom_template_id del config
          const bomTemplateId = normalized.quoteLine.bom_template_id || (productConfig as any).bom_template_id || null;
          
          if (import.meta.env.DEV) {
            console.debug('[QuoteNew] Creating QuoteLine with bom_template_id', {
              quoteId: quoteId,
              configuredProductId,
              bomTemplateId,
              organizationId: activeOrganizationId,
            });
          }
          
          // ✅ GUARDRAIL: Validar que tenemos quote_line_id (se creará en el servicio)
          if (!quoteId) {
            throw new Error('quoteId is required to create QuoteLine');
          }
          
          const result = await createQuoteLineFromConfiguredProduct({
            organizationId: activeOrganizationId,
            quoteId: quoteId!,
            configuredProductId: configuredProductId,
            quantity: quantity,
            discountPct: discountPct,
            bom_template_id: bomTemplateId, // ✅ CRITICAL: Pasar bom_template_id
            // Campos adicionales del QuoteLine
            catalog_item_id: rollItemId || null,
            collection_name: catalogItem?.collection_name || null,
            variant_name: catalogItem?.variant_name || null,
            area: productConfig.area || null,
            position: productConfig.position || null,
            hardware_color: (productConfig as any).hardware_color || null,
            cassette: (productConfig as any).cassette || false,
            side_channel: (productConfig as any).side_channel || false,
            drive_type: (productConfig as any).operation_type || (productConfig as any).drive_type || null,
            product_type: productConfig.productType || null,
            // Metadata
            ...(Object.keys(quoteLineMetadata).length > 0 ? { metadata: quoteLineMetadata } : {}),
          });

          finalLineId = result.quoteLineId;

          useUIStore.getState().addNotification({
            type: 'success',
            title: 'Success',
            message: `Quote line added with snapshots: MSRP $${result.msrp.toFixed(2)}, Cost $${result.totalCost.toFixed(2)}`,
          });

          if (import.meta.env.DEV) {
            console.log('[QuoteNew] QuoteLine created with snapshots:', {
              quoteLineId: finalLineId,
              rollMsrpSnapshot: result.rollMsrpSnapshot,
              bomMsrpSnapshot: result.bomMsrpSnapshot,
              rollCostSnapshot: result.rollCostSnapshot,
              bomCostSnapshot: result.bomCostSnapshot,
              msrp: result.msrp,
              totalCost: result.totalCost,
              netPrice: result.netPrice,
            });
          }

          // ✅ IMPORTANTE: El servicio ya creó el BOMInstance y calculó precios
          // NO continuar con el flujo de generación de BOM manual
          // Refrescar líneas y retornar
          refetchLines();
          return;
        } catch (snapshotError: any) {
          console.error('[QuoteNew] Error creating QuoteLine with snapshots:', snapshotError);
          useUIStore.getState().addNotification({
            type: 'error',
            title: 'Error',
            message: snapshotError.message || 'Failed to create quote line with snapshots',
          });
          return;
        }
      } else if (editingLineId) {
        // Update existing line
        const { error: updateError } = await supabase
          .from('QuoteLines')
          .update(sanitizedQuoteLineData)
          .eq('id', editingLineId)
          .eq('organization_id', activeOrganizationId);

        if (updateError) throw updateError;

        useUIStore.getState().addNotification({
          type: 'success',
          title: 'Success',
          message: 'Quote line updated successfully',
        });
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
            // Update QuoteLine metadata with roll rotation/heatseal if provided
            const rollRotation = (productConfig as any).roll_rotation || (productConfig as any).fabric_rotation || false;
            const rollHeatseal = (productConfig as any).roll_heatseal || (productConfig as any).fabric_heatseal || false;
            
            if (rollRotation || rollHeatseal) {
              await supabase
                .from('QuoteLines')
                .update({
                  metadata: {
                    roll_rotation: rollRotation,
                    roll_heatseal: rollHeatseal,
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
      // SAVE CONFIGURATION OPTIONS TO QuoteLineComponents
      // ============================================
      if (finalLineId) {
        try {
          // STEP 1: Soft-delete previous options (when editing)
          // Only delete 'option' kind, preserve accessories
          const { error: deleteOptionsError } = await supabase
            .from('QuoteLineComponents')
            .update({ deleted: true })
            .eq('quote_line_id', finalLineId)
            .eq('organization_id', activeOrganizationId)
            .eq('kind', 'option');

          if (deleteOptionsError && import.meta.env.DEV) {
            console.warn('Failed to delete old options:', deleteOptionsError);
          }

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

          // STEP 3: Insert configuration options
          if (configOptions.length > 0) {
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
          if (fabricItemId) {
            skuSelections.push({
              organization_id: activeOrganizationId,
              quote_line_id: finalLineId,
              kind: 'selection',
              component_role: 'fabric',
              catalog_item_id: rollItemId,
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
            const { error: selectionsError } = await supabase
              .from('QuoteLineComponents')
              .insert(skuSelections);

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
              
              // 2. Obtener hardware_color
              const { data: hardwareColorData } = await supabase
                .from('QuoteLineComponents')
                .select('payload')
                .eq('quote_line_id', finalLineId)
                .eq('component_role', 'hardware_color')
                .eq('kind', 'option')
                .eq('deleted', false)
                .maybeSingle();
              
              const hardwareColor = hardwareColorData?.payload?.hardware_color || null;
              console.log('🎨 Hardware Color:', hardwareColor);
              
              // 3. Obtener selecciones SKU del usuario
              const { data: userSelections } = await supabase
                .from('QuoteLineComponents')
                .select('component_role, catalog_item_id')
                .eq('quote_line_id', finalLineId)
                .eq('kind', 'selection')
                .eq('deleted', false);
              
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

                // 2. Obtener Fabric desde QuoteLineComponents (kind='selection', component_role='fabric')
                const { data: fabricComponent } = await supabase
                  .from('QuoteLineComponents')
                  .select('catalog_item_id')
                  .eq('quote_line_id', finalLineId)
                  .eq('organization_id', activeOrganizationId)
                  .eq('kind', 'selection')
                  .eq('component_role', 'fabric')
                  .eq('deleted', false)
                  .maybeSingle();

                const savedFabricItemId = fabricComponent?.catalog_item_id || null;

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
                      .select('msrp_sale_out')
                      .eq('catalog_item_id', savedFabricItemId)
                      .or(`organization_id.eq.${activeOrganizationId},organization_id.is.null`)
                      .maybeSingle();
                    
                    savedMsrpSaleOut = msrpCache?.msrp_sale_out || null;
                  }
                }

                // 4. Obtener Accessories desde QuoteLineComponents
                const { data: accessoriesData } = await supabase
                  .from('QuoteLineComponents')
                  .select('catalog_item_id, qty, unit_cost_exw')
                  .eq('quote_line_id', finalLineId)
                  .eq('organization_id', activeOrganizationId)
                  .eq('deleted', false)
                  .or('source.eq.accessory,component_role.eq.accessory');

                const accessories = accessoriesData || [];
                const accessoryIds = accessories
                  .map((acc: any) => acc.catalog_item_id)
                  .filter(Boolean) as string[];

                // 5. Obtener MSRP de Accessories
                let accessoriesMsrpTotal = 0;
                if (accessoryIds.length > 0) {
                  const { data: accessoriesMsrp } = await supabase
                    .from('CatalogItemsMSRP')
                    .select('catalog_item_id, msrp_sale_out')
                    .in('catalog_item_id', accessoryIds)
                    .or(`organization_id.eq.${activeOrganizationId},organization_id.is.null`);

                  const msrpMap = new Map<string, number>();
                  (accessoriesMsrp || []).forEach((r: any) => {
                    msrpMap.set(r.catalog_item_id, Number(r.msrp_sale_out ?? 0));
                  });

                  accessories.forEach((acc: any) => {
                    const accMsrp = msrpMap.get(acc.catalog_item_id) || 0;
                    const accQty = acc.qty || 1;
                    accessoriesMsrpTotal += accMsrp * accQty;
                  });
                }

                // ✅ FABRIC PRICE: Fabric MSRP sale_out (W del Roll total × H) × quantity
                // Fórmula: width_m × height_m × CatalogItemsMSRP.msrp_sale_out × quantity
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
                    source: 'CatalogItemsMSRP.msrp_sale_out',
                    table: 'CatalogItemsMSRP',
                    column: 'msrp_sale_out',
                  });
                }
                
                let fabricMsrpTotal = 0;
                if (savedFabricItemId && savedCatalogItem && savedMsrpSaleOut && savedWidth_m && savedHeight_m) {
                  // ✅ Fabric MSRP sale_out (W del Roll total × H) × quantity
                  // width_m = ancho del rollo total, height_m = altura del producto
                  fabricMsrpTotal = savedWidth_m * savedHeight_m * savedMsrpSaleOut * savedQuantity;
                  
                  if (import.meta.env.DEV) {
                    console.log('🧮 Calculation:', {
                      formula: 'width_m × height_m × msrp_sale_out × quantity',
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
                    source: 'CatalogItemsMSRP.msrp_sale_out',
                    calculation: savedFabricItemId && savedCatalogItem && savedMsrpSaleOut && savedWidth_m && savedHeight_m
                      ? `${savedWidth_m} × ${savedHeight_m} × ${savedMsrpSaleOut} × ${savedQuantity} = ${fabricMsrpTotal}`
                      : 'N/A (missing data)',
                  });
                  console.log('🔧 BOM Pricing:', {
                    baseTotal: pricing.total,
                    source: 'CatalogItemsMSRP.msrp_sale_out (for each BOM component)',
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
                    source: 'CatalogItemsMSRP.msrp_sale_out',
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
                    fabric: 'CatalogItemsMSRP.msrp_sale_out',
                    bomComponents: 'CatalogItemsMSRP.msrp_sale_out',
                    accessories: 'CatalogItemsMSRP.msrp_sale_out',
                    note: 'Todos los precios de venta vienen de CatalogItemsMSRP.msrp_sale_out',
                  });
                  console.groupEnd();
                }

                // (C3) IMPORTANT: actualiza QuoteLine con verificación
                // ✅ FÓRMULA: Precio Final = Fabric + (BOM × labor_pct)
                // ✅ Fabric = width_m × height_m × CatalogItemsMSRP.msrp_sale_out × quantity
                // ✅ BOM con labor = BOM total × (1 + labor_pct / 100)
                // ✅ msrp = precio final de venta al cliente (Fabric + BOM con labor)
                // ✅ NUEVO: Si viene de ConfiguredProduct, usar sus totals (ya calculados)
                // ✅ total_cost = costo base total (solo para referencia/márgenes, NO precio de venta)
                
                // ✅ NUEVO: Si existe configured_product_id, actualizar metadata
                const updateData: Record<string, any> = {
                  msrp: totalMSRP, // ✅ Precio final de venta al cliente = Fabric + (BOM × labor_pct)
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
                    fabricMsrpTotal, // ✅ Fabric = width_m × height_m × msrp_sale_out × quantity
                    bomMsrpBase: pricing.total, // ✅ BOM MSRP base (de CatalogItemsMSRP.msrp_sale_out)
                    fabricPlusBom: fabricPlusBom, // ✅ Fabric + BOM (antes de labor)
                    fabricPlusBomWithLabor, // ✅ (Fabric + BOM) × (1 + labor_pct)
                    accessoriesMsrpTotal, // ✅ Accessories MSRP (de CatalogItemsMSRP.msrp_sale_out)
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
          const { error: deleteError } = await supabase
            .from('QuoteLineComponents')
            .update({ deleted: true })
            .eq('quote_line_id', finalLineId)
            .eq('organization_id', activeOrganizationId)
            .or('source.eq.accessory,component_role.eq.accessory');

          if (deleteError && import.meta.env.DEV) {
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
                const { error: accessoryError } = await supabase
                  .from('QuoteLineComponents')
                  .insert(accessoryComponents);

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

  // Load initial config for editing a line
  useEffect(() => {
    const loadLineConfig = async () => {
      if (!editingLineId || !quoteId || !activeOrganizationId) {
        setInitialLineConfig(undefined);
        return;
      }

      try {
        // First, fetch the QuoteLine without embedded relationships (more reliable)
        const { data: lineData, error } = await supabase
          .from('QuoteLines')
          .select('*')
          .eq('id', editingLineId)
          .eq('organization_id', activeOrganizationId)
          .maybeSingle();

        if (error) throw error;
        if (!lineData) {
          setInitialLineConfig(undefined);
          return;
        }

        // Fetch CatalogItem separately (for main product)
        let catalogItem = null;
        if (lineData.catalog_item_id) {
          const { data: catalogItemData } = await supabase
            .from('CatalogItems')
            .select('id, collection_name, variant_name, sku, name, item_name')
            .eq('id', lineData.catalog_item_id)
            .eq('organization_id', activeOrganizationId)
            .eq('is_active', true)
            .maybeSingle();
          catalogItem = catalogItemData;
        }

        // Fetch ProductType separately
        // Try to get product_type_id from lineData, or look it up by product_type string
        let productType = null;
        let productTypeId = lineData.product_type_id;
        
        if (!productTypeId && lineData.product_type) {
          // If product_type_id is not stored, try to find it by product_type string
          // ✅ FIX: Soportar registros globales (organization_id NULL)
          // ✅ FIX: ProductTypes NO tiene columna "deleted"
          const { data: productTypeByCode } = await supabase
            .from('ProductTypes')
            .select('id, code, name')
            .or(`organization_id.eq.${activeOrganizationId},organization_id.is.null`)
            .ilike('code', lineData.product_type)
            .maybeSingle();
          
          if (productTypeByCode) {
            productTypeId = productTypeByCode.id;
            productType = productTypeByCode;
          }
        }
        
        if (productTypeId && !productType) {
          // Fetch ProductType by ID
          // ✅ FIX: Soportar registros globales (organization_id NULL)
          // ✅ FIX: ProductTypes NO tiene columna "deleted"
          const { data: productTypeData } = await supabase
            .from('ProductTypes')
            .select('id, code, name')
            .eq('id', productTypeId)
            .or(`organization_id.eq.${activeOrganizationId},organization_id.is.null`)
            .maybeSingle();
          productType = productTypeData;
        }

        // Load accessories (filter by source='accessory' OR component_role='accessory')
        // Fetch accessories and their CatalogItems separately
        const { data: accessoriesData } = await supabase
          .from('QuoteLineComponents')
          .select('id, catalog_item_id, qty, unit_cost_exw, source, component_role')
          .eq('quote_line_id', editingLineId)
          .eq('deleted', false)
          .eq('organization_id', activeOrganizationId)
          .or('source.eq.accessory,component_role.eq.accessory');

        // Fetch CatalogItems for accessories
        const accessoryCatalogItemIds = (accessoriesData || [])
          .map((acc: any) => acc.catalog_item_id)
          .filter((id: string | null) => id);
        
        let accessoriesCatalogItemsMap = new Map<string, any>();
        if (accessoryCatalogItemIds.length > 0) {
          const { data: accessoryCatalogItems } = await supabase
            .from('CatalogItems')
            // ✅ FIX: CatalogItems NO tiene columna "msrp" (está en CatalogItemsMSRP)
            .select('id, item_name, sku, name')
            .in('id', accessoryCatalogItemIds)
            .eq('organization_id', activeOrganizationId)
            .eq('is_active', true);
          
          if (accessoryCatalogItems) {
            accessoryCatalogItems.forEach((item: any) => {
              accessoriesCatalogItemsMap.set(item.id, item);
            });
          }
        }

        const accessories = (accessoriesData || []).map((acc: any) => {
          const catalogItem = accessoriesCatalogItemsMap.get(acc.catalog_item_id);
          return {
            id: acc.catalog_item_id,
            // Use item_name from CatalogItems (same pattern as area/position from QuoteLines)
            name: catalogItem?.item_name || catalogItem?.name || catalogItem?.sku || 'Unknown',
            qty: acc.qty || 1,
            price: acc.unit_cost_exw || catalogItem?.msrp || 0,
          };
        });

        // Convert QuoteLine to ProductConfig based on product_type
        // Use productType from DB query or fallback to lineData.product_type
        const productTypeCode = productType?.code || lineData.product_type?.toUpperCase() || 'ROLLER';
        // Map DB code to UI code
        const productTypeMap: Record<string, string> = {
          'ROLLER': 'roller-shade',
          'DUAL': 'dual-shade',
          'TRIPLE': 'triple-shade',
          'DRAPERY': 'drapery',
          'AWNING': 'awning',
          'FILM': 'window-film',
        };
        const productTypeUI = productTypeMap[productTypeCode] || 'roller-shade';
        
        // CRITICAL: Ensure we have productTypeId - use the one we found or fallback
        const finalProductTypeId = productTypeId || productType?.id;
        const width_mm = lineData.width_m ? lineData.width_m * 1000 : undefined;
        const height_mm = lineData.height_m ? lineData.height_m * 1000 : undefined;

        let config: ProductConfig;

        if (productTypeUI === 'roller-shade' || productTypeUI === 'triple-shade') {
          config = {
            productType: productTypeUI as 'roller-shade' | 'triple-shade',
            productTypeId: finalProductTypeId || undefined,
            area: lineData.area || undefined,
            position: lineData.position || '',
            quantity: lineData.qty || 1,
            width_mm,
            height_mm,
            variantId: lineData.catalog_item_id,
            catalogItemId: lineData.catalog_item_id,
            fabric_catalog_item_id: lineData.catalog_item_id, // For VariantsStep
            collectionName: catalogItem?.collection_name || lineData.collection_name || undefined, // For VariantsStep dropdown
            variantName: catalogItem?.variant_name || lineData.variant_name || undefined, // For display
            operatingSystem: lineData.drive_type === 'motor' ? 'motorized' : 'manual',
            operation_type: lineData.drive_type || 'motor',
            drive_type: lineData.drive_type || 'motor',
            bom_template_id: lineData.bom_template_id || undefined,
            operating_system_variant: lineData.operating_system_variant || undefined,
            tube_type: lineData.tube_type || undefined,
            bottom_rail_type: lineData.bottom_rail_type || 'standard',
            cassette: lineData.cassette || false,
            cassette_type: lineData.cassette_type || undefined,
            side_channel: lineData.side_channel || false,
            // CRITICAL: If side_channel is true but type is null, default to 'side_only'
            side_channel_type: lineData.side_channel 
              ? (lineData.side_channel_type || 'side_only')
              : (lineData.side_channel_type || undefined),
            hardware_color: lineData.hardware_color || 'white',
            hardwareColor: lineData.hardware_color || 'white',
            fabric_rotation: lineData.metadata?.fabric_rotation || false,
            fabric_heatseal: lineData.metadata?.fabric_heatseal || false,
            accessories,
          } as ProductConfig;
        } else if (productTypeUI === 'dual-shade') {
          config = {
            productType: 'dual-shade',
            productTypeId: finalProductTypeId || undefined,
            area: lineData.area || undefined,
            position: lineData.position || '',
            quantity: lineData.qty || 1,
            width_mm,
            height_mm,
            frontFabric: {
              variantId: lineData.catalog_item_id,
            },
            fabric_catalog_item_id: lineData.catalog_item_id, // For VariantsStep
            collectionName: catalogItem?.collection_name || lineData.collection_name || undefined, // For VariantsStep dropdown
            variantName: catalogItem?.variant_name || lineData.variant_name || undefined, // For display
            operatingSystem: lineData.drive_type === 'motor' ? 'motorized' : 'manual',
            drive_type: lineData.drive_type || 'motor',
            bottom_rail_type: lineData.bottom_rail_type || 'standard',
            cassette: lineData.cassette || false,
            side_channel: lineData.side_channel || false,
            hardware_color: lineData.hardware_color || 'white',
            fabric_rotation: lineData.metadata?.fabric_rotation || false,
            fabric_heatseal: lineData.metadata?.fabric_heatseal || false,
            accessories,
          } as ProductConfig;
        } else {
          // Default to roller-shade if unknown type
          config = {
            productType: 'roller-shade',
            productTypeId: finalProductTypeId || undefined,
            area: lineData.area || undefined,
            position: lineData.position || '',
            quantity: lineData.qty || 1,
            width_mm,
            height_mm,
            variantId: lineData.catalog_item_id,
            catalogItemId: lineData.catalog_item_id,
            fabric_catalog_item_id: lineData.catalog_item_id, // For VariantsStep
            collectionName: catalogItem?.collection_name || lineData.collection_name || undefined, // For VariantsStep dropdown
            variantName: catalogItem?.variant_name || lineData.variant_name || undefined, // For display
            operatingSystem: lineData.drive_type === 'motor' ? 'motorized' : 'manual',
            fabric_rotation: lineData.metadata?.fabric_rotation || false,
            fabric_heatseal: lineData.metadata?.fabric_heatseal || false,
            accessories,
          } as ProductConfig;
        }

        if (import.meta.env.DEV) {
          console.log('loadLineConfig: Config loaded - FULL DEBUG', {
            lineId: editingLineId,
            productType: config.productType,
            productTypeId: config.productTypeId,
            productTypeFromDB: productType?.id,
            finalProductTypeId: finalProductTypeId,
            hasArea: !!config.area,
            hasPosition: !!config.position,
            accessoriesCount: accessories.length,
            hasCollection: !!(config as any).collectionName || !!(config as any).collection_name,
            hasVariant: !!(config as any).variantName || !!(config as any).variant_name,
            width_mm: config.width_mm,
            height_mm: config.height_mm,
            drive_type: (config as any).drive_type,
            hardware_color: (config as any).hardware_color,
            fullConfig: config,
          });
        }

        setInitialLineConfig(config);
        // Show configurator after config is loaded
        if (editingLineId) {
          setShowConfigurator(true);
        }
      } catch (err: any) {
        const errorMessage = err?.message || 'Failed to load quote line configuration';
        if (import.meta.env.DEV) {
          console.error('Error loading line config:', {
            message: errorMessage,
            code: err?.code,
            editingLineId,
            quoteId,
          });
        }
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'Error loading quote line',
          message: errorMessage + '. Please try again.',
        });
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

  // Handle PDF download
  const handleDownloadPDF = async () => {
    if (!quoteId || !quoteData || !selectedCustomer) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: 'Quote data is not available',
      });
      return;
    }

    try {
      // Get organization name
      const { data: orgData } = await supabase
        .from('Organizations')
        .select('name')
        .eq('id', activeOrganizationId)
        .maybeSingle();

      const organizationName = orgData?.name || 'Arquiproductos';

      // Generate PDF
      const doc = generateQuotePDF(
        {
          quote_no: quoteData.quote_no || watch('quote_no'),
          customer_id: quoteData.customer_id || watch('customer_id'),
          status: quoteData.status || watch('status'),
          currency: quoteData.currency || watch('currency'),
          notes: quoteData.notes || watch('notes'),
          totals: quoteData.totals || totals,
          created_at: quoteData.created_at || new Date().toISOString(),
        },
        selectedCustomer,
        selectedContact || null,
        quoteLines as any[],
        organizationName
      );

      // Download PDF
      const fileName = `Quote_${quoteData.quote_no || watch('quote_no')}_${new Date().toISOString().split('T')[0]}.pdf`;
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

  // Handle form submit
  const onSubmit = async (data: QuoteFormValues, shouldNavigate: boolean = false) => {
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
      // Quotes table columns (from DB schema):
      // id, organization_id, quote_no, status, tracking_status, customer_id, contact_id,
      // created_by_user_id, deleted, created_at, updated_at, company_id, created_by_portal_user_id
      // NOTE: currency, notes, totals are NOT stored in Quotes table
      const quoteDataPayload: any = {
        quote_no: data.quote_no,
        customer_id: data.customer_id || null, // Optional
        contact_id: selectedContactId || null, // Optional - contact_id DOES exist in Quotes table
        status: data.status,
        organization_id: activeOrganizationId,
        company_id: companyInfo?.id || quoteData?.company_id || null,
      };

      if (quoteId) {
        // Update existing quote
        // Check if status is changing to 'approved' - use approveQuote function
        const isApproving = normalizeStatus(quoteDataPayload.status) === 'approved';
        
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
            // If status is 'approved', navigate to QuoteApproved view
            if (isApproving) {
              router.navigate('/sales/quotes/approved');
            } else {
              // Otherwise, navigate back to quotes list
              router.navigate('/sales/quotes');
            }
          }
      } else {
        // Create new quote
        const created = await createQuote(quoteDataPayload);
        if (created?.id) {
          // Update quoteId state so form knows it's now in edit mode
          setQuoteId(created.id);
          setQuoteData(created);
          
          // Update company info from created quote if available
          if (created.company_id && !companyInfo) {
            const { data: company } = await supabase
              .from('Companies')
              .select('id, company_name, company_no')
              .eq('id', created.company_id)
              .eq('organization_id', activeOrganizationId)
              .eq('deleted', false)
              .maybeSingle();

            if (company) {
              setCompanyInfo({
                id: company.id,
                name: company.company_name || 'Unknown Company',
                number: company.company_no || null,
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
            // If status is 'approved', navigate to QuoteApproved view
            if (quoteDataPayload.status === 'approved') {
              router.navigate('/sales/quotes/approved');
            } else {
              // Otherwise, navigate back to quotes list
              router.navigate('/sales/quotes');
            }
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

  // Get selected customer name
  const selectedCustomer = customers.find(c => c.id === selectedCustomerId);
  const selectedContact = contacts.find(c => c.id === selectedContactId);

  return (
    <div className="py-6">
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
              onClick={handleDownloadPDF}
              className="flex items-center gap-2 px-3 py-1.5 rounded border border-gray-300 bg-white text-gray-700 transition-colors text-sm hover:bg-gray-50"
              title="Download PDF"
            >
              <Download className="w-4 h-4" />
              Download PDF
            </button>
          )}
          <button
            type="button"
            onClick={() => router.navigate('/sales/quotes')}
            className="px-3 py-1.5 rounded border border-gray-300 bg-white text-gray-700 transition-colors text-sm hover:bg-gray-50"
          >
            Close
          </button>
          <button
            type="button"
            onClick={handleSubmit((data) => onSubmit(data, false))}
            disabled={isSaving || isCreating || isUpdating}
            className="px-3 py-1.5 rounded text-white transition-colors text-sm hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed"
            style={{ backgroundColor: 'var(--primary-brand-hex)' }}
          >
            {isSaving || isCreating || isUpdating ? 'Saving...' : 'Save'}
          </button>
          <button
            type="button"
            onClick={handleSubmit(handleSaveAndClose)}
            disabled={isSaving || isCreating || isUpdating}
            className="px-3 py-1.5 rounded text-white transition-colors text-sm hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed"
            style={{ backgroundColor: 'var(--primary-brand-hex)' }}
          >
            {isSaving || isCreating || isUpdating ? 'Saving...' : 'Save and Close'}
          </button>
        </div>
      </div>

      {saveError && (
        <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded text-red-700 text-sm">
          {saveError}
        </div>
      )}

      {/* Quote Form */}
      <div className="bg-white border border-gray-200 rounded-lg mb-6">
        {/* Company Info Banner (always show if available) */}
        {companyInfo && (
          <div className="bg-gray-50 border-b border-gray-200 px-6 py-4">
            <div className="flex items-center justify-between">
              <div>
                <div className="text-xs font-medium text-gray-500 mb-1">COMPANY</div>
                <div className="font-semibold text-gray-900">{companyInfo.name}</div>
              </div>
              {companyInfo.number && (
                <div className="text-right">
                  <div className="text-xs font-medium text-gray-500 mb-1">COMPANY NO.</div>
                  <div className="font-semibold text-gray-900">{companyInfo.number}</div>
                </div>
              )}
            </div>
          </div>
        )}

        {/* Form Fields */}
        <div className="p-6">
          <div className="grid grid-cols-12 gap-4">
            {/* Quote Number */}
            <div className="col-span-12 md:col-span-6">
              <Label htmlFor="quote_no">Quote Number *</Label>
              <Input
                id="quote_no"
                {...register('quote_no')}
                error={errors.quote_no?.message}
              />
            </div>

            {/* Customer (optional) */}
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
              disabled={!selectedCustomerId}
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

            {/* Status */}
            <div className="col-span-12 md:col-span-3">
              <Label htmlFor="status">Status *</Label>
            <SelectShadcn
              value={watch('status') || 'draft'}
              onValueChange={(value) => {
                const validStatus = value as 'draft' | 'sent' | 'approved' | 'rejected';
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

            {/* Notes */}
            <div className="col-span-12">
              <Label htmlFor="notes">Notes</Label>
              <textarea
                id="notes"
                {...register('notes')}
                rows={3}
                className="w-full px-3 py-2 border border-gray-200 rounded text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
                placeholder="Add any additional notes or comments..."
              />
            </div>

            {/* Summary */}
            {quoteId && (
              <div className="col-span-12 border-t border-gray-200 pt-4 mt-4">
              <div className="flex justify-end">
                <div className="w-64">
                  <div className="space-y-2">
                    <div className="flex justify-between text-sm">
                      <span className="text-gray-600">Subtotal:</span>
                      <span className="font-medium">{formatCurrency(totals.subtotal, watch('currency'))}</span>
                    </div>
                    <div className="flex justify-between text-sm">
                      <span className="text-gray-600">Tax:</span>
                      <span className="font-medium">{formatCurrency(totals.tax, watch('currency'))}</span>
                    </div>
                    <div className="flex justify-between text-lg font-semibold border-t border-gray-200 pt-2">
                      <span>Total:</span>
                      <span>{formatCurrency(totals.total, watch('currency'))}</span>
                    </div>
                  </div>
                </div>
              </div>
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Quote Lines Section */}
      {quoteId && (
        <div className="bg-white border border-gray-200 rounded-lg overflow-hidden mb-4">
          <div className="py-4 px-6 border-b border-gray-200">
            <div className="flex items-center justify-between">
              <div>
                <h2 className="text-lg font-semibold text-foreground">Quote Lines</h2>
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
          ) : quoteLines.length === 0 ? (
            <div className="p-6 text-center text-gray-500">No lines added yet. Click "Add Line" to get started.</div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead className="bg-gray-50">
                  <tr>
                    <th className="py-3 px-6 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">Area</th>
                    <th className="py-3 px-6 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">Position</th>
                    <th className="py-3 px-6 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">Product Type</th>
                    <th className="py-3 px-6 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">Collection</th>
                    <th className="py-3 px-6 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">System Drive</th>
                    <th className="py-3 px-6 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">Measurements</th>
                    <th className="py-3 px-6 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">Accessories</th>
                    <th className="py-3 px-6 text-right text-xs font-medium text-gray-700 uppercase tracking-wider">Qty</th>
                    <th className="py-3 px-6 text-right text-xs font-medium text-gray-700 uppercase tracking-wider">List Price</th>
                    <th className="py-3 px-6 text-right text-xs font-medium text-gray-700 uppercase tracking-wider">Total</th>
                    <th className="py-3 px-6 text-right text-xs font-medium text-gray-700 uppercase tracking-wider">Action</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-200">
                  {quoteLines.map((line: any) => {
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

                    return (
                      <tr key={line.id} className="border-b border-gray-100 hover:bg-gray-50 transition-colors">
                        <td className="py-4 px-6 text-gray-700 text-sm">
                          {area != null && String(area).trim() !== '' ? String(area).trim() : '—'}
                        </td>
                        <td className="py-4 px-6 text-gray-700 text-sm">
                          {position != null && String(position).trim() !== '' ? String(position).trim() : '—'}
                        </td>
                        <td className="py-4 px-6 text-gray-900 text-sm font-medium">
                          {productTypeName}
                        </td>
                        <td className="py-4 px-6 text-gray-700 text-sm">
                          {collectionDisplay}
                        </td>
                        <td className="py-4 px-6 text-gray-700 text-sm">
                          {driveDisplay}
                        </td>
                        <td className="py-4 px-6 text-gray-700 text-sm">
                          {line.width_m && line.height_m
                            ? `${(line.width_m * 1000).toFixed(0)} x ${(line.height_m * 1000).toFixed(0)} mm`
                            : '—'}
                        </td>
                        <td className="py-4 px-6 text-gray-700 text-sm">
                          {line.Accessories && line.Accessories.length > 0 ? (
                            <div className="flex flex-wrap gap-1 items-center">
                              {line.Accessories.map((acc: any, idx: number) => {
                                // Get item_name from CatalogItems relationship (similar to how area/position work)
                                const itemName = acc.CatalogItems?.item_name || 
                                                acc.CatalogItems?.name || 
                                                acc.CatalogItems?.sku || 
                                                'Unknown';
                                return (
                                  <span key={acc.id || idx} className="text-xs bg-gray-100 px-2 py-0.5 rounded inline-block">
                                    {itemName}
                                  </span>
                                );
                              })}
                            </div>
                          ) : (
                            <span className="text-gray-400">—</span>
                          )}
                        </td>
                        <td className="py-4 px-6 text-right text-gray-900 text-sm">
                          {/* ✅ FIX: Usar "quantity" (columna correcta en QuoteLines) */}
                          {line.quantity ? line.quantity.toFixed(0) : 'N/A'}
                        </td>
                        {/* List Price (MSRP End User) - Precio unitario */}
                        <td className="py-4 px-6 text-right text-gray-900 text-sm font-medium">
                          {(() => {
                            // ✅ SNAPSHOT: Usar snapshots si están disponibles, sino usar msrp total
                            const rollMsrp = line.roll_msrp_snapshot || 0;
                            const bomMsrp = line.bom_msrp_snapshot || 0;
                            const totalMsrp = line.msrp || (rollMsrp + bomMsrp);
                            const qty = line.quantity || 1;
                            const unitPrice = qty > 0 ? totalMsrp / qty : totalMsrp;
                            
                            // Mostrar tooltip con desglose si hay snapshots
                            const hasSnapshots = rollMsrp > 0 || bomMsrp > 0;
                            
                            return (
                              <div className="relative group">
                                <span>{formatCurrency(unitPrice, watch('currency'))}</span>
                                {hasSnapshots && (
                                  <div className="absolute right-0 bottom-full mb-2 hidden group-hover:block z-10 bg-gray-900 text-white text-xs rounded px-2 py-1 whitespace-nowrap shadow-lg">
                                    <div className="text-left">
                                      <div>Roll MSRP: {formatCurrency(rollMsrp / qty, watch('currency'))}</div>
                                      <div>BOM MSRP: {formatCurrency(bomMsrp / qty, watch('currency'))}</div>
                                      <div className="border-t border-gray-700 mt-1 pt-1">Total: {formatCurrency(unitPrice, watch('currency'))}</div>
                                    </div>
                                  </div>
                                )}
                              </div>
                            );
                          })()}
                        </td>
                        {/* Total = QTY × List Price */}
                        <td className="py-4 px-6 text-right text-gray-900 text-sm font-medium">
                          {(() => {
                            // ✅ SNAPSHOT: Usar snapshots si están disponibles
                            const rollMsrp = line.roll_msrp_snapshot || 0;
                            const bomMsrp = line.bom_msrp_snapshot || 0;
                            const totalMsrp = line.msrp || (rollMsrp + bomMsrp);
                            const qty = line.quantity || 1;
                            const unitPrice = qty > 0 ? totalMsrp / qty : totalMsrp;
                            const calculatedTotal = unitPrice * qty;
                            
                            // Mostrar tooltip con desglose si hay snapshots
                            const hasSnapshots = rollMsrp > 0 || bomMsrp > 0;
                            
                            return (
                              <div className="relative group">
                                <span>{formatCurrency(calculatedTotal, watch('currency'))}</span>
                                {hasSnapshots && (
                                  <div className="absolute right-0 bottom-full mb-2 hidden group-hover:block z-10 bg-gray-900 text-white text-xs rounded px-2 py-1 whitespace-nowrap shadow-lg">
                                    <div className="text-left">
                                      <div>Roll MSRP: {formatCurrency(rollMsrp, watch('currency'))}</div>
                                      <div>BOM MSRP: {formatCurrency(bomMsrp, watch('currency'))}</div>
                                      <div className="border-t border-gray-700 mt-1 pt-1">Total: {formatCurrency(calculatedTotal, watch('currency'))}</div>
                                    </div>
                                  </div>
                                )}
                              </div>
                            );
                          })()}
                        </td>
                        <td className="py-4 px-6">
                          <div className="flex items-center gap-1 justify-end">
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
    </div>
  );
}

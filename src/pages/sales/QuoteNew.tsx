import React, { useState, useEffect, useMemo } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { router } from '../../lib/router';
import { supabase } from '../../lib/supabase/client';
import { useUIStore } from '../../stores/ui-store';
import Input from '../../components/ui/Input';
import { Select as SelectShadcn, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../../components/ui/SelectShadcn';
import Label from '../../components/ui/Label';
import { useCurrentOrgRole } from '../../hooks/useCurrentOrgRole';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useCreateQuote, useUpdateQuote, useQuotes, useQuoteLines, useCreateQuoteLine, useUpdateQuoteLine } from '../../hooks/useQuotes';
import { useConfirmDialog } from '../../hooks/useConfirmDialog';
import ConfirmDialog from '../../components/ui/ConfirmDialog';
import { QuoteStatus, MeasureBasis, Quote } from '../../types/catalog';
import { Search, X, Plus, Edit, Trash2 } from 'lucide-react';
import ProductConfigurator from './ProductConfigurator';
import { ProductConfig } from './product-config/types';
import { adaptFromProductConfig, adaptQuoteLineToProductConfig } from './product-config/adapters';
import { CurtainConfiguration } from './CurtainConfigurator'; // Keep for backward compatibility
import { computeComputedQty } from '../../lib/catalog/computeComputedQty';
import QuoteLineCostsSectionV1 from '../../components/quotes/QuoteLineCostsSectionV1';

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

// Schema for Quote
const quoteSchema = z.object({
  quote_no: z.string().min(1, 'Quote number is required'),
  customer_id: z.string().uuid('Customer is required'),
  status: z.enum(['draft', 'sent', 'approved', 'rejected']),
  currency: z.string().min(1, 'Currency is required'),
  notes: z.string().optional(),
});

type QuoteFormValues = z.infer<typeof quoteSchema>;

interface Customer {
  id: string;
  customer_name: string;
  primary_contact_id?: string | null;
}

interface Contact {
  id: string;
  contact_name: string;
  email?: string | null;
  primary_phone?: string | null;
  customer_id?: string | null;
}

interface CustomerWithContacts extends Customer {
  contacts?: Contact[];
  primary_contact?: Contact | null;
  pricing_tier_code?: string | null;
  discount_pct?: number | null;
}

export default function QuoteNew() {
  const { activeOrganizationId } = useOrganizationContext();
  const { canEditQuotes, isViewer, loading: roleLoading } = useCurrentOrgRole();
  const { dialogState, showConfirm, closeDialog, setLoading, handleConfirm } = useConfirmDialog();
  const [isSaving, setIsSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [quoteId, setQuoteId] = useState<string | null>(null);
  const [quoteData, setQuoteData] = useState<Quote | null>(null);
  const [customers, setCustomers] = useState<CustomerWithContacts[]>([]);
  const [allContacts, setAllContacts] = useState<Contact[]>([]);
  const [loadingCustomers, setLoadingCustomers] = useState(true);
  const [quoteNo, setQuoteNo] = useState<string>('');
  const [customerSearchTerm, setCustomerSearchTerm] = useState('');
  const [showCustomerDropdown, setShowCustomerDropdown] = useState(false);
  const [selectedContactId, setSelectedContactId] = useState<string>('');
  const [showConfigurator, setShowConfigurator] = useState(false);
  const [editingLineId, setEditingLineId] = useState<string | null>(null); // Track which line is being edited
  const [expandedLineId, setExpandedLineId] = useState<string | null>(null); // Track which line has costs expanded
  
  // Helper functions to get display names
  const getCollectionName = (collectionId?: string): string => {
    if (!collectionId) return 'N/A';
    const collections: Record<string, string> = {
      'essential-3000': 'Essential_3000',
      'sunset-blackout': 'Sunset_Blackout',
    };
    return collections[collectionId] || collectionId;
  };
  
  const getSystemDriveName = (driveId?: string): string => {
    if (!driveId) return 'N/A';
    // Map of drive IDs to names (from OperatingSystemStep)
    const drives: Record<string, string> = {
      'roller-m-s': 'ROLLER M S',
      'roller-m-m': 'ROLLER M M',
      'roller-m-l': 'ROLLER M L',
      'roller-m-xl': 'ROLLER M XL',
      'roller-m-xxl': 'ROLLER M XXL',
      'roller-m-xxxl': 'ROLLER M XXXL',
      'roller-m-xxxxl': 'ROLLER M XXXXL',
      'roller-m-xxxxxl': 'ROLLER M XXXXXL',
      'roller-m-xxxxxxl': 'ROLLER M XXXXXXL',
      'roller-m-xxxxxxxl': 'ROLLER M XXXXXXXL',
      'roller-m-xxxxxxxxl': 'ROLLER M XXXXXXXXL',
      'roller-m-xxxxxxxxxl': 'ROLLER M XXXXXXXXXL',
      'roller-m-xxxxxxxxxxl': 'ROLLER M XXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'roller-m-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxl': 'ROLLER M XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXL',
      'lutron-edu150': 'LUTRON-EDU150',
      'lutron-edu300': 'LUTRON-EDU300',
      'lutron-edu64': 'LUTRON-EDU64',
      'inter-lutron': 'INTER. LUTRON',
      'cm-09-qc120-m': 'CM-09-QC120-M',
      'cm-10-qc120-m': 'CM-10-QC120-M',
      'cm-09-c120-m': 'CM-09-C120-M',
      'cm-09-qc120-l': 'CM-09-QC120-L',
      'cm-10-qc120-l': 'CM-10-QC120-L',
      'cm-09-c120-l': 'CM-09-C120-L',
      'inter-coulisse-m': 'INTER. COULISSE-M',
      'inter-coulisse-l': 'INTER. COULISSE-L',
      're-lion': 'Re-Lion',
    };
    return drives[driveId] || driveId;
  };
  
  const getProductTypeName = (productType?: string): string => {
    if (!productType) return 'N/A';
    const types: Record<string, string> = {
      'roller-shade': 'Roller Shade',
      'dual-shade': 'Dual Shade',
      'triple-shade': 'Triple Shade',
      'drapery': 'Drapery Wave / Ripple Fold',
      'awning': 'Awning',
      'window-film': 'Window Films',
    };
    return types[productType] || productType;
  };
  const { createQuote, isCreating } = useCreateQuote();
  const { updateQuote, isUpdating } = useUpdateQuote();
  const { quotes } = useQuotes();
  const { lines: quoteLines, loading: loadingLines, refetch: refetchLines } = useQuoteLines(quoteId);
  const { createLine: createQuoteLine, isCreating: isCreatingLine } = useCreateQuoteLine();
  const { updateLine: updateQuoteLine, isUpdating: isUpdatingLine } = useUpdateQuoteLine();
  
  // Get totals from quote data (calculated automatically by trigger)
  // Fallback to calculated value if quote data not loaded yet
  const quoteTotals = useMemo(() => {
    if (quoteData?.totals) {
      return quoteData.totals;
    }
    // Fallback: calculate from lines (for new quotes or while loading)
    const subtotal = quoteLines.reduce((sum, line) => sum + (line.line_total || 0), 0);
    const discountTotal = quoteLines.reduce((sum, line) => sum + (line.discount_amount || 0), 0);
    return {
      subtotal,
      discount_total: discountTotal,
      tax: 0,
      total: subtotal - discountTotal,
    };
  }, [quoteData, quoteLines]);
  
  // Determine if form should be read-only (using canEditQuotes from line 83)
  const isReadOnly = isViewer || !canEditQuotes;

  const {
    register,
    handleSubmit,
    watch,
    setValue,
    trigger,
    formState: { errors },
  } = useForm<QuoteFormValues>({
    resolver: zodResolver(quoteSchema),
    defaultValues: {
      status: 'draft',
      currency: 'USD',
    },
  });

  // Get quote ID from URL if in edit mode - MUST run first
  useEffect(() => {
    const getQuoteIdFromUrl = () => {
      const path = window.location.pathname;
      const match = path.match(/\/sales\/quotes\/edit\/([^/]+)/);
      if (match && match[1]) {
        const id = match[1];
        setQuoteId(id);
        return id;
      } else {
        setQuoteId(null);
        return null;
      }
    };

    getQuoteIdFromUrl();

    // Also listen for route changes
    const handleRouteChange = () => {
      getQuoteIdFromUrl();
    };

    // Check on mount and when pathname changes
    window.addEventListener('popstate', handleRouteChange);
    
    return () => {
      window.removeEventListener('popstate', handleRouteChange);
    };
  }, []);

  // Generate quote number - only if NOT editing
  useEffect(() => {
    const generateQuoteNo = async () => {
      // Don't generate if editing or if no organization
      if (!activeOrganizationId || quoteId) {
        return;
      }

      // Only generate if quote_no is not already set
      if (quoteNo) {
        return;
      }

      try {
        // Get all quote numbers for this organization to find the highest one
        const { data, error } = await supabase
          .from('Quotes')
          .select('quote_no')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false);

        if (error && error.code !== 'PGRST116' && import.meta.env.DEV) {
          console.error('Error fetching quotes:', error.message);
        }

        let nextNumber = 1;
        if (data && data.length > 0) {
          // Extract all numbers from quote_no and find the maximum
          const numbers = data
            .map((q: any) => {
              if (!q.quote_no) return 0;
              const match = q.quote_no.match(/\d+/);
              return match ? parseInt(match[0], 10) : 0;
            })
            .filter((n: number) => !isNaN(n) && n > 0);
          
          if (numbers.length > 0) {
            nextNumber = Math.max(...numbers) + 1;
          }
        }

        // Format as QT-000001, QT-000002, etc.
        const formattedNo = `QT-${String(nextNumber).padStart(6, '0')}`;
        setQuoteNo(formattedNo);
        setValue('quote_no', formattedNo, { shouldValidate: true });
      } catch (err) {
        if (import.meta.env.DEV) {
          console.error('Error generating quote number:', err instanceof Error ? err.message : String(err));
        }
        // Fallback to timestamp-based number
        const fallbackNo = `QT-${Date.now().toString().slice(-6)}`;
        setQuoteNo(fallbackNo);
        setValue('quote_no', fallbackNo, { shouldValidate: true });
      }
    };

    generateQuoteNo();
  }, [activeOrganizationId, quoteId, setValue]);

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

        if (error) {
          if (import.meta.env.DEV) {
            console.error('Error loading quote:', error.message);
          }
          useUIStore.getState().addNotification({
            type: 'error',
            title: 'Error loading quote',
            message: 'Could not load quote data. Please try again.',
          });
          return;
        }

        if (data) {
          const quoteNumber = (data as any).quote_no || '';
          setQuoteNo(quoteNumber);
          setValue('quote_no', quoteNumber, { shouldValidate: true });
          const customerId = data.customer_id || '';
          setValue('customer_id', customerId, { shouldValidate: true });
          setValue('status', data.status || 'draft', { shouldValidate: true });
          setValue('currency', data.currency || 'USD', { shouldValidate: true });
          setValue('notes', data.notes || '', { shouldValidate: true });
          
          // Store quote data to access totals
          setQuoteData(data as Quote);
          
          // Note: customerSearchTerm will be updated by the useEffect when customers are loaded
        }
      } catch (err) {
        if (import.meta.env.DEV) {
          console.error('Error loading quote data:', err instanceof Error ? err.message : String(err));
        }
      }
    };

    loadQuoteData();
  }, [quoteId, activeOrganizationId, setValue]);

  // Load Customers and Contacts from Supabase
  useEffect(() => {
    const loadCustomersAndContacts = async () => {
      if (!activeOrganizationId) {
        setLoadingCustomers(false);
        return;
      }

      try {
        setLoadingCustomers(true);
        
        // Load Customers
        // IMPORTANT: Load ALL customers for this organization, even if they don't have primary_contact_id
        const { data: customersData, error: customersError } = await supabase
          .from('DirectoryCustomers')
          .select(`
            id, 
            customer_name, 
            primary_contact_id,
            pricing_tier_code,
            discount_pct
          `)
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .eq('archived', false)
          .order('customer_name', { ascending: true });

        if (customersError) {
          if (import.meta.env.DEV) {
            console.error('Error loading customers:', customersError.message);
          }
          useUIStore.getState().addNotification({
            type: 'error',
            title: 'Error loading customers',
            message: customersError.message || 'Could not load customers',
          });
          return;
        }

        // Debug logging to diagnose missing customers
        if (import.meta.env.DEV) {
          console.log('📊 Customers loaded:', {
            total: customersData?.length || 0,
            organizationId: activeOrganizationId,
            customersWithoutPrimaryContact: customersData?.filter(c => !c.primary_contact_id).length || 0,
            sample: customersData?.slice(0, 5).map(c => ({
              id: c.id,
              name: c.customer_name,
              hasPrimaryContact: !!c.primary_contact_id,
            })),
          });
        }

        // Load Contacts
        // IMPORTANT: Load ALL contacts for this organization
        const { data: contactsData, error: contactsError } = await supabase
          .from('DirectoryContacts')
          .select('id, contact_name, email, primary_phone, customer_id')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .order('contact_name', { ascending: true });

        if (contactsError) {
          if (import.meta.env.DEV) {
            console.error('Error loading contacts:', contactsError.message);
          }
          // Continue even if contacts fail - customers can still be displayed
        }

        // Debug logging
        if (import.meta.env.DEV) {
          console.log('📊 Contacts loaded:', {
            total: contactsData?.length || 0,
            contactsWithoutCustomer: contactsData?.filter(c => !c.customer_id).length || 0,
            contactsByCustomer: contactsData?.reduce((acc: Record<string, number>, contact: any) => {
              const customerId = contact.customer_id || 'no-customer';
              acc[customerId] = (acc[customerId] || 0) + 1;
              return acc;
            }, {}),
          });
        }

        // Combine customers with their contacts
        // IMPORTANT: Include ALL customers, even if they don't have contacts yet
        const customersWithContacts: CustomerWithContacts[] = (customersData || []).map((customer) => {
          const customerContacts = (contactsData || []).filter(
            (contact: Contact) => contact.customer_id === customer.id
          );
          
          // Find primary contact - first try from customerContacts, then from all contacts
          let primaryContact = null;
          if (customer.primary_contact_id) {
            primaryContact = customerContacts.find((c: Contact) => c.id === customer.primary_contact_id) 
              || (contactsData || []).find((c: Contact) => c.id === customer.primary_contact_id) 
              || null;
          }

          return {
            id: customer.id,
            customer_name: customer.customer_name,
            primary_contact_id: customer.primary_contact_id,
            pricing_tier_code: customer.pricing_tier_code || null,
            discount_pct: customer.discount_pct || null,
            contacts: customerContacts,
            primary_contact: primaryContact,
          };
        });

        // Debug logging for final result
        if (import.meta.env.DEV) {
          console.log('📊 Final customers with contacts:', {
            totalCustomers: customersWithContacts.length,
            customersWithContacts: customersWithContacts.filter(c => c.contacts.length > 0).length,
            customersWithoutContacts: customersWithContacts.filter(c => c.contacts.length === 0).length,
            customersWithoutPrimaryContact: customersWithContacts.filter(c => !c.primary_contact).length,
          });
        }

        setCustomers(customersWithContacts);
        setAllContacts(contactsData || []);
      } catch (err) {
        if (import.meta.env.DEV) {
          console.error('Error loading customers and contacts:', err instanceof Error ? err.message : String(err));
        }
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'Error loading data',
          message: err instanceof Error ? err.message : 'Could not load customers and contacts',
        });
      } finally {
        setLoadingCustomers(false);
      }
    };

    loadCustomersAndContacts();
  }, [activeOrganizationId]);

  // Update customer search term when quote is loaded and customers are available
  useEffect(() => {
    const customerId = watch('customer_id');
    if (customerId && customers.length > 0) {
      const selectedCustomer = customers.find(c => c.id === customerId);
      if (selectedCustomer) {
        // Always update the search term to show the customer name
        setCustomerSearchTerm(selectedCustomer.customer_name);
      }
    } else if (!customerId) {
      // Clear search term if no customer is selected
      setCustomerSearchTerm('');
    }
  }, [quoteId, customers, watch('customer_id')]);

  // Filter customers and contacts based on search term
  const filteredCustomers = useMemo(() => {
    if (!customers || customers.length === 0) return [];
    const searchLower = customerSearchTerm.toLowerCase().trim();
    // If no search term, show all customers OR the selected customer if one is selected
    if (!searchLower) {
      const selectedCustomerId = watch('customer_id');
      if (selectedCustomerId) {
        // Include the selected customer even if search term is empty
        const selectedCustomer = customers.find(c => c.id === selectedCustomerId);
        if (selectedCustomer) {
          return [selectedCustomer];
        }
      }
      return customers;
    }
    return customers.filter(customer => {
      // Search in customer name
      if (customer.customer_name?.toLowerCase().includes(searchLower)) return true;
      
      // Search in primary contact
      if (customer.primary_contact?.contact_name?.toLowerCase().includes(searchLower)) return true;
      if (customer.primary_contact?.email?.toLowerCase().includes(searchLower)) return true;
      if (customer.primary_contact?.primary_phone?.toLowerCase().includes(searchLower)) return true;
      
      // Search in all contacts
      if (customer.contacts?.some(contact => 
        contact.contact_name?.toLowerCase().includes(searchLower) ||
        contact.email?.toLowerCase().includes(searchLower) ||
        contact.primary_phone?.toLowerCase().includes(searchLower)
      )) return true;
      
      return false;
    });
  }, [customers, customerSearchTerm]);

  // Get selected customer info
  const selectedCustomer = useMemo(() => {
    const customerId = watch('customer_id');
    if (!customerId) return null;
    return customers.find(c => c.id === customerId);
  }, [watch('customer_id'), customers]);

  // Get available contacts for selected customer
  const availableContacts = useMemo(() => {
    if (!selectedCustomer) return [];
    return selectedCustomer.contacts || [];
  }, [selectedCustomer]);

  // Reset contact selection when customer changes
  useEffect(() => {
    if (!watch('customer_id')) {
      setSelectedContactId('');
    }
  }, [watch('customer_id')]);

  // Refetch quote lines when quoteId changes
  useEffect(() => {
    if (quoteId) {
      // Lines will be fetched automatically by useQuoteLines hook
    }
  }, [quoteId]);

  // Handle product configuration completion
  // NOTE: Currently in architecture mode - not persisting to database
  // Helper function to create a QuoteLine for a specific panel
  // Note: height_mm is stored globally in productConfig, not per panel
  const createQuoteLineForPanel = async (
    productConfig: ProductConfig,
    panel: { width_mm: number }, // Panel only has width, height is global
    panelIndex: number,
    totalPanels: number
  ) => {
    if (!quoteId || !activeOrganizationId) {
      throw new Error('Quote must be saved first before adding lines');
    }

    // Get height from global config (not from panel - avoids redundancy)
    const globalHeight_mm = (productConfig as any).height_mm || 0;
    const width_m = panel.width_mm ? panel.width_mm / 1000 : null;
    const height_m = globalHeight_mm ? globalHeight_mm / 1000 : null;

    if (!width_m || width_m <= 0) {
      throw new Error(`Panel ${panelIndex + 1}: Width must be greater than 0`);
    }
    if (!height_m || height_m <= 0) {
      throw new Error(`Height must be set (applies to all panels)`);
    }

    // Find or create catalog item (same logic as single panel)
    let catalogItemId: string | null = null;
    
    const { data: existingItems, error: searchError } = await supabase
      .from('CatalogItems')
      .select('id')
      .eq('organization_id', activeOrganizationId)
      .eq('deleted', false)
      .eq('active', true)
      .ilike('name', `%${productConfig.productType}%`)
      .limit(1);

    if (searchError && import.meta.env.DEV) {
      console.error('Error searching for catalog item:', searchError.message);
    }

    if (!searchError && existingItems && existingItems.length > 0) {
      catalogItemId = existingItems[0].id;
    } else {
      const itemType = 'component';
      const { data: newItem, error: createError } = await supabase
        .from('CatalogItems')
        .insert({
          organization_id: activeOrganizationId,
          sku: `${productConfig.productType.toUpperCase()}-${Date.now()}`,
          name: `${productConfig.productType.replace('-', ' ').replace(/\b\w/g, l => l.toUpperCase())}`,
          description: `Product configuration: ${productConfig.productType}`,
          item_type: itemType,
          measure_basis: 'area',
          uom: 'sqm',
          is_fabric: false,
          unit_price: 0,
          cost_price: 0,
          active: true,
          discontinued: false,
          metadata: {
            product_type: productConfig.productType,
            configured: true,
          },
        })
        .select('id')
        .single();

      if (createError) {
        throw new Error(`Failed to create catalog item: ${createError.message}`);
      }

      if (!newItem || !newItem.id) {
        throw new Error('Catalog item was created but no ID was returned');
      }

      catalogItemId = newItem.id;
    }

    if (!catalogItemId) {
      throw new Error('Could not find or create catalog item');
    }

    // Get catalog item for pricing
    const { data: catalogItem, error: itemError } = await supabase
      .from('CatalogItems')
      .select('unit_price, measure_basis')
      .eq('id', catalogItemId)
      .single();

    if (itemError || !catalogItem) {
      throw new Error(`Could not load catalog item details: ${itemError?.message || 'Not found'}`);
    }

    // Extract configuration data
    const area = productConfig.area || null;
    const position = productConfig.position ? String(productConfig.position) : null;
    
    // Extract collection_name and variant_name based on product type
    // Note: Now using collection_name directly (text) instead of collection_id (FK)
    let collectionName: string | null = null;
    let variantName: string | null = null;
    let collectionId: string | null = null; // Keep for backward compatibility
    let variantId: string | null = null; // Keep for backward compatibility
    
    if (productConfig.productType === 'roller-shade') {
      collectionId = (productConfig as any).collectionId || null;
      variantId = (productConfig as any).variantId || null;
      collectionName = (productConfig as any).collectionName || (productConfig as any).collectionId || null;
      variantName = (productConfig as any).variantName || (productConfig as any).variantId || null;
    } else if (productConfig.productType === 'dual-shade' || productConfig.productType === 'triple-shade') {
      collectionId = (productConfig as any).frontFabric?.collectionId || null;
      variantId = (productConfig as any).frontFabric?.variantId || null;
      collectionName = (productConfig as any).frontFabric?.collectionName || (productConfig as any).frontFabric?.collectionId || null;
      variantName = (productConfig as any).frontFabric?.variantName || (productConfig as any).frontFabric?.variantId || null;
    } else if (productConfig.productType === 'drapery' || productConfig.productType === 'awning') {
      collectionId = (productConfig as any).fabric?.collectionId || null;
      variantId = (productConfig as any).fabric?.variantId || null;
      collectionName = (productConfig as any).fabric?.collectionName || (productConfig as any).fabric?.collectionId || null;
      variantName = (productConfig as any).fabric?.variantName || (productConfig as any).fabric?.variantId || null;
    }
    
    const operatingSystemVariant = (productConfig as any).operatingSystemVariant || null;
    const operatingSystem = (productConfig as any).operatingSystem || null;
    const operatingSystemManufacturer = (productConfig as any).operatingSystemManufacturer || null;
    const installationType = (productConfig as any).installationType || null;
    const installationLocation = (productConfig as any).installationLocation || null;
    const fabricDrop = (productConfig as any).fabricDrop || null;
    
    const isOperatingSystemVariantUUID = operatingSystemVariant && 
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(operatingSystemVariant);
    const operatingSystemDriveId = isOperatingSystemVariantUUID ? operatingSystemVariant : null;

    // Calculate quantities and totals
    const quantity = (productConfig as any).quantity || 1;
    const measureBasis = (catalogItem.measure_basis as MeasureBasis) || 'area';
    
    if (typeof measureBasis !== 'string') {
      throw new Error(`Invalid measure_basis value: ${measureBasis}`);
    }
    
    const computedQty = computeComputedQty(
      measureBasis,
      quantity,
      width_m,
      height_m,
      null,
      null,
    );

    const unitPrice = catalogItem.unit_price || 0;
    const accessoriesTotal = (productConfig as any).accessories?.reduce((sum: number, acc: any) => sum + (acc.price * acc.qty), 0) || 0;
    const lineTotal = (unitPrice * computedQty) + accessoriesTotal;

    // Build quoteLineData with panel metadata
    const quoteLineData: any = {
      quote_id: quoteId,
      catalog_item_id: catalogItemId,
      qty: quantity || 1,
      width_m: width_m || null,
      height_m: height_m || null,
      area: area,
      position: position,
      collection_id: collectionId, // Legacy - kept for compatibility
      collection_name: collectionName, // New - preferred field
      variant_id: variantId, // Legacy - kept for compatibility
      variant_name: variantName, // New - preferred field (if available)
      product_type: productConfig.productType,
      operating_system: operatingSystem,
      operating_system_manufacturer: operatingSystemManufacturer,
      installation_type: installationType,
      installation_location: installationLocation,
      fabric_drop: fabricDrop,
      measure_basis_snapshot: measureBasis,
      roll_width_m_snapshot: null,
      fabric_pricing_mode_snapshot: null,
      computed_qty: computedQty || 0,
      unit_price_snapshot: unitPrice || 0,
      unit_cost_snapshot: 0,
      line_total: lineTotal || 0,
      // Panel metadata for BOM and production tracking
      // Store only widths in panels array (height is global, stored in height_m field)
      metadata: {
        panel_index: panelIndex,
        total_panels: totalPanels,
        panels: (productConfig as any).panels || [{ width_mm: panel.width_mm }], // Only widths, no redundant height
      },
    };
    
    if (operatingSystemDriveId) {
      quoteLineData.operating_system_drive_id = operatingSystemDriveId;
    }

    // Check if we're editing an existing line or creating a new one
    if (editingLineId) {
      // Update existing line
      const updatedLine = await updateQuoteLine(editingLineId, quoteLineData);
      
      if (!updatedLine) {
        throw new Error('QuoteLine was not updated - no data returned');
      }

      return updatedLine;
    } else {
      // Create new line
      const createdLine = await createQuoteLine(quoteLineData);
      
      if (!createdLine) {
        throw new Error('QuoteLine was not created - no data returned');
      }

      return createdLine;
    }
  };

  const handleProductConfigComplete = async (productConfig: ProductConfig) => {
    // Convert to old format for now (backward compatibility)
    const config = adaptFromProductConfig(productConfig);
    
    if (!quoteId || !activeOrganizationId) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: 'Quote must be saved first before adding lines',
      });
      return;
    }

    try {
      // Check if product supports multiple panels and has panels array
      const productType = productConfig.productType;
      const supportsPanels = ['roller-shade', 'dual-shade', 'triple-shade'].includes(productType);
      const panels = supportsPanels && (productConfig as any).panels 
        ? (productConfig as any).panels 
        : null;
      
      // If panels exist and has more than 1 panel, create ONE QuoteLine with all panels in metadata
      if (panels && Array.isArray(panels) && panels.length > 1) {
        // Get global height (applies to all panels - avoids redundancy)
        const globalHeight_mm = (productConfig as any).height_mm || 0;
        const globalHeight_m = globalHeight_mm ? globalHeight_mm / 1000 : null;
        
        if (!globalHeight_m || globalHeight_m <= 0) {
          useUIStore.getState().addNotification({
            type: 'error',
            title: 'Validation Error',
            message: 'Height must be set (applies to all panels)',
          });
          return;
        }
        
        // Validate all panel widths
        for (let i = 0; i < panels.length; i++) {
          const panel = panels[i];
          const width_m = panel.width_mm ? panel.width_mm / 1000 : null;
          
          if (!width_m || width_m <= 0) {
            useUIStore.getState().addNotification({
              type: 'error',
              title: 'Validation Error',
              message: `Panel ${i + 1}: Width must be greater than 0`,
            });
            return;
          }
        }
        
        // Create ONE QuoteLine using the first panel's width and global height
        // All panel widths will be stored in metadata
        try {
          await createQuoteLineForPanel(productConfig, panels[0], 0, panels.length);
          
          const action = editingLineId ? 'updated' : 'created';
          useUIStore.getState().addNotification({
            type: 'success',
            title: `Line ${action.charAt(0).toUpperCase() + action.slice(1)}`,
            message: `Successfully ${action} line with ${panels.length} panel${panels.length > 1 ? 's' : ''}.`,
          });
          
          // Clear editing state if we were editing
          if (editingLineId) {
            setEditingLineId(null);
          }
          
          // Refresh quote lines
          if (refetchLines) {
            refetchLines();
          }
          
          // Close configurator
          setShowConfigurator(false);
          return;
        } catch (error) {
          const errorMessage = error instanceof Error ? error.message : String(error);
          if (import.meta.env.DEV) {
            console.error('Error creating QuoteLine with panels:', error);
            console.error('Error details:', {
              panels: panels,
              productConfig: productConfig,
              error: errorMessage
            });
          }
          useUIStore.getState().addNotification({
            type: 'error',
            title: 'Error',
            message: `Failed to ${editingLineId ? 'update' : 'create'} line: ${errorMessage}`,
          });
          return;
        }
      }
      
      // Handle accessories-only product type
      const productTypeStr = String((productConfig as any).productType || productType);
      if (productTypeStr === 'accessories') {
        const accessories = (productConfig as any).accessories || [];
        
        if (import.meta.env.DEV) {
          console.log('🔍 QuoteNew - Processing accessories:', {
            count: accessories.length,
            accessories: accessories.map((a: any) => ({
              id: a.id,
              name: a.name,
              idType: typeof a.id,
              isUUID: a.id ? /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(a.id) : false,
            })),
          });
        }
        
        if (accessories.length === 0) {
          useUIStore.getState().addNotification({
            type: 'error',
            title: 'Validation Error',
            message: 'Please select at least one accessory',
          });
          return;
        }

        // Create a QuoteLine for each accessory
        const createdLines = [];
        for (const accessory of accessories) {
          // CRITICAL: Validate that accessory.id is a valid UUID
          // If id is missing or invalid, skip this accessory
          if (!accessory.id) {
            useUIStore.getState().addNotification({
              type: 'error',
              title: 'Invalid Accessory',
              message: `Accessory "${accessory.name || 'Unknown'}" is missing an ID. Please remove and re-add it from the catalog.`,
            });
            if (import.meta.env.DEV) {
              console.error('❌ Accessory missing ID:', {
                name: accessory.name,
                accessory: accessory,
              });
            }
            continue;
          }

          // Check if id is a valid UUID format
          const isValidUUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(String(accessory.id));
          if (!isValidUUID) {
            useUIStore.getState().addNotification({
              type: 'error',
              title: 'Invalid Accessory ID',
              message: `Accessory "${accessory.name}" has an invalid ID format ("${accessory.id}"). The ID must be a UUID. Please remove and re-add this accessory from the catalog.`,
            });
            if (import.meta.env.DEV) {
              console.error('❌ Invalid accessory ID format:', {
                name: accessory.name,
                id: accessory.id,
                idType: typeof accessory.id,
                fullAccessory: accessory,
              });
            }
            continue;
          }

          // Get the catalog item to get pricing information
          const { data: catalogItem, error: itemError } = await supabase
            .from('CatalogItems')
            .select('id, cost_exw, msrp, default_margin_pct, measure_basis, uom')
            .eq('id', accessory.id)
            .eq('organization_id', activeOrganizationId)
            .eq('deleted', false)
            .single();

          if (itemError || !catalogItem) {
            useUIStore.getState().addNotification({
              type: 'error',
              title: 'Error Loading Accessory',
              message: `Could not load catalog item for "${accessory.name}": ${itemError?.message || 'Item not found'}`,
            });
            if (import.meta.env.DEV) {
              console.error('❌ Error loading catalog item:', {
                accessoryId: accessory.id,
                accessoryName: accessory.name,
                error: itemError,
              });
            }
            continue;
          }

          // Calculate unit price (use msrp if available, otherwise calculate from cost_exw and margin)
          let unitPrice = accessory.price || 0;
          if (!unitPrice || unitPrice === 0) {
            if (catalogItem.msrp) {
              unitPrice = catalogItem.msrp;
            } else if (catalogItem.cost_exw && catalogItem.default_margin_pct) {
              unitPrice = catalogItem.cost_exw * (1 + catalogItem.default_margin_pct / 100);
            }
          }

          const measureBasis = (catalogItem.measure_basis as MeasureBasis) || 'unit';
          const qty = accessory.qty || 1;
          const computedQty = measureBasis === 'unit' ? qty : qty; // For accessories, qty is usually 1:1
          const lineTotal = unitPrice * computedQty;

          // Double-check that catalog_item_id is a valid UUID before creating QuoteLine
          const catalogItemId = String(accessory.id).trim();
          if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(catalogItemId)) {
            useUIStore.getState().addNotification({
              type: 'error',
              title: 'Invalid Catalog Item ID',
              message: `Cannot create line for "${accessory.name}": Invalid catalog item ID ("${catalogItemId}"). Please remove and re-add this accessory.`,
            });
            if (import.meta.env.DEV) {
              console.error('❌ Final validation failed - Invalid catalog_item_id:', {
                accessoryName: accessory.name,
                catalogItemId: catalogItemId,
                originalId: accessory.id,
                catalogItem: catalogItem,
              });
            }
            continue;
          }

          const quoteLineData: any = {
            quote_id: quoteId,
            catalog_item_id: catalogItemId, // Use the validated UUID
            qty: qty,
            width_m: null,
            height_m: null,
            area: null,
            position: null,
            // Explicitly set collection/variant fields to null to avoid UUID errors
            collection_id: null,
            variant_id: null,
            collection_name: null,
            variant_name: null,
            product_type: 'accessories',
            measure_basis_snapshot: measureBasis,
            roll_width_m_snapshot: null,
            fabric_pricing_mode_snapshot: null,
            computed_qty: computedQty,
            unit_price_snapshot: unitPrice,
            unit_cost_snapshot: catalogItem.cost_exw || 0,
            line_total: lineTotal,
            metadata: {
              accessory_name: accessory.name,
              is_accessory: true,
            },
          };

          if (import.meta.env.DEV) {
            console.log('📝 Creating QuoteLine with data:', {
              catalog_item_id: quoteLineData.catalog_item_id,
              catalog_item_id_type: typeof quoteLineData.catalog_item_id,
              isUUID: /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(quoteLineData.catalog_item_id),
              accessoryName: accessory.name,
              quoteLineData: quoteLineData,
            });
          }

          try {
            const createdLine = await createQuoteLine(quoteLineData);
            if (createdLine) {
              createdLines.push(createdLine);
            }
          } catch (error) {
            const errorMessage = error instanceof Error ? error.message : String(error);
            useUIStore.getState().addNotification({
              type: 'error',
              title: 'Error Creating Line',
              message: `Failed to create line for "${accessory.name}": ${errorMessage}`,
            });
          }
        }

        if (createdLines.length > 0) {
          useUIStore.getState().addNotification({
            type: 'success',
            title: 'Lines Added',
            message: `Successfully added ${createdLines.length} accessory line${createdLines.length > 1 ? 's' : ''} to the quote.`,
          });
          
          // Clear editing state if we were editing
          if (editingLineId) {
            setEditingLineId(null);
          }
          
          // Refresh quote lines
          if (refetchLines) {
            refetchLines();
          }
          
          // Close configurator
          setShowConfigurator(false);
          return;
        } else {
          useUIStore.getState().addNotification({
            type: 'error',
            title: 'Error',
            message: 'No accessory lines were created. Please check the errors above.',
          });
          return;
        }
      }

      // Single panel or legacy format - use existing logic
      // Calculate dimensions in meters
      const width_m = config.width_mm ? config.width_mm / 1000 : null;
      const height_m = config.height_mm ? config.height_mm / 1000 : null;

      if (!width_m || !height_m) {
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'Validation Error',
          message: 'Width and height are required to create a quote line',
        });
        return;
      }

      // Find or create a catalog item for this product type
      let catalogItemId: string | null = null;
      
      // Try to find an existing catalog item for this product type
      const { data: existingItems, error: searchError } = await supabase
        .from('CatalogItems')
        .select('id')
        .eq('organization_id', activeOrganizationId)
        .eq('deleted', false)
        .eq('active', true)
        .ilike('name', `%${productConfig.productType}%`)
        .limit(1);

      if (searchError && import.meta.env.DEV) {
        console.error('Error searching for catalog item:', searchError.message);
      }

      // Extract configuration data to store directly in QuoteLine
      const area = productConfig.area || null;
      const position = productConfig.position ? String(productConfig.position) : null;
      
      // Extract collection_name and variant_name based on product type
      // Note: Now using collection_name directly (text) instead of collection_id (FK)
      let collectionName: string | null = null;
      let variantName: string | null = null;
      let collectionId: string | null = null; // Keep for backward compatibility
      let variantId: string | null = null; // Keep for backward compatibility
      
      if (productConfig.productType === 'roller-shade') {
        collectionName = (productConfig as any).collectionName || (productConfig as any).collectionId || null;
        variantName = (productConfig as any).variantName || (productConfig as any).variantId || null;
        collectionId = (productConfig as any).collectionId || null; // Legacy
        variantId = (productConfig as any).variantId || null; // Legacy
      } else if (productConfig.productType === 'dual-shade' || productConfig.productType === 'triple-shade') {
        // For dual/triple shade, use front fabric as primary
        collectionName = (productConfig as any).frontFabric?.collectionName || (productConfig as any).frontFabric?.collectionId || null;
        variantName = (productConfig as any).frontFabric?.variantName || (productConfig as any).frontFabric?.variantId || null;
        collectionId = (productConfig as any).frontFabric?.collectionId || null; // Legacy
        variantId = (productConfig as any).frontFabric?.variantId || null; // Legacy
      } else if (productConfig.productType === 'drapery' || productConfig.productType === 'awning') {
        collectionName = (productConfig as any).fabric?.collectionName || (productConfig as any).fabric?.collectionId || null;
        variantName = (productConfig as any).fabric?.variantName || (productConfig as any).fabric?.variantId || null;
        collectionId = (productConfig as any).fabric?.collectionId || null; // Legacy
        variantId = (productConfig as any).fabric?.variantId || null; // Legacy
      }
      
      const operatingSystemVariant = (productConfig as any).operatingSystemVariant || null;
      const operatingSystem = (productConfig as any).operatingSystem || null;
      const operatingSystemManufacturer = (productConfig as any).operatingSystemManufacturer || null;
      const installationType = (productConfig as any).installationType || null;
      const installationLocation = (productConfig as any).installationLocation || null;
      const fabricDrop = (productConfig as any).fabricDrop || null;
      
      // Check if operatingSystemVariant is a UUID (for FK) or a string code (legacy)
      const isOperatingSystemVariantUUID = operatingSystemVariant && 
        /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(operatingSystemVariant);
      const operatingSystemDriveId = isOperatingSystemVariantUUID ? operatingSystemVariant : null;
      
      if (!searchError && existingItems && existingItems.length > 0) {
        catalogItemId = existingItems[0].id;
      } else {
        // If no catalog item found, create one
        
        // Determine item_type based on product type
        // For configured products, we'll use 'component' as default
        // since they are typically components of a curtain system
        const itemType = 'component';
        
        const { data: newItem, error: createError } = await supabase
          .from('CatalogItems')
          .insert({
            organization_id: activeOrganizationId,
            sku: `${productConfig.productType.toUpperCase()}-${Date.now()}`,
            name: `${productConfig.productType.replace('-', ' ').replace(/\b\w/g, l => l.toUpperCase())}`,
            description: `Product configuration: ${productConfig.productType}`,
            item_type: itemType, // Required field: component, fabric, linear, service, or accessory
            measure_basis: 'area',
            uom: 'sqm',
            is_fabric: false,
            unit_price: 0,
            cost_price: 0,
            active: true,
            discontinued: false,
            metadata: {
              product_type: productConfig.productType,
              configured: true,
            },
          })
          .select('id')
          .single();

        if (createError) {
          if (import.meta.env.DEV) {
            console.error('Error creating catalog item:', createError.message);
          }
          throw new Error(`Failed to create catalog item for quote line: ${createError.message}`);
        }

        if (!newItem || !newItem.id) {
          throw new Error('Catalog item was created but no ID was returned');
        }

        catalogItemId = newItem.id;
      }

      if (!catalogItemId) {
        throw new Error('Could not find or create catalog item');
      }

      // Get the catalog item to get pricing information
      const { data: catalogItem, error: itemError } = await supabase
        .from('CatalogItems')
        .select('unit_price, measure_basis')
        .eq('id', catalogItemId)
        .single();

      if (itemError) {
        if (import.meta.env.DEV) {
          console.error('Error loading catalog item:', itemError.message);
        }
        throw new Error(`Could not load catalog item details: ${itemError.message}`);
      }

      if (!catalogItem) {
        throw new Error('Catalog item not found after creation');
      }

        // Calculate computed quantity and line total
        const quantity = (productConfig as any).quantity || 1;
        
        // Ensure measure_basis is a valid string value
        const measureBasis = (catalogItem.measure_basis as MeasureBasis) || 'area';
        if (typeof measureBasis !== 'string') {
          if (import.meta.env.DEV) {
            console.error('Invalid measure_basis type:', typeof measureBasis, measureBasis);
          }
          throw new Error(`Invalid measure_basis value: ${measureBasis}. Expected one of: unit, linear_m, area, fabric`);
        }
        
        const computedQty = computeComputedQty(
          measureBasis,
          quantity,
          width_m,
          height_m,
          null, // roll_width_m
          null, // fabric_pricing_mode
        );

        const unitPrice = catalogItem.unit_price || 0;
      const accessoriesTotal = (productConfig as any).accessories?.reduce((sum: number, acc: any) => sum + (acc.price * acc.qty), 0) || 0;
        const lineTotal = (unitPrice * computedQty) + accessoriesTotal;

        // Create QuoteLine in database
        // Ensure all required fields are properly set
        const finalComputedQty = computedQty || 0;
        const finalUnitPrice = unitPrice || 0;
        const finalLineTotal = lineTotal || 0;
        
        // Build quoteLineData - only include operating_system_drive_id if it's a valid UUID
        const quoteLineData: any = {
          quote_id: quoteId,
          catalog_item_id: catalogItemId,
          qty: quantity || 1,
          width_m: width_m || null,
          height_m: height_m || null,
          // Configuration fields - stored directly in QuoteLine
          area: area,
          position: position,
          collection_id: collectionId,
          variant_id: variantId,
          product_type: productConfig.productType,
          operating_system: operatingSystem,
          operating_system_manufacturer: operatingSystemManufacturer,
          installation_type: installationType,
          installation_location: installationLocation,
          fabric_drop: fabricDrop,
          // Snapshots
          measure_basis_snapshot: measureBasis,
          roll_width_m_snapshot: null,
          fabric_pricing_mode_snapshot: null,
          // Computed values
          computed_qty: finalComputedQty,
          unit_price_snapshot: finalUnitPrice,
          unit_cost_snapshot: 0,
          line_total: finalLineTotal,
        };
        
        // Only add operating_system_drive_id if it's a valid UUID
        // This field may not exist if migration hasn't been run yet
        if (operatingSystemDriveId) {
          quoteLineData.operating_system_drive_id = operatingSystemDriveId;
        }

        // Validate all required fields before creating
        if (!quoteId) {
          throw new Error('Quote ID is required');
        }
        if (!catalogItemId) {
          throw new Error('Catalog Item ID is required');
        }
        if (!activeOrganizationId) {
          throw new Error('Organization ID is required');
        }
        if (!measureBasis) {
          throw new Error('Measure basis is required');
        }

        // Check if we're editing an existing line or creating a new one
        if (editingLineId) {
          // Update existing line
          const updatedLine = await updateQuoteLine(editingLineId, quoteLineData);
          
          if (!updatedLine) {
            throw new Error('QuoteLine was not updated - no data returned from updateQuoteLine');
          }

          // Show success notification
          useUIStore.getState().addNotification({
            type: 'success',
            title: 'Line Updated',
            message: `Product configuration has been updated successfully.`,
          });

          // Clear editing state
          setEditingLineId(null);
        } else {
          // Create new line
          const createdLine = await createQuoteLine(quoteLineData);
          
          if (!createdLine) {
            throw new Error('QuoteLine was not created - no data returned from createQuoteLine');
          }
          
          if (!createdLine.id) {
            throw new Error('QuoteLine was created but has no ID');
          }

          // Show success notification
          useUIStore.getState().addNotification({
            type: 'success',
            title: 'Line Added',
            message: `Product configuration for ${productConfig.productType} has been added to the quote.`,
          });
        }

      // Totals are automatically calculated by trigger, just refetch quote and lines
      // Refetch quote to get updated totals
      if (quoteId) {
        const { data: updatedQuote } = await supabase
          .from('Quotes')
          .select('*')
          .eq('id', quoteId)
          .single();
        
        if (updatedQuote) {
          setQuoteData(updatedQuote as Quote);
        }
      }
      
      // Refetch lines to update the UI
      refetchLines();
      
      // Close the configurator modal
      setShowConfigurator(false);
      setEditingLineId(null); // Clear editing state
    } catch (error) {
        if (import.meta.env.DEV) {
          console.error('Error adding line:', error instanceof Error ? error.message : String(error));
        }
        
      const errorMessage = error instanceof Error 
        ? error.message 
        : typeof error === 'object' && error !== null && 'message' in error
        ? String(error.message)
        : 'Failed to add line to quote';
      
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: `Failed to add line to quote: ${errorMessage}`,
      });
    }
  };

  // Close dropdown when clicking outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      const target = event.target as HTMLElement;
      const container = document.querySelector('.customer-search-container');
      if (container && !container.contains(target)) {
        setShowCustomerDropdown(false);
      }
    };

    if (showCustomerDropdown) {
      // Use a small delay to allow click events on dropdown items
      const timeoutId = setTimeout(() => {
        document.addEventListener('mousedown', handleClickOutside);
      }, 100);
      
      return () => {
        clearTimeout(timeoutId);
        document.removeEventListener('mousedown', handleClickOutside);
      };
    }
  }, [showCustomerDropdown]);

  // Show message if no organization is selected
  if (!activeOrganizationId) {
    return (
      <div className="py-6 px-6">
        <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
          <p className="text-sm text-yellow-800">
            Select an organization to continue.
          </p>
        </div>
      </div>
    );
  }

  const onSubmit = async (values: QuoteFormValues, shouldClose: boolean = false) => {
    if (!activeOrganizationId) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: 'No organization selected. Please select an organization.',
      });
      return;
    }

    // Validate form before saving
    const isValid = await trigger();
    if (!isValid) {
      const missingFields: string[] = [];
      
      if (errors.quote_no) missingFields.push('Quote Number');
      if (errors.customer_id) missingFields.push('Customer');
      if (errors.status) missingFields.push('Status');
      if (errors.currency) missingFields.push('Currency');
      
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Missing Required Information',
        message: missingFields.length > 0 
          ? `Please complete the following required fields: ${missingFields.join(', ')}.`
          : 'Please complete all required fields before saving.',
      });
      return;
    }

    setIsSaving(true);
    setSaveError(null);

    try {
      const quoteData: any = {
        quote_no: values.quote_no.trim(),
        customer_id: values.customer_id,
        status: values.status,
        currency: values.currency,
        notes: values.notes?.trim() || null,
        totals: {
          subtotal: 0,
          discount_total: 0,
          tax: 0,
          total: 0,
        },
      };

      // Check if we have a quoteId - this determines if we're editing or creating
      // Also check URL to be sure
      const path = window.location.pathname;
      const urlMatch = path.match(/\/sales\/quotes\/edit\/([^/]+)/);
      const editQuoteId = urlMatch ? urlMatch[1] : null;
      
      const finalQuoteId = quoteId || editQuoteId;
      
      if (finalQuoteId) {
        // Update existing quote
        // Always verify quote_no doesn't exist for another quote (even if it hasn't changed, this prevents race conditions)
        const { data: duplicateCheck, error: checkError } = await supabase
          .from('Quotes')
          .select('id, quote_no')
          .eq('organization_id', activeOrganizationId)
          .eq('quote_no', values.quote_no.trim())
          .eq('deleted', false)
          .neq('id', finalQuoteId) // Exclude current quote
          .maybeSingle();

        if (checkError && checkError.code !== 'PGRST116') {
          // PGRST116 means no rows found, which is fine
          if (import.meta.env.DEV) {
            console.error('Error checking for duplicate quote_no:', checkError.message);
          }
        }

        if (duplicateCheck) {
          throw new Error(`Quote number "${values.quote_no.trim()}" already exists. Please use a different quote number.`);
        }

        await updateQuote(finalQuoteId, quoteData);
        useUIStore.getState().addNotification({
          type: 'success',
          title: 'Quote updated',
          message: 'Quote has been updated successfully.',
        });
      } else {
        // Create new quote - verify quote_no doesn't already exist
        const { data: duplicateCheck } = await supabase
          .from('Quotes')
          .select('id')
          .eq('organization_id', activeOrganizationId)
          .eq('quote_no', values.quote_no.trim())
          .eq('deleted', false)
          .maybeSingle();

        if (duplicateCheck) {
          throw new Error(`Quote number "${values.quote_no.trim()}" already exists. Please use a different quote number.`);
        }

        // Create new quote
        const created = await createQuote(quoteData);
        
        // Update quoteId state so we can edit it later
        if (created?.id) {
          setQuoteId(created.id);
          // Store quote data to access totals
          setQuoteData(created);
          // Update URL to edit mode (using window.history to replace current entry)
          window.history.replaceState({}, '', `/sales/quotes/edit/${created.id}`);
        }
        
        useUIStore.getState().addNotification({
          type: 'success',
          title: 'Quote created',
          message: 'Quote has been created successfully.',
        });
      }

      // Only navigate away if shouldClose is true
      if (shouldClose) {
        router.navigate('/sales/quotes');
      }
    } catch (err: any) {
      if (import.meta.env.DEV) {
        console.error('Error saving quote:', err.message || 'Unknown error');
      }
      
      // Extract a more user-friendly error message
      let errorMessage = err.message || 'Failed to save quote. Please try again.';
      
      // Handle specific database constraint errors
      if (err.message?.includes('duplicate key') || err.message?.includes('unique constraint')) {
        if (err.message?.includes('quote_no')) {
          errorMessage = `Quote number "${values.quote_no.trim()}" already exists. Please use a different quote number.`;
        } else {
          errorMessage = 'This record already exists. Please check your input and try again.';
        }
      }
      
      setSaveError(errorMessage);
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error saving quote',
        message: errorMessage,
      });
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <div className="py-6 px-6">
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
        
        {/* Action Buttons */}
        <div className="flex items-center gap-3">
          <button
            type="button"
            onClick={() => router.navigate('/sales/quotes')}
            className="px-3 py-1.5 rounded border border-gray-300 bg-white text-gray-700 transition-colors text-sm hover:bg-gray-50"
            title="Close without saving"
            disabled={isSaving}
          >
            Close
          </button>
          {!isReadOnly && (
            <button
              type="button"
              className="px-3 py-1.5 rounded text-white transition-colors text-sm hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed"
              style={{ backgroundColor: 'var(--primary-brand-hex)' }}
              onClick={handleSubmit((values) => onSubmit(values, false))}
              disabled={isSaving}
              title="Save and stay on page"
            >
              {isSaving ? 'Saving...' : 'Save'}
            </button>
          )}
          <button
            type="button"
            className="px-3 py-1.5 rounded text-white transition-colors text-sm hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed"
            style={{ backgroundColor: isReadOnly ? 'var(--primary-brand-hex)' : '#10b981' }}
            onClick={handleSubmit((values) => onSubmit(values, true))}
            disabled={isSaving || isReadOnly}
            title={isReadOnly ? 'You only have read permissions' : 'Save and return to quotes list'}
          >
            {isSaving ? 'Saving...' : isReadOnly ? 'Read Only' : 'Save and Close'}
          </button>
        </div>
      </div>

      {saveError && (
        <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded text-red-700 text-sm">
          {saveError}
        </div>
      )}

      {/* Main Content Card */}
      <div className="bg-white border border-gray-200 rounded-lg overflow-hidden mb-4">
        {/* Form Body */}
        <div className="py-6 px-6">
          <div className="grid grid-cols-12 gap-x-4 gap-y-4">
            {/* First Row: Quote Number, Customer, Contact, Status */}
            <div className="col-span-12 grid grid-cols-12 gap-x-4 gap-y-3">
              {/* Quote Number */}
              <div className="col-span-3">
                <Label htmlFor="quote_no" className="text-xs" required>Quote Number</Label>
                <Input 
                  id="quote_no" 
                  {...register('quote_no')}
                  className="py-1 text-xs"
                  error={errors.quote_no?.message}
                  disabled={isReadOnly}
                  placeholder="QT-000001"
                />
              </div>
              
              {/* Customer */}
              <div className="col-span-4">
                <div className="flex items-center gap-2 mb-1">
                  <Label htmlFor="customer_id" className="text-xs" required>Customer</Label>
                  {watch('customer_id') && (() => {
                    const selectedCustomer = customers.find(c => c.id === watch('customer_id'));
                    if (selectedCustomer?.pricing_tier_code && selectedCustomer?.discount_pct) {
                      return (
                        <span className="text-xs px-2 py-0.5 bg-purple-100 text-purple-700 rounded font-medium">
                          {selectedCustomer.pricing_tier_code} ({selectedCustomer.discount_pct}% off)
                        </span>
                      );
                    }
                    return null;
                  })()}
                </div>
                <div className="relative customer-search-container">
                  <div className="relative">
                    <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400" />
                    <input
                      type="text"
                      placeholder={loadingCustomers ? "Loading customers..." : customers.length === 0 ? "No customers available. Create one first." : "Search customer or contact..."}
                      value={customerSearchTerm}
                      onChange={(e) => {
                        setCustomerSearchTerm(e.target.value);
                        setShowCustomerDropdown(true);
                      }}
                      onFocus={() => {
                        setShowCustomerDropdown(true);
                      }}
                      onClick={() => {
                        setShowCustomerDropdown(true);
                      }}
                      onBlur={(e) => {
                        // Don't close if clicking on dropdown
                        const relatedTarget = e.relatedTarget as HTMLElement;
                        if (relatedTarget && relatedTarget.closest('.customer-search-container')) {
                          return;
                        }
                        // Delay closing to allow click on dropdown items
                        setTimeout(() => {
                          setShowCustomerDropdown(false);
                        }, 200);
                      }}
                      className={`w-full pl-10 pr-10 py-1 text-xs border rounded-md transition-colors focus:outline-none focus:ring-2 focus:ring-offset-0 ${
                        errors.customer_id 
                          ? 'border-red-300 bg-red-50 focus:ring-red-500/20 focus:border-red-500' 
                          : 'border-gray-200 bg-gray-50 focus:ring-primary/20 focus:border-primary/50'
                      } ${isReadOnly ? 'opacity-50 cursor-not-allowed' : ''}`}
                      disabled={loadingCustomers || isReadOnly}
                      readOnly={false}
                    />
                    {watch('customer_id') && (
                      <button
                        type="button"
                        onClick={(e) => {
                          e.stopPropagation();
                          setValue('customer_id', '', { shouldValidate: true });
                          setCustomerSearchTerm('');
                          setShowCustomerDropdown(false);
                        }}
                        className="absolute right-2 top-1/2 transform -translate-y-1/2 p-1 hover:bg-gray-100 rounded"
                        disabled={isReadOnly}
                      >
                        <X className="w-3 h-3 text-gray-400" />
                      </button>
                    )}
                  </div>
                  
                  {/* Customer Dropdown */}
                  {showCustomerDropdown && !loadingCustomers && customers.length > 0 && (
                    <>
                      {filteredCustomers.length > 0 && (
                    <div className="absolute z-50 w-full mt-1 bg-white border border-gray-200 rounded-lg shadow-lg max-h-60 overflow-y-auto">
                      {filteredCustomers.map((customer) => (
                        <div key={customer.id}>
                          {/* Customer Option */}
                          <div
                            onMouseDown={(e) => {
                              e.preventDefault(); // Prevent input blur
                            }}
                            onClick={() => {
                              setValue('customer_id', customer.id, { shouldValidate: true });
                              setCustomerSearchTerm(customer.customer_name);
                              setShowCustomerDropdown(false);
                            }}
                            className={`px-3 py-2 hover:bg-gray-50 cursor-pointer border-b border-gray-100 ${
                              watch('customer_id') === customer.id ? 'bg-blue-50' : ''
                            }`}
                          >
                            <div className="flex items-center justify-between">
                              <div className="flex-1">
                                <p className="text-xs font-medium text-gray-900">{customer.customer_name}</p>
                                {customer.primary_contact && (
                                  <p className="text-xs text-gray-500 mt-0.5">
                                    Primary: {customer.primary_contact.contact_name}
                                  </p>
                                )}
                                {customer.pricing_tier_code && customer.discount_pct && (
                                  <p className="text-xs text-purple-600 font-medium mt-0.5">
                                    {customer.pricing_tier_code} ({customer.discount_pct}% discount)
                                  </p>
                                )}
                              </div>
                              {watch('customer_id') === customer.id && (
                                <div className="ml-2">
                                  <div className="w-2 h-2 bg-primary rounded-full"></div>
                                </div>
                              )}
                            </div>
                          </div>
                          
                          {/* Show all contacts for this customer */}
                          {customer.contacts && customer.contacts.length > 0 && (
                            <div className="bg-gray-50 pl-6">
                              {customer.contacts.map((contact) => (
                                <div
                                  key={contact.id}
                                  onMouseDown={(e) => {
                                    e.preventDefault(); // Prevent input blur
                                  }}
                                  onClick={(e) => {
                                    e.stopPropagation();
                                    setValue('customer_id', customer.id, { shouldValidate: true });
                                    setCustomerSearchTerm(`${customer.customer_name} - ${contact.contact_name}`);
                                    setShowCustomerDropdown(false);
                                  }}
                                  className="px-3 py-1.5 hover:bg-gray-100 cursor-pointer text-xs"
                                >
                                  <p className="text-gray-700">
                                    <span className="font-medium">{contact.contact_name}</span>
                                  </p>
                                </div>
                              ))}
                            </div>
                          )}
                        </div>
                      ))}
                      </div>
                      )}
                  
                      {/* Show message when no results found */}
                      {filteredCustomers.length === 0 && customerSearchTerm.trim() && (
                        <div className="absolute z-50 w-full mt-1 bg-white border border-gray-200 rounded-lg shadow-lg p-3">
                          <p className="text-xs text-gray-500 text-center">No customers found matching "{customerSearchTerm}"</p>
                        </div>
                      )}
                    </>
                  )}
                  
                  {/* Show message when no customers available */}
                  {showCustomerDropdown && !loadingCustomers && customers.length === 0 && (
                    <div className="absolute z-50 w-full mt-1 bg-yellow-50 border border-yellow-200 rounded-lg shadow-lg p-3">
                      <p className="text-xs text-yellow-800 text-center">
                        No customers available. Please create a customer first in the Directory module.
                      </p>
                    </div>
                  )}
                </div>
                
                
                {errors.customer_id && (
                  <p className="text-xs text-red-600 mt-1">{errors.customer_id.message}</p>
                )}
              </div>
              
              {/* Contact Selector */}
              <div className="col-span-3">
                <Label htmlFor="contact_id" className="text-xs">Contact</Label>
                <SelectShadcn
                  value={selectedContactId}
                  onValueChange={(value) => {
                    setSelectedContactId(value);
                  }}
                  disabled={!selectedCustomer || isReadOnly || availableContacts.length === 0}
                >
                  <SelectTrigger className="py-1 text-xs">
                    <SelectValue placeholder={
                      !selectedCustomer 
                        ? "Select customer first" 
                        : availableContacts.length === 0 
                        ? "No contacts available" 
                        : "Select contact"
                    } />
                  </SelectTrigger>
                  <SelectContent>
                    {availableContacts.map((contact) => (
                      <SelectItem key={contact.id} value={contact.id}>
                        {contact.contact_name}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </SelectShadcn>
              </div>
              
              {/* Quote Status - Aligned to right */}
              <div className="col-span-2 flex justify-end">
                <div className="w-full">
                  <Label htmlFor="status" className="text-xs" required>Status</Label>
                  <SelectShadcn
                  value={watch('status') || 'draft'}
                  onValueChange={(value) => {
                    setValue('status', value as 'draft' | 'sent' | 'approved' | 'rejected', { shouldValidate: true });
                  }}
                    disabled={isReadOnly}
                  >
                    <SelectTrigger className={`py-1 text-xs ${errors.status ? 'border-red-300 bg-red-50' : ''}`}>
                      <SelectValue placeholder="Select status" />
                    </SelectTrigger>
                    <SelectContent>
                      {QUOTE_STATUS_OPTIONS.map((option) => (
                        <SelectItem key={option.value} value={option.value}>
                          {option.label}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </SelectShadcn>
                  {errors.status && (
                    <p className="text-xs text-red-600 mt-1">{errors.status.message}</p>
                  )}
                </div>
              </div>
            </div>
            
            {/* Second Row: Currency */}
            <div className="col-span-12 grid grid-cols-12 gap-x-4 gap-y-3">
              <div className="col-span-3">
                <Label htmlFor="currency" className="text-xs" required>Currency</Label>
                <SelectShadcn
                  value={watch('currency') || 'USD'}
                  onValueChange={(value) => {
                    setValue('currency', value, { shouldValidate: true });
                  }}
                  disabled={isReadOnly}
                >
                  <SelectTrigger className={`py-1 text-xs ${errors.currency ? 'border-red-300 bg-red-50' : ''}`}>
                    <SelectValue placeholder="Select currency" />
                  </SelectTrigger>
                  <SelectContent>
                    {CURRENCY_OPTIONS.map((option) => (
                      <SelectItem key={option.value} value={option.value}>
                        {option.label}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </SelectShadcn>
                {errors.currency && (
                  <p className="text-xs text-red-600 mt-1">{errors.currency.message}</p>
                )}
              </div>
            </div>

            {/* Notes */}
            <div className="col-span-12">
              <Label htmlFor="notes" className="text-xs">Notes</Label>
              <textarea
                id="notes"
                {...register('notes')}
                className="w-full px-2.5 py-1.5 text-xs border border-gray-200 bg-gray-50 rounded-md focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50 disabled:opacity-50"
                rows={4}
                disabled={isReadOnly}
                placeholder="Add any additional notes or comments..."
              />
            </div>
            
            {/* Quote Total Summary */}
            {quoteId && (
              <div className="col-span-12 border-t border-gray-200 pt-4 mt-4">
                <div className="flex justify-end">
                  <div className="w-64">
                    <div className="space-y-2">
                      <div className="flex justify-between text-sm">
                        <span className="text-gray-600">Subtotal:</span>
                        <span className="text-gray-900 font-medium">
                          {formatCurrency(quoteTotals.subtotal, watch('currency') || 'USD')}
                        </span>
                      </div>
                      {quoteTotals.discount_total > 0 && (
                        <div className="flex justify-between text-sm">
                          <span className="text-gray-600">Discount:</span>
                          <span className="text-gray-900 font-medium text-red-600">
                            -{formatCurrency(quoteTotals.discount_total, watch('currency') || 'USD')}
                          </span>
                        </div>
                      )}
                      {quoteTotals.tax > 0 && (
                        <div className="flex justify-between text-sm">
                          <span className="text-gray-600">Tax:</span>
                          <span className="text-gray-900 font-medium">
                            {formatCurrency(quoteTotals.tax, watch('currency') || 'USD')}
                          </span>
                        </div>
                      )}
                      <div className="border-t border-gray-200 pt-2 flex justify-between">
                        <span className="text-sm font-semibold text-gray-900">Total:</span>
                        <span className="text-sm font-semibold text-gray-900">
                          {formatCurrency(quoteTotals.total, watch('currency') || 'USD')}
                        </span>
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
                <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
                  {loadingLines ? 'Loading...' : `${quoteLines.length} line${quoteLines.length !== 1 ? 's' : ''}`}
                </p>
              </div>
              {!isReadOnly && (
                <button
                  type="button"
                  onClick={() => {
                    setEditingLineId(null); // Clear any editing state
                    setShowConfigurator(true);
                  }}
                  className="flex items-center gap-2 px-3 py-1.5 rounded text-white transition-colors text-sm hover:opacity-90"
                  style={{ backgroundColor: 'var(--primary-brand-hex)' }}
                >
                  <Plus style={{ width: '14px', height: '14px' }} />
                  Add Line
                </button>
              )}
            </div>
          </div>

          {loadingLines ? (
            <div className="py-12 text-center">
              <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary mx-auto mb-4"></div>
              <p className="text-sm text-gray-600">Loading quote lines...</p>
            </div>
          ) : quoteLines.length === 0 ? (
            <div className="py-12 text-center">
              <p className="text-sm text-gray-600 mb-2">No lines added yet</p>
              <p className="text-xs text-gray-500">Click "Add Line" to configure a curtain</p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead className="bg-gray-50 border-b border-gray-200">
                  <tr>
                    <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Area</th>
                    <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Position</th>
                    <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Product Type</th>
                    <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Collection</th>
                    <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">System Drive</th>
                    <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Measurements (mm)</th>
                    <th className="text-right py-3 px-6 font-medium text-gray-900 text-xs">Qty</th>
                    <th className="text-right py-3 px-6 font-medium text-gray-900 text-xs">Unit Price</th>
                    <th className="text-right py-3 px-6 font-medium text-gray-900 text-xs">Margin</th>
                    <th className="text-right py-3 px-6 font-medium text-gray-900 text-xs">Discount</th>
                    <th className="text-right py-3 px-6 font-medium text-gray-900 text-xs">Final Price</th>
                    <th className="text-right py-3 px-6 font-medium text-gray-900 text-xs">Total</th>
                    {!isReadOnly && (
                      <th className="text-right py-3 px-6 font-medium text-gray-900 text-xs">Actions</th>
                    )}
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-200">
                  {quoteLines.map((line) => {
                    const item = (line as any).Item;
                    const collection = (line as any).Collection;
                    const systemDriveItem = (line as any).SystemDriveItem;
                    
                    // Read configuration fields directly from QuoteLine
                    const area = (line as any).area || null;
                    const position = (line as any).position || null;
                    const collectionId = (line as any).collection_id || null;
                    const collectionNameFromLine = (line as any).collection_name || null;
                    const productType = (line as any).product_type || null;
                    
                    // Get collection name from line (preferred), joined data, or fallback to helper function
                    const collectionName = collectionNameFromLine || collection?.name || (collectionId ? getCollectionName(collectionId) : 'N/A');
                    
                    // Get operating system drive name from joined SystemDriveItem
                    const systemDriveName = systemDriveItem?.name ?? 'N/A';
                    
                    // Check if this is part of a multi-panel configuration
                    const metadata = (line as any).metadata || {};
                    const totalPanels = metadata.total_panels as number | undefined;
                    const panels = metadata.panels as Array<{ width_mm: number }> | undefined;
                    const isMultiPanel = totalPanels && totalPanels > 1 && panels && panels.length > 1;
                    
                    return (
                      <React.Fragment key={line.id}>
                      <tr 
                        className="border-b border-gray-100 hover:bg-gray-50 transition-colors cursor-pointer"
                        onClick={() => {
                          // Toggle cost expansion on row click
                          setExpandedLineId(expandedLineId === line.id ? null : line.id);
                        }}
                      >
                        <td className="py-4 px-6 text-gray-700 text-sm">
                          {area || <span className="text-gray-500">N/A</span>}
                        </td>
                        <td className="py-4 px-6 text-gray-700 text-sm">
                          {position || <span className="text-gray-500">N/A</span>}
                        </td>
                        <td className="py-4 px-6 text-gray-900 text-sm">
                          <div className="font-medium">
                            {(() => {
                              // For fabrics: Collection + Variant
                              // For others: item_name
                              const isFabric = (line as any).is_fabric || item?.is_fabric;
                              const collectionName = (line as any).collection_name || collection?.name;
                              const variantName = (line as any).variant_name || item?.variant_name;
                              const itemName = (line as any).item_name || item?.item_name || item?.name;
                              
                              if (productType) {
                                return getProductTypeName(productType);
                              }
                              
                              let displayName: string;
                              if (isFabric && collectionName && variantName) {
                                // For fabrics: Collection + Variant
                                displayName = `${collectionName} ${variantName}`;
                              } else {
                                // For non-fabrics: item_name
                                displayName = itemName || 'N/A';
                              }
                              
                              return (
                                <div>
                                  <div className="font-medium">{displayName}</div>
                                  {item?.sku && (
                                    <div className="text-xs text-gray-500 mt-0.5">{item.sku}</div>
                                  )}
                                </div>
                              );
                            })()}
                          </div>
                        </td>
                        <td className="py-4 px-6 text-gray-700 text-sm">
                          {collectionName || <span className="text-gray-500">N/A</span>}
                        </td>
                        <td className="py-4 px-6 text-gray-700 text-sm">
                          {systemDriveName || <span className="text-gray-500">N/A</span>}
                        </td>
                        <td className="py-4 px-6 text-gray-900 text-sm">
                          {(() => {
                            // If it's a multi-panel config, show all panels stacked and aligned
                            // Convention: Width (Ancho) on the left, Height (Alto) on the right
                            // First panel shows: "1000 × 2000"
                            // Additional panels show only width (Ancho) stacked below the first panel's width
                            // Only one × symbol (in the first line)
                            if (isMultiPanel && panels && panels.length > 0) {
                              const height_mm = line.height_m ? Math.round(line.height_m * 1000) : 0;
                              
                              return (
                                <div className="space-y-0.5">
                                  {/* Panel 1: Full measurement (Ancho × Alto) - only line with × */}
                                  <div className="font-medium text-gray-900">
                                    {panels[0]?.width_mm || 0} × {height_mm}
                                  </div>
                                  {/* Additional panels: Only width (Ancho), stacked below first panel's width */}
                                  {panels.length > 1 && panels.slice(1).map((p: any, idx: number) => {
                                    return (
                                      <div key={idx + 1} className="font-medium text-gray-900">
                                        {p.width_mm || 0}
                                      </div>
                                    );
                                  })}
                                </div>
                              );
                            }
                            
                            // Single panel or legacy format
                            if (line.width_m && line.height_m) {
                              return (
                                <span className="font-medium text-gray-900">
                                  {Math.round(line.width_m * 1000)} × {Math.round(line.height_m * 1000)}
                                </span>
                              );
                            }
                            return <span className="text-gray-500">N/A</span>;
                          })()}
                        </td>
                        <td className="py-4 px-6 text-right text-gray-900 text-sm font-medium">
                          {line.computed_qty.toFixed(2)}
                        </td>
                        <td className="py-4 px-6 text-right text-gray-900 text-sm">
                          <div className="font-medium">
                            €{line.unit_price_snapshot.toFixed(2)}
                          </div>
                        </td>
                        <td className="py-4 px-6 text-right text-gray-900 text-sm">
                          {line.margin_percentage_used !== null && line.margin_percentage_used !== undefined ? (
                            <div className="space-y-0.5">
                              <div className="font-medium">
                                {line.margin_percentage_used.toFixed(2)}%
                              </div>
                              {line.margin_source && (
                                <div className="text-xs text-gray-500">
                                  {line.margin_source === 'category' && (
                                    <span className="text-blue-600" title="Using category margin">Category</span>
                                  )}
                                  {line.margin_source === 'item' && (
                                    <span className="text-gray-600" title="Using item default margin">Item</span>
                                  )}
                                  {line.margin_source === 'default' && (
                                    <span className="text-gray-400" title="Using default 35% margin">Default</span>
                                  )}
                                </div>
                              )}
                            </div>
                          ) : (
                            <span className="text-gray-400 text-xs">N/A</span>
                          )}
                        </td>
                        <td className="py-4 px-6 text-right text-gray-900 text-sm">
                          {line.discount_percentage !== null && line.discount_percentage !== undefined && line.discount_percentage > 0 ? (
                            <div className="space-y-0.5">
                              <div className="font-medium text-green-600">
                                -{line.discount_percentage.toFixed(2)}%
                              </div>
                              {line.discount_amount !== null && line.discount_amount !== undefined && (
                                <div className="text-xs text-gray-500">
                                  -€{line.discount_amount.toFixed(2)}
                                </div>
                              )}
                              {line.discount_source && (
                                <div className="text-xs text-gray-500">
                                  {line.discount_source === 'customer_type' && (
                                    <span className="text-purple-600" title="Customer type discount">Type</span>
                                  )}
                                  {line.discount_source === 'manual_customer' && (
                                    <span className="text-blue-600" title="Customer manual discount">Customer</span>
                                  )}
                                  {line.discount_source === 'manual_line' && (
                                    <span className="text-orange-600" title="Manual line discount override">Manual</span>
                                  )}
                                </div>
                              )}
                            </div>
                          ) : (
                            <span className="text-gray-400 text-xs">—</span>
                          )}
                        </td>
                        <td className="py-4 px-6 text-right text-gray-900 text-sm">
                          <div className="font-medium">
                            €{(line.final_unit_price || line.unit_price_snapshot || 0).toFixed(2)}
                          </div>
                          {line.final_unit_price !== null && line.final_unit_price !== undefined && line.final_unit_price < line.unit_price_snapshot && (
                            <div className="text-xs text-gray-500 line-through">
                              €{line.unit_price_snapshot.toFixed(2)}
                            </div>
                          )}
                        </td>
                        <td className="py-4 px-6 text-right text-gray-900 text-sm">
                          <div className="font-medium">
                            €{line.line_total.toFixed(2)}
                          </div>
                          <button
                            type="button"
                            onClick={(e) => {
                              e.stopPropagation();
                              setExpandedLineId(expandedLineId === line.id ? null : line.id);
                            }}
                            className="text-xs text-primary hover:underline mt-1"
                          >
                            {expandedLineId === line.id ? 'Hide Costs' : 'View Costs'}
                          </button>
                        </td>
                        {!isReadOnly && (
                          <td className="py-4 px-6" onClick={(e) => e.stopPropagation()}>
                            <div className="flex items-center gap-1 justify-end">
                              <button
                                onClick={() => {
                                  // Convert QuoteLine to ProductConfig for editing
                                  const initialConfig = adaptQuoteLineToProductConfig(line as any);
                                  setEditingLineId(line.id);
                                  setShowConfigurator(true);
                                }}
                                className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600"
                                aria-label="Edit line"
                                title="Edit line"
                              >
                                <Edit className="w-4 h-4" />
                              </button>
                              <button
                                onClick={async () => {
                                  const confirmed = await showConfirm({
                                    title: 'Eliminar Línea',
                                    message: '¿Estás seguro de que deseas eliminar esta línea?',
                                    variant: 'danger',
                                    confirmText: 'Eliminar',
                                    cancelText: 'Cancelar',
                                  });

                                  if (!confirmed) return;
                                  
                                    try {
                                      setLoading(true);
                                      await supabase
                                        .from('QuoteLines')
                                        .update({ deleted: true })
                                        .eq('id', line.id);
                                    
                                    // Totals are automatically calculated by trigger, just refetch quote and lines
                                    const { data: updatedQuote } = await supabase
                                      .from('Quotes')
                                      .select('*')
                                      .eq('id', quoteId)
                                      .single();
                                    
                                    if (updatedQuote) {
                                      setQuoteData(updatedQuote as Quote);
                                    }
                                    
                                    refetchLines();
                                      useUIStore.getState().addNotification({
                                        type: 'success',
                                        title: 'Line deleted',
                                        message: 'Quote line has been removed',
                                      });
                                    } catch (error) {
                                      useUIStore.getState().addNotification({
                                        type: 'error',
                                        title: 'Error',
                                        message: 'Failed to delete line',
                                      });
                                    } finally {
                                      setLoading(false);
                                    }
                                  }}
                                className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600"
                                aria-label="Delete line"
                                title="Delete line"
                              >
                                <Trash2 className="w-4 h-4" />
                              </button>
                            </div>
                          </td>
                        )}
                      </tr>
                      {/* Expandable Cost Summary Row */}
                      {expandedLineId === line.id && (
                        <tr className="bg-gray-50">
                          <td colSpan={isReadOnly ? 8 : 9} className="py-4 px-6">
                            <QuoteLineCostsSectionV1
                              quoteLineId={line.id}
                              currency={watch('currency') || 'USD'}
                              onUpdate={() => {
                                refetchLines();
                              }}
                            />
                          </td>
                        </tr>
                      )}
                      </React.Fragment>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}

      {/* Product Configurator Modal */}
      {showConfigurator && quoteId && (() => {
        // Get initial config if editing
        const editingLine = editingLineId ? quoteLines.find(l => l.id === editingLineId) : null;
        const initialConfig = editingLine ? adaptQuoteLineToProductConfig(editingLine as any) : undefined;
        
        return (
          <div key="product-configurator-modal" className="fixed inset-0 bg-black bg-opacity-50 z-50 flex items-center justify-center">
            <div className="bg-white rounded-lg w-full h-full max-w-7xl m-4 overflow-hidden">
              <ProductConfigurator
                quoteId={quoteId}
                onComplete={handleProductConfigComplete}
                onClose={() => {
                  setShowConfigurator(false);
                  setEditingLineId(null); // Clear editing state when closing
                }}
                initialConfig={initialConfig}
              />
            </div>
          </div>
        );
      })()}

      {/* Confirm Dialog */}
      <ConfirmDialog
        isOpen={dialogState.isOpen}
        onClose={closeDialog}
        onConfirm={handleConfirm}
        title={dialogState.title}
        message={dialogState.message}
        confirmText={dialogState.confirmText}
        cancelText={dialogState.cancelText}
        variant={dialogState.variant}
        isLoading={dialogState.isLoading}
      />
    </div>
  );
}


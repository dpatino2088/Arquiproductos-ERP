import { useState, useEffect, useMemo } from 'react';
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
import { useCreateQuote, useUpdateQuote, useQuotes, useQuoteLines, useCreateQuoteLine } from '../../hooks/useQuotes';
import { QuoteStatus, MeasureBasis } from '../../types/catalog';
import { Search, X, Plus, Edit, Trash2 } from 'lucide-react';
import ProductConfigurator from './ProductConfigurator';
import { ProductConfig } from './product-config/types';
import { adaptFromProductConfig } from './product-config/adapters';
import { CurtainConfiguration } from './CurtainConfigurator'; // Keep for backward compatibility
import { computeComputedQty } from '../../lib/catalog/computeComputedQty';

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
}

export default function QuoteNew() {
  const [isSaving, setIsSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [quoteId, setQuoteId] = useState<string | null>(null);
  const [customers, setCustomers] = useState<CustomerWithContacts[]>([]);
  const [allContacts, setAllContacts] = useState<Contact[]>([]);
  const [loadingCustomers, setLoadingCustomers] = useState(true);
  const [quoteNo, setQuoteNo] = useState<string>('');
  const [customerSearchTerm, setCustomerSearchTerm] = useState('');
  const [showCustomerDropdown, setShowCustomerDropdown] = useState(false);
  const [selectedContactId, setSelectedContactId] = useState<string>('');
  const [showConfigurator, setShowConfigurator] = useState(false);
  
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
  const { activeOrganizationId } = useOrganizationContext();
  const { createQuote, isCreating } = useCreateQuote();
  const { updateQuote, isUpdating } = useUpdateQuote();
  const { quotes } = useQuotes();
  const { lines: quoteLines, loading: loadingLines, refetch: refetchLines } = useQuoteLines(quoteId);
  const { createLine: createQuoteLine, isCreating: isCreatingLine } = useCreateQuoteLine();
  
  // Calculate total from all lines
  const calculatedTotal = useMemo(() => {
    return quoteLines.reduce((sum, line) => sum + (line.line_total || 0), 0);
  }, [quoteLines]);
  
  // Get current user's role and permissions
  const { canEditCustomers, loading: roleLoading } = useCurrentOrgRole();
  
  // Determine if form should be read-only
  const isReadOnly = !canEditCustomers;

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
        console.log('Quote ID from URL:', id);
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
        // Get the last quote number for this organization
        const { data, error } = await supabase
          .from('Quotes')
          .select('quote_no')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .order('created_at', { ascending: false })
          .limit(1);

        if (error && error.code !== 'PGRST116') {
          console.error('Error fetching last quote:', error);
        }

        let nextNumber = 1;
        if (data && data.length > 0) {
          // Use quote_no from database
          const lastQuoteNo = (data[0] as any).quote_no;
          if (lastQuoteNo) {
            const match = lastQuoteNo.match(/\d+/);
            if (match) {
              nextNumber = parseInt(match[0], 10) + 1;
            }
          }
        }

        // Format as QT-000001, QT-000002, etc.
        const formattedNo = `QT-${String(nextNumber).padStart(6, '0')}`;
        setQuoteNo(formattedNo);
        setValue('quote_no', formattedNo, { shouldValidate: true });
      } catch (err) {
        console.error('Error generating quote number:', err);
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
          console.error('Error loading quote:', error);
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
          setValue('quote_no', quoteNumber);
          setValue('customer_id', data.customer_id || '');
          setValue('status', data.status || 'draft');
          setValue('currency', data.currency || 'USD');
          setValue('notes', data.notes || '');
        }
      } catch (err) {
        console.error('Error loading quote data:', err);
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
        const { data: customersData, error: customersError } = await supabase
          .from('DirectoryCustomers')
          .select('id, customer_name, primary_contact_id')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .eq('archived', false)
          .order('customer_name', { ascending: true });

        if (customersError) {
          console.error('Error loading customers:', customersError);
          useUIStore.getState().addNotification({
            type: 'error',
            title: 'Error loading customers',
            message: customersError.message || 'Could not load customers',
          });
          return;
        }

        // Load Contacts
        const { data: contactsData, error: contactsError } = await supabase
          .from('DirectoryContacts')
          .select('id, contact_name, email, primary_phone, customer_id')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .order('contact_name', { ascending: true });

        if (contactsError) {
          console.error('Error loading contacts:', contactsError);
          // Continue even if contacts fail
        }

        // Combine customers with their contacts
        const customersWithContacts: CustomerWithContacts[] = (customersData || []).map((customer) => {
          const customerContacts = (contactsData || []).filter(
            (contact: Contact) => contact.customer_id === customer.id
          );
          const primaryContact = customer.primary_contact_id
            ? customerContacts.find((c: Contact) => c.id === customer.primary_contact_id) || null
            : null;

          return {
            id: customer.id,
            customer_name: customer.customer_name,
            primary_contact_id: customer.primary_contact_id,
            contacts: customerContacts,
            primary_contact: primaryContact,
          };
        });

        setCustomers(customersWithContacts);
        setAllContacts(contactsData || []);
      } catch (err) {
        console.error('Error loading customers and contacts:', err);
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
    if (quoteId && customers.length > 0 && watch('customer_id')) {
      const selectedCustomer = customers.find(c => c.id === watch('customer_id'));
      if (selectedCustomer && !customerSearchTerm) {
        setCustomerSearchTerm(selectedCustomer.customer_name);
      }
    }
  }, [quoteId, customers, watch('customer_id'), customerSearchTerm]);

  // Filter customers and contacts based on search term
  const filteredCustomers = useMemo(() => {
    if (!customerSearchTerm.trim()) return customers;
    const searchLower = customerSearchTerm.toLowerCase().trim();
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

      if (searchError) {
        console.error('Error searching for catalog item:', searchError);
      }

      // Extract configuration data to store in metadata
      const area = productConfig.area || null;
      const position = productConfig.position || null;
      const collectionId = (productConfig as any).collectionId || 
                          (productConfig as any).frontFabric?.collectionId || 
                          (productConfig as any).fabric?.collectionId || 
                          null;
      const operatingSystemVariant = (productConfig as any).operatingSystemVariant || null;
      
      if (!searchError && existingItems && existingItems.length > 0) {
        catalogItemId = existingItems[0].id;
        console.log('Found existing catalog item:', catalogItemId);
        
        // Update the existing catalog item's metadata with configuration data
        const { error: updateError } = await supabase
          .from('CatalogItems')
          .update({
            metadata: {
              product_type: productConfig.productType,
              configured: true,
              area: area,
              position: position,
              collection_id: collectionId,
              operating_system_variant: operatingSystemVariant,
            },
          })
          .eq('id', catalogItemId);
        
        if (updateError) {
          console.error('Error updating catalog item metadata:', updateError);
        } else {
          console.log('Updated catalog item metadata with configuration data');
        }
      } else {
        // If no catalog item found, create one
        console.log('No existing catalog item found, creating new one...');
        
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
              area: area,
              position: position,
              collection_id: collectionId,
              operating_system_variant: operatingSystemVariant,
            },
          })
          .select('id')
          .single();

        if (createError) {
          console.error('Error creating catalog item:', createError);
          throw new Error(`Failed to create catalog item for quote line: ${createError.message}`);
        }

        if (!newItem || !newItem.id) {
          throw new Error('Catalog item was created but no ID was returned');
        }

        catalogItemId = newItem.id;
        console.log('Created new catalog item:', catalogItemId);
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
        console.error('Error loading catalog item:', itemError);
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
          console.error('Invalid measure_basis type:', typeof measureBasis, measureBasis);
          throw new Error(`Invalid measure_basis value: ${measureBasis}. Expected one of: unit, linear_m, area, fabric`);
        }
        
        console.log('Computing quantity with:', {
          measureBasis,
          quantity,
          width_m,
          height_m,
        });
        
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
        
        const quoteLineData = {
          quote_id: quoteId,
          catalog_item_id: catalogItemId,
          qty: quantity || 1,
          width_m: width_m || null,
          height_m: height_m || null,
          measure_basis_snapshot: measureBasis,
          roll_width_m_snapshot: null,
          fabric_pricing_mode_snapshot: null,
          computed_qty: finalComputedQty,
          unit_price_snapshot: finalUnitPrice,
          unit_cost_snapshot: 0,
          line_total: finalLineTotal,
        };

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

        console.log('Creating QuoteLine with data:', quoteLineData);
        console.log('Quote ID:', quoteId);
        console.log('Catalog Item ID:', catalogItemId);
        console.log('Organization ID:', activeOrganizationId);
        console.log('Measure Basis:', measureBasis);
        console.log('Computed Qty:', finalComputedQty);
        console.log('Unit Price:', finalUnitPrice);
        console.log('Line Total:', finalLineTotal);
        
        const createdLine = await createQuoteLine(quoteLineData);
        console.log('QuoteLine created successfully:', createdLine);
        
        if (!createdLine) {
          throw new Error('QuoteLine was not created - no data returned from createQuoteLine');
        }
        
        if (!createdLine.id) {
          throw new Error('QuoteLine was created but has no ID');
        }
        
        console.log('QuoteLine ID:', createdLine.id);

        // Update quote totals
        const { data: allLines } = await supabase
          .from('QuoteLines')
          .select('line_total')
          .eq('quote_id', quoteId)
          .eq('deleted', false);

        const newTotal = (allLines || []).reduce((sum: number, line: any) => sum + (line.line_total || 0), 0);

        await updateQuote(quoteId, {
          totals: {
            subtotal: newTotal,
            tax_total: 0,
            total: newTotal,
          },
        });

        // Refetch lines to update the UI
        refetchLines();

        // Show success notification
        useUIStore.getState().addNotification({
          type: 'success',
          title: 'Line Added',
          message: `Product configuration for ${productConfig.productType} has been added to the quote.`,
        });

        // Close the configurator modal
        setShowConfigurator(false);
      } catch (error) {
        console.error('Error adding line - Full error:', error);
        console.error('Error details:', {
          error,
          errorType: typeof error,
          errorString: String(error),
          errorMessage: error instanceof Error ? error.message : 'Unknown error',
          errorStack: error instanceof Error ? error.stack : 'No stack trace',
        });
        
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
          tax_total: 0,
          total: 0,
        },
      };

      // Check if we have a quoteId - this determines if we're editing or creating
      // Also check URL to be sure
      const path = window.location.pathname;
      const urlMatch = path.match(/\/sales\/quotes\/edit\/([^/]+)/);
      const editQuoteId = urlMatch ? urlMatch[1] : null;
      
      const finalQuoteId = quoteId || editQuoteId;
      
      console.log('Quote submission:', {
        quoteId,
        editQuoteId,
        finalQuoteId,
        path,
        isEdit: !!finalQuoteId
      });
      
      if (finalQuoteId) {
        // Update existing quote
        console.log('Updating quote with ID:', finalQuoteId);
        const updated = await updateQuote(finalQuoteId, quoteData);
        console.log('Quote updated:', updated);
        useUIStore.getState().addNotification({
          type: 'success',
          title: 'Quote updated',
          message: 'Quote has been updated successfully.',
        });
      } else {
        // Create new quote
        console.log('Creating new quote - no quoteId found');
        const created = await createQuote(quoteData);
        console.log('Quote created:', created);
        
        // Update quoteId state so we can edit it later
        if (created?.id) {
          setQuoteId(created.id);
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
      console.error('Error saving quote:', err);
      setSaveError(err.message || 'Failed to save quote. Please try again.');
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error saving quote',
        message: err.message || 'Failed to save quote. Please try again.',
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
                <Label htmlFor="customer_id" className="text-xs" required>Customer</Label>
                <div className="relative customer-search-container">
                  <div className="relative">
                    <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400" />
                    <input
                      type="text"
                      placeholder={loadingCustomers ? "Loading customers..." : "Search customer or contact..."}
                      value={customerSearchTerm}
                      onChange={(e) => {
                        setCustomerSearchTerm(e.target.value);
                        setShowCustomerDropdown(true);
                      }}
                      onFocus={() => {
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
                  {showCustomerDropdown && !loadingCustomers && (
                    <div className="absolute z-50 w-full mt-1 bg-white border border-gray-200 rounded-lg shadow-lg max-h-60 overflow-y-auto">
                      {filteredCustomers.length > 0 ? filteredCustomers.map((customer) => (
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
                      )) : (
                        <div className="p-3">
                          <p className="text-xs text-gray-500 text-center">No customers found</p>
                        </div>
                      )}
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
                          {formatCurrency(calculatedTotal, watch('currency') || 'USD')}
                        </span>
                      </div>
                      <div className="flex justify-between text-sm">
                        <span className="text-gray-600">Tax:</span>
                        <span className="text-gray-900 font-medium">
                          {formatCurrency(0, watch('currency') || 'USD')}
                        </span>
                      </div>
                      <div className="border-t border-gray-200 pt-2 flex justify-between">
                        <span className="text-sm font-semibold text-gray-900">Total:</span>
                        <span className="text-sm font-semibold text-gray-900">
                          {formatCurrency(calculatedTotal, watch('currency') || 'USD')}
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
                  onClick={() => setShowConfigurator(true)}
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
                    <th className="text-left py-3 px-6 font-medium text-gray-900 text-xs">Measurements</th>
                    <th className="text-right py-3 px-6 font-medium text-gray-900 text-xs">Qty</th>
                    <th className="text-right py-3 px-6 font-medium text-gray-900 text-xs">Total Price</th>
                    {!isReadOnly && (
                      <th className="text-right py-3 px-6 font-medium text-gray-900 text-xs">Actions</th>
                    )}
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-200">
                  {quoteLines.map((line) => {
                    const item = (line as any).CatalogItems;
                    const metadata = item?.metadata || {};
                    
                    // Debug logging
                    if (import.meta.env.DEV) {
                      console.log('QuoteLine rendering:', {
                        lineId: line.id,
                        catalogItemId: line.catalog_item_id,
                        catalogItem: item,
                        hasMetadata: !!item?.metadata,
                        metadata: metadata,
                        metadataType: typeof metadata,
                        area: metadata?.area,
                        position: metadata?.position,
                        collection_id: metadata?.collection_id,
                        operating_system_variant: metadata?.operating_system_variant,
                      });
                    }
                    
                    // Handle metadata - it might be a string that needs parsing
                    let parsedMetadata = metadata;
                    if (typeof metadata === 'string') {
                      try {
                        parsedMetadata = JSON.parse(metadata);
                      } catch (e) {
                        console.error('Error parsing metadata:', e);
                        parsedMetadata = {};
                      }
                    }
                    
                    return (
                      <tr 
                        key={line.id} 
                        className="border-b border-gray-100 hover:bg-gray-50 transition-colors"
                      >
                        <td className="py-4 px-6 text-gray-700 text-sm">
                          {parsedMetadata?.area || 'N/A'}
                        </td>
                        <td className="py-4 px-6 text-gray-700 text-sm">
                          {parsedMetadata?.position !== undefined && parsedMetadata?.position !== null 
                            ? String(parsedMetadata.position) 
                            : 'N/A'}
                        </td>
                        <td className="py-4 px-6 text-gray-900 text-sm">
                          <div className="font-medium">
                            {item?.name || 'N/A'}
                          </div>
                        </td>
                        <td className="py-4 px-6 text-gray-700 text-sm">
                          {parsedMetadata?.collection_id ? getCollectionName(parsedMetadata.collection_id) : 'N/A'}
                        </td>
                        <td className="py-4 px-6 text-gray-700 text-sm">
                          {parsedMetadata?.operating_system_variant ? getSystemDriveName(parsedMetadata.operating_system_variant) : 'N/A'}
                        </td>
                        <td className="py-4 px-6 text-gray-700 text-sm">
                          {line.width_m && line.height_m
                            ? `${(line.width_m * 1000).toFixed(0)} x ${(line.height_m * 1000).toFixed(0)} mm`
                            : 'N/A'}
                        </td>
                        <td className="py-4 px-6 text-right text-gray-900 text-sm">
                          {line.computed_qty.toFixed(2)}
                        </td>
                        <td className="py-4 px-6 text-right text-gray-900 text-sm">
                          <div className="font-medium">
                            €{line.line_total.toFixed(2)}
                          </div>
                        </td>
                        {!isReadOnly && (
                          <td className="py-4 px-6" onClick={(e) => e.stopPropagation()}>
                            <div className="flex items-center gap-1 justify-end">
                              <button
                                onClick={() => {
                                  // TODO: Implement edit functionality
                                  useUIStore.getState().addNotification({
                                    type: 'info',
                                    title: 'Coming soon',
                                    message: 'Edit functionality will be available soon',
                                  });
                                }}
                                className="p-1.5 hover:bg-gray-100 rounded transition-colors text-gray-600"
                                aria-label="Edit line"
                                title="Edit line"
                              >
                                <Edit className="w-4 h-4" />
                              </button>
                              <button
                                onClick={async () => {
                                  if (!confirm('Are you sure you want to delete this line?')) return;
                                  
                                  try {
                                    await supabase
                                      .from('QuoteLines')
                                      .update({ deleted: true })
                                      .eq('id', line.id);
                                    
                                    // Update quote totals after deleting line
                                    const { data: remainingLines } = await supabase
                                      .from('QuoteLines')
                                      .select('line_total')
                                      .eq('quote_id', quoteId)
                                      .eq('deleted', false);

                                    const newTotal = (remainingLines || []).reduce((sum: number, l: any) => sum + (l.line_total || 0), 0);

                                    await updateQuote(quoteId, {
                                      totals: {
                                        subtotal: newTotal,
                                        tax_total: 0,
                                        total: newTotal,
                                      },
                                    });
                                    
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
        <div className="fixed inset-0 bg-black bg-opacity-50 z-50 flex items-center justify-center">
          <div className="bg-white rounded-lg w-full h-full max-w-7xl m-4 overflow-hidden">
            <ProductConfigurator
              quoteId={quoteId}
              onComplete={handleProductConfigComplete}
              onClose={() => setShowConfigurator(false)}
            />
          </div>
        </div>
      )}
    </div>
  );
}


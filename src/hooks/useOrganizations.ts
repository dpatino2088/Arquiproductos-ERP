import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { useCompanyStore } from '../stores/company-store';

export interface Organization {
  id: string;
  name: string;
  legal_name?: string | null;
  tax_id?: string | null;
  country?: string | null;
  main_email?: string | null;
  billing_email?: string | null;
  support_email?: string | null;
  phone_number?: string | null;
  tier?: 'free' | 'starter' | 'pro' | 'enterprise' | null;
  status?: 'active' | 'trialing' | 'suspended' | null;
  address_line_1?: string | null;
  address_line_2?: string | null;
  city?: string | null;
  state?: string | null;
  zip_code?: string | null;
  default_currency?: 'USD' | 'PAB' | 'EUR' | null;
  default_locale?: 'es-PA' | 'en-US' | null;
  is_active?: boolean;
  created_at: string;
  updated_at?: string | null;
}

interface UseOrganizationsResult {
  organizations: Organization[];
  isLoading: boolean;
  error: string | null;
  refetch: () => Promise<void>;
}

export const useOrganizations = (): UseOrganizationsResult => {
  const { currentCompany } = useCompanyStore();
  const [organizations, setOrganizations] = useState<Organization[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchOrganizations = async () => {
    try {
      setIsLoading(true);
      setError(null);

      // Fetch all organizations from Organizations table
      const { data, error: fetchError } = await supabase
        .from('Organizations')
        .select('*')
        .order('created_at', { ascending: false });

      if (fetchError) {
        console.error('Error fetching organizations:', fetchError);
        throw fetchError;
      }

      // Map Organizations to Organization interface
      const mappedOrganizations: Organization[] = (data || []).map((org: any) => ({
        id: org.id,
        name: org.organization_name || '',
        legal_name: org.legal_name || null,
        tax_id: org.tax_id || null,
        country: org.country || null,
        main_email: org.main_email || null,
        billing_email: org.billing_email || null,
        support_email: org.support_email || null,
        phone_number: org.phone_number || null,
        tier: org.tier || null,
        status: org.status || null,
        address_line_1: org.address_line_1 || null,
        address_line_2: org.address_line_2 || null,
        city: org.city || null,
        state: org.state || null,
        zip_code: org.zip_code || null,
        default_currency: org.default_currency || null,
        default_locale: org.default_locale || null,
        is_active: org.is_active ?? true,
        created_at: org.created_at || new Date().toISOString(),
        updated_at: org.updated_at || null,
      }));

      setOrganizations(mappedOrganizations);
    } catch (err: any) {
      console.error('Error loading organizations:', err);
      setError(err?.message || 'Failed to load organizations');
      setOrganizations([]);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchOrganizations();
  }, []);

  return {
    organizations,
    isLoading,
    error,
    refetch: fetchOrganizations,
  };
};


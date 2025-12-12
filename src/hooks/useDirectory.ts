import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { useAuthStore } from '../stores/auth-store';
import { useCompanyStore } from '../stores/company-store';

// Helper to get organization_id from user metadata or currentCompany
// This is synchronous to avoid timing issues in useEffect
const getOrganizationId = (user: any, currentCompany: any): string | null => {
  // First try to get from user metadata (set during login)
  if (user?.metadata?.default_organization_id) {
    return user.metadata.default_organization_id;
  }
  
  // Fallback to currentCompany.id (this should be the organization_id in the new model)
  // In the new model, currentCompany.id IS the organization_id
  return currentCompany?.id || null;
};

// Hook para obtener contactos
export function useContacts() {
  const [contacts, setContacts] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const { user } = useAuthStore();
  const { currentCompany } = useCompanyStore();

  useEffect(() => {
    async function fetchContacts() {
      if (!user || !currentCompany?.id) {
        setLoading(false);
        return;
      }
      
      const organizationId = getOrganizationId(user, currentCompany);
      
      if (!organizationId) {
        setLoading(false);
        if (import.meta.env.DEV) {
          console.warn('⚠️ No organization_id available for fetching contacts');
        }
        return;
      }

      try {
        setLoading(true);
        setError(null);

        if (import.meta.env.DEV) {
          console.log('🔍 Fetching contacts for organization:', organizationId);
        }

        const { data, error: queryError } = await supabase
          .from('DirectoryContacts')
          .select(`
            id,
            contact_type,
            title_id,
            customer_name,
            identification_number,
            primary_phone,
            cell_phone,
            alt_phone,
            email,
            street_address_line_1,
            street_address_line_2,
            city,
            state,
            zip_code,
            country,
            company_id,
            created_at,
            deleted,
            archived,
            ContactTitles!title_id (
              title
            ),
            DirectoryCustomers!company_id (
              id,
              company_name
            )
          `)
          .eq('organization_id', organizationId)
          .eq('deleted', false)
          .eq('archived', false)
          .order('created_at', { ascending: false });

        if (queryError) {
          console.error('❌ Supabase query error:', queryError);
          throw queryError;
        }

        if (import.meta.env.DEV) {
          console.log('📊 Raw contacts data from Supabase:', data);
          console.log('📊 Contacts count:', data?.length || 0);
        }

        // Transform data to match frontend interface
        const transformedContacts = (data || []).map((contact) => {
          const companyData = (contact.DirectoryCustomers as any) || null;
          return {
            id: contact.id,
            firstName: contact.customer_name || '',
            lastName: '',
            email: contact.email || '',
            company: companyData?.company_name || '',
            company_id: contact.company_id || null,
            category: contact.contact_type === 'company' ? 'Company' : 'Individual',
            status: contact.archived ? 'Archived' : 'Active' as 'Active' | 'Inactive' | 'Archived',
            location: [contact.city, contact.state, contact.country].filter(Boolean).join(', ') || 'N/A',
            dateAdded: contact.created_at || '',
            phone: contact.primary_phone || contact.cell_phone || '',
            contactType: 'Business' as 'Business' | 'Personal' | 'Vendor' | 'Customer',
            title: (contact.ContactTitles as any)?.title || null,
            // Additional fields for table display
            primary_phone: contact.primary_phone || '',
            city: contact.city || '',
            country: contact.country || '',
            contact_type: contact.contact_type || 'individual',
            created_at: contact.created_at || '',
          };
        });

        setContacts(transformedContacts);
        
        // Debug log
        if (import.meta.env.DEV) {
          console.log('📦 Contacts loaded:', transformedContacts.length, 'contacts');
          console.log('📋 Contacts data:', transformedContacts);
        }
      } catch (err) {
        console.error('❌ Error fetching contacts:', err);
        setError(err instanceof Error ? err.message : 'Error loading contacts');
      } finally {
        setLoading(false);
      }
    }

    fetchContacts();
  }, [user, currentCompany?.id]);

  return { contacts, loading, error };
}

// Hook para obtener customers
export function useCustomers() {
  const [customers, setCustomers] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const { user } = useAuthStore();
  const { currentCompany } = useCompanyStore();

  useEffect(() => {
    async function fetchCustomers() {
      if (!user || !currentCompany?.id) {
        setLoading(false);
        return;
      }

      try {
        setLoading(true);
        setError(null);

        const { data, error: queryError } = await supabase
          .from('DirectoryCustomers')
          .select(`
            id,
            customer_type_id,
            company_name,
            ein,
            website,
            email,
            company_phone,
            alt_phone,
            street_address_line_1,
            street_address_line_2,
            city,
            state,
            zip_code,
            country,
            primary_contact_id,
            created_at,
            deleted,
            archived,
            CustomerTypes!customer_type_id (
              name
            ),
            DirectoryContacts!primary_contact_id (
              customer_name,
              identification_number,
              email
            )
          `)
          .eq('organization_id', currentCompany.id)
          .eq('deleted', false)
          .eq('archived', false)
          .order('created_at', { ascending: false });

        if (queryError) throw queryError;

        // Transform data to match frontend interface
        const transformedCustomers = (data || []).map((customer) => ({
          id: customer.id,
          companyName: customer.company_name || '',
          contactName: customer.DirectoryContacts 
            ? (customer.DirectoryContacts as any).customer_name || ''
            : '',
          email: customer.email || '',
          phone: customer.company_phone || '',
          industry: 'N/A', // Not in schema yet
          customerType: (customer.CustomerTypes as any)?.name || 'Customer',
          status: customer.archived ? 'Archived' : 'Active' as 'Active' | 'On Hold' | 'Archived',
          location: [customer.city, customer.state, customer.country].filter(Boolean).join(', ') || 'N/A',
          dateAdded: customer.created_at ? new Date(customer.created_at).toISOString().split('T')[0] : '',
          totalRevenue: 0, // Not in schema yet
        }));

        setCustomers(transformedCustomers);
      } catch (err) {
        console.error('Error fetching customers:', err);
        setError(err instanceof Error ? err.message : 'Error loading customers');
      } finally {
        setLoading(false);
      }
    }

    fetchCustomers();
  }, [user, currentCompany?.id]);

  return { customers, loading, error };
}

// Hook para obtener vendors
export function useVendors() {
  const [vendors, setVendors] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const { user } = useAuthStore();
  const { currentCompany } = useCompanyStore();

  useEffect(() => {
    async function fetchVendors() {
      if (!user || !currentCompany?.id) {
        setLoading(false);
        return;
      }

      const organizationId = getOrganizationId(user, currentCompany);
      
      if (!organizationId) {
        setLoading(false);
        return;
      }

      try {
        setLoading(true);
        setError(null);

        const { data, error: queryError } = await supabase
          .from('DirectoryVendors')
          .select(`
            id,
            vendor_type_id,
            vendor_name,
            ein,
            website,
            email,
            work_phone,
            fax,
            street_address_line_1,
            street_address_line_2,
            city,
            state,
            zip_code,
            country,
            created_at,
            deleted,
            archived,
            VendorTypes!vendor_type_id (
              name
            )
          `)
          .eq('organization_id', organizationId)
          .eq('deleted', false)
          .eq('archived', false)
          .order('created_at', { ascending: false });

        if (queryError) throw queryError;

        // Transform data to match frontend interface
        const transformedVendors = (data || []).map((vendor) => ({
          id: vendor.id,
          vendorName: vendor.vendor_name || '',
          vendorId: vendor.ein || '',
          phone: vendor.work_phone || '',
          email: vendor.email || '',
          country: vendor.country || '',
          currency: 'USD', // Not in schema yet
          status: vendor.archived ? 'Archived' : 'Active' as 'Active' | 'Inactive' | 'Archived',
          dateAdded: vendor.created_at ? new Date(vendor.created_at).toISOString().split('T')[0] : '',
          vendorType: (vendor.VendorTypes as any)?.name || '',
        }));

        setVendors(transformedVendors);
      } catch (err) {
        console.error('Error fetching vendors:', err);
        setError(err instanceof Error ? err.message : 'Error loading vendors');
      } finally {
        setLoading(false);
      }
    }

    fetchVendors();
  }, [user, currentCompany?.id]);

  return { vendors, loading, error };
}

// Hook para obtener contractors
export function useContractors() {
  const [contractors, setContractors] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const { user } = useAuthStore();
  const { currentCompany } = useCompanyStore();

  useEffect(() => {
    async function fetchContractors() {
      if (!user || !currentCompany?.id) {
        setLoading(false);
        return;
      }
      
      const organizationId = getOrganizationId(user, currentCompany);
      
      if (!organizationId) {
        setLoading(false);
        return;
      }

      try {
        setLoading(true);
        setError(null);

        const { data, error: queryError } = await supabase
          .from('DirectoryContractors')
          .select(`
            id,
            contractor_role_id,
            contractor_company_name,
            contact_name,
            position,
            street_address_line_1,
            street_address_line_2,
            city,
            state,
            zip_code,
            country,
            date_of_hire,
            date_of_birth,
            ein,
            company_number,
            primary_email,
            secondary_email,
            phone,
            extension,
            cell_phone,
            fax,
            created_at,
            deleted,
            archived,
            ContractorRoles!contractor_role_id (
              role_name
            )
          `)
          .eq('organization_id', organizationId)
          .eq('deleted', false)
          .eq('archived', false)
          .order('created_at', { ascending: false });

        if (queryError) throw queryError;

        // Transform data to match frontend interface
        const transformedContractors = (data || []).map((contractor) => ({
          id: contractor.id,
          company: contractor.contractor_company_name || '',
          name: contractor.contact_name || '',
          licensesApplied: contractor.company_number || '',
          cellPhone: contractor.cell_phone || '',
          proficiency1: (contractor.ContractorRoles as any)?.role_name || '',
          proficiency2: '',
          proficiency3: '',
          email: contractor.primary_email || '',
          status: contractor.archived ? 'Archived' : 'Active' as 'Active' | 'Inactive' | 'Archived',
          dateAdded: contractor.created_at ? new Date(contractor.created_at).toISOString().split('T')[0] : '',
          location: [contractor.city, contractor.state, contractor.country].filter(Boolean).join(', ') || 'N/A',
        }));

        setContractors(transformedContractors);
      } catch (err) {
        console.error('Error fetching contractors:', err);
        setError(err instanceof Error ? err.message : 'Error loading contractors');
      } finally {
        setLoading(false);
      }
    }

    fetchContractors();
  }, [user, currentCompany?.id]);

  return { contractors, loading, error };
}

// Hook para obtener sites
export function useSites() {
  const [sites, setSites] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const { user } = useAuthStore();
  const { currentCompany } = useCompanyStore();

  useEffect(() => {
    async function fetchSites() {
      if (!user || !currentCompany?.id) {
        setLoading(false);
        return;
      }
      
      const organizationId = getOrganizationId(user, currentCompany);
      
      if (!organizationId) {
        setLoading(false);
        return;
      }

      try {
        setLoading(true);
        setError(null);

        const { data, error: queryError } = await supabase
          .from('DirectorySites')
          .select(`
            id,
            site_type_id,
            site_name,
            zone,
            street_address_line_1,
            street_address_line_2,
            city,
            state,
            zip_code,
            country,
            site_id,
            created_at,
            deleted,
            archived,
            SiteTypes!site_type_id (
              name
            )
          `)
          .eq('organization_id', organizationId)
          .eq('deleted', false)
          .eq('archived', false)
          .order('created_at', { ascending: false });

        if (queryError) throw queryError;

        // Transform data to match frontend interface
        const transformedSites = (data || []).map((site) => ({
          id: site.id,
          siteName: site.site_name || '',
          siteId: site.site_id || '',
          siteAddress: [site.street_address_line_1, site.street_address_line_2, site.city, site.state, site.zip_code].filter(Boolean).join(', ') || 'N/A',
          country: site.country || '',
          siteType: (site.SiteTypes as any)?.name || '',
          status: site.archived ? 'Archived' : 'Active' as 'Active' | 'Inactive' | 'Archived',
          dateAdded: site.created_at ? new Date(site.created_at).toISOString().split('T')[0] : '',
        }));

        setSites(transformedSites);
      } catch (err) {
        console.error('Error fetching sites:', err);
        setError(err instanceof Error ? err.message : 'Error loading sites');
      } finally {
        setLoading(false);
      }
    }

    fetchSites();
  }, [user, currentCompany?.id]);

  return { sites, loading, error };
}


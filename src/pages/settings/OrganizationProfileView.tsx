import { useEffect, useState } from 'react';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { supabase } from '../../lib/supabase/client';
import { NoOrganizationMessage } from '../../components/NoOrganizationMessage';
import { devLog } from '../../lib/dev-logger';

interface OrganizationData {
  name: string | null;
  legal_name: string | null;
  tax_id: string | null;
  country: string | null;
  main_email: string | null;
  owner_name: string | null;
  owner_email: string | null;
  address: {
    street_address_line_1: string | null;
    street_address_line_2: string | null;
    city: string | null;
    state: string | null;
    zip_code: string | null;
    country: string | null;
  } | null;
}

export default function OrganizationProfileView() {
  const { activeOrganizationId, loading: orgLoading } = useOrganizationContext();
  const [organizationData, setOrganizationData] = useState<OrganizationData | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const loadOrganizationData = async () => {
      if (!activeOrganizationId) {
        setIsLoading(false);
        setOrganizationData(null);
        return;
      }

      try {
        setIsLoading(true);
        setError(null);

        // Fetch organization data
        const { data: orgData, error: orgError } = await supabase
          .from('Organizations')
          .select('id, name, legal_name, tax_id, country, main_email, owner_user_id')
          .eq('id', activeOrganizationId)
          .eq('deleted', false)
          .single();

        if (orgError) {
          throw orgError;
        }

        if (!orgData) {
          setOrganizationData(null);
          setIsLoading(false);
          return;
        }

        // Fetch address data
        const { data: addressData } = await supabase
          .from('Addresses')
          .select('street_address_line_1, street_address_line_2, city, state, zip_code, country')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .maybeSingle();

        // Fetch owner data (name and email) from OrganizationUsers
        let ownerName: string | null = null;
        let ownerEmail: string | null = null;

        if (orgData.owner_user_id) {
          // Get from OrganizationUsers (has cached name/email)
          const { data: orgUserData } = await supabase
            .from('OrganizationUsers')
            .select('name, email')
            .eq('user_id', orgData.owner_user_id)
            .eq('organization_id', activeOrganizationId)
            .eq('deleted', false)
            .maybeSingle();

          if (orgUserData) {
            ownerName = orgUserData.name || null;
            ownerEmail = orgUserData.email || null;
          }
        }

        // Set organization data
        setOrganizationData({
          name: orgData.name || null,
          legal_name: orgData.legal_name || orgData.name || null, // Fallback to name if legal_name doesn't exist
          tax_id: orgData.tax_id || null,
          country: orgData.country || null,
          main_email: orgData.main_email || ownerEmail || null, // Use main_email or fallback to owner email
          owner_name: ownerName,
          owner_email: ownerEmail,
          address: addressData ? {
            street_address_line_1: addressData.street_address_line_1 || null,
            street_address_line_2: addressData.street_address_line_2 || null,
            city: addressData.city || null,
            state: addressData.state || null,
            zip_code: addressData.zip_code || null,
            country: addressData.country || null,
          } : null,
        });
      } catch (err: any) {
        devLog('Error loading organization data:', err);
        setError(err?.message || 'Failed to load organization data');
      } finally {
        setIsLoading(false);
      }
    };

    loadOrganizationData();
  }, [activeOrganizationId]);

  // Show loading state
  if (orgLoading || isLoading) {
    return (
      <div className="bg-white border border-gray-200 rounded-lg p-6">
        <div className="flex items-center justify-center py-12">
          <div className="text-center">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary mx-auto mb-4"></div>
            <p className="text-sm text-gray-500">Loading organization data...</p>
          </div>
        </div>
      </div>
    );
  }

  // Show error or no organization
  if (!activeOrganizationId || error) {
    return (
      <div className="bg-white border border-gray-200 rounded-lg p-6">
        {!activeOrganizationId ? (
          <NoOrganizationMessage />
        ) : (
          <div className="text-center py-12">
            <p className="text-sm text-red-600">{error || 'Failed to load organization data'}</p>
          </div>
        )}
      </div>
    );
  }

  if (!organizationData) {
    return (
      <div className="bg-white border border-gray-200 rounded-lg p-6">
        <div className="text-center py-12">
          <p className="text-sm text-gray-500">No organization data found</p>
        </div>
      </div>
    );
  }

  // Format address for display
  const formatAddress = () => {
    const addr = organizationData.address;
    if (!addr) return 'N/A';

    const parts = [
      addr.street_address_line_1,
      addr.street_address_line_2,
      addr.city,
      addr.state,
      addr.zip_code,
      addr.country,
    ].filter(Boolean);

    return parts.length > 0 ? parts.join(', ') : 'N/A';
  };

  return (
    <div className="bg-white border border-gray-200 rounded-lg p-6">
      <div className="space-y-6">
        {/* Organization Information */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">Nombre</label>
            <div className="w-full px-3 py-2 border border-gray-300 rounded-md bg-gray-50 text-gray-900">
              {organizationData.name || 'N/A'}
            </div>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">Nombre Legal</label>
            <div className="w-full px-3 py-2 border border-gray-300 rounded-md bg-gray-50 text-gray-900">
              {organizationData.legal_name || 'N/A'}
            </div>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">ID Number</label>
            <div className="w-full px-3 py-2 border border-gray-300 rounded-md bg-gray-50 text-gray-900">
              {organizationData.tax_id || 'N/A'}
            </div>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">Main Email</label>
            <div className="w-full px-3 py-2 border border-gray-300 rounded-md bg-gray-50 text-gray-900">
              {organizationData.main_email || 'N/A'}
            </div>
          </div>
          <div className="md:col-span-2">
            <label className="block text-sm font-medium text-gray-700 mb-2">Dirección</label>
            <div className="w-full px-3 py-2 border border-gray-300 rounded-md bg-gray-50 text-gray-900 min-h-[42px]">
              {formatAddress()}
            </div>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">Persona Principal</label>
            <div className="w-full px-3 py-2 border border-gray-300 rounded-md bg-gray-50 text-gray-900">
              {organizationData.owner_name || 'N/A'}
            </div>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">País</label>
            <div className="w-full px-3 py-2 border border-gray-300 rounded-md bg-gray-50 text-gray-900">
              {organizationData.country || 'N/A'}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}


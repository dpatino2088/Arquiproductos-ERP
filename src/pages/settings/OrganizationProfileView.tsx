import { useEffect, useState } from 'react';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { supabase } from '../../lib/supabase/client';
import { NoOrganizationMessage } from '../../components/NoOrganizationMessage';
import { devLog } from '../../lib/dev-logger';
import { Users, Building, Shield, Calendar, Mail, MapPin } from 'lucide-react';

interface OrganizationData {
  name: string | null;
  legal_name: string | null;
  tax_id: string | null;
  country: string | null;
  main_email: string | null;
  owner_name: string | null;
  owner_email: string | null;
  created_at: string | null;
  address: {
    street_address_line_1: string | null;
    street_address_line_2: string | null;
    city: string | null;
    state: string | null;
    zip_code: string | null;
    country: string | null;
  } | null;
}

interface OrganizationStats {
  organizationUsers: number;
  companies: number;
  portalUsers: number;
}

export default function OrganizationProfileView() {
  const { activeOrganizationId, loading: orgLoading } = useOrganizationContext();
  const [organizationData, setOrganizationData] = useState<OrganizationData | null>(null);
  const [stats, setStats] = useState<OrganizationStats>({
    organizationUsers: 0,
    companies: 0,
    portalUsers: 0,
  });
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

        // Fetch organization data - use 'name' column, not 'organization_name'
        const { data: orgData, error: orgError } = await supabase
          .from('Organizations')
          .select('id, name, legal_name, tax_id, country, main_email, owner_user_id, created_at')
          .eq('id', activeOrganizationId)
          .maybeSingle();

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
            .select('user_name, user_email')
            .eq('user_id', orgData.owner_user_id)
            .eq('organization_id', activeOrganizationId)
            .eq('deleted', false)
            .maybeSingle();

          if (orgUserData) {
            ownerName = orgUserData.user_name || null;
            ownerEmail = orgUserData.user_email || null;
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
          created_at: orgData.created_at || null,
          address: addressData ? {
            street_address_line_1: addressData.street_address_line_1 || null,
            street_address_line_2: addressData.street_address_line_2 || null,
            city: addressData.city || null,
            state: addressData.state || null,
            zip_code: addressData.zip_code || null,
            country: addressData.country || null,
          } : null,
        });

        // Fetch statistics
        const [orgUsersResult, companiesResult, portalUsersResult] = await Promise.all([
          supabase
            .from('OrganizationUsers')
            .select('id', { count: 'exact', head: true })
            .eq('organization_id', activeOrganizationId)
            .eq('deleted', false),
          supabase
            .from('Companies')
            .select('id', { count: 'exact', head: true })
            .eq('organization_id', activeOrganizationId)
            .eq('deleted', false),
          supabase
            .from('CompanyPortalUsers')
            .select('id', { count: 'exact', head: true })
            .eq('organization_id', activeOrganizationId)
            .eq('deleted', false),
        ]);

        setStats({
          organizationUsers: orgUsersResult.count || 0,
          companies: companiesResult.count || 0,
          portalUsers: portalUsersResult.count || 0,
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
    <div className="space-y-6">
      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="bg-white border border-gray-200 rounded-lg p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600 mb-1">Organization Users</p>
              <p className="text-2xl font-semibold text-gray-900">{stats.organizationUsers}</p>
            </div>
            <div className="p-3 bg-blue-50 rounded-lg">
              <Users className="w-6 h-6 text-blue-600" />
            </div>
          </div>
        </div>

        <div className="bg-white border border-gray-200 rounded-lg p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600 mb-1">Companies</p>
              <p className="text-2xl font-semibold text-gray-900">{stats.companies}</p>
            </div>
            <div className="p-3 bg-green-50 rounded-lg">
              <Building className="w-6 h-6 text-green-600" />
            </div>
          </div>
        </div>

        <div className="bg-white border border-gray-200 rounded-lg p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600 mb-1">Portal Users</p>
              <p className="text-2xl font-semibold text-gray-900">{stats.portalUsers}</p>
            </div>
            <div className="p-3 bg-purple-50 rounded-lg">
              <Shield className="w-6 h-6 text-purple-600" />
            </div>
          </div>
        </div>
      </div>

      {/* Organization Information */}
      <div className="bg-white border border-gray-200 rounded-lg p-6">
        <h2 className="text-lg font-semibold text-gray-900 mb-6">Organization Information</h2>
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
            <label className="block text-sm font-medium text-gray-700 mb-2 flex items-center gap-2">
              <Mail className="w-4 h-4" />
              Main Email
            </label>
            <div className="w-full px-3 py-2 border border-gray-300 rounded-md bg-gray-50 text-gray-900">
              {organizationData.main_email || 'N/A'}
            </div>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">Persona Principal</label>
            <div className="w-full px-3 py-2 border border-gray-300 rounded-md bg-gray-50 text-gray-900">
              {organizationData.owner_name || 'N/A'}
            </div>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2 flex items-center gap-2">
              <Calendar className="w-4 h-4" />
              Created At
            </label>
            <div className="w-full px-3 py-2 border border-gray-300 rounded-md bg-gray-50 text-gray-900">
              {organizationData.created_at 
                ? new Date(organizationData.created_at).toLocaleDateString()
                : 'N/A'}
            </div>
          </div>
          <div className="md:col-span-2">
            <label className="block text-sm font-medium text-gray-700 mb-2 flex items-center gap-2">
              <MapPin className="w-4 h-4" />
              Dirección
            </label>
            <div className="w-full px-3 py-2 border border-gray-300 rounded-md bg-gray-50 text-gray-900 min-h-[42px]">
              {formatAddress()}
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


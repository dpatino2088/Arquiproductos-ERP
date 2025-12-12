import { useState, useEffect } from 'react';
import { useCompanyStore } from '../../stores/company-store';
import { useUIStore } from '../../stores/ui-store';
import { supabase } from '../../lib/supabase';
import Input from '../../components/ui/Input';
import Label from '../../components/ui/Label';
import { Select as SelectShadcn, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../../components/ui/SelectShadcn';
import { COUNTRIES } from '../../lib/constants';
import OrganizationsRecords from './OrganizationsRecords';
import OrganizationUsers from './OrganizationUsers';
import { Organization } from '../../hooks/useOrganizations';
import PasswordModal from '../../components/ui/PasswordModal';

// Import refetch function from hook
let organizationsRefetch: (() => Promise<void>) | null = null;

export default function OrganizationProfile() {
  const { currentCompany } = useCompanyStore();
  const [activeTab, setActiveTab] = useState<'profile' | 'records' | 'users'>('profile');
  const [selectedOrganization, setSelectedOrganization] = useState<Organization | null>(null);
  const [organizationId, setOrganizationId] = useState<string | null>(null);
  
  // Identity fields
  const [organizationName, setOrganizationName] = useState('');
  const [legalName, setLegalName] = useState('');
  const [taxId, setTaxId] = useState('');
  const [country, setCountry] = useState('');
  
  // Contact fields
  const [mainEmail, setMainEmail] = useState('');
  const [billingEmail, setBillingEmail] = useState('');
  const [supportEmail, setSupportEmail] = useState('');
  const [phoneNumber, setPhoneNumber] = useState('');
  
  // Plan/Tier fields
  const [tier, setTier] = useState<'free' | 'starter' | 'pro' | 'enterprise'>('free');
  const [status, setStatus] = useState<'active' | 'trialing' | 'suspended'>('active');
  
  // Address fields
  const [addressLine1, setAddressLine1] = useState('');
  const [addressLine2, setAddressLine2] = useState('');
  const [city, setCity] = useState('');
  const [state, setState] = useState('');
  const [zipCode, setZipCode] = useState('');
  
  // Config defaults
  const [defaultCurrency, setDefaultCurrency] = useState<'USD' | 'PAB' | 'EUR'>('USD');
  const [defaultLocale, setDefaultLocale] = useState<'es-PA' | 'en-US'>('es-PA');
  
  const [isLoading, setIsLoading] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const [validationErrors, setValidationErrors] = useState<Record<string, string>>({});
  const [showPasswordModal, setShowPasswordModal] = useState(false);
  const [passwordModalData, setPasswordModalData] = useState<{
    email: string;
    password: string;
    organizationName: string;
  } | null>(null);

  // Load organization data
  const loadOrganizationData = async (orgId?: string | null) => {
    const idToLoad = orgId || selectedOrganization?.id || currentCompany?.id;
    if (!idToLoad) return;

    setIsLoading(true);
    try {
      const { data, error } = await supabase
        .from('Organizations')
        .select('*')
        .eq('id', idToLoad)
        .single();

      if (error) {
        console.error('Error loading organization:', error);
        // If organization doesn't exist, start with empty form
        if (error.code === 'PGRST116') {
          setOrganizationId(null);
          resetForm();
          setIsLoading(false);
          return;
        }
        throw error;
      }

      if (data) {
        setOrganizationId(data.id);
        setOrganizationName(data.organization_name || '');
        setLegalName(data.legal_name || '');
        setTaxId(data.tax_id || '');
        setCountry(data.country || '');
        setMainEmail(data.main_email || '');
        setBillingEmail(data.billing_email || '');
        setSupportEmail(data.support_email || '');
        setPhoneNumber(data.phone_number || '');
        setTier(data.tier || 'free');
        setStatus(data.status || 'active');
        setAddressLine1(data.address_line_1 || '');
        setAddressLine2(data.address_line_2 || '');
        setCity(data.city || '');
        setState(data.state || '');
        setZipCode(data.zip_code || '');
        setDefaultCurrency(data.default_currency || 'USD');
        setDefaultLocale(data.default_locale || 'es-PA');
      }
    } catch (err: any) {
      console.error('Error loading organization data:', err);
    } finally {
      setIsLoading(false);
    }
  };

  // Reset form to empty state
  const resetForm = () => {
    console.log('🔄 Resetting form to empty state');
    setOrganizationId(null);
    setOrganizationName('');
    setLegalName('');
    setTaxId('');
    setCountry('');
    setMainEmail('');
    setBillingEmail('');
    setSupportEmail('');
    setPhoneNumber('');
    setTier('free');
    setStatus('active');
    setAddressLine1('');
    setAddressLine2('');
    setCity('');
    setState('');
    setZipCode('');
    setDefaultCurrency('USD');
    setDefaultLocale('es-PA');
    setValidationErrors({});
  };

  // Load organization data on mount or when selected organization changes
  useEffect(() => {
    if (selectedOrganization) {
      loadOrganizationData(selectedOrganization.id);
    } else {
      // Reset form to empty state when no organization is selected
      resetForm();
      setOrganizationId(null);
    }
  }, [selectedOrganization]);

  // Reset form when component unmounts or when switching away from profile tab
  useEffect(() => {
    return () => {
      // Cleanup: reset form when component unmounts
      resetForm();
      setOrganizationId(null);
    };
  }, []);

  const handleSave = async (e?: React.FormEvent) => {
    if (e) {
      e.preventDefault();
    }

    // Validate required fields
    const errors: Record<string, string> = {};
    const missingFields: string[] = [];
    
    if (!organizationName.trim()) {
      errors.organizationName = 'Organization name is required';
      missingFields.push('Organization Name');
    }
    if (!taxId.trim()) {
      errors.tax_id = 'ID Number is required';
      missingFields.push('ID Number');
    }
    if (!mainEmail.trim()) {
      errors.main_email = 'Main email is required';
      missingFields.push('Main Email');
    } else {
      // Validate email format
      const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
      if (!emailRegex.test(mainEmail.trim())) {
        errors.main_email = 'Please enter a valid email address';
        missingFields.push('Main Email (invalid format)');
      }
    }
    if (!country.trim()) {
      errors.country = 'Country is required';
      missingFields.push('Country');
    }
    if (!addressLine1.trim()) {
      errors.address_line_1 = 'Address Line 1 is required';
      missingFields.push('Address Line 1');
    }
    if (!city.trim()) {
      errors.city = 'City is required';
      missingFields.push('City');
    }
    if (!state.trim()) {
      errors.state = 'State is required';
      missingFields.push('State');
    }
    if (!zipCode.trim()) {
      errors.zip_code = 'Zip Code is required';
      missingFields.push('Zip Code');
    }
    
    setValidationErrors(errors);
    
    if (missingFields.length > 0) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Missing Required Information',
        message: `Please complete the following required fields: ${missingFields.join(', ')}.`,
      });
      return;
    }

    setIsSaving(true);

    try {
      // Prepare organization data
      const organizationData = {
        organization_name: organizationName.trim(),
        legal_name: legalName?.trim() || null,
        tax_id: taxId?.trim() || null,
        country: country?.trim() || null,
        main_email: mainEmail?.trim() || null,
        billing_email: billingEmail?.trim() || null,
        support_email: supportEmail?.trim() || null,
        phone_number: phoneNumber?.trim() || null,
        tier: tier || null,
        status: status || null,
        address_line_1: addressLine1?.trim() || null,
        address_line_2: addressLine2?.trim() || null,
        city: city?.trim() || null,
        state: state?.trim() || null,
        zip_code: zipCode?.trim() || null,
        default_currency: defaultCurrency || null,
        default_locale: defaultLocale || null,
        updated_at: new Date().toISOString(),
      };

      // Check for duplicate organization by name (excluding current organization if updating)
      if (organizationName.trim()) {
        let duplicateQuery = supabase
          .from('Organizations')
          .select('id, organization_name')
          .eq('organization_name', organizationName.trim())
          .limit(1);

        if (organizationId) {
          duplicateQuery = duplicateQuery.neq('id', organizationId);
        }

        const { data: existingOrg, error: checkError } = await duplicateQuery;

        if (checkError) {
          console.error('Error checking for duplicate organization:', checkError);
        }

        if (existingOrg && existingOrg.length > 0) {
          useUIStore.getState().addNotification({
            type: 'error',
            title: 'Duplicate organization name',
            message: 'An organization with this name already exists. Please use a different name.',
          });
          setIsSaving(false);
          return;
        }
      }

      // Check for duplicate organization by main_email (excluding current organization if updating)
      if (mainEmail.trim()) {
        let duplicateEmailQuery = supabase
          .from('Organizations')
          .select('id, organization_name, main_email')
          .eq('main_email', mainEmail.trim())
          .limit(1);

        if (organizationId) {
          duplicateEmailQuery = duplicateEmailQuery.neq('id', organizationId);
        }

        const { data: existingOrgByEmail, error: checkEmailError } = await duplicateEmailQuery;

        if (checkEmailError) {
          console.error('Error checking for duplicate email:', checkEmailError);
        }

        if (existingOrgByEmail && existingOrgByEmail.length > 0) {
          useUIStore.getState().addNotification({
            type: 'error',
            title: 'Duplicate email',
            message: 'An organization with this main email already exists. Please use a different email.',
          });
          setIsSaving(false);
          return;
        }
      }

      // Try Edge Function first, fallback to direct Supabase if it fails
      console.log('💾 Saving organization with payload:', organizationData);
      console.log('📋 Organization ID:', organizationId || 'NEW');
      
      const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
      if (!supabaseUrl) {
        throw new Error('VITE_SUPABASE_URL is not configured');
      }

      let result: any = null;
      let useEdgeFunction = true;

      // Try Edge Function
      try {
        const functionUrl = `${supabaseUrl}/functions/v1/create-organization-with-user`;
        const { data: session } = await supabase.auth.getSession();
        
        console.log('📞 Calling Edge Function:', functionUrl);
        
        const response = await fetch(functionUrl, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${session?.session?.access_token || ''}`,
            'apikey': import.meta.env.VITE_SUPABASE_ANON_KEY || '',
          },
          body: JSON.stringify({
            organizationId: organizationId || null,
            organizationData,
          }),
        });

        console.log('📥 Edge Function response status:', response.status);

        if (!response.ok) {
          const errorText = await response.text();
          console.error('❌ Edge Function error response:', errorText);
          let errorData;
          try {
            errorData = JSON.parse(errorText);
          } catch {
            errorData = { error: errorText || 'Edge Function failed' };
          }
          throw new Error(errorData.error || `Edge Function returned status ${response.status}`);
        }

        result = await response.json();
        console.log('✅ Edge Function response:', result);
        
        if (!result.success) {
          throw new Error(result.error || 'Edge Function returned unsuccessful response');
        }
      } catch (edgeError: any) {
        console.warn('⚠️ Edge Function failed, falling back to direct Supabase:', edgeError);
        useEdgeFunction = false;
        
        // Fallback: Use direct Supabase (without user creation for now)
        const now = new Date().toISOString();
        
        if (organizationId) {
          // Update existing organization
          console.log('🔄 Updating existing organization directly...');
          const { data: savedOrg, error: updateError } = await supabase
            .from('Organizations')
            .update({
              ...organizationData,
              updated_at: now,
            })
            .eq('id', organizationId)
            .select()
            .single();

          if (updateError) {
            console.error('❌ Error updating organization:', updateError);
            throw updateError;
          }

          if (!savedOrg) {
            throw new Error('No data returned from update operation');
          }

          result = {
            success: true,
            organization: savedOrg,
            initialPassword: undefined,
            userCreationError: 'Edge Function not available. User creation skipped.',
          };
        } else {
          // Insert new organization
          console.log('➕ Creating new organization directly...');
          const { data: savedOrg, error: insertError } = await supabase
            .from('Organizations')
            .insert({
              ...organizationData,
              created_at: now,
              updated_at: now,
            })
            .select()
            .single();

          if (insertError) {
            console.error('❌ Error creating organization:', insertError);
            throw insertError;
          }

          if (!savedOrg) {
            throw new Error('No data returned from insert operation');
          }

          result = {
            success: true,
            organization: savedOrg,
            initialPassword: undefined,
            userCreationError: 'Edge Function not available. Please create user manually or deploy the Edge Function.',
          };
        }
      }

      console.log('✅ Final result:', result);

      if (!result || !result.organization) {
        console.error('❌ Invalid result structure:', result);
        throw new Error('Invalid response from server: missing organization data');
      }

      const savedOrg = result.organization;
      console.log('📋 Saved organization data:', savedOrg);

      // Update local state with saved data
      setOrganizationId(savedOrg.id);
      setOrganizationName(savedOrg.organization_name || '');
      setLegalName(savedOrg.legal_name || '');
      setTaxId(savedOrg.tax_id || '');
      setCountry(savedOrg.country || '');
      setMainEmail(savedOrg.main_email || '');
      setBillingEmail(savedOrg.billing_email || '');
      setSupportEmail(savedOrg.support_email || '');
      setPhoneNumber(savedOrg.phone_number || '');
      setTier(savedOrg.tier || 'free');
      setStatus(savedOrg.status || 'active');
      setAddressLine1(savedOrg.address_line_1 || '');
      setAddressLine2(savedOrg.address_line_2 || '');
      setCity(savedOrg.city || '');
      setState(savedOrg.state || '');
      setZipCode(savedOrg.zip_code || '');
      setDefaultCurrency(savedOrg.default_currency || 'USD');
      setDefaultLocale(savedOrg.default_locale || 'es-PA');
      
      // Handle response
      if (result.initialPassword) {
        // New organization with user created - show password modal
        setPasswordModalData({
          email: mainEmail.trim(),
          password: result.initialPassword,
          organizationName: organizationName.trim(),
        });
        setShowPasswordModal(true);
        
        useUIStore.getState().addNotification({
          type: 'success',
          title: 'Organization created and access enabled',
          message: 'The organization has been created and a user account has been set up.',
        });
      } else if (result.userCreationError) {
        // Organization created but user creation failed
        useUIStore.getState().addNotification({
          type: 'error',
          title: 'Organization saved, but failed to create login user',
          message: result.userCreationError,
        });
      } else if (organizationId) {
        // Existing organization updated
        useUIStore.getState().addNotification({
          type: 'success',
          title: 'Organization updated',
          message: 'Your organization profile has been saved successfully.',
        });
      } else {
        // New organization but user already exists
        console.log('✅ Organization created successfully (user already exists or Edge Function not available)');
        useUIStore.getState().addNotification({
          type: 'success',
          title: 'Organization created',
          message: 'The organization has been created successfully.' + (result.userCreationError ? ' Note: ' + result.userCreationError : ''),
        });
      }

      // Refresh organizations list
      if (organizationsRefetch) {
        console.log('🔄 Refreshing organizations list...');
        try {
          await organizationsRefetch();
          console.log('✅ Organizations list refreshed');
        } catch (refetchError) {
          console.error('⚠️ Error refreshing organizations list:', refetchError);
        }
      }
      
      console.log('✅ Save operation completed successfully');

    } catch (error: any) {
      console.error('❌ Error saving organization profile:', error);
      console.error('Error type:', typeof error);
      console.error('Error keys:', Object.keys(error || {}));
      console.error('Error message:', error?.message);
      console.error('Error details:', error?.details);
      console.error('Error code:', error?.code);
      console.error('Error hint:', error?.hint);
      
      // Show error notification with detailed message
      const errorMessage = error?.message || error?.details || error?.hint || 'Something went wrong while saving the organization profile. Please try again.';
      
      console.error('📢 Showing error notification to user:', errorMessage);
      console.error('Full error object:', JSON.stringify(error, null, 2));
      
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Could not save organization',
        message: errorMessage,
      });
    } finally {
      setIsSaving(false);
      console.log('🏁 Save operation completed, isSaving set to false');
    }
  };

  const handleCancel = () => {
    // Reset form to empty state
    resetForm();
  };

  const handleSelectOrganization = (org: Organization) => {
    setSelectedOrganization(org);
    setActiveTab('profile');
  };

  return (
    <div className="p-6">
      {/* Tab Toggle Header - Matching Sub bar style from Layout (height: 2.625rem) */}
      <div className="bg-white border border-gray-200 rounded-t-lg overflow-hidden mb-0">
        <div 
          className="border-b"
          style={{
            height: '2.625rem',
            backgroundColor: 'var(--gray-100)',
            borderColor: 'var(--gray-250)'
          }}
        >
          <div className="flex items-stretch h-full" role="tablist">
            <button
              onClick={() => setActiveTab('profile')}
              className={`transition-colors flex items-center justify-start border-r ${
                activeTab === 'profile'
                  ? 'bg-white font-semibold'
                  : 'hover:bg-white/50 font-normal'
              }`}
              style={{
                fontSize: '12px',
                padding: '0 48px',
                height: '100%',
                minWidth: '140px',
                width: 'auto',
                color: activeTab === 'profile' ? 'var(--primary-brand-hex)' : 'var(--graphite-black-hex)',
                borderColor: 'var(--gray-250)',
                borderBottom: activeTab === 'profile' ? '2px solid var(--primary-brand-hex)' : 'none'
              }}
              role="tab"
              aria-selected={activeTab === 'profile'}
            >
              Profile
            </button>
            <button
              onClick={() => setActiveTab('records')}
              className={`transition-colors flex items-center justify-start ${
                activeTab === 'records'
                  ? 'bg-white font-semibold'
                  : 'hover:bg-white/50 font-normal'
              }`}
              style={{
                fontSize: '12px',
                padding: '0 48px',
                height: '100%',
                minWidth: '140px',
                width: 'auto',
                color: activeTab === 'records' ? 'var(--primary-brand-hex)' : 'var(--graphite-black-hex)',
                borderBottom: activeTab === 'records' ? '2px solid var(--primary-brand-hex)' : 'none'
              }}
              role="tab"
              aria-selected={activeTab === 'records'}
            >
              Records
            </button>
            <button
              onClick={() => setActiveTab('users')}
              className={`transition-colors flex items-center justify-start ${
                activeTab === 'users'
                  ? 'bg-white font-semibold'
                  : 'hover:bg-white/50 font-normal'
              }`}
              style={{
                fontSize: '12px',
                padding: '0 48px',
                height: '100%',
                minWidth: '140px',
                width: 'auto',
                color: activeTab === 'users' ? 'var(--primary-brand-hex)' : 'var(--graphite-black-hex)',
                borderBottom: activeTab === 'users' ? '2px solid var(--primary-brand-hex)' : 'none'
              }}
              role="tab"
              aria-selected={activeTab === 'users'}
            >
              Users
            </button>
          </div>
        </div>
      </div>

      {/* Tab Content */}
      {activeTab === 'users' ? (
        <OrganizationUsers organizationId={organizationId || selectedOrganization?.id || null} />
      ) : activeTab === 'records' ? (
        <OrganizationsRecords 
          onSelectOrganization={handleSelectOrganization}
          selectedOrganizationId={organizationId || undefined}
          onRefetchReady={(refetch) => { organizationsRefetch = refetch; }}
        />
      ) : (
        <div className="bg-white border-l border-r border-b border-gray-200 rounded-b-lg p-6">
          {isLoading ? (
            <div className="flex items-center justify-center min-h-[400px]">
              <div className="text-center">
                <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary mx-auto mb-4"></div>
                <p className="text-sm text-gray-600">Loading organization...</p>
              </div>
            </div>
          ) : (
            <div className="space-y-6">
        {/* IDENTITY - Row 1 */}
        <div>
          <h3 className="text-sm font-semibold text-gray-900 mb-3">IDENTITY</h3>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <Label htmlFor="organization_name" className="text-xs" required>Organization Name</Label>
              <Input
                id="organization_name"
                value={organizationName}
                onChange={(e) => {
                  setOrganizationName(e.target.value);
                  if (validationErrors.organizationName) {
                    setValidationErrors(prev => ({ ...prev, organizationName: '' }));
                  }
                }}
                placeholder="Organization Name"
                className="py-1 text-xs"
                error={validationErrors.organizationName}
              />
            </div>
            <div>
              <Label htmlFor="legal_name" className="text-xs">Legal Name</Label>
              <Input
                id="legal_name"
                value={legalName}
                onChange={(e) => setLegalName(e.target.value)}
                className="py-1 text-xs"
              />
            </div>
          </div>
        </div>

        {/* IDENTITY - Row 2 */}
        <div>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <Label htmlFor="tax_id" className="text-xs" required>ID Number</Label>
              <Input
                id="tax_id"
                value={taxId}
                onChange={(e) => {
                  setTaxId(e.target.value);
                  if (validationErrors.tax_id) {
                    setValidationErrors(prev => ({ ...prev, tax_id: '' }));
                  }
                }}
                className="py-1 text-xs"
                error={validationErrors.tax_id}
              />
            </div>
            <div>
              <Label htmlFor="country" className="text-xs" required>Country</Label>
              <SelectShadcn
                value={country || ''}
                onValueChange={(value) => {
                  setCountry(value);
                  if (validationErrors.country) {
                    setValidationErrors(prev => ({ ...prev, country: '' }));
                  }
                }}
              >
                <SelectTrigger className={`py-1 text-xs ${validationErrors.country ? 'border-red-300 bg-red-50' : ''}`}>
                  <SelectValue placeholder="Select country" />
                </SelectTrigger>
                <SelectContent>
                  {COUNTRIES.map((c) => (
                    <SelectItem key={c} value={c}>
                      {c}
                    </SelectItem>
                  ))}
                </SelectContent>
              </SelectShadcn>
              {validationErrors.country && (
                <p className="mt-1 text-xs text-red-600">{validationErrors.country}</p>
              )}
            </div>
          </div>
        </div>

        {/* CONTACT - Row 3 */}
        <div>
          <h3 className="text-sm font-semibold text-gray-900 mb-3">CONTACT</h3>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <Label htmlFor="main_email" className="text-xs" required>Main Email</Label>
              <Input
                id="main_email"
                type="email"
                value={mainEmail}
                onChange={(e) => {
                  setMainEmail(e.target.value);
                  if (validationErrors.main_email) {
                    setValidationErrors(prev => ({ ...prev, main_email: '' }));
                  }
                }}
                className="py-1 text-xs"
                error={validationErrors.main_email}
              />
            </div>
            <div>
              <Label htmlFor="billing_email" className="text-xs">Billing Email</Label>
              <Input
                id="billing_email"
                type="email"
                value={billingEmail}
                onChange={(e) => setBillingEmail(e.target.value)}
                className="py-1 text-xs"
              />
            </div>
          </div>
        </div>

        {/* CONTACT - Row 4 */}
        <div>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <Label htmlFor="support_email" className="text-xs">Support Email</Label>
              <Input
                id="support_email"
                type="email"
                value={supportEmail}
                onChange={(e) => setSupportEmail(e.target.value)}
                className="py-1 text-xs"
              />
            </div>
            <div>
              <Label htmlFor="phone_number" className="text-xs">Phone Number</Label>
              <Input
                id="phone_number"
                type="tel"
                value={phoneNumber}
                onChange={(e) => setPhoneNumber(e.target.value)}
                className="py-1 text-xs"
              />
            </div>
          </div>
        </div>

        {/* PLAN / TIER - Row 5 */}
        <div>
          <h3 className="text-sm font-semibold text-gray-900 mb-3">PLAN / TIER</h3>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <Label htmlFor="tier" className="text-xs">Tier</Label>
              <SelectShadcn
                value={tier}
                onValueChange={(value) => setTier(value as typeof tier)}
              >
                <SelectTrigger className="py-1 text-xs">
                  <SelectValue placeholder="Select tier" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="free">Free</SelectItem>
                  <SelectItem value="starter">Starter</SelectItem>
                  <SelectItem value="pro">Pro</SelectItem>
                  <SelectItem value="enterprise">Enterprise</SelectItem>
                </SelectContent>
              </SelectShadcn>
            </div>
            <div>
              <Label htmlFor="status" className="text-xs">Status</Label>
              <SelectShadcn
                value={status}
                onValueChange={(value) => setStatus(value as typeof status)}
              >
                <SelectTrigger className="py-1 text-xs">
                  <SelectValue placeholder="Select status" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="active">Active</SelectItem>
                  <SelectItem value="trialing">Trialing</SelectItem>
                  <SelectItem value="suspended">Suspended</SelectItem>
                </SelectContent>
              </SelectShadcn>
            </div>
          </div>
        </div>

        {/* ADDRESS - Row 6 */}
        <div>
          <h3 className="text-sm font-semibold text-gray-900 mb-3">ADDRESS</h3>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <Label htmlFor="address_line_1" className="text-xs" required>Address Line 1</Label>
              <Input
                id="address_line_1"
                value={addressLine1}
                onChange={(e) => {
                  setAddressLine1(e.target.value);
                  if (validationErrors.address_line_1) {
                    setValidationErrors(prev => ({ ...prev, address_line_1: '' }));
                  }
                }}
                className="py-1 text-xs"
                error={validationErrors.address_line_1}
              />
            </div>
            <div>
              <Label htmlFor="address_line_2" className="text-xs">Address Line 2</Label>
              <Input
                id="address_line_2"
                value={addressLine2}
                onChange={(e) => setAddressLine2(e.target.value)}
                className="py-1 text-xs"
              />
            </div>
          </div>
        </div>

        {/* ADDRESS - Row 7 */}
        <div>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <Label htmlFor="city" className="text-xs" required>City</Label>
              <Input
                id="city"
                value={city}
                onChange={(e) => {
                  setCity(e.target.value);
                  if (validationErrors.city) {
                    setValidationErrors(prev => ({ ...prev, city: '' }));
                  }
                }}
                className="py-1 text-xs"
                error={validationErrors.city}
              />
            </div>
            <div>
              <Label htmlFor="state" className="text-xs" required>State</Label>
              <Input
                id="state"
                value={state}
                onChange={(e) => {
                  setState(e.target.value);
                  if (validationErrors.state) {
                    setValidationErrors(prev => ({ ...prev, state: '' }));
                  }
                }}
                className="py-1 text-xs"
                error={validationErrors.state}
              />
            </div>
          </div>
        </div>

        <div>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <Label htmlFor="zip_code" className="text-xs" required>Zip Code</Label>
              <Input
                id="zip_code"
                value={zipCode}
                onChange={(e) => {
                  setZipCode(e.target.value);
                  if (validationErrors.zip_code) {
                    setValidationErrors(prev => ({ ...prev, zip_code: '' }));
                  }
                }}
                className="py-1 text-xs"
                error={validationErrors.zip_code}
              />
            </div>
          </div>
        </div>

        {/* CONFIG DEFAULTS - Row 8 */}
        <div>
          <h3 className="text-sm font-semibold text-gray-900 mb-3">CONFIG DEFAULTS</h3>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <Label htmlFor="default_currency" className="text-xs">Default Currency</Label>
              <SelectShadcn
                value={defaultCurrency}
                onValueChange={(value) => setDefaultCurrency(value as typeof defaultCurrency)}
              >
                <SelectTrigger className="py-1 text-xs">
                  <SelectValue placeholder="Select currency" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="USD">USD</SelectItem>
                  <SelectItem value="PAB">PAB</SelectItem>
                  <SelectItem value="EUR">EUR</SelectItem>
                </SelectContent>
              </SelectShadcn>
            </div>
            <div>
              <Label htmlFor="default_locale" className="text-xs">Default Locale</Label>
              <SelectShadcn
                value={defaultLocale}
                onValueChange={(value) => setDefaultLocale(value as typeof defaultLocale)}
              >
                <SelectTrigger className="py-1 text-xs">
                  <SelectValue placeholder="Select locale" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="es-PA">es-PA</SelectItem>
                  <SelectItem value="en-US">en-US</SelectItem>
                </SelectContent>
              </SelectShadcn>
            </div>
          </div>
        </div>


              <div className="flex gap-3">
                <button
                  type="button"
                  onClick={(e) => {
                    e.preventDefault();
                    handleSave(e);
                  }}
                  disabled={isSaving}
                  className="px-4 py-2 bg-primary text-white rounded-md hover:bg-primary/90 transition-colors disabled:opacity-50 disabled:cursor-not-allowed text-sm flex items-center gap-2"
                  style={{ backgroundColor: 'var(--primary-brand-hex)' }}
                >
                  {isSaving && (
                    <div className="animate-spin rounded-full h-4 w-4 border-2 border-white border-t-transparent"></div>
                  )}
                  {isSaving ? 'Saving...' : 'Save Changes'}
                </button>
                <button
                  onClick={handleCancel}
                  className="px-4 py-2 border border-gray-300 text-gray-700 rounded-md hover:bg-gray-50 transition-colors text-sm"
                >
                  Cancel
                </button>
              </div>
            </div>
          )}
        </div>
      )}

      {/* Password Modal */}
      {passwordModalData && (
        <PasswordModal
          isOpen={showPasswordModal}
          onClose={() => {
            setShowPasswordModal(false);
            setPasswordModalData(null);
          }}
          email={passwordModalData.email}
          password={passwordModalData.password}
          organizationName={passwordModalData.organizationName}
        />
      )}
    </div>
  );
}


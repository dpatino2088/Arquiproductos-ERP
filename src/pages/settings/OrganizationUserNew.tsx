import { useState, useEffect } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { router } from '../../lib/router';
import { supabase } from '../../lib/supabase/client';
import { useUIStore } from '../../stores/ui-store';
import { X, ChevronLeft } from 'lucide-react';
import Input from '../../components/ui/Input';
import { Select as SelectShadcn, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../../components/ui/SelectShadcn';
import Label from '../../components/ui/Label';
import { useCurrentOrgRole } from '../../hooks/useCurrentOrgRole';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useAuthStore } from '../../stores/auth-store';
import { NoOrganizationMessage } from '../../components/NoOrganizationMessage';
import { useContacts, useCustomers } from '../../hooks/useDirectory';

// Schema for organization user
const organizationUserSchema = z.object({
  name: z.string().min(1, 'Name is required'),
  email: z.string().email('Invalid email address').min(1, 'Email is required'),
  role: z.enum(['owner', 'admin', 'member', 'viewer']),
  contact_id: z.string().uuid('Contact is required').min(1, 'Contact is required'),
  customer_id: z.string().uuid('Customer is required').min(1, 'Customer is required'),
});

type OrganizationUserFormData = z.infer<typeof organizationUserSchema>;

interface OrganizationUser {
  id: string;
  role: 'owner' | 'admin' | 'member' | 'viewer';
  created_at: string;
  user_id: string;
  name?: string;
  email?: string;
  contact_id?: string;
  customer_id?: string;
}

interface OrganizationUserNewProps {
  embedded?: boolean; // If true, this component is embedded within Settings
}

export default function OrganizationUserNew({ embedded = false }: OrganizationUserNewProps) {
  const [isSaving, setIsSaving] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [userId, setUserId] = useState<string | null>(null);
  const [existingUser, setExistingUser] = useState<OrganizationUser | null>(null);
  const { activeOrganizationId, activeOrganization, hasOrganizations, loading: orgLoading } = useOrganizationContext();
  const { user } = useAuthStore();
  
  // Get current user's role and permissions
  const { canManageUsers, isViewer, loading: roleLoading, isOwner } = useCurrentOrgRole();
  
  // Determine if form should be read-only
  const isReadOnly = isViewer || !canManageUsers;

  // Load customers and contacts for selection
  const { customers, isLoading: customersLoading, error: customersError } = useCustomers();
  const { contacts, isLoading: contactsLoading } = useContacts();
  
  // State to track selected customer and available contacts for that customer
  const [selectedCustomerId, setSelectedCustomerId] = useState<string | null>(null);
  const [availableContactsForCustomer, setAvailableContactsForCustomer] = useState<Array<{ id: string; firstName: string; lastName: string; fullName: string; email: string }>>([]);

  // Debug: Log customers loading state
  useEffect(() => {
    if (import.meta.env.DEV) {
      console.log('OrganizationUserNew - Customers state:', {
        customersCount: customers.length,
        customersLoading,
        customersError,
        activeOrganizationId,
        availableCustomersCount: customers.filter((c) => c.status !== 'Archived').length
      });
    }
  }, [customers, customersLoading, customersError, activeOrganizationId]);

  // Filter customers to only show active, non-archived
  // Note: deleted customers are already filtered in the query
  const availableCustomers = customers.filter(
    (customer) => customer.status !== 'Archived'
  );

  // Get user ID from URL if in edit mode
  useEffect(() => {
    const path = window.location.pathname;
    const match = path.match(/\/settings\/organization-users\/edit\/([^/]+)/);
    if (match && match[1]) {
      setUserId(match[1]);
      loadUserData(match[1]);
    }
  }, []);

  const form = useForm<OrganizationUserFormData>({
    resolver: zodResolver(organizationUserSchema),
    defaultValues: {
      name: '',
      email: '',
      role: 'member',
      contact_id: '',
      customer_id: '',
    },
  });

  // Load user data for edit mode
  const loadUserData = async (id: string) => {
    if (!activeOrganizationId) {
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'No organization selected',
        message: 'Please select an organization first.',
      });
      router.navigate('/settings/organization-user');
      return;
    }

    setIsLoading(true);
    try {
      // Primero intentar query directo (más rápido y confiable)
      const { data: directData, error: directError } = await supabase
        .from('OrganizationUsers')
        .select('id, role, created_at, user_id, name, email, invited_by, contact_id, customer_id')
        .eq('organization_id', activeOrganizationId)
        .eq('id', id)  // Buscar por id del registro, no user_id
        .eq('deleted', false)
        .maybeSingle();

      if (!directError && directData) {
        setExistingUser(directData);
        const contactId = directData.contact_id || '';
        const customerId = directData.customer_id || '';
        
        form.reset({
          name: directData.name || '',
          email: directData.email || '',
          role: directData.role,
          contact_id: contactId,
          customer_id: customerId,
        });

        // Load available contacts for the customer if customer_id exists
        if (customerId) {
          setSelectedCustomerId(customerId);
          await loadContactsForCustomer(customerId, contactId);
        }
        
        setIsLoading(false);
        return;
      }

      // Si falla, usar Edge Function como fallback
      const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
      if (!supabaseUrl) {
        throw new Error('VITE_SUPABASE_URL is not configured');
      }

      const { data: session, error: sessionError } = await supabase.auth.getSession();
      
      if (sessionError || !session?.session) {
        throw new Error('Not authenticated');
      }

      const functionUrl = `${supabaseUrl}/functions/v1/get-organization-users`;
      const response = await fetch(functionUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${session.session.access_token}`,
          'apikey': import.meta.env.VITE_SUPABASE_ANON_KEY || '',
        },
        body: JSON.stringify({ organizationId: activeOrganizationId }),
      });

      if (response.ok) {
        const result = await response.json();
        // Buscar por id del registro, no user_id
        const foundUser = result.users?.find((u: OrganizationUser) => u.id === id);
        
        if (foundUser) {
          setExistingUser(foundUser);
          const contactId = foundUser.contact_id || '';
          const customerId = foundUser.customer_id || '';
          
          form.reset({
            name: foundUser.name || '',
            email: foundUser.email || '',
            role: foundUser.role,
            contact_id: contactId,
            customer_id: customerId,
          });

          // Load available contacts for the customer if customer_id exists
          if (customerId) {
            setSelectedCustomerId(customerId);
            await loadContactsForCustomer(customerId, contactId);
          }
          
          setIsLoading(false);
          return;
        }
      }

      // Si no se encuentra el usuario
      throw new Error('User not found in this organization');
    } catch (err: any) {
      console.error('Error loading user:', err);
      const errorMessage = err.message || 'Could not load user data. Please try again.';
      setSaveError(errorMessage);
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error loading user',
        message: errorMessage,
      });
      // No redirigir automáticamente, permitir que el usuario intente de nuevo
    } finally {
      setIsLoading(false);
    }
  };

  // Helper function to load contacts for a customer
  const loadContactsForCustomer = async (customerId: string, preselectedContactId?: string) => {
    if (!activeOrganizationId) return;

    try {
      // Get the customer to find its primary_contact_id
      const { data: customerData, error: customerError } = await supabase
        .from('DirectoryCustomers')
        .select('primary_contact_id')
        .eq('id', customerId)
        .eq('organization_id', activeOrganizationId)
        .eq('deleted', false)
        .maybeSingle();

      if (customerError || !customerData) {
        setAvailableContactsForCustomer([]);
        form.setValue('contact_id', '');
        return;
      }

      // Get the primary contact for this customer
      const primaryContactId = customerData.primary_contact_id;
      
      if (!primaryContactId) {
        setAvailableContactsForCustomer([]);
        form.setValue('contact_id', '');
        return;
      }

      // Get the contact details
      const { data: contactData, error: contactError } = await supabase
        .from('DirectoryContacts')
        .select('id, customer_name, email, first_name, last_name')
        .eq('id', primaryContactId)
        .eq('organization_id', activeOrganizationId)
        .eq('deleted', false)
        .maybeSingle();

      if (!contactError && contactData) {
        // Construir nombre completo: first_name + last_name, o customer_name si no hay first_name
        const fullName = contactData.first_name && contactData.last_name
          ? `${contactData.first_name} ${contactData.last_name}`.trim()
          : contactData.customer_name || contactData.first_name || contactData.last_name || '';

        // Transform to match the interface
        const contact = {
          id: contactData.id,
          firstName: contactData.first_name || '',
          lastName: contactData.last_name || '',
          fullName: fullName,
          email: contactData.email || '',
        };
        
        setAvailableContactsForCustomer([contact]);

        // Auto-select the primary contact
        if (preselectedContactId) {
          form.setValue('contact_id', preselectedContactId);
        } else {
          form.setValue('contact_id', contactData.id);
          // Auto-fill name and email (only when creating new user)
          if (!userId) {
            form.setValue('name', contact.fullName);
            form.setValue('email', contact.email);
          }
        }
      } else {
        setAvailableContactsForCustomer([]);
        form.setValue('contact_id', '');
      }
    } catch (err) {
      console.error('Error finding contact for customer:', err);
      setAvailableContactsForCustomer([]);
      form.setValue('contact_id', '');
    }
  };

  // Handler for when customer is selected
  const handleCustomerChange = async (customerId: string) => {
    form.setValue('customer_id', customerId, { shouldValidate: true });
    setSelectedCustomerId(customerId);

    // Clear contact and related fields when customer changes
    form.setValue('contact_id', '');
    if (!userId) {
      form.setValue('name', '');
      form.setValue('email', '');
    }

    // Load contacts for this customer
    await loadContactsForCustomer(customerId);
  };

  // Handler for when contact is selected (should only happen if there are multiple contacts, but for now customer has only one primary contact)
  const handleContactChange = async (contactId: string) => {
    form.setValue('contact_id', contactId, { shouldValidate: true });

    // Find the selected contact
    const selectedContact = availableContactsForCustomer.find((c) => c.id === contactId);

    if (selectedContact && !userId) {
      // Auto-fill name and email from contact (only when creating new user)
      // Usar fullName si existe, sino construir desde firstName + lastName
      const fullName = selectedContact.fullName || 
        `${selectedContact.firstName || ''} ${selectedContact.lastName || ''}`.trim() || 
        selectedContact.firstName || '';
      form.setValue('name', fullName);
      form.setValue('email', selectedContact.email || '');
    }
  };

  const handleSubmit = async (data: OrganizationUserFormData) => {
    // Validación mejorada para asegurar que activeOrganizationId esté presente
    if (!activeOrganizationId) {
      const errorMsg = 'No organization selected. Please select an organization first.';
      setSaveError(errorMsg);
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'No Organization Selected',
        message: 'Please select an organization from the switcher above before creating a user.',
      });
      return;
    }

    if (!user?.id) {
      const errorMsg = 'User not authenticated. Please log in again.';
      setSaveError(errorMsg);
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Authentication Error',
        message: 'Your session has expired. Please log in again.',
      });
      return;
    }

    setIsSaving(true);
    setSaveError(null);

    try {
      // Validate that both contact_id and customer_id are set
      if (!data.contact_id || !data.customer_id) {
        const errorMsg = 'Contact and Customer are required. Please select a contact that is linked to a customer.';
        setSaveError(errorMsg);
        form.setError('contact_id', { type: 'manual', message: 'Contact is required' });
        form.setError('customer_id', { type: 'manual', message: 'Customer is required' });
        return;
      }

      const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
      if (!supabaseUrl) {
        throw new Error('VITE_SUPABASE_URL is not configured');
      }

      const { data: session } = await supabase.auth.getSession();
      if (!session?.session?.access_token) {
        throw new Error('Not authenticated');
      }

      if (userId && existingUser) {
        // Update existing user role, name, contact_id, and customer_id
        // Usar id del registro, no user_id
        const { error } = await supabase
          .from('OrganizationUsers')
          .update({ 
            role: data.role,
            name: data.name.trim(),
            contact_id: data.contact_id,
            customer_id: data.customer_id,
            updated_at: new Date().toISOString() 
          })
          .eq('id', userId)  // Usar id del registro
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false);

        if (error) throw error;

        useUIStore.getState().addNotification({
          type: 'success',
          title: 'User Updated',
          message: 'User role has been updated successfully.',
        });

        router.navigate('/settings/organization-user');
      } else {
        // Create new Organization User directly (sin Edge Function, sin enviar email)
        const normalizedEmail = data.email.trim().toLowerCase();
        const userName = data.name.trim();

        // Verificar si el usuario ya existe en OrganizationUsers para esta organización
        const { data: existingOrgUser, error: checkError } = await supabase
          .from('OrganizationUsers')
          .select('id, user_id, deleted')
          .eq('organization_id', activeOrganizationId)
          .eq('email', normalizedEmail)
          .maybeSingle();

        if (checkError && checkError.code !== 'PGRST116') {
          throw new Error(`Error verificando usuario existente: ${checkError.message}`);
        }

        // Si el usuario ya existe y está activo
        if (existingOrgUser && !existingOrgUser.deleted) {
          throw new Error('El usuario ya es miembro de esta organización');
        }

        // Si el usuario existe pero está eliminado (soft delete), reactivarlo
        if (existingOrgUser && existingOrgUser.deleted) {
          const { error: updateError } = await supabase
            .from('OrganizationUsers')
            .update({
              role: data.role,
              name: userName,
              email: normalizedEmail,
              contact_id: data.contact_id,
              customer_id: data.customer_id,
              deleted: false,
              updated_at: new Date().toISOString(),
            })
            .eq('id', existingOrgUser.id);

          if (updateError) {
            throw new Error(`Error reactivando usuario: ${updateError.message}`);
          }

          useUIStore.getState().addNotification({
            type: 'success',
            title: 'Usuario Agregado',
            message: 'El usuario ha sido reactivado en la organización.',
          });

          router.navigate('/settings/organization-user');
          return;
        }

        // Crear el registro directamente en OrganizationUsers
        // Generamos un user_id temporal que se actualizará cuando el usuario se registre
        // Nota: Esto requiere que cuando el usuario se registre con este email,
        // se actualice el user_id en OrganizationUsers con el ID real de auth.users
        
        // Generar UUID temporal para user_id
        // Este se actualizará cuando el usuario se registre con este email
        const tempUserId = crypto.randomUUID();

        const insertData = {
          organization_id: activeOrganizationId,
          user_id: tempUserId, // UUID temporal, se actualizará cuando el usuario se registre
          role: data.role,
          name: userName,
          email: normalizedEmail,
          contact_id: data.contact_id,
          customer_id: data.customer_id,
          invited_by: user.id,
          deleted: false,
        };

        const { error: insertError } = await supabase
          .from('OrganizationUsers')
          .insert(insertData);

        if (insertError) {
          // Si el error es de constraint único, el usuario ya existe
          if (insertError.code === '23505' || insertError.message?.includes('duplicate') || insertError.message?.includes('unique')) {
            throw new Error('El usuario ya es miembro de esta organización');
          }
          throw new Error(`Error agregando usuario a la organización: ${insertError.message}`);
        }

        useUIStore.getState().addNotification({
          type: 'success',
          title: 'Usuario Creado',
          message: 'El usuario ha sido agregado a la organización. El usuario deberá registrarse para acceder al sistema.',
        });

        router.navigate('/settings/organization-user');
      }
    } catch (err: any) {
      console.error('Error saving user:', err);
      const errorMessage = err.message || 'Failed to save user. Please try again.';
      setSaveError(errorMessage);
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: errorMessage,
      });
    } finally {
      setIsSaving(false);
    }
  };

  // Show message if user has no organizations at all
  if (!orgLoading && !hasOrganizations) {
    return <NoOrganizationMessage />;
  }

  // Show message if organization is not selected (but user has organizations)
  if (!orgLoading && !activeOrganizationId && hasOrganizations) {
    return (
      <div className="p-6">
        <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
          <p className="text-sm text-yellow-800 font-medium">No organization selected</p>
          <p className="text-sm text-yellow-700 mt-1">Please select an organization from the switcher above to continue.</p>
        </div>
      </div>
    );
  }

  if (isLoading || roleLoading) {
    return (
      <div className="p-6">
        <div className="flex items-center justify-center min-h-[400px]">
          <div className="text-center">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary mx-auto mb-4"></div>
            <p className="text-sm text-gray-600">Loading...</p>
          </div>
        </div>
      </div>
    );
  }

  // If embedded, don't show the outer padding/container - Settings will handle that
  const content = (
    <>
      {/* Header - only show if not embedded */}
      {!embedded && (
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center gap-3">
            <button
              onClick={() => router.navigate('/settings/organization-user')}
              className="text-gray-400 hover:text-gray-600 transition-colors"
            >
              <ChevronLeft className="w-5 h-5" />
            </button>
            <div>
              <h1 className="text-xl font-semibold text-foreground">
                {userId ? 'Edit Organization User' : 'Add Organization User'}
              </h1>
              <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
                {userId ? 'Update user role and permissions' : 'Invite a new user to your organization'}
              </p>
            </div>
          </div>
        </div>
      )}

      {/* Embedded header - simpler version when inside Settings */}
      {embedded && (
        <div className="mb-6">
          <h2 className="text-xl font-semibold text-gray-900 mb-2">
            {userId ? 'Edit Organization User' : 'Add Organization User'}
          </h2>
          <p className="text-sm text-gray-600">
            {userId ? 'Update user role and permissions' : 'Invite a new user to your organization'}
          </p>
        </div>
      )}

      {/* Form */}
      <div className="bg-white border border-gray-200 p-6">
        <form onSubmit={form.handleSubmit(handleSubmit)} className="space-y-6">
          {/* Customer Field - FIRST */}
          <div>
            <Label htmlFor="customer_id" className="text-xs" required>
              Customer
            </Label>
            <SelectShadcn
              value={form.watch('customer_id') || ''}
              onValueChange={handleCustomerChange}
              disabled={isReadOnly || !!userId} // Disable if editing (can't change customer)
            >
              <SelectTrigger className={`py-1 text-xs ${form.formState.errors.customer_id ? 'border-red-300 bg-red-50' : ''}`}>
                <SelectValue placeholder={customersLoading ? "Loading customers..." : "Select a customer"} />
              </SelectTrigger>
              <SelectContent>
                {availableCustomers.length === 0 ? (
                  <div className="px-2 py-1.5 text-xs text-gray-500">
                    {customersLoading ? "Loading..." : "No customers available. Please create a customer first in the Directory module."}
                  </div>
                ) : (
                  availableCustomers.map((customer) => (
                    <SelectItem key={customer.id} value={customer.id}>
                      {customer.companyName || 'Unnamed Customer'}
                    </SelectItem>
                  ))
                )}
              </SelectContent>
            </SelectShadcn>
            {form.formState.errors.customer_id && (
              <p className="mt-1 text-xs text-red-600">{form.formState.errors.customer_id.message}</p>
            )}
            <p className="mt-1 text-xs text-gray-500">
              {userId 
                ? 'Customer cannot be changed for existing users'
                : 'Select a customer first. The contact will be automatically loaded based on the customer\'s primary contact.'}
            </p>
            {availableCustomers.length === 0 && !customersLoading && (
              <p className="mt-1 text-xs text-yellow-600">
                ⚠️ No customers found. Please create a customer in the Directory module before creating a user.
                {import.meta.env.DEV && customersError && (
                  <span className="block mt-1 text-red-600">Error: {customersError}</span>
                )}
                {import.meta.env.DEV && !customersError && customers.length === 0 && (
                  <span className="block mt-1 text-blue-600">Debug: Total customers loaded: 0 (check organization and database)</span>
                )}
                {import.meta.env.DEV && customers.length > 0 && (
                  <span className="block mt-1 text-blue-600">Debug: {customers.length} customers loaded, {availableCustomers.length} available after filter</span>
                )}
              </p>
            )}
          </div>

          {/* Contact Field - SECOND */}
          <div>
            <Label htmlFor="contact_id" className="text-xs" required>
              Contact
            </Label>
            <SelectShadcn
              value={form.watch('contact_id') || ''}
              onValueChange={handleContactChange}
              disabled={isReadOnly || !!userId || !selectedCustomerId || availableContactsForCustomer.length === 0}
            >
              <SelectTrigger className={`py-1 text-xs ${form.formState.errors.contact_id ? 'border-red-300 bg-red-50' : ''}`}>
                <SelectValue placeholder={
                  !selectedCustomerId 
                    ? "Select a customer first" 
                    : availableContactsForCustomer.length === 0 
                      ? "No contact found for this customer"
                      : "Select a contact"
                } />
              </SelectTrigger>
              <SelectContent>
                {availableContactsForCustomer.length === 0 ? (
                  <div className="px-2 py-1.5 text-xs text-gray-500">
                    {selectedCustomerId 
                      ? "No contact available. The customer must have a primary contact."
                      : "Select a customer first"}
                  </div>
                ) : (
                  availableContactsForCustomer.map((contact) => (
                    <SelectItem key={contact.id} value={contact.id}>
                      {contact.fullName || `${contact.firstName || ''} ${contact.lastName || ''}`.trim()} {contact.email ? `(${contact.email})` : ''}
                    </SelectItem>
                  ))
                )}
              </SelectContent>
            </SelectShadcn>
            {form.formState.errors.contact_id && (
              <p className="mt-1 text-xs text-red-600">{form.formState.errors.contact_id.message}</p>
            )}
            <p className="mt-1 text-xs text-gray-500">
              Contact is automatically loaded from the customer's primary contact. Email and name will be auto-filled.
            </p>
          </div>

          {/* Name Field - AUTO-FILLED FROM CONTACT */}
          <div>
            <Label htmlFor="name" className="text-xs" required>
              Name
            </Label>
            <Input
              id="name"
              type="text"
              {...form.register('name')}
              disabled={true}
              className="py-1 text-xs bg-gray-50"
              error={form.formState.errors.name?.message}
              placeholder="John Doe"
              readOnly
            />
            <p className="mt-1 text-xs text-gray-400">
              Automatically filled from selected contact's name (read-only - comes from Contact)
            </p>
          </div>

          {/* Email Field - AUTO-FILLED FROM CONTACT */}
          <div>
            <Label htmlFor="email" className="text-xs" required>
              Email
            </Label>
            <Input
              id="email"
              type="email"
              {...form.register('email')}
              disabled={true}
              className="py-1 text-xs bg-gray-50"
              error={form.formState.errors.email?.message}
              placeholder="user@example.com"
              readOnly
            />
            <p className="mt-1 text-xs text-gray-400">
              Automatically filled from selected contact (cannot be edited)
            </p>
          </div>

          {/* Role Field - ONLY FIELD USER NEEDS TO SET */}
          <div>
            <Label htmlFor="role" className="text-xs" required>
              Role
            </Label>
            <SelectShadcn
              value={form.watch('role')}
              onValueChange={(value) => form.setValue('role', value as any)}
              disabled={isReadOnly}
            >
              <SelectTrigger className={`py-1 text-xs ${form.formState.errors.role ? 'border-red-300 bg-red-50' : ''}`}>
                <SelectValue placeholder="Select role" />
              </SelectTrigger>
              <SelectContent>
                {isOwner && <SelectItem value="owner">Owner</SelectItem>}
                <SelectItem value="admin">Admin</SelectItem>
                <SelectItem value="member">Member</SelectItem>
                <SelectItem value="viewer">Viewer</SelectItem>
              </SelectContent>
            </SelectShadcn>
            {form.formState.errors.role && (
              <p className="mt-1 text-xs text-red-600">{form.formState.errors.role.message}</p>
            )}
            <p className="mt-1 text-xs text-gray-500">
              {userId 
                ? 'Change the user\'s role in this organization'
                : 'Select the role for the new user'}
            </p>
          </div>

          {/* Error Message */}
          {saveError && (
            <div className="bg-red-50 border border-red-200 p-3">
              <p className="text-sm text-red-800">{saveError}</p>
            </div>
          )}

          {/* Read Only Message */}
          {isReadOnly && (
            <div className="bg-yellow-50 border border-yellow-200 p-3">
              <p className="text-sm text-yellow-800">
                You only have read permissions (viewer role). You cannot create or edit users.
              </p>
            </div>
          )}

          {/* Action Buttons */}
          <div className="flex gap-3 pt-4 border-t border-gray-200">
            <button
              type="button"
              onClick={() => router.navigate('/settings/organization-user')}
              className="px-4 py-2 border border-gray-300 text-gray-700 hover:bg-gray-50 transition-colors text-sm"
              disabled={isSaving}
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={isSaving || isReadOnly}
              className="px-4 py-2 bg-primary text-white hover:bg-primary/90 transition-colors disabled:opacity-50 disabled:cursor-not-allowed text-sm flex items-center gap-2"
              style={{ backgroundColor: 'var(--primary-brand-hex)' }}
            >
              {isSaving ? (
                <>
                  <div className="animate-spin rounded-full h-4 w-4 border-2 border-white border-t-transparent"></div>
                  <span>{userId ? 'Updating...' : 'Inviting...'}</span>
                </>
              ) : (
                <span>{userId ? 'Update User' : 'Invite User'}</span>
              )}
            </button>
          </div>
        </form>
      </div>
    </>
  );

  // If embedded, return content without outer wrapper
  if (embedded) {
    return content;
  }

  // If not embedded, wrap in container with padding
  return <div className="p-6">{content}</div>;
}


import { useState, useEffect } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { router } from '../../lib/router';
import { supabase } from '../../lib/supabase/client';
import { useUIStore } from '../../stores/ui-store';
import { ChevronLeft, X } from 'lucide-react';
import Input from '../../components/ui/Input';
import Label from '../../components/ui/Label';
import { useCurrentOrgRole } from '../../hooks/useCurrentOrgRole';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useAuthStore } from '../../stores/auth-store';
import { NoOrganizationMessage } from '../../components/NoOrganizationMessage';
// Schema: Email + Role obligatorios, Customer/Contact opcionales
const organizationUserSchema = z.object({
  email: z.string().email('Debes ingresar un email válido'),
  role: z.enum(['superadmin', 'admin', 'member']),
  customer_id: z.union([z.string().uuid(), z.null(), z.literal('')]).optional(),
  contact_id: z.union([z.string().uuid(), z.null(), z.literal('')]).optional(),
}).refine(
  (data) => {
    // Si contact_id está presente y no es null/vacío, customer_id debe estar presente
    const hasContact = data.contact_id && data.contact_id !== '' && data.contact_id !== null;
    const hasCustomer = data.customer_id && data.customer_id !== '' && data.customer_id !== null;
    if (hasContact && !hasCustomer) {
      return false;
    }
    return true;
  },
  {
    message: 'Si seleccionas un Contact, debes seleccionar un Customer',
    path: ['contact_id'],
  }
);

type OrganizationUserFormData = z.infer<typeof organizationUserSchema>;

interface OrganizationUserNewProps {
  embedded?: boolean;
}

export default function OrganizationUserNew({ embedded = false }: OrganizationUserNewProps) {
  const [isSaving, setIsSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  const { activeOrganizationId, hasOrganizations, loading: orgLoading } = useOrganizationContext();
  const { user } = useAuthStore();
  const { isSuperAdmin, loading: roleLoading } = useCurrentOrgRole();

  // ✅ OPTIONAL: Cargar contactos y customers solo si se necesita (no bloquea el flujo)
  const [customers, setCustomers] = useState<Array<{ id: string; companyName?: string; customerName?: string }>>([]);
  const [contacts, setContacts] = useState<Array<{ id: string; firstName?: string; email?: string; customer_id?: string; status?: string }>>([]);
  const [loadingCustomers, setLoadingCustomers] = useState(false);
  const [loadingContacts, setLoadingContacts] = useState(false);
  const [showLinkSection, setShowLinkSection] = useState(false);

  // Estado para contactos disponibles (solo los que tienen customer_id y email)
  const [availableContacts, setAvailableContacts] = useState<Array<{
    id: string;
    name: string;
    email: string;
    customer_id: string;
    customer_name: string;
  }>>([]);

  // ✅ Load customers and contacts OPTIONALLY (non-blocking)
  useEffect(() => {
    if (!showLinkSection || !activeOrganizationId) return;

    const loadOptionalData = async () => {
      try {
        setLoadingCustomers(true);
        const { data: customersData, error: customersError } = await supabase
          .from('DirectoryCustomers')
          .select('id, company_name, customer_name')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .limit(100);

        if (!customersError && customersData) {
          setCustomers(customersData.map(c => ({
            id: c.id,
            companyName: c.company_name,
            customerName: c.customer_name,
          })));
        }
      } catch (err) {
        // Silently fail - this is optional
        if (import.meta.env.DEV) {
          console.warn('Failed to load customers (optional):', err);
        }
      } finally {
        setLoadingCustomers(false);
      }

      try {
        setLoadingContacts(true);
        const { data: contactsData, error: contactsError } = await supabase
          .from('DirectoryContacts')
          .select('id, contact_name, email, customer_id, status')
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .limit(100);

        if (!contactsError && contactsData) {
          setContacts(contactsData.map(c => ({
            id: c.id,
            firstName: c.contact_name,
            email: c.email,
            customer_id: c.customer_id,
            status: c.status,
          })));
        }
      } catch (err) {
        // Silently fail - this is optional
        if (import.meta.env.DEV) {
          console.warn('Failed to load contacts (optional):', err);
        }
      } finally {
        setLoadingContacts(false);
      }
    };

    loadOptionalData();
  }, [showLinkSection, activeOrganizationId]);

  // Preparar contactos disponibles cuando se cargan los datos (non-blocking)
  useEffect(() => {
    if (contacts.length > 0 && customers.length > 0) {
      // Crear mapa de customers para búsqueda rápida
      const customersMap = new Map(
        customers.map(c => [c.id, c.companyName || c.customerName || 'N/A'])
      );

      // Filtrar contactos que:
      // 1. Tienen customer_id
      // 2. Tienen email (requerido para usuario único)
      // 3. No están archivados
      const validContacts = contacts
        .filter(contact => {
          const hasCustomer = contact.customer_id && customersMap.has(contact.customer_id);
          const hasEmail = contact.email && contact.email.trim().length > 0;
          const isActive = contact.status !== 'Archived';
          return hasCustomer && hasEmail && isActive;
        })
        .map(contact => ({
          id: contact.id,
          name: contact.firstName || contact.email || 'Sin nombre',
          email: contact.email!.trim().toLowerCase(),
          customer_id: contact.customer_id!,
          customer_name: customersMap.get(contact.customer_id!) || 'N/A',
        }))
        .sort((a, b) => a.name.localeCompare(b.name));

      setAvailableContacts(validContacts);
    } else {
      setAvailableContacts([]);
    }
  }, [contacts, customers]);

  const form = useForm<OrganizationUserFormData>({
    resolver: zodResolver(organizationUserSchema),
    defaultValues: {
      email: '',
      role: 'member',
      customer_id: null,
      contact_id: null,
    },
  });

  // Watch form values
  const selectedContactId = form.watch('contact_id');
  const selectedCustomerId = form.watch('customer_id');
  const selectedContact = availableContacts.find(c => c.id === selectedContactId);
  
  // Filter contacts by selected customer
  const filteredContacts = selectedCustomerId
    ? availableContacts.filter(c => c.customer_id === selectedCustomerId)
    : availableContacts;

  const handleSubmit = async (data: OrganizationUserFormData) => {
    // Validaciones básicas
    if (!activeOrganizationId) {
      setSaveError('No hay organización seleccionada. Por favor, selecciona una organización.');
      return;
    }

    if (!user?.id) {
      setSaveError('No estás autenticado. Por favor, inicia sesión nuevamente.');
      return;
    }

    // Solo Superadmin puede crear usuarios
    if (!isSuperAdmin) {
      setSaveError('Solo los Superadmins pueden crear usuarios.');
      return;
    }

    setIsSaving(true);
    setSaveError(null);

    try {
      const normalizedEmail = data.email.trim().toLowerCase();
      
      // Si se selecciona un contact, obtener su información
      let userName: string | null = null;
      // Normalizar customer_id y contact_id (convertir '' a null)
      let finalCustomerId: string | null = (data.customer_id && data.customer_id !== '') ? data.customer_id : null;
      let finalContactId: string | null = (data.contact_id && data.contact_id !== '') ? data.contact_id : null;
      
      if (finalContactId) {
        const contact = availableContacts.find(c => c.id === finalContactId);
        if (contact) {
          userName = contact.name.trim();
          // Si no se seleccionó customer pero sí contact, usar el customer del contact
          if (!finalCustomerId && contact.customer_id) {
            finalCustomerId = contact.customer_id;
          }
        }
      }

      // VALIDACIÓN CRÍTICA: Verificar que el email sea único en esta organización
      const { data: existingUser, error: checkError } = await supabase
        .from('OrganizationUsers')
        .select('id, deleted, email')
        .eq('organization_id', activeOrganizationId)
        .eq('email', normalizedEmail)
        .maybeSingle();

      if (checkError && checkError.code !== 'PGRST116') {
        throw new Error(`Error verificando email único: ${checkError.message}`);
      }

      // Si existe y está activo, error
      if (existingUser && !existingUser.deleted) {
        throw new Error(`El email ${normalizedEmail} ya está en uso por otro usuario en esta organización.`);
      }

      // Si existe pero está eliminado (soft delete), reactivarlo
      if (existingUser && existingUser.deleted) {
        const { error: updateError } = await supabase
          .from('OrganizationUsers')
          .update({
            role: data.role,
            user_name: userName,
            email: normalizedEmail,
            contact_id: finalContactId,
            customer_id: finalCustomerId,
            deleted: false,
            updated_at: new Date().toISOString(),
          })
          .eq('id', existingUser.id);

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

      // Crear nuevo usuario
      // Generar UUID temporal para user_id (se actualizará cuando el usuario se registre)
      const tempUserId = crypto.randomUUID();

      const { error: insertError } = await supabase
        .from('OrganizationUsers')
        .insert({
          organization_id: activeOrganizationId,
          user_id: tempUserId,
          role: data.role,
          user_name: userName,
          email: normalizedEmail,
          contact_id: finalContactId,
          customer_id: finalCustomerId,
          invited_by: user.id,
          deleted: false,
          is_system: false,
        });

      if (insertError) {
        // Manejo de errores específicos
        if (insertError.code === '23505' || insertError.message?.includes('unique')) {
          throw new Error('El email ya está en uso por otro usuario en esta organización.');
        }
        
        if (insertError.code === '42501' || insertError.message?.includes('permission denied')) {
          throw new Error('No tienes permisos para crear usuarios. Solo los Superadmins pueden crear usuarios.');
        }
        
        if (insertError.code === '23503' || insertError.message?.includes('foreign key')) {
          throw new Error('El contacto o customer seleccionado no es válido. Verifica que pertenezcan a esta organización.');
        }

        throw new Error(`Error agregando usuario: ${insertError.message}`);
      }

      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Usuario Creado',
        message: 'El usuario ha sido agregado a la organización exitosamente.',
      });

      router.navigate('/settings/organization-user');
    } catch (err: any) {
      console.error('Error creating user:', err);
      const errorMessage = err.message || 'Error al crear el usuario. Por favor, intenta de nuevo.';
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

  // Estados de carga (NO incluir contacts/customers loading - son opcionales)
  if (orgLoading || roleLoading) {
    return (
      <div className="py-6 px-6">
        <div className="flex items-center justify-center min-h-[400px]">
          <div className="text-center">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary mx-auto mb-4"></div>
            <p className="text-sm text-gray-600">Cargando...</p>
          </div>
        </div>
      </div>
    );
  }

  // Sin organizaciones
  if (!orgLoading && !hasOrganizations) {
    return <NoOrganizationMessage />;
  }

  // Sin organización seleccionada
  if (!orgLoading && !activeOrganizationId && hasOrganizations) {
    return (
      <div className="py-6 px-6">
        <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
          <p className="text-sm text-yellow-800 font-medium">No hay organización seleccionada</p>
          <p className="text-sm text-yellow-700 mt-1">Por favor, selecciona una organización para continuar.</p>
        </div>
      </div>
    );
  }

  // Sin permisos (solo Superadmin puede crear usuarios)
  if (!isSuperAdmin) {
    return (
      <div className="py-6 px-6">
        <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
          <p className="text-sm text-yellow-800 font-medium">Sin permisos</p>
          <p className="text-sm text-yellow-700 mt-1">Solo los Superadmins pueden crear usuarios.</p>
        </div>
      </div>
    );
  }

  const content = (
    <>
      {/* Header */}
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
              <h1 className="text-xl font-semibold text-foreground">Agregar Usuario</h1>
              <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
                Agrega un nuevo usuario a tu organización (email + rol obligatorios, Customer/Contact opcionales)
              </p>
            </div>
          </div>
        </div>
      )}

      {embedded && (
        <div className="mb-6 flex items-center justify-between">
          <div>
            <h2 className="text-xl font-semibold text-gray-900 mb-2">Agregar Usuario</h2>
            <p className="text-sm text-gray-600">
              Agrega un nuevo usuario a tu organización (email + rol obligatorios, Customer/Contact opcionales)
            </p>
          </div>
          <button
            type="button"
            onClick={() => router.navigate('/settings/organization-user')}
            className="text-gray-400 hover:text-gray-600 transition-colors p-1"
            title="Cerrar y volver a la lista"
          >
            <X className="w-5 h-5" />
          </button>
        </div>
      )}

      {/* Form */}
      <div className="bg-white border border-gray-200 rounded-lg overflow-hidden mb-4">
        <div className="py-6 px-6">
          <form onSubmit={form.handleSubmit(handleSubmit)} className="space-y-6">
            {/* Email - Campo obligatorio */}
            <div>
              <Label htmlFor="email" className="text-xs" required>
                Email
              </Label>
              <Input
                id="email"
                type="email"
                {...form.register('email')}
                className={`w-full py-1.5 px-2.5 text-xs border rounded-md bg-white focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50 ${
                  form.formState.errors.email ? 'border-red-300 bg-red-50' : 'border-gray-200'
                }`}
                placeholder="usuario@ejemplo.com"
              />
              {form.formState.errors.email && (
                <p className="mt-1 text-xs text-red-600">
                  {form.formState.errors.email.message}
                </p>
              )}
              <p className="mt-1 text-xs text-gray-500">
                El email debe ser único en la organización y será usado para identificar al usuario.
              </p>
            </div>

            {/* Rol - Campo obligatorio */}
            <div>
              <Label htmlFor="role" className="text-xs" required>
                Rol
              </Label>
              <select
                id="role"
                {...form.register('role')}
                className={`w-full py-1.5 px-2.5 text-xs border rounded-md bg-white focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50 ${
                  form.formState.errors.role ? 'border-red-300 bg-red-50' : 'border-gray-200'
                }`}
              >
                <option value="superadmin">Superadmin (Puede hacer todo)</option>
                <option value="admin">Admin (Puede ver todas las cotizaciones y hacer todo, excepto crear/borrar usuarios)</option>
                <option value="member">Member (Solo puede ver/editar/borrar sus propias cotizaciones)</option>
              </select>
              {form.formState.errors.role && (
                <p className="mt-1 text-xs text-red-600">
                  {form.formState.errors.role.message}
                </p>
              )}
              <p className="mt-1 text-xs text-gray-500">
                Selecciona el rol para el nuevo usuario en esta organización.
              </p>
            </div>

            {/* Sección opcional: Vincular Customer/Contact */}
            <div className="border-t border-gray-200 pt-6">
              <button
                type="button"
                onClick={() => {
                  setShowLinkSection(!showLinkSection);
                  if (!showLinkSection && activeOrganizationId) {
                    // Trigger load when opening
                  }
                }}
                className="flex items-center justify-between w-full text-left mb-4"
              >
                <div>
                  <h3 className="text-sm font-medium text-gray-900">Vincular (Opcional)</h3>
                  <p className="text-xs text-gray-500 mt-1">
                    Opcionalmente puedes vincular este usuario a un Customer y/o Contact existente.
                  </p>
                </div>
                <span className="text-xs text-gray-400">
                  {showLinkSection ? 'Ocultar' : 'Mostrar'}
                </span>
              </button>

              {showLinkSection && (
                <div className="space-y-4">
                  {/* Customer - Opcional */}
                  <div>
                    <Label htmlFor="customer_id" className="text-xs">
                      Customer
                    </Label>
                    {loadingCustomers ? (
                      <div className="text-xs text-gray-400 py-2">Cargando customers...</div>
                    ) : (
                      <select
                        id="customer_id"
                        {...form.register('customer_id')}
                        onChange={(e) => {
                          const value = e.target.value || null;
                          form.setValue('customer_id', value);
                          // Si se deselecciona customer, limpiar contact
                          if (!value) {
                            form.setValue('contact_id', null);
                          }
                        }}
                        className="w-full py-1.5 px-2.5 text-xs border border-gray-200 rounded-md bg-white focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50"
                      >
                        <option value="">Ninguno (opcional)</option>
                        {customers.length === 0 ? (
                          <option value="" disabled>No hay customers disponibles</option>
                        ) : (
                          customers.map((customer) => (
                            <option key={customer.id} value={customer.id}>
                              {customer.companyName || customer.customerName || 'N/A'}
                            </option>
                          ))
                        )}
                      </select>
                    )}
                    <p className="mt-1 text-xs text-gray-400">
                      Selecciona un Customer si deseas vincular este usuario a uno existente.
                    </p>
                  </div>

                  {/* Contact - Opcional (filtrado por customer) */}
                  <div>
                    <Label htmlFor="contact_id" className="text-xs">
                      Contact
                    </Label>
                    {loadingContacts ? (
                      <div className="text-xs text-gray-400 py-2">Cargando contactos...</div>
                    ) : (
                      <select
                        id="contact_id"
                        {...form.register('contact_id')}
                        disabled={!selectedCustomerId && filteredContacts.length === 0}
                        className={`w-full py-1.5 px-2.5 text-xs border rounded-md bg-white focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50 ${
                          form.formState.errors.contact_id ? 'border-red-300 bg-red-50' : 'border-gray-200'
                        } ${!selectedCustomerId && filteredContacts.length === 0 ? 'bg-gray-50 cursor-not-allowed' : ''}`}
                      >
                        <option value="">
                          {!selectedCustomerId
                            ? "Selecciona primero un Customer (opcional)"
                            : filteredContacts.length === 0
                              ? "No hay contactos disponibles para este Customer"
                              : "Ninguno (opcional)"}
                        </option>
                        {filteredContacts.map((contact) => (
                          <option key={contact.id} value={contact.id}>
                            {contact.name} ({contact.email})
                          </option>
                        ))}
                      </select>
                    )}
                    {form.formState.errors.contact_id && (
                      <p className="mt-1 text-xs text-red-600">
                        {form.formState.errors.contact_id.message}
                      </p>
                    )}
                    <p className="mt-1 text-xs text-gray-400">
                      Si seleccionas un Contact, debe pertenecer al Customer seleccionado.
                    </p>
                  </div>
                </div>
              )}
            </div>


            {/* Error Message */}
            {saveError && (
              <div className="bg-red-50 border border-red-200 rounded p-3">
                <p className="text-sm text-red-800">{saveError}</p>
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
                Cancelar
              </button>
              <button
                type="submit"
                disabled={isSaving}
                className="px-4 py-2 bg-primary text-white hover:bg-primary/90 transition-colors disabled:opacity-50 disabled:cursor-not-allowed text-sm flex items-center gap-2"
                style={{ backgroundColor: 'var(--primary-brand-hex)' }}
              >
                {isSaving ? (
                  <>
                    <div className="animate-spin rounded-full h-4 w-4 border-2 border-white border-t-transparent"></div>
                    <span>Creando...</span>
                  </>
                ) : (
                  <span>Crear Usuario</span>
                )}
              </button>
            </div>
          </form>
        </div>
      </div>
    </>
  );

  if (embedded) {
    return content;
  }

  return <div className="py-6 px-6">{content}</div>;
}

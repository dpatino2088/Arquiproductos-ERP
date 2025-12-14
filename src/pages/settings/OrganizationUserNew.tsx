import { useState, useEffect } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { router } from '../../lib/router';
import { supabase } from '../../lib/supabase/client';
import { useUIStore } from '../../stores/ui-store';
import { ChevronLeft } from 'lucide-react';
import Input from '../../components/ui/Input';
import Label from '../../components/ui/Label';
import { useCurrentOrgRole } from '../../hooks/useCurrentOrgRole';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useAuthStore } from '../../stores/auth-store';
import { NoOrganizationMessage } from '../../components/NoOrganizationMessage';
import { useContacts, useCustomers } from '../../hooks/useDirectory';

// Schema: Solo 3 roles (superadmin, admin, member)
const organizationUserSchema = z.object({
  contact_id: z.string().uuid('Debes seleccionar un contacto'),
  role: z.enum(['superadmin', 'admin', 'member']),
});

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

  // Cargar contactos y customers
  const { contacts, isLoading: contactsLoading } = useContacts();
  const { customers, isLoading: customersLoading } = useCustomers();

  // Estado para contactos disponibles (solo los que tienen customer_id y email)
  const [availableContacts, setAvailableContacts] = useState<Array<{
    id: string;
    name: string;
    email: string;
    customer_id: string;
    customer_name: string;
  }>>([]);

  // Preparar contactos disponibles cuando se cargan los datos
  useEffect(() => {
    if (contacts.length > 0 && customers.length > 0) {
      // Crear mapa de customers para búsqueda rápida
      const customersMap = new Map(
        customers.map(c => [c.id, c.companyName || 'N/A'])
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
          name: contact.firstName || contact.email || 'Sin nombre', // firstName contiene contact_name
          email: contact.email!.trim().toLowerCase(), // Normalizar email
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
      contact_id: '',
      role: 'member',
    },
  });

  // Obtener el contacto seleccionado para mostrar información
  const selectedContactId = form.watch('contact_id');
  const selectedContact = availableContacts.find(c => c.id === selectedContactId);

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

    const contact = availableContacts.find(c => c.id === data.contact_id);
    if (!contact) {
      setSaveError('El contacto seleccionado no es válido.');
      return;
    }

    // Validar que el contacto tenga customer_id
    if (!contact.customer_id) {
      setSaveError('El contacto seleccionado debe estar relacionado con un Customer.');
      return;
    }

    // Validar que el contacto tenga email
    if (!contact.email || contact.email.trim().length === 0) {
      setSaveError('El contacto seleccionado debe tener un email válido.');
      return;
    }

    setIsSaving(true);
    setSaveError(null);

    try {
      const normalizedEmail = contact.email.trim().toLowerCase();
      const userName = contact.name.trim();

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
            contact_id: contact.id,
            customer_id: contact.customer_id,
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
          contact_id: contact.id,
          customer_id: contact.customer_id,
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

  // Estados de carga
  if (orgLoading || roleLoading || contactsLoading || customersLoading) {
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
                Agrega un nuevo usuario a tu organización (debe ser un Contact relacionado con un Customer)
              </p>
            </div>
          </div>
        </div>
      )}

      {embedded && (
        <div className="mb-6">
          <h2 className="text-xl font-semibold text-gray-900 mb-2">Agregar Usuario</h2>
          <p className="text-sm text-gray-600">
            Agrega un nuevo usuario a tu organización (debe ser un Contact relacionado con un Customer)
          </p>
        </div>
      )}

      {/* Form */}
      <div className="bg-white border border-gray-200 rounded-lg overflow-hidden mb-4">
        <div className="py-6 px-6">
          <form onSubmit={form.handleSubmit(handleSubmit)} className="space-y-6">
            {/* Contacto - Campo principal */}
            <div>
              <Label htmlFor="contact_id" className="text-xs" required>
                Contacto
              </Label>
              <select
                id="contact_id"
                {...form.register('contact_id')}
                className={`w-full py-1.5 px-2.5 text-xs border rounded-md bg-white focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50 ${
                  form.formState.errors.contact_id ? 'border-red-300 bg-red-50' : 'border-gray-200'
                }`}
              >
                <option value="">
                  {contactsLoading || customersLoading 
                    ? "Cargando contactos..." 
                    : availableContacts.length === 0
                      ? "No hay contactos disponibles (deben tener Customer y Email)"
                      : "Selecciona un contacto"}
                </option>
                {availableContacts.map((contact) => (
                  <option key={contact.id} value={contact.id}>
                    {contact.name} ({contact.email}) - {contact.customer_name}
                  </option>
                ))}
              </select>
              {form.formState.errors.contact_id && (
                <p className="mt-1 text-xs text-red-600">
                  {form.formState.errors.contact_id.message}
                </p>
              )}
              <p className="mt-1 text-xs text-gray-500">
                Selecciona un contacto que esté relacionado con un Customer y tenga un email válido.
                El email debe ser único en la organización.
              </p>
              {availableContacts.length === 0 && !contactsLoading && !customersLoading && (
                <div className="mt-2 p-3 bg-yellow-50 border border-yellow-200 rounded">
                  <p className="text-xs text-yellow-800 font-medium">⚠️ No hay contactos disponibles</p>
                  <p className="text-xs text-yellow-700 mt-1">
                    Los contactos deben cumplir:
                  </p>
                  <ul className="text-xs text-yellow-700 mt-1 list-disc list-inside ml-2">
                    <li>Estar relacionados con un Customer</li>
                    <li>Tener un email válido</li>
                    <li>No estar archivados</li>
                  </ul>
                </div>
              )}
            </div>

            {/* Información del contacto seleccionado (solo lectura) */}
            {selectedContact && (
              <>
                <div>
                  <Label className="text-xs">Nombre</Label>
                  <Input
                    type="text"
                    value={selectedContact.name}
                    disabled
                    className="py-1 text-xs bg-gray-50"
                    readOnly
                  />
                  <p className="mt-1 text-xs text-gray-400">Tomado del contacto seleccionado (contact_name)</p>
                </div>

                <div>
                  <Label className="text-xs">Email (Único)</Label>
                  <Input
                    type="email"
                    value={selectedContact.email}
                    disabled
                    className="py-1 text-xs bg-gray-50"
                    readOnly
                  />
                  <p className="mt-1 text-xs text-gray-400">
                    Este email debe ser único en la organización
                  </p>
                </div>

                <div>
                  <Label className="text-xs">Customer</Label>
                  <Input
                    type="text"
                    value={selectedContact.customer_name}
                    disabled
                    className="py-1 text-xs bg-gray-50"
                    readOnly
                  />
                  <p className="mt-1 text-xs text-gray-400">Customer asociado al contacto (customer_name)</p>
                </div>
              </>
            )}

            {/* Rol - Solo 3 opciones */}
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
                disabled={isSaving || !selectedContact}
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

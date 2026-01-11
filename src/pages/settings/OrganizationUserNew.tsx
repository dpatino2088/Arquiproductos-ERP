import { useState, useEffect, useRef } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { router } from '../../lib/router';
import { supabase } from '../../lib/supabase/client';
import { useUIStore } from '../../stores/ui-store';
import { ChevronLeft, X, Shield } from 'lucide-react';
import Input from '../../components/ui/Input';
import Label from '../../components/ui/Label';
import { useCurrentOrgRole } from '../../hooks/useCurrentOrgRole';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useAuthStore } from '../../stores/auth-store';
import { NoOrganizationMessage } from '../../components/NoOrganizationMessage';
import OrganizationUserPermissions from './OrganizationUserPermissions';
import { getRoleLabel, getDefaultPermissionsForRole, type OrgRole, isValidOrgRole, mapLegacyRole } from '../../rbac/rolePresets';
import { useConfirmDialog } from '../../hooks/useConfirmDialog';
import ConfirmDialog from '../../components/ui/ConfirmDialog';
// Schema: Email + Role obligatorios
const organizationUserSchema = z.object({
  email: z.string().email('Debes ingresar un email válido'),
  role: z.enum(['superadmin', 'admin', 'operator', 'procurement', 'finance', 'member']), // Keep 'member' for backward compatibility
  user_name: z.string().optional(),
});

type OrganizationUserFormData = z.infer<typeof organizationUserSchema>;

interface OrganizationUserNewProps {
  embedded?: boolean;
}

export default function OrganizationUserNew({ embedded = false }: OrganizationUserNewProps) {
  const [isSaving, setIsSaving] = useState(false);
  const [isSavingPermissions, setIsSavingPermissions] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState<'details' | 'permissions'>('details');
  const [isDirtyPermissions, setIsDirtyPermissions] = useState(false);
  const [createdUserId, setCreatedUserId] = useState<string | null>(null);
  const { activeOrganizationId, hasOrganizations, loading: orgLoading } = useOrganizationContext();
  const { user } = useAuthStore();
  const { isSuperAdmin, loading: roleLoading } = useCurrentOrgRole();
  const { showConfirm, dialogState, closeDialog, handleConfirm } = useConfirmDialog();
  const previousRoleRef = useRef<string | null>(null);
  const permissionsComponentRef = useRef<{ applyRolePreset: (role: OrgRole, allPermissionCodes?: string[]) => Promise<void> } | null>(null);
  const savePermissionsFnRef = useRef<(() => Promise<void>) | null>(null);


  const form = useForm<OrganizationUserFormData>({
    resolver: zodResolver(organizationUserSchema),
    defaultValues: {
      email: '',
      role: 'operator', // Default to operator instead of member
      user_name: '',
    },
  });

  // Initialize previousRoleRef
  useEffect(() => {
    previousRoleRef.current = form.getValues('role');
  }, []);

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
      const userName: string | null = data.user_name?.trim() || null;

      // Use Edge Function send-invite to create auth user and send invitation email
      const { data: inviteData, error: inviteError } = await supabase.functions.invoke('send-invite', {
        body: {
          kind: 'org',
          organization_id: activeOrganizationId,
          email: normalizedEmail,
          role: data.role,
          name: userName,
          redirect_to: `${window.location.origin}/auth/callback`,
        },
      });

      if (inviteError) {
        throw inviteError;
      }

      if (!inviteData?.ok) {
        throw new Error(inviteData?.error || 'Invite failed');
      }

      if (import.meta.env.DEV) {
        console.log('[OrganizationUserNew] Invite OK:', inviteData);
      }

      // Store the created user ID for permissions tab if available
      const userId = inviteData?.membership_id || inviteData?.invited_user_id || null;
      
      if (userId) {
        setCreatedUserId(userId);
        // Switch to permissions tab automatically after creating user
        setActiveTab('permissions');
      }

      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Usuario Invitado',
        message: 'El correo de invitación ha sido enviado exitosamente.',
      });
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
                Agrega un nuevo usuario interno a tu organización (email + rol obligatorios)
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
              Agrega un nuevo usuario interno a tu organización (email + rol obligatorios)
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

      {/* Tabs - Show always, but Permissions tab is only functional after user is created */}
      <div className="mb-6 border-b border-gray-200">
        <div className="flex gap-4">
          <button
            onClick={() => setActiveTab('details')}
            className={`px-4 py-2 text-sm font-medium border-b-2 transition-colors ${
              activeTab === 'details'
                ? 'border-primary text-primary'
                : 'border-transparent text-gray-500 hover:text-gray-700'
            }`}
          >
            Details
          </button>
          <button
            onClick={() => {
              if (createdUserId) {
                setActiveTab('permissions');
              } else {
                useUIStore.getState().addNotification({
                  type: 'info',
                  title: 'Create User First',
                  message: 'Please create the user first to assign permissions.',
                });
              }
            }}
            disabled={!createdUserId}
            className={`px-4 py-2 text-sm font-medium border-b-2 transition-colors flex items-center gap-2 ${
              activeTab === 'permissions'
                ? 'border-primary text-primary'
                : 'border-transparent text-gray-500 hover:text-gray-700'
            } ${!createdUserId ? 'opacity-50 cursor-not-allowed' : ''}`}
          >
            <Shield className="w-4 h-4" />
            Permissions
          </button>
        </div>
      </div>

      {/* Tab Content */}
      {activeTab === 'details' && (
        <>
          {/* Form */}
          <div className="bg-white border border-gray-200 rounded-lg overflow-hidden mb-4">
        <div className="py-6 px-6">
          <form onSubmit={form.handleSubmit(handleSubmit)} className="space-y-6">
            {/* Name - Campo opcional */}
            <div>
              <Label htmlFor="user_name" className="text-xs">
                Name
              </Label>
              <Input
                id="user_name"
                type="text"
                {...form.register('user_name')}
                className={`w-full py-1.5 px-2.5 text-xs border rounded-md bg-white focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50 ${
                  form.formState.errors.user_name ? 'border-red-300 bg-red-50' : 'border-gray-200'
                }`}
                placeholder="User Name (Optional)"
              />
              {form.formState.errors.user_name && (
                <p className="mt-1 text-xs text-red-600">
                  {form.formState.errors.user_name.message}
                </p>
              )}
              <p className="mt-1 text-xs text-gray-500">
                El nombre del usuario (opcional).
              </p>
            </div>

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
                {...form.register('role', {
                  onChange: async (e) => {
                    const newRole = e.target.value;
                    const oldRole = previousRoleRef.current;
                    
                    // Only handle role preset logic for new roles (not 'member')
                    if (oldRole && oldRole !== newRole && isValidOrgRole(newRole)) {
                      // If permissions are dirty, ask user
                      if (isDirtyPermissions) {
                        const confirmed = await showConfirm({
                          title: 'Apply role defaults?',
                          message: `You have modified permissions. Do you want to apply the default permissions for "${getRoleLabel(newRole)}" or keep your current permissions?`,
                          confirmText: 'Apply defaults',
                          cancelText: 'Keep current',
                          variant: 'info',
                        });
                        
                        if (confirmed && permissionsComponentRef.current) {
                          // Apply role preset
                          await permissionsComponentRef.current.applyRolePreset(newRole);
                        }
                        // If not confirmed, just change the role (permissions stay as-is)
                      } else {
                        // No dirty permissions, apply preset automatically
                        if (permissionsComponentRef.current) {
                          await permissionsComponentRef.current.applyRolePreset(newRole);
                        }
                      }
                    }
                    
                    previousRoleRef.current = newRole;
                  },
                })}
                className={`w-full py-1.5 px-2.5 text-xs border rounded-md bg-white focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/50 ${
                  form.formState.errors.role ? 'border-red-300 bg-red-50' : 'border-gray-200'
                }`}
              >
                <option value="superadmin">{getRoleLabel('superadmin')}</option>
                <option value="admin">{getRoleLabel('admin')}</option>
                <option value="operator">{getRoleLabel('operator')}</option>
                <option value="procurement">{getRoleLabel('procurement')}</option>
                <option value="finance">{getRoleLabel('finance')}</option>
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
      )}

      {/* Permissions Tab Content - Only show if user is created */}
      {activeTab === 'permissions' && createdUserId && (
        <>
          <div className="bg-white border border-gray-200 rounded-lg p-6">
            <OrganizationUserPermissions
              ref={permissionsComponentRef}
              organizationUserId={createdUserId}
              userRole={form.watch('role')}
              onSave={(finish) => {
                setIsSavingPermissions(false);
                if (finish) {
                  router.navigate('/settings/organization-user');
                }
              }}
              onCancel={() => router.navigate('/settings/organization-user')}
              onDirtyChange={setIsDirtyPermissions}
              externalSave={(saveFn) => {
                savePermissionsFnRef.current = saveFn;
              }}
              showActions={true}
            />
          </div>
        </>
      )}

      {activeTab === 'permissions' && !createdUserId && (
        <div className="bg-white border border-gray-200 rounded-lg p-6 text-center">
          <Shield className="w-12 h-12 text-gray-400 mx-auto mb-4" />
          <p className="text-sm text-gray-600 mb-2">Create user first</p>
          <p className="text-xs text-gray-500">
            Please fill in the user details and click "Create User" to assign permissions.
          </p>
        </div>
      )}

      {/* Confirm Dialog */}
      <ConfirmDialog
        isOpen={dialogState.isOpen}
        title={dialogState.title}
        message={dialogState.message}
        confirmText={dialogState.confirmText}
        cancelText={dialogState.cancelText}
        variant={dialogState.variant}
        onConfirm={handleConfirm}
        onClose={closeDialog}
        isLoading={dialogState.isLoading}
      />
    </>
  );

  if (embedded) {
    return content;
  }

  return <div className="py-6 px-6">{content}</div>;
}

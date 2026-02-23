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
  /** Draft permissions while user not created; persisted so first Save writes them to DB */
  const [draftPermissionsFromParent, setDraftPermissionsFromParent] = useState<Set<string> | null>(null);
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
      setSaveError('No organization selected. Please select an organization.');
      return;
    }

    if (!user?.id) {
      setSaveError('You are not authenticated. Please log in again.');
      return;
    }

    // Solo Superadmin puede crear usuarios
    if (!isSuperAdmin) {
      setSaveError('Only Superadmins can create users.');
      return;
    }

    setIsSaving(true);
    setSaveError(null);

    try {
      const normalizedEmail = data.email.trim().toLowerCase();
      const userName: string | null = data.user_name?.trim() || null;

      // ✅ Redirect del correo de invitación: usar URL base configurable en producción para evitar 404
      // (ej. si la app está en app.adaptio.app, define VITE_APP_ORIGIN=https://app.adaptio.app)
      const appOrigin = (import.meta.env.VITE_APP_ORIGIN ?? '').trim() || window.location.origin;
      const redirectTo = `${appOrigin.replace(/\/$/, '')}/auth/callback?next=/set-password`;
      const { data: inviteData, error: inviteError } = await supabase.functions.invoke('send-org-invite', {
        body: {
          organization_id: activeOrganizationId,
          user_email: normalizedEmail,
          user_name: userName,
          role: data.role,
          redirect_to: redirectTo,
        },
      });

      // Edge returns 200 with ok: true even when invite email fails (org record is created)
      const errStr =
        (typeof inviteData?.error === 'string' && inviteData.error) ||
        (typeof (inviteError as any)?.context === 'string' && (inviteError as any).context) ||
        (typeof inviteError?.message === 'string' && inviteError.message) ||
        (inviteData?.ok === false ? 'Edge Function failed' : null);
      const realMessage = typeof errStr === 'string' ? errStr : 'Failed to send invite';
      if (inviteError && !inviteData?.ok) {
        if (import.meta.env.DEV) console.error('[OrganizationUserNew] send-org-invite', { inviteData, inviteError, realMessage });
        throw new Error(realMessage);
      }

      const emailSent = inviteData?.email_sent === true;
      const inviteErr = inviteData?.invite_error;
      const message = emailSent
        ? `Usuario creado correctamente. Se envió invitación por email a ${normalizedEmail}.`
        : `Usuario creado correctamente y añadido a la organización.${inviteErr ? ` No se pudo enviar el correo de invitación (el usuario puede ya estar registrado).` : ' No se pudo enviar el correo de invitación.'}`;

      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Usuario creado',
        message,
      });

      // Redirigir a la lista de usuarios de la organización
      router.navigate('/settings/organization-user');
    } catch (err: any) {
      console.error('Error creating user:', err);
      const errorMessage = err.message || 'Error creating user. Please try again.';
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
          <p className="text-sm text-yellow-800 font-medium">No organization selected</p>
          <p className="text-sm text-yellow-700 mt-1">Please select an organization to continue.</p>
        </div>
      </div>
    );
  }

  // No permissions (only Superadmin can create users)
  if (!isSuperAdmin) {
    return (
      <div className="py-6 px-6">
        <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
          <p className="text-sm text-yellow-800 font-medium">No permissions</p>
          <p className="text-sm text-yellow-700 mt-1">Only Superadmins can create users.</p>
        </div>
      </div>
    );
  }

  const content = (
    <>
      {/* Header with Action Buttons */}
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
              <h1 className="text-xl font-semibold text-foreground">Add User</h1>
              <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
                Add a new internal user to your organization (email + role required)
              </p>
            </div>
          </div>
          
          {/* Action Buttons - Top Right - Dynamic based on active tab */}
          {activeTab === 'details' && (
            <div className="flex items-center gap-3">
              <button
                type="button"
                onClick={() => router.navigate('/settings/organization-user')}
                disabled={isSaving}
                className="px-3 py-1.5 rounded border border-gray-300 bg-white text-gray-700 transition-colors text-sm hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={() => {
                  const submitEvent = new Event('submit', { cancelable: true, bubbles: true });
                  document.querySelector('form')?.dispatchEvent(submitEvent);
                }}
                disabled={isSaving}
                className="px-3 py-1.5 rounded text-white transition-colors text-sm hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed"
                style={{ backgroundColor: 'var(--primary-brand-hex)' }}
              >
                {isSaving ? 'Creating...' : 'Create User'}
              </button>
            </div>
          )}
          
          {/* Permission tab buttons */}
          {activeTab === 'permissions' && createdUserId && (
            <div className="flex items-center gap-3">
              <button
                type="button"
                onClick={() => router.navigate('/settings/organization-user')}
                disabled={isSavingPermissions}
                className="px-3 py-1.5 rounded border border-gray-300 bg-white text-gray-700 transition-colors text-sm hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                Close
              </button>
              <button
                type="button"
                onClick={() => {
                  if (savePermissionsFnRef.current) {
                    savePermissionsFnRef.current();
                  }
                }}
                disabled={isSavingPermissions || !isDirtyPermissions}
                className="btn-save px-3 py-1.5 rounded text-white transition-colors text-sm hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {isSavingPermissions ? 'Saving...' : 'Save'}
              </button>
              <button
                type="button"
                onClick={() => {
                  if (savePermissionsFnRef.current) {
                    savePermissionsFnRef.current().then(() => {
                      router.navigate('/settings/organization-user');
                    });
                  }
                }}
                disabled={isSavingPermissions || !isDirtyPermissions}
                className="btn-save-close px-3 py-1.5 rounded text-white transition-colors text-sm hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {isSavingPermissions ? 'Saving...' : 'Save and Close'}
              </button>
            </div>
          )}
        </div>
      )}

      {embedded && (
        <div className="mb-6 flex items-center justify-between">
          <div>
            <h2 className="text-xl font-semibold text-gray-900 mb-2">Add User</h2>
            <p className="text-sm text-gray-600">
              Add a new internal user to your organization (email + role required)
            </p>
          </div>
          
          {/* Action Buttons - Top Right - Dynamic based on active tab */}
          {activeTab === 'details' && (
            <div className="flex items-center gap-3">
              <button
                type="button"
                onClick={() => router.navigate('/settings/organization-user')}
                disabled={isSaving}
                className="px-3 py-1.5 rounded border border-gray-300 bg-white text-gray-700 transition-colors text-sm hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={() => {
                  const submitEvent = new Event('submit', { cancelable: true, bubbles: true });
                  document.querySelector('form')?.dispatchEvent(submitEvent);
                }}
                disabled={isSaving}
                className="px-3 py-1.5 rounded text-white transition-colors text-sm hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed"
                style={{ backgroundColor: 'var(--primary-brand-hex)' }}
              >
                {isSaving ? 'Creating...' : 'Create User'}
              </button>
            </div>
          )}
          
          {/* Permission tab buttons */}
          {activeTab === 'permissions' && createdUserId && (
            <div className="flex items-center gap-3">
              <button
                type="button"
                onClick={() => router.navigate('/settings/organization-user')}
                disabled={isSavingPermissions}
                className="px-3 py-1.5 rounded border border-gray-300 bg-white text-gray-700 transition-colors text-sm hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                Close
              </button>
              <button
                type="button"
                onClick={() => {
                  if (savePermissionsFnRef.current) {
                    savePermissionsFnRef.current();
                  }
                }}
                disabled={isSavingPermissions || !isDirtyPermissions}
                className="btn-save px-3 py-1.5 rounded text-white transition-colors text-sm hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {isSavingPermissions ? 'Saving...' : 'Save'}
              </button>
              <button
                type="button"
                onClick={() => {
                  if (savePermissionsFnRef.current) {
                    savePermissionsFnRef.current().then(() => {
                      router.navigate('/settings/organization-user');
                    });
                  }
                }}
                disabled={isSavingPermissions || !isDirtyPermissions}
                className="btn-save-close px-3 py-1.5 rounded text-white transition-colors text-sm hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {isSavingPermissions ? 'Saving...' : 'Save and Close'}
              </button>
            </div>
          )}
        </div>
      )}

      {/* Tabs - Permissions always clickable; content shows message or permissions UI */}
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
            onClick={() => setActiveTab('permissions')}
            className={`px-4 py-2 text-sm font-medium border-b-2 transition-colors flex items-center gap-2 ${
              activeTab === 'permissions'
                ? 'border-primary text-primary'
                : 'border-transparent text-gray-500 hover:text-gray-700'
            }`}
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
                The user's name (optional).
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
                The email must be unique in the organization and will be used to identify the user.
              </p>
            </div>

            {/* Role - Required field */}
            <div>
              <Label htmlFor="role" className="text-xs" required>
                Role
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
                <option value="member">Member (Can only view/edit/delete own quotes)</option>
              </select>
              {form.formState.errors.role && (
                <p className="mt-1 text-xs text-red-600">
                  {form.formState.errors.role.message}
                </p>
              )}
              <p className="mt-1 text-xs text-gray-500">
                Select the role for the new user in this organization.
              </p>
            </div>

            {/* Error Message */}
            {saveError && (
              <div className="bg-red-50 border border-red-200 rounded p-3">
                <p className="text-sm text-red-800">{saveError}</p>
              </div>
            )}

            {/* Hidden submit button for form submission */}
            <button type="submit" style={{ display: 'none' }} />
          </form>
        </div>
      </div>
        </>
      )}

      {/* Permissions Tab: same UI with or without user; draft kept in React until Save (after user created) */}
      {activeTab === 'permissions' && (
        <div className="bg-white border border-gray-200 rounded-lg p-6">
          <OrganizationUserPermissions
            ref={permissionsComponentRef}
            organizationUserId={createdUserId}
            userRole={form.watch('role')}
            initialDraftPermissions={draftPermissionsFromParent ?? undefined}
            onDraftChange={setDraftPermissionsFromParent}
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
            showActions={false}
          />
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

import { useState, useEffect, useRef, useCallback } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { router } from '../../lib/router';
import { supabase } from '../../lib/supabase/client';
import { useUIStore } from '../../stores/ui-store';
import { ChevronLeft, Shield, X } from 'lucide-react';
import Input from '../../components/ui/Input';
import Label from '../../components/ui/Label';
import { useCurrentOrgRole } from '../../hooks/useCurrentOrgRole';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useAuthStore } from '../../stores/auth-store';
import { NoOrganizationMessage } from '../../components/NoOrganizationMessage';
import OrganizationUserPermissions from './OrganizationUserPermissions';
import { useConfirmDialog } from '../../hooks/useConfirmDialog';
import ConfirmDialog from '../../components/ui/ConfirmDialog';

// Debug state (temporary)
let debugClickCount = 0;
let debugBanner = '';

const organizationUserEditSchema = z.object({
  email: z.string().email('Debes ingresar un email válido'),
  role: z.enum(['superadmin', 'admin', 'member']),
  customer_id: z.union([z.string().uuid(), z.null(), z.literal('')]).optional(),
  contact_id: z.union([z.string().uuid(), z.null(), z.literal('')]).optional(),
});

type OrganizationUserEditFormData = z.infer<typeof organizationUserEditSchema>;

interface OrganizationUserEditProps {
  userId: string;
  embedded?: boolean;
}

export default function OrganizationUserEdit({ userId, embedded = false }: OrganizationUserEditProps) {
  const [isSaving, setIsSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState<'details' | 'permissions'>('details');
  const [isDirtyPermissions, setIsDirtyPermissions] = useState(false);
  const [debugInfo, setDebugInfo] = useState({ clicks: 0, banner: '', lastAction: '' });
  const { activeOrganizationId, hasOrganizations, loading: orgLoading } = useOrganizationContext();
  const { user } = useAuthStore();
  const { isSuperAdmin, isAdmin, loading: roleLoading } = useCurrentOrgRole();
  const hasLoadedRef = useRef(false);
  const loadingRef = useRef(false);
  const savePermissionsFnRef = useRef<(() => Promise<void>) | null>(null);
  const permissionsSaveRef = useRef<(() => Promise<void>) | null>(null);
  const { showConfirm, dialogState, closeDialog, handleConfirm } = useConfirmDialog();

  const form = useForm<OrganizationUserEditFormData>({
    resolver: zodResolver(organizationUserEditSchema),
    defaultValues: {
      email: '',
      role: 'member',
      customer_id: null,
      contact_id: null,
    },
  });

  // Check if details form is dirty
  const isDirtyDetails = form.formState.isDirty;
  const isDirtyAny = isDirtyDetails || isDirtyPermissions;

  useEffect(() => {
    // Prevent multiple loads and loops
    if (loadingRef.current || hasLoadedRef.current) return;
    if (!activeOrganizationId || !userId) return;

    loadUser();
  }, [userId, activeOrganizationId]);

  const loadUser = async () => {
    if (!activeOrganizationId || !userId) return;
    if (loadingRef.current) return;

    loadingRef.current = true;
    setLoading(true);
    try {
      const { data, error } = await supabase
        .rpc('get_organization_users', {
          p_organization_id: activeOrganizationId
        });

      if (error) throw error;

      const userData = data?.find(u => u.id === userId);
      if (!userData) {
        setSaveError('Usuario no encontrado');
        setLoading(false);
        loadingRef.current = false;
        return;
      }

      form.reset({
        email: userData.email || '',
        role: userData.role as 'superadmin' | 'admin' | 'member',
        customer_id: userData.customer_id || null,
        contact_id: userData.contact_id || null,
      });

      hasLoadedRef.current = true;
    } catch (err: any) {
      if (import.meta.env.DEV) {
        console.error('Error loading user:', err);
      }
      setSaveError('Error al cargar el usuario');
    } finally {
      setLoading(false);
      loadingRef.current = false;
    }
  };

  // Handle close with confirmation if there are changes
  const handleClose = useCallback(async () => {
    console.log('HANDLE CLOSE', { ts: Date.now(), isDirtyAny });
    debugClickCount++;
    setDebugInfo(prev => ({ ...prev, clicks: debugClickCount, lastAction: 'CLOSE', banner: 'Closing...' }));

    // If there are changes, ask for confirmation
    if (isDirtyAny) {
      const confirmed = await showConfirm({
        title: '¿Salir sin guardar?',
        message: 'Tienes cambios sin guardar. ¿Estás seguro de que deseas salir sin guardar?',
        confirmText: 'Salir sin guardar',
        cancelText: 'Cancelar',
        variant: 'warning',
      });

      if (!confirmed) {
        console.log('CLOSE CANCELLED by user');
        setDebugInfo(prev => ({ ...prev, banner: 'Close cancelled' }));
        return;
      }
    }

    // Navigate back
    console.log('CLOSE CONFIRMED - Navigating back');
    setDebugInfo(prev => ({ ...prev, banner: 'Exiting...' }));
    
    try {
      window.history.replaceState({}, '', '/settings/organization-user');
      router.navigate('/settings/organization-user');
    } catch (err) {
      console.error('Router navigate failed, using window.location', err);
      window.location.href = '/settings/organization-user';
    }
    
    // Fallback after timeout
    setTimeout(() => {
      if (window.location.pathname.includes('/edit/')) {
        console.warn('Still in edit page, forcing redirect');
        window.location.href = '/settings/organization-user';
      }
    }, 150);
  }, [isDirtyAny, showConfirm]);

  // Handle cancel (same as close)
  const handleCancel = () => {
    handleClose();
  };

  // ESC key handler
  useEffect(() => {
    const handleEsc = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        e.preventDefault();
        e.stopPropagation();
        handleClose();
      }
    };

    window.addEventListener('keydown', handleEsc);
    return () => window.removeEventListener('keydown', handleEsc);
  }, [handleClose]);

  // Handle permissions save callback
  const handlePermissionsSave = (finish: boolean) => {
    if (finish) {
      router.navigate('/settings/organization-user');
    }
  };

  // Handle dirty state change from permissions
  const handlePermissionsDirtyChange = (isDirty: boolean) => {
    setIsDirtyPermissions(isDirty);
  };

  // Save permissions externally (called from handleSubmit)
  const savePermissions = async () => {
    if (savePermissionsFnRef.current) {
      await savePermissionsFnRef.current();
    }
  };

  // Receive save function from permissions component
  const handleReceiveSaveFn = (saveFn: () => Promise<void>) => {
    savePermissionsFnRef.current = saveFn;
    permissionsSaveRef.current = saveFn;
  };

  // Save permissions directly (without ref)
  const savePermissionsDirect = async () => {
    console.log('SAVE PERMISSIONS DIRECT CALLED', { 
      hasRef: !!permissionsSaveRef.current,
      hasOnRequestSave: !!permissionsSaveRef.current 
    });
    
    if (permissionsSaveRef.current) {
      try {
        await permissionsSaveRef.current();
        console.log('SAVE PERMISSIONS DIRECT - SUCCESS');
      } catch (err) {
        console.error('SAVE PERMISSIONS DIRECT - ERROR', err);
        throw err;
      }
    } else {
      console.error('NO SAVE HANDLER - permissionsSaveRef.current is null');
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: 'Save handler no está listo. Por favor, recarga la página.',
      });
      throw new Error('Save handler not ready');
    }
  };

  // Unified save handler - always enabled, dirty state controls WHAT is saved
  const handleSaveAll = async (finish: boolean = false) => {
    debugClickCount++;
    const action = finish ? 'SAVE_AND_FINISH' : 'SAVE';
    console.log('ACTIONBAR CLICK', { action, ts: Date.now(), isDirtyDetails, isDirtyPermissions, isDirtyAny, isSaving });
    setDebugInfo(prev => ({ ...prev, clicks: debugClickCount, lastAction: action, banner: `Clicked ${action}` }));

    if (!activeOrganizationId || (!isSuperAdmin && !isAdmin)) {
      setSaveError('No tienes permisos para editar usuarios.');
      setDebugInfo(prev => ({ ...prev, banner: 'ERROR: No permissions' }));
      return;
    }

    // If nothing is dirty, just exit (no-op save)
    if (!isDirtyAny) {
      console.log('SAVE SKIP - No changes', { finish });
      setDebugInfo(prev => ({ ...prev, banner: 'No changes to save' }));
      
      // Reset states
      setIsDirtyPermissions(false);
      
      if (finish || !embedded) {
        setTimeout(() => {
          router.navigate('/settings/organization-user');
        }, 100);
      }
      return;
    }

    console.log('SAVE START', { 
      isDirtyDetails, 
      isDirtyPermissions, 
      orgUserId: userId, 
      role: form.watch('role'),
      activeOrganizationId 
    });

    setIsSaving(true);
    setSaveError(null);
    setDebugInfo(prev => ({ ...prev, banner: 'Saving...' }));

    try {
      const formData = form.getValues();
      
      // Save details if dirty
      if (isDirtyDetails) {
        const normalizedEmail = formData.email.trim().toLowerCase();
        const finalCustomerId = (formData.customer_id && formData.customer_id !== '') ? formData.customer_id : null;
        const finalContactId = (formData.contact_id && formData.contact_id !== '') ? formData.contact_id : null;

        const { error } = await supabase
          .from('OrganizationUsers')
          .update({
            email: normalizedEmail,
            role: formData.role,
            customer_id: finalCustomerId,
            contact_id: finalContactId,
            updated_at: new Date().toISOString(),
          })
          .eq('id', userId)
          .eq('organization_id', activeOrganizationId);

        if (error) throw error;

        // Reset form dirty state
        form.reset(formData);
      }

      // Save permissions if dirty and not superadmin
      if (isDirtyPermissions && formData.role !== 'superadmin') {
        await savePermissionsDirect();
      }

      useUIStore.getState().addNotification({
        type: 'success',
        title: 'Usuario Actualizado',
        message: 'El usuario ha sido actualizado exitosamente.',
      });

      // Reset permissions dirty state
      setIsDirtyPermissions(false);
      setDebugInfo(prev => ({ ...prev, banner: 'Saved successfully!' }));

      console.log('SAVE DONE');

      if (finish || !embedded) {
        setTimeout(() => {
          router.navigate('/settings/organization-user');
        }, 500);
      }
    } catch (err: any) {
      if (import.meta.env.DEV) {
        console.error('Error updating user:', err);
      }
      const errorMsg = err.message || 'Error al actualizar el usuario';
      setSaveError(errorMsg);
      setDebugInfo(prev => ({ ...prev, banner: `ERROR: ${errorMsg}` }));
      useUIStore.getState().addNotification({
        type: 'error',
        title: 'Error',
        message: errorMsg,
      });
    } finally {
      setIsSaving(false);
    }
  };

  const handleSubmit = async (data: OrganizationUserEditFormData) => {
    await handleSaveAll(false);
  };

  if (orgLoading || roleLoading || loading) {
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

  if (!orgLoading && !hasOrganizations) {
    return <NoOrganizationMessage />;
  }

  if (!isSuperAdmin && !isAdmin) {
    return (
      <div className="py-6 px-6">
        <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
          <p className="text-sm text-yellow-800 font-medium">Sin permisos</p>
          <p className="text-sm text-yellow-700 mt-1">Solo los administradores pueden editar usuarios.</p>
        </div>
      </div>
    );
  }

  return (
    <div className="py-6">
      {/* Header with Action Buttons - Always visible */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground">Edit User</h1>
          <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
            Edit user information and permissions
          </p>
        </div>
        
        {/* Action Buttons - Top Right */}
        <div className="flex items-center gap-3">
          <button
            type="button"
            onClick={(e) => {
              e.preventDefault();
              e.stopPropagation();
              debugClickCount++;
              setDebugInfo(prev => ({ ...prev, clicks: debugClickCount, lastAction: 'CANCEL', banner: 'Cancel clicked' }));
              console.log('HEADER CLICK', { action: 'cancel', ts: Date.now() });
              handleClose();
            }}
            disabled={isSaving}
            className="px-3 py-1.5 rounded border border-gray-300 bg-white text-gray-700 transition-colors text-sm hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            Cancel
          </button>
          <button
            type="button"
            onClick={(e) => {
              e.preventDefault();
              e.stopPropagation();
              debugClickCount++;
              setDebugInfo(prev => ({ ...prev, clicks: debugClickCount, lastAction: 'SAVE', banner: 'Save clicked' }));
              console.log('HEADER CLICK', { action: 'save', ts: Date.now() });
              handleSaveAll(false);
            }}
            disabled={isSaving}
            className="px-3 py-1.5 rounded text-white transition-colors text-sm hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed"
            style={{ backgroundColor: 'var(--primary-brand-hex)' }}
          >
            {isSaving ? 'Saving...' : 'Save'}
          </button>
          <button
            type="button"
            onClick={(e) => {
              e.preventDefault();
              e.stopPropagation();
              debugClickCount++;
              setDebugInfo(prev => ({ ...prev, clicks: debugClickCount, lastAction: 'SAVE_FINISH', banner: 'Save & Finish clicked' }));
              console.log('HEADER CLICK', { action: 'save_finish', ts: Date.now() });
              handleSaveAll(true);
            }}
            disabled={isSaving}
            className="px-3 py-1.5 rounded text-white transition-colors text-sm hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed"
            style={{ backgroundColor: '#10b981' }}
          >
            {isSaving ? 'Saving...' : 'Save & Finish'}
          </button>
        </div>
      </div>

      {/* Tabs */}
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
        <div className="bg-white border border-gray-200 rounded-lg p-6 mb-4">
          <form onSubmit={form.handleSubmit(handleSubmit)}>
            <div className="grid grid-cols-12 gap-4">
              <div className="col-span-12 md:col-span-6">
                <Label htmlFor="email" required>
                  Email
                </Label>
                <Input
                  id="email"
                  type="email"
                  {...form.register('email')}
                  error={form.formState.errors.email?.message}
                  placeholder="user@example.com"
                />
              </div>

              <div className="col-span-12 md:col-span-6">
                <Label htmlFor="role" required>
                  Role
                </Label>
                <select
                  id="role"
                  {...form.register('role')}
                  className={`w-full px-2.5 py-1.5 text-xs border rounded-md bg-white transition-colors focus:outline-none focus:ring-2 focus:ring-offset-0 ${
                    form.formState.errors.role 
                      ? 'border-red-300 bg-red-50 focus:ring-red-500/20 focus:border-red-500' 
                      : 'border-gray-200 focus:ring-primary/20 focus:border-primary/50'
                  }`}
                >
                  <option value="superadmin">Superadmin (Can do everything)</option>
                  <option value="admin">Admin (Can view all quotes and do everything, except create/delete users)</option>
                  <option value="member">Member (Can only view/edit/delete their own quotes)</option>
                </select>
                {form.formState.errors.role && (
                  <p className="mt-1 text-xs text-red-600">
                    {form.formState.errors.role.message}
                  </p>
                )}
              </div>
            </div>

            {saveError && (
              <div className="mt-4 bg-red-50 border border-red-200 rounded p-3">
                <p className="text-sm text-red-800">{saveError}</p>
              </div>
            )}
          </form>
        </div>
      )}

      {activeTab === 'permissions' && (
        <div className="bg-white border border-gray-200 rounded-lg p-6">
          <OrganizationUserPermissions
            organizationUserId={userId}
            userRole={form.watch('role')}
            onSave={handlePermissionsSave}
            onCancel={handleClose}
            onDirtyChange={handlePermissionsDirtyChange}
            externalSave={handleReceiveSaveFn}
            onRequestSave={savePermissionsDirect}
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
        onCancel={closeDialog}
        isLoading={dialogState.isLoading}
      />
    </div>
  );
}


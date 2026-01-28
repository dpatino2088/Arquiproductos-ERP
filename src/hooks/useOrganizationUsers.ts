import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';

export interface OrganizationUser {
  id: string;
  organization_id: string;
  user_id: string | null;
  user_email: string;
  user_name: string | null;
  role: 'superadmin' | 'admin' | 'operator' | 'procurement' | 'finance' | 'member' | 'owner' | 'viewer'; // Include new roles and legacy roles
  status: 'invited' | 'active' | 'disabled';
  invited_by_user_id: string | null;
  invited_at: string | null;
  accepted_at: string | null;
  deleted: boolean;
  created_at: string;
  updated_at: string | null;
}

export interface InviteOrganizationUserInput {
  user_email: string;
  role: 'owner' | 'admin' | 'member' | 'viewer';
  user_name?: string | null;
  redirect_to?: string;
}

export function useOrganizationUsers(organizationId?: string) {
  const [data, setData] = useState<OrganizationUser[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [isInviting, setIsInviting] = useState(false);
  const [isUpdating, setIsUpdating] = useState<Record<string, boolean>>({});
  
  const { activeOrganizationId } = useOrganizationContext();
  const effectiveOrgId = organizationId || activeOrganizationId;

  // Fetch users usando RPC para evitar recursión en RLS
  const fetchUsers = useCallback(async () => {
    if (!effectiveOrgId) {
      setData([]);
      setIsLoading(false);
      setError(null);
      return;
    }

    setIsLoading(true);
    setError(null);

    try {
      // Usar RPC list_organization_users (SECURITY DEFINER, no recursión)
      const { data: usersData, error: queryError } = await supabase
        .rpc('list_organization_users', { p_organization_id: effectiveOrgId });

      if (queryError) {
        if (import.meta.env.DEV) {
          console.error('[useOrganizationUsers] RPC error:', queryError);
        }
        throw queryError;
      }

      const mappedUsers: OrganizationUser[] = (usersData || []).map((row: any) => ({
        id: row.id,
        organization_id: row.organization_id,
        user_id: row.user_id,
        user_email: (row.user_email ?? '').toString().trim().toLowerCase(),
        user_name: row.user_name || null,
        role: row.role,
        status: row.status || 'invited',
        invited_by_user_id: row.invited_by_user_id || null,
        invited_at: row.invited_at || null,
        accepted_at: row.accepted_at || null,
        deleted: row.deleted || false,
        created_at: row.created_at,
        updated_at: row.updated_at || null,
      }));

      if (import.meta.env.DEV) {
        console.log('[useOrganizationUsers] Fetched users:', {
          count: mappedUsers.length,
          sample: mappedUsers[0] || null,
        });
      }

      setData(mappedUsers);
    } catch (err: any) {
      const errorMessage = err?.message || 'Error loading organization users';
      console.error('[useOrganizationUsers] Error:', errorMessage, err);
      setError(errorMessage);
      setData([]);
    } finally {
      setIsLoading(false);
    }
  }, [effectiveOrgId]);

  // Initial fetch
  useEffect(() => {
    fetchUsers();
  }, [fetchUsers]);

  // Invite organization user (via Edge Function)
  const inviteOrganizationUser = useCallback(async (input: InviteOrganizationUserInput): Promise<void> => {
    if (!effectiveOrgId) {
      throw new Error('Organization ID required');
    }

    if (isInviting) {
      throw new Error('Invite operation already in progress');
    }

    setIsInviting(true);
    try {
      const { data: functionResult, error: functionError } = await supabase.functions.invoke('send-org-invite', {
        body: {
          organization_id: effectiveOrgId,
          user_email: input.user_email.trim().toLowerCase(),
          role: input.role,
          // ✅ NO redirect_to - deja que el Edge Function use APP_ORIGIN
        },
      });

      if (functionError) {
        throw new Error(functionError.message || 'Failed to invoke invite function');
      }

      if (!functionResult?.ok) {
        throw new Error(functionResult?.error || 'Invite function returned error');
      }

      // Refresh list after invite
      await fetchUsers();
    } finally {
      setIsInviting(false);
    }
  }, [effectiveOrgId, isInviting, fetchUsers]);

  // Update organization user status (enable/disable) usando RPC para evitar recursión
  const updateOrganizationUserStatus = useCallback(async (userId: string, status: 'active' | 'disabled'): Promise<void> => {
    if (!effectiveOrgId) {
      throw new Error('Organization ID required');
    }

    if (isUpdating[userId]) {
      throw new Error('Update operation already in progress for this user');
    }

    // Primero obtener el usuario para tener email y role
    const userToUpdate = data.find(u => u.id === userId);
    if (!userToUpdate) {
      throw new Error('User not found');
    }

    setIsUpdating(prev => ({ ...prev, [userId]: true }));
    try {
      // Usar RPC upsert_organization_user para actualizar (evita recursión en RLS)
      const { data: updatedUser, error: rpcError } = await supabase
        .rpc('upsert_organization_user', {
          p_organization_id: effectiveOrgId,
          p_user_email: userToUpdate.user_email,
          p_role: userToUpdate.role as any,
          p_status: status as any,
        });

      if (rpcError) {
        if (import.meta.env.DEV) {
          console.error('[useOrganizationUsers] RPC upsert error:', rpcError);
        }
        throw rpcError;
      }

      if (import.meta.env.DEV) {
        console.log('[useOrganizationUsers] Updated user status:', {
          userId,
          status,
          updatedUser,
        });
      }

      // Refresh list
      await fetchUsers();
    } finally {
      setIsUpdating(prev => {
        const next = { ...prev };
        delete next[userId];
        return next;
      });
    }
  }, [effectiveOrgId, isUpdating, data, fetchUsers]);

  return {
    data,
    isLoading,
    error,
    refresh: fetchUsers,
    inviteOrganizationUser,
    updateOrganizationUserStatus,
    // Action loading states
    isInviting,
    isUpdating,
  };
}

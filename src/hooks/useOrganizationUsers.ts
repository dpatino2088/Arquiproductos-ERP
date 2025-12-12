import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';

export interface OrganizationUser {
  id: string;
  role: 'owner' | 'admin' | 'member' | 'viewer';
  created_at: string;
  user_id: string;
  email?: string;
  invited_by?: string;
}

interface UseOrganizationUsersResult {
  users: OrganizationUser[];
  isLoading: boolean;
  error: string | null;
  refetch: () => Promise<void>;
}

export function useOrganizationUsers(organizationId: string | null): UseOrganizationUsersResult {
  const [users, setUsers] = useState<OrganizationUser[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchUsers = async () => {
    if (!organizationId) {
      setUsers([]);
      setIsLoading(false);
      return;
    }

    setIsLoading(true);
    setError(null);

    try {
      // Note: We need to join with auth.users to get email
      // Since we can't directly query auth.users from the client,
      // we'll use a different approach: fetch OrganizationUsers and then
      // get user emails separately or use a database view/function
      
      const { data, error: fetchError } = await supabase
        .from('OrganizationUsers')
        .select('id, role, created_at, user_id, invited_by')
        .eq('organization_id', organizationId)
        .eq('deleted', false)
        .order('created_at', { ascending: false });

      if (fetchError) {
        throw fetchError;
      }

      // For now, we'll fetch emails separately if needed
      // In production, you might want to create a database view or function
      // that joins OrganizationUsers with a public.users table
      const usersWithEmails = await Promise.all(
        (data || []).map(async (user) => {
          // Try to get email from current user's session or use a server function
          // For now, we'll return the user without email and fetch it separately
          return {
            ...user,
            email: undefined, // Will be populated by server function or view
          } as OrganizationUser;
        })
      );

      setUsers(usersWithEmails);
    } catch (err: any) {
      console.error('Error fetching organization users:', err);
      setError(err.message || 'Failed to fetch organization users');
      setUsers([]);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchUsers();
  }, [organizationId]);

  return {
    users,
    isLoading,
    error,
    refetch: fetchUsers,
  };
}


import { useEffect, useState, useCallback } from 'react';
import { supabase } from '../lib/supabase/client';

export function useCustomerPortalUsers(organizationId?: string) {
  const [users, setUsers] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const fetchUsers = useCallback(async () => {
    if (!organizationId) {
      setUsers([]);
      setLoading(false);
      setError(null);
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const { data, error: queryError } = await supabase
        .from('v_customer_portal_users')
        .select('*')
        .eq('organization_id', organizationId)
        .order('created_at', { ascending: false });

      if (queryError) {
        setError(queryError.message);
        setUsers([]);
      } else {
        setUsers(data ?? []);
      }
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Error loading portal users';
      setError(errorMessage);
      setUsers([]);
    } finally {
      setLoading(false);
    }
  }, [organizationId]);

  useEffect(() => {
    fetchUsers();
  }, [fetchUsers]);

  return {
    users,
    loading,
    error,
    refetch: fetchUsers,
  };
}


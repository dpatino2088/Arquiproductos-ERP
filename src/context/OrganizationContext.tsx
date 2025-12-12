import React, { createContext, useContext, useEffect, useState, ReactNode } from 'react';
import { supabase } from '../lib/supabase';
import type { OrgRole } from '../types/roles';

export type OrganizationSummary = {
  id: string;
  name: string;
  role: OrgRole;
};

type OrganizationContextValue = {
  organizations: OrganizationSummary[];
  activeOrganization: OrganizationSummary | null;
  activeOrganizationId: string | null;
  setActiveOrganizationId: (id: string | null) => void;
  loading: boolean;
  error: string | null;
  refresh: () => Promise<void>;
};

const OrganizationContext = createContext<OrganizationContextValue | undefined>(undefined);

const STORAGE_KEY = 'activeOrganizationId';

export function OrganizationProvider({ children }: { children: ReactNode }) {
  const [organizations, setOrganizations] = useState<OrganizationSummary[]>([]);
  const [activeOrganizationId, setActiveOrganizationIdState] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const setActiveOrganizationId = (id: string | null) => {
    setActiveOrganizationIdState(id);
    if (id) {
      localStorage.setItem(STORAGE_KEY, id);
    } else {
      localStorage.removeItem(STORAGE_KEY);
    }
  };

  const loadOrganizations = async () => {
    try {
      setLoading(true);
      setError(null);

      // 1) Get current user
      const {
        data: { user },
        error: userError,
      } = await supabase.auth.getUser();

      if (userError) throw userError;

      if (!user) {
        setOrganizations([]);
        setActiveOrganizationIdState(null);
        setLoading(false);
        return;
      }

      // 2) Query OrganizationUsers joined with Organizations
      const { data: orgUsers, error: orgError } = await supabase
        .from('OrganizationUsers')
        .select(`
          organization_id,
          role,
          organization_id (
            id,
            organization_name
          )
        `)
        .eq('user_id', user.id)
        .eq('deleted', false);

      if (orgError) {
        // Handle expected errors gracefully
        if (orgError.code === 'PGRST116' || orgError.code === '42P01') {
          // No rows or table doesn't exist
          setOrganizations([]);
          setActiveOrganizationIdState(null);
          setLoading(false);
          return;
        }
        throw orgError;
      }

      // 3) Map result into OrganizationSummary[]
      const orgs: OrganizationSummary[] = (orgUsers || [])
        .filter((ou: any) => ou.organization_id && typeof ou.organization_id === 'object')
        .map((ou: any) => ({
          id: ou.organization_id.id,
          name: ou.organization_id.organization_name || 'Unnamed Organization',
          role: (ou.role as OrgRole) || null,
        }))
        .sort((a, b) => {
          // Sort by role priority, then by name
          const roleOrder: Record<string, number> = {
            owner: 0,
            admin: 1,
            member: 2,
            viewer: 3,
          };
          const aOrder = roleOrder[a.role || ''] ?? 999;
          const bOrder = roleOrder[b.role || ''] ?? 999;
          if (aOrder !== bOrder) return aOrder - bOrder;
          return a.name.localeCompare(b.name);
        });

      setOrganizations(orgs);

      // 4) Determine active organization
      const storedId = localStorage.getItem(STORAGE_KEY);
      let newActiveId: string | null = null;

      if (storedId && orgs.some((org) => org.id === storedId)) {
        // Use stored ID if it still exists
        newActiveId = storedId;
      } else if (orgs.length > 0) {
        // Use first organization
        newActiveId = orgs[0].id;
      }

      setActiveOrganizationIdState(newActiveId);
      if (newActiveId) {
        localStorage.setItem(STORAGE_KEY, newActiveId);
      } else {
        localStorage.removeItem(STORAGE_KEY);
      }

      setLoading(false);
    } catch (err: any) {
      console.error('Error loading organizations:', err);
      setError(err.message || 'Error loading organizations');
      setOrganizations([]);
      setActiveOrganizationIdState(null);
      setLoading(false);
    }
  };

  useEffect(() => {
    loadOrganizations();

    // Listen for auth state changes
    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange(() => {
      loadOrganizations();
    });

    return () => {
      subscription.unsubscribe();
    };
  }, []);

  const activeOrganization =
    organizations.find((org) => org.id === activeOrganizationId) || null;

  const refresh = async () => {
    await loadOrganizations();
  };

  return (
    <OrganizationContext.Provider
      value={{
        organizations,
        activeOrganization,
        activeOrganizationId,
        setActiveOrganizationId,
        loading,
        error,
        refresh,
      }}
    >
      {children}
    </OrganizationContext.Provider>
  );
}

export function useOrganizationContext(): OrganizationContextValue {
  const context = useContext(OrganizationContext);
  if (context === undefined) {
    throw new Error(
      'useOrganizationContext must be used within an OrganizationProvider'
    );
  }
  return context;
}

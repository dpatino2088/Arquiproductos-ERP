import React, { createContext, useContext, useEffect, useState, ReactNode, useRef, useCallback } from 'react';
import { supabase } from '../lib/supabase/client';
import type { OrgRole } from '../types/roles';
import { useAuthSession } from '../hooks/useAuthSession';

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
  hasOrganizations: boolean;
  refresh: () => Promise<void>;
};

const OrganizationContext = createContext<OrganizationContextValue | undefined>(undefined);

const STORAGE_KEY = 'activeOrganizationId';

export function OrganizationProvider({ children }: { children: ReactNode }) {
  const { session, userId, loading: sessionLoading } = useAuthSession();
  const [organizations, setOrganizations] = useState<OrganizationSummary[]>([]);
  const [activeOrganizationId, setActiveOrganizationIdState] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const lastUserIdRef = useRef<string | null>(null);

  const setActiveOrganizationId = (id: string | null) => {
    setActiveOrganizationIdState(id);
    if (id) {
      localStorage.setItem(STORAGE_KEY, id);
    } else {
      localStorage.removeItem(STORAGE_KEY);
    }
  };

  const loadOrganizations = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);

      // ✅ FIX: Usar userId de useAuthSession en lugar de getUser()
      // No llamamos supabase.auth.getUser() aquí
      if (!userId || !session?.user) {
        if (import.meta.env.DEV) {
          console.warn('⚠️ OrganizationContext - No hay usuario autenticado (session)');
        }
        setOrganizations([]);
        setActiveOrganizationIdState(null);
        setLoading(false);
        return;
      }

      const user = session.user;

      // 2) Query OrganizationUsers joined with Organizations
      console.log('🔍 OrganizationContext - Buscando organizaciones para user_id:', user.id);
      
      // Query OrganizationUsers with nested Organizations data
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
        // NOTA: No filtramos por is_system aquí porque el usuario necesita ver su organización
        // El filtro is_system solo se usa para ocultar usuarios en las LISTAS, no para ocultar organizaciones
      
      // Always log this to debug the issue
      console.log('📊 OrganizationContext - Resultado query:', {
        orgUsersCount: orgUsers?.length || 0,
        error: orgError,
        firstOrg: orgUsers?.[0],
        allOrgs: orgUsers,
        rawData: JSON.stringify(orgUsers, null, 2)
      });

      if (orgError) {
        // Log detailed error information
        console.error('❌ OrganizationContext - Error en query:', {
          error: orgError,
          code: orgError.code,
          message: orgError.message,
          details: orgError.details,
          hint: orgError.hint,
          user_id: user.id
        });
        
        // Handle expected errors gracefully
        if (orgError.code === 'PGRST116' || orgError.code === '42P01') {
          // No rows or table doesn't exist - esto es normal si no hay organizaciones
          if (import.meta.env.DEV) {
            console.log('ℹ️ OrganizationContext - No hay organizaciones (esto es normal)');
          }
          setOrganizations([]);
          setActiveOrganizationIdState(null);
          setLoading(false);
          return;
        }
        
        // Handle column does not exist error (42703)
        if (orgError.code === '42703' || orgError.message?.includes('does not exist') || orgError.message?.includes('column')) {
          console.error('❌ OrganizationContext - Error de columna no encontrada:', {
            code: orgError.code,
            message: orgError.message,
            details: orgError.details,
            hint: orgError.hint
          });
          setError(`Database schema error: ${orgError.message}. Please check if migrations were applied correctly.`);
          setOrganizations([]);
          setActiveOrganizationIdState(null);
          setLoading(false);
          return;
        }
        
        // Para errores de RLS o permisos, no mostrar error al usuario
        // Solo loguear en desarrollo
        if (orgError.code === '42501' || orgError.message?.includes('permission') || orgError.message?.includes('policy')) {
          if (import.meta.env.DEV) {
            console.warn('⚠️ OrganizationContext - Error de permisos/RLS:', orgError.message);
          }
          setOrganizations([]);
          setActiveOrganizationIdState(null);
          setLoading(false);
          return;
        }
        
        // Para otros errores, mostrar información detallada
        console.error('❌ OrganizationContext - Error desconocido:', {
          code: orgError.code,
          message: orgError.message,
          details: orgError.details,
          hint: orgError.hint
        });
        setError(orgError.message || 'Error loading organizations');
        setOrganizations([]);
        setActiveOrganizationIdState(null);
        setLoading(false);
        return;
      }

      // 3) Map result into OrganizationSummary[]
      // In Supabase nested select, organization_id becomes an object with the nested data
      const orgs: OrganizationSummary[] = (orgUsers || [])
        .map((ou: any) => {
          // organization_id should be an object with id and organization_name
          const org = ou.organization_id;
          
          if (!org || typeof org !== 'object' || !org.id) {
            if (import.meta.env.DEV) {
              console.warn('⚠️ OrganizationContext - organization_id no es un objeto válido:', {
                raw: ou,
                organization_id: org,
                type: typeof org
              });
            }
            return null;
          }
          
          return {
            id: org.id,
            name: org.organization_name || 'Unnamed Organization',
            role: (ou.role as OrgRole) || null,
          };
        })
        .filter((org): org is OrganizationSummary => org !== null)
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

      console.log('📋 OrganizationContext - Organizaciones mapeadas:', {
        count: orgs.length,
        orgs: orgs,
        rawOrgUsers: orgUsers
      });
      
      setOrganizations(orgs);

      // 4) Determine active organization
      const storedId = localStorage.getItem(STORAGE_KEY);
      let newActiveId: string | null = null;

      if (storedId && orgs.some((org) => org.id === storedId)) {
        // Use stored ID if it still exists
        newActiveId = storedId;
      } else if (orgs.length > 0 && orgs[0]) {
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
        // Enhanced error logging
        const errorDetails = {
          message: err?.message,
          name: err?.name,
          code: err?.code,
          status: err?.status,
          stack: err?.stack,
          cause: err?.cause,
        };
        
        console.error('❌ OrganizationContext - Exception in loadOrganizations:', {
          error: err,
          details: errorDetails,
          timestamp: new Date().toISOString(),
        });
        
        // Check for network/fetch errors
        if (err?.message?.includes('Failed to fetch') || 
            err?.message?.includes('ERR_INTERNET_DISCONNECTED') ||
            err?.name === 'AuthRetryableFetchError' ||
            err?.name === 'TypeError') {
          const networkError = 'Network error: Unable to connect to Supabase. Please check your internet connection and Supabase configuration.';
          console.error('❌ OrganizationContext - Network/Fetch Error in catch:', networkError);
          setError(networkError);
        } else {
          setError(err?.message || 'Error loading organizations');
        }
        
        setOrganizations([]);
        setActiveOrganizationIdState(null);
        setLoading(false);
      }
  }, [session, userId]);

  useEffect(() => {
    // ✅ FIX: Guard para evitar cargar múltiples veces con el mismo userId
    if (sessionLoading) {
      return; // Esperar a que la sesión cargue
    }

    const currentUserId = userId;
    if (lastUserIdRef.current === currentUserId) {
      return; // Ya se cargó para este userId
    }
    lastUserIdRef.current = currentUserId || null;

    // ✅ FIX: Depender SOLO de session?.user?.id (no hacer polling)
    if (session?.user?.id) {
      loadOrganizations();
    } else {
      // No hay sesión, establecer estado vacío sin error
      if (import.meta.env.DEV) {
        console.log('ℹ️ OrganizationContext - No hay sesión, no se cargarán organizaciones');
      }
      setOrganizations([]);
      setActiveOrganizationIdState(null);
      setLoading(false);
    }
  }, [session?.user?.id, sessionLoading, loadOrganizations]);

  const activeOrganization =
    organizations.find((org) => org.id === activeOrganizationId) || null;

  const hasOrganizations = organizations.length > 0;

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
        hasOrganizations,
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

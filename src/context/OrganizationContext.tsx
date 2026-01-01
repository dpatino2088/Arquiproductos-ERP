import React, { createContext, useContext, useEffect, useState, ReactNode } from 'react';
import { supabase } from '../lib/supabase/client';
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
  hasOrganizations: boolean;
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
      let user = null;
      let userError = null;
      
      try {
        const result = await supabase.auth.getUser();
        user = result.data?.user || null;
        userError = result.error;
      } catch (err: any) {
        userError = err;
      }

      // Manejar error de sesión faltante
      if (userError) {
        if (userError.message?.includes('session') || userError.message?.includes('Auth session missing')) {
          if (import.meta.env.DEV) {
            console.warn('⚠️ OrganizationContext - Sesión de autenticación faltante, intentando refrescar...');
          }
          
          // Intentar refrescar la sesión
          const { data: { session }, error: sessionError } = await supabase.auth.getSession();
          
          if (sessionError || !session) {
            if (import.meta.env.DEV) {
              console.warn('⚠️ OrganizationContext - No hay sesión disponible. El usuario necesita hacer login.');
            }
            // No establecer error aquí, simplemente retornar sin organizaciones
            // El usuario verá el mensaje de "No organizations available" que es correcto
            setOrganizations([]);
            setActiveOrganizationIdState(null);
            setLoading(false);
            return; // No establecer error, solo retornar silenciosamente
          }
          
          // Si tenemos sesión, intentar obtener el usuario nuevamente
          const { data: { user: retryUser }, error: retryError } = await supabase.auth.getUser();
          
          if (retryError || !retryUser) {
            if (import.meta.env.DEV) {
              console.error('❌ OrganizationContext - No se pudo obtener usuario después de refrescar sesión:', retryError);
            }
            setOrganizations([]);
            setActiveOrganizationIdState(null);
            setLoading(false);
            setError('Please log in to view organizations');
            return;
          }
          
          // Continuar con el usuario obtenido
          user = retryUser;
        } else {
          // Log detailed error information for debugging
          const errorDetails = {
            message: userError?.message,
            name: userError?.name,
            code: (userError as any)?.code,
            status: (userError as any)?.status,
            stack: userError?.stack,
          };
          
          console.error('❌ OrganizationContext - Error obteniendo usuario:', {
            error: userError,
            details: errorDetails,
            timestamp: new Date().toISOString(),
          });
          
          // Check if it's a network/fetch error
          if (userError?.message?.includes('Failed to fetch') || 
              userError?.message?.includes('ERR_INTERNET_DISCONNECTED') ||
              userError?.name === 'AuthRetryableFetchError') {
            const networkError = 'Network error: Unable to connect to Supabase. Please check your internet connection and Supabase configuration.';
            console.error('❌ OrganizationContext - Network/Fetch Error:', networkError);
            setError(networkError);
          } else {
            setError(userError?.message || 'Error loading organizations');
          }
          
          setOrganizations([]);
          setActiveOrganizationIdState(null);
          setLoading(false);
          return;
        }
      }

      if (!user) {
        if (import.meta.env.DEV) {
          console.warn('⚠️ OrganizationContext - No hay usuario autenticado');
        }
        setOrganizations([]);
        setActiveOrganizationIdState(null);
        setLoading(false);
        return;
      }

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
  };

  useEffect(() => {
    // Verificar primero si hay una sesión antes de cargar organizaciones
    const checkSessionAndLoad = async () => {
      const { data: { session } } = await supabase.auth.getSession();
      
      if (session) {
        // Solo cargar organizaciones si hay una sesión válida
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
    };

    checkSessionAndLoad();

    // Listen for auth state changes - OPTIMIZED: Solo recargar en eventos críticos
    // Esto evita recargas innecesarias en cada TOKEN_REFRESHED
    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((event, session) => {
      // Solo recargar en eventos importantes, no en cada cambio de token
      if (event === 'SIGNED_IN' && session) {
        loadOrganizations();
      } else if (event === 'SIGNED_OUT') {
        // Limpiar organizaciones al cerrar sesión
        setOrganizations([]);
        setActiveOrganizationIdState(null);
        setLoading(false);
      } else if (event === 'USER_UPDATED' && session) {
        loadOrganizations();
      }
      // Ignorar: TOKEN_REFRESHED, PASSWORD_RECOVERY, etc. para reducir peticiones
    });

    return () => {
      subscription.unsubscribe();
    };
  }, []);

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

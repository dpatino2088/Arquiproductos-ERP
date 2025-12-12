import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import { logger } from '../lib/logger';
import { supabase } from '../lib/supabase';

export interface Company {
  id: string;
  name: string;
  country?: string;
  timezone: string;
  address?: string;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface CompanyUser {
  id: string;
  user_id: string;
  company_id: string;
  role: 'super_admin' | 'admin' | 'supervisor' | 'employee';
  is_deleted: boolean;
  created_at: string;
  company?: Company;
}

interface CompanyState {
  // Current company
  currentCompany: Company | null;
  currentCompanyUser: CompanyUser | null;
  
  // Available companies
  availableCompanies: CompanyUser[];
  
  // Loading state
  isLoading: boolean;
  error: string | null;
  
  // Actions
  setCurrentCompany: (company: Company, companyUser: CompanyUser) => void;
  loadUserCompanies: (userId: string) => Promise<void>;
  switchCompany: (companyId: string) => Promise<void>;
  clearCompanies: () => void;
}

export const useCompanyStore = create<CompanyState>()(
  persist(
    (set, get) => ({
      // Initial state
      currentCompany: null,
      currentCompanyUser: null,
      availableCompanies: [],
      isLoading: false,
      error: null,

      // Set current company
      setCurrentCompany: (company: Company, companyUser: CompanyUser) => {
        logger.info('Company switched', { companyId: company.id, companyName: company.name });
        set({
          currentCompany: company,
          currentCompanyUser: companyUser,
        });
      },

      // Load all companies for a user
      loadUserCompanies: async (userId: string) => {
        try {
          set({ isLoading: true, error: null });

          if (import.meta.env.DEV) {
            console.log('🔍 Loading companies for user:', userId);
          }

          const { data, error } = await supabase
            .from('company_users')
            .select(`
              *,
              company:companies(*)
            `)
            .eq('user_id', userId)
            .eq('is_deleted', false)
            .order('created_at', { ascending: true });

          if (error) {
            // Handle case where table doesn't exist or user has no companies
            // Also handle RLS errors (42501) and 404/500 errors gracefully
            const isExpectedError = 
              error.code === 'PGRST116' || // No rows returned
              error.code === '42501' || // Permission denied (RLS)
              error.code === '42P01' || // Relation does not exist
              error.message?.includes('relation') || 
              error.message?.includes('does not exist') ||
              error.message?.includes('permission denied') ||
              error.message?.includes('row-level security');

            if (isExpectedError) {
              // Silently handle expected errors - user may not have companies yet or tables don't exist
              if (import.meta.env.DEV) {
                console.debug('⚠️ Companies query returned expected error (user may not have companies):', error.code);
              }
              // Return empty array instead of throwing
              set({
                availableCompanies: [],
                isLoading: false,
                error: null,
              });
              return;
            }
            
            // Only log unexpected errors
            if (import.meta.env.DEV) {
              console.error('❌ Unexpected error loading companies:', error);
            }
            // Don't throw - just set error state
            set({
              error: error?.message || 'Failed to load companies',
              availableCompanies: [],
              isLoading: false,
            });
            return;
          }

          if (import.meta.env.DEV) {
            console.log('📦 Companies data received:', data);
          }

          const companyUsers = (data || []).map((cu: any) => ({
            id: cu.id,
            user_id: cu.user_id,
            company_id: cu.company_id,
            role: cu.role,
            is_deleted: cu.is_deleted,
            created_at: cu.created_at,
            company: cu.company,
          })) as CompanyUser[];

          if (import.meta.env.DEV) {
            console.log('✅ Processed companies:', companyUsers.length, companyUsers);
          }

          // Set available companies
          set({ availableCompanies: companyUsers });

          // If no current company is set, use the first one
          const firstCompanyUser = companyUsers[0];
          if (!get().currentCompany && firstCompanyUser && firstCompanyUser.company) {
            get().setCurrentCompany(firstCompanyUser.company, firstCompanyUser);
          }

          logger.info('User companies loaded', { count: companyUsers.length });
        } catch (error: any) {
          // Only log unexpected errors
          const isExpectedError = 
            error?.code === 'PGRST116' ||
            error?.code === '42501' ||
            error?.code === '42P01' ||
            error?.message?.includes('relation') ||
            error?.message?.includes('does not exist') ||
            error?.message?.includes('permission denied');

          if (!isExpectedError) {
            logger.error('Error loading user companies', error);
            if (import.meta.env.DEV) {
              console.error('❌ Error in loadUserCompanies:', error);
            }
          }
          
          set({ 
            error: isExpectedError ? null : (error?.message || 'Failed to load companies'),
            availableCompanies: [],
          });
        } finally {
          set({ isLoading: false });
        }
      },

      // Switch to a different company
      switchCompany: async (companyId: string) => {
        const { availableCompanies } = get();
        const companyUser = availableCompanies.find(
          (cu) => cu.company_id === companyId && cu.company
        );

        if (!companyUser || !companyUser.company) {
          logger.warn('Company not found', { companyId });
          set({ error: 'Company not found' });
          return;
        }

        get().setCurrentCompany(companyUser.company, companyUser);
        
        // Reload the page to refresh all data with new company context
        window.location.reload();
      },

      // Clear companies (on logout)
      clearCompanies: () => {
        set({
          currentCompany: null,
          currentCompanyUser: null,
          availableCompanies: [],
          error: null,
        });
      },
    }),
    {
      name: 'company-storage',
      partialize: (state) => ({
        currentCompany: state.currentCompany,
        currentCompanyUser: state.currentCompanyUser,
        // Don't persist availableCompanies to force refresh on load
      }),
    }
  )
);


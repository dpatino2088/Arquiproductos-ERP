import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import { logger } from '../lib/logger';
import { supabase } from '../lib/supabase/client';

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
      // NOTE: This store is for legacy "company" system. The new system uses Organizations.
      // This function will gracefully fail if the tables don't exist (expected in new system).
      loadUserCompanies: async (userId: string) => {
        try {
          set({ isLoading: true, error: null });

          // Check if tables exist by attempting a simple query
          // If tables don't exist, this is expected in the new organization-based system
          const { data, error } = await supabase
            .from('company_users')
            .select(`
              *,
              company:companies(*)
            `)
            .eq('user_id', userId)
            .eq('is_deleted', false)
            .order('created_at', { ascending: true })
            .limit(1); // Limit to 1 to reduce overhead if table doesn't exist

          if (error) {
            // ALL errors are expected if using the new organization system
            // The company_users and companies tables may not exist
            const isExpectedError = 
              error.code === 'PGRST116' || // No rows returned
              error.code === '42501' || // Permission denied (RLS)
              error.code === '42P01' || // Relation does not exist
              error.status === 404 || // Table not found
              error.message?.includes('relation') || 
              error.message?.includes('does not exist') ||
              error.message?.includes('permission denied') ||
              error.message?.includes('row-level security') ||
              error.message?.includes('Could not find a relationship');

            // Silently handle all errors - this is expected when using Organizations instead of Companies
            if (import.meta.env.DEV && !isExpectedError) {
              // Only log truly unexpected errors
              console.debug('⚠️ Companies query error (expected if using Organizations):', error.code, error.message);
            }
            
            // Return empty array - this is normal when using the new organization system
            set({
              availableCompanies: [],
              isLoading: false,
              error: null, // Don't set error state - this is expected
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


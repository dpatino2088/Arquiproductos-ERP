import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { useCompany } from './useCompany';
import { logger } from '../lib/logger';

export interface Branch {
  id: string;
  name: string;
  address: string;
  city: string;
  state: string;
  zipCode: string;
  latitude?: number;
  longitude?: number;
  country?: string;
  // Additional fields from database
  branch_name?: string;
  branch_address?: string;
  timezone?: string;
  radius_meters?: number;
  type?: 'branch' | 'site';
  is_active?: boolean;
}

interface UseBranchesResult {
  branches: Branch[];
  isLoading: boolean;
  error: string | null;
  refetch: () => Promise<void>;
}

export const useBranches = (): UseBranchesResult => {
  const { currentCompany } = useCompany();
  const [branches, setBranches] = useState<Branch[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchBranches = async () => {
    if (!currentCompany?.id) {
      setBranches([]);
      setIsLoading(false);
      return;
    }

    try {
      // Don't set loading to true if we already have data to avoid flickering
      if (branches.length === 0) {
        setIsLoading(true);
      }
      setError(null);

      if (import.meta.env.DEV) {
        console.log('🔍 Fetching branches for company:', currentCompany.id);
      }

      // Fetch branches from Supabase
      const { data, error: fetchError } = await supabase
        .from('branches')
        .select('*')
        .eq('company_id', currentCompany.id)
        .eq('is_deleted', false)
        .eq('archived', false)
        .order('created_at', { ascending: false });

      if (fetchError) {
        // Handle expected errors silently (table doesn't exist, RLS, etc.)
        const isExpectedError = 
          fetchError.code === 'PGRST116' ||
          fetchError.code === '42501' ||
          fetchError.code === '42P01' ||
          fetchError.message?.includes('relation') ||
          fetchError.message?.includes('does not exist') ||
          fetchError.message?.includes('permission denied');

        if (!isExpectedError && import.meta.env.DEV) {
          console.error('❌ Error fetching branches:', fetchError);
        }
        
        if (isExpectedError) {
          // Silently return empty array for expected errors
          setBranches([]);
          setIsLoading(false);
          return;
        }
        
        throw fetchError;
      }

      if (import.meta.env.DEV) {
        console.log('📦 Branches data received:', data?.length || 0, 'branches');
      }

      // Map database branches to UI Branch interface
      const mappedBranches: Branch[] = (data || []).map((branch: any) => {
        // Parse address to extract city, state, zipCode if possible
        // Format: "address, city, state zipCode" or just "address"
        const addressParts = branch.branch_address?.split(',').map((s: string) => s.trim()) || [];
        let city = '';
        let state = '';
        let zipCode = '';

        if (addressParts.length >= 2) {
          city = addressParts[1] || '';
          if (addressParts.length >= 3) {
            const stateZip = addressParts[2]?.split(' ') || [];
            state = stateZip[0] || '';
            zipCode = stateZip.slice(1).join(' ') || '';
          }
        }

        return {
          id: branch.id,
          name: branch.branch_name || 'Unnamed Branch',
          address: branch.branch_address || '',
          city,
          state,
          zipCode,
          latitude: branch.latitude ? Number(branch.latitude) : undefined,
          longitude: branch.longitude ? Number(branch.longitude) : undefined,
          country: branch.country || undefined,
          branch_name: branch.branch_name,
          branch_address: branch.branch_address,
          timezone: branch.timezone,
          radius_meters: branch.radius_meters,
          type: branch.type,
          is_active: branch.is_active,
        };
      });

      setBranches(mappedBranches);
      logger.info('Branches loaded', { count: mappedBranches.length, companyId: currentCompany.id });
    } catch (err: any) {
      // Only log unexpected errors
      const isExpectedError = 
        err?.code === 'PGRST116' ||
        err?.code === '42501' ||
        err?.code === '42P01' ||
        err?.message?.includes('relation') ||
        err?.message?.includes('does not exist') ||
        err?.message?.includes('permission denied');

      if (!isExpectedError) {
        logger.error('Error loading branches', err);
      }
      
      setError(isExpectedError ? null : (err?.message || 'Failed to load branches'));
      setBranches([]);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchBranches();
  }, [currentCompany?.id]);

  return {
    branches,
    isLoading,
    error,
    refetch: fetchBranches,
  };
};


import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { useCompany } from './useCompany';
import { logger } from '../lib/logger';

export interface Employee {
  id: string;
  firstName: string;
  lastName: string;
  email: string;
  jobTitle: string;
  department: string;
  status: 'Active' | 'Suspended' | 'Onboarding' | 'On Leave';
  location: string;
  startDate: string;
  avatar?: string;
  phone?: string;
  // Additional fields from database
  employee_code?: string;
  whatsapp_number?: string;
  current_status?: 'out' | 'in' | 'on_break' | 'on_transfer';
  user_id?: string;
}

interface UseEmployeesResult {
  employees: Employee[];
  isLoading: boolean;
  error: string | null;
  refetch: () => Promise<void>;
}

export const useEmployees = (): UseEmployeesResult => {
  const { currentCompany } = useCompany();
  const [employees, setEmployees] = useState<Employee[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchEmployees = async () => {
    if (!currentCompany?.id) {
      setEmployees([]);
      setIsLoading(false);
      return;
    }

    try {
      // Don't set loading to true if we already have data to avoid flickering
      if (employees.length === 0) {
        setIsLoading(true);
      }
      setError(null);

      if (import.meta.env.DEV) {
        console.log('🔍 Fetching employees for company:', currentCompany.id);
      }

      // Fetch employees from Supabase
      const { data, error: fetchError } = await supabase
        .from('employees')
        .select('*')
        .eq('company_id', currentCompany.id)
        .eq('is_deleted', false)
        .order('created_at', { ascending: false });

      if (fetchError) {
        if (import.meta.env.DEV) {
          console.error('❌ Error fetching employees:', fetchError);
        }
        throw fetchError;
      }

      if (import.meta.env.DEV) {
        console.log('📦 Employees data received:', data?.length || 0, 'employees');
      }

      // Map database employees to UI Employee interface
      const mappedEmployees: Employee[] = (data || []).map((emp: any) => {
        // Map current_status to UI status
        let status: 'Active' | 'Suspended' | 'Onboarding' | 'On Leave' = 'Active';
        if (!emp.is_active) {
          status = 'Suspended';
        } else if (emp.archived) {
          status = 'On Leave';
        }

        // Format start date
        const startDate = emp.created_at 
          ? new Date(emp.created_at).toLocaleDateString('en-US', {
              month: 'numeric',
              day: 'numeric',
              year: 'numeric'
            })
          : '';

        return {
          id: emp.id,
          firstName: emp.first_name || '',
          lastName: emp.last_name || '',
          email: '', // Email would need to come from auth.users via user_id
          jobTitle: emp.position || 'Employee',
          department: '', // Department not in employees table, would need separate table
          status,
          location: '', // Location would come from branches
          startDate,
          phone: emp.whatsapp_number || undefined,
          employee_code: emp.employee_code,
          whatsapp_number: emp.whatsapp_number,
          current_status: emp.current_status,
          user_id: emp.user_id,
        };
      });

      setEmployees(mappedEmployees);
      logger.info('Employees loaded', { count: mappedEmployees.length, companyId: currentCompany.id });
    } catch (err: any) {
      logger.error('Error loading employees', err);
      setError(err?.message || 'Failed to load employees');
      setEmployees([]);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchEmployees();
  }, [currentCompany?.id]);

  return {
    employees,
    isLoading,
    error,
    refetch: fetchEmployees,
  };
};


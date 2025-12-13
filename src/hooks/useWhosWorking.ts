/**
 * useWhosWorking Hook
 * Temporary mock implementation - returns empty data
 * TODO: Implement actual data fetching when backend is ready
 */

export interface WhosWorkingEmployee {
  id: string;
  name: string;
  role: string;
  department: string;
  status: 'present' | 'on-break' | 'on-transfer' | 'on-leave' | 'absent';
  checkIn?: string;
  checkOut?: string;
  location?: string;
  avatar?: string;
}

export function useWhosWorking() {
  // Mock implementation - returns empty array
  // Replace with actual Supabase query when ready
  return {
    employees: [] as WhosWorkingEmployee[],
    isLoading: false,
    error: null,
    refetch: () => Promise.resolve(),
  };
}


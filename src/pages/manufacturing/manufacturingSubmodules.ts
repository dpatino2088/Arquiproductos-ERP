import { useMemo } from 'react';
import { useManufacturingAccess } from '../../hooks/usePermissions';

export type MfgSubmodule = {
  id: string;
  label: string;
  href: string;
  permissionKey?: keyof ReturnType<typeof useManufacturingAccess>;
};

const ALL_MANUFACTURING_SUBMODULES: MfgSubmodule[] = [
  { id: 'manufacturing-orders', label: 'Manufacturing Orders', href: '/manufacturing/manufacturing-orders', permissionKey: 'canViewMOs' },
  { id: 'work-orders', label: 'Work Orders', href: '/manufacturing/work-orders', permissionKey: 'canViewWOs' },
  { id: 'calendar', label: 'Calendar', href: '/manufacturing/calendar', permissionKey: 'canViewCalendar' },
  { id: 'finished-goods', label: 'Finished Goods', href: '/manufacturing/finished-goods', permissionKey: 'canViewWOs' },
  { id: 'cut-optimization', label: 'Cut Optimization', href: '/manufacturing/cut-optimization', permissionKey: 'canViewCutOpt' },
];

/** Static export for backward compatibility — all tabs, unfiltered */
export const MANUFACTURING_SUBMODULES = ALL_MANUFACTURING_SUBMODULES;

/** Hook that returns only the submodule tabs the current user has permission to see */
export function useFilteredMfgSubmodules(): MfgSubmodule[] {
  const access = useManufacturingAccess();
  return useMemo(
    () => ALL_MANUFACTURING_SUBMODULES.filter(s => !s.permissionKey || access[s.permissionKey]),
    [access],
  );
}

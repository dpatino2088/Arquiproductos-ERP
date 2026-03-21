import { useEffect } from 'react';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useFilteredMfgSubmodules } from './manufacturingSubmodules';
import ApprovedBOMList from '../catalog/ApprovedBOMList';

export default function BillOfMaterials() {
  const filteredSubmodules = useFilteredMfgSubmodules();
  const { registerSubmodules, clearSubmoduleNav } = useSubmoduleNav();

  useEffect(() => {
    const currentPath = window.location.pathname;
    if (currentPath.startsWith('/manufacturing')) {
      registerSubmodules('Manufacturing', filteredSubmodules);
    }
    
    return () => {
      const path = window.location.pathname;
      if (!path.startsWith('/manufacturing')) {
        clearSubmoduleNav();
      }
    };
  }, [registerSubmodules, clearSubmoduleNav, filteredSubmodules]);

  return <ApprovedBOMList />;
}

import { useEffect } from 'react';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { MANUFACTURING_SUBMODULES } from './manufacturingSubmodules';
import ApprovedBOMList from '../catalog/ApprovedBOMList';

export default function BillOfMaterials() {
  const { registerSubmodules, clearSubmoduleNav } = useSubmoduleNav();

  useEffect(() => {
    const currentPath = window.location.pathname;
    if (currentPath.startsWith('/manufacturing')) {
      registerSubmodules('Manufacturing', [...MANUFACTURING_SUBMODULES]);
    }
    
    return () => {
      const path = window.location.pathname;
      if (!path.startsWith('/manufacturing')) {
        clearSubmoduleNav();
      }
    };
  }, [registerSubmodules, clearSubmoduleNav]);

  return <ApprovedBOMList />;
}

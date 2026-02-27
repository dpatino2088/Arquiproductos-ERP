import { useEffect, useRef } from 'react';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { Building, Store, Building2, Plus } from 'lucide-react';
import Manufacturers, { type ManufacturersRef } from '../catalog/Manufacturers';

const PARTNERS_SUBMODULES = [
  { id: 'dealers', label: 'Dealers', href: '/partners/dealers', icon: Building },
  { id: 'vendors', label: 'Vendors', href: '/partners/vendors', icon: Store },
  { id: 'manufacturers', label: 'Manufacturers', href: '/partners/manufacturers', icon: Building2 },
];

export default function PartnerManufacturers() {
  const { registerSubmodules } = useSubmoduleNav();
  const manufacturersRef = useRef<ManufacturersRef>(null);

  useEffect(() => {
    registerSubmodules('Partners', PARTNERS_SUBMODULES);
  }, [registerSubmodules]);

  return (
    <div className="py-6">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-foreground mb-1">Manufacturers</h1>
          <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
            Manage your manufacturer partners
          </p>
        </div>
        <button
          onClick={() => manufacturersRef.current?.openNewModal()}
          className="flex items-center gap-2 px-2 py-1 rounded text-white text-sm hover:opacity-90"
          style={{ backgroundColor: 'var(--primary-brand-hex)' }}
        >
          <Plus style={{ width: '14px', height: '14px' }} />
          Add Manufacturer
        </button>
      </div>
      <Manufacturers ref={manufacturersRef} />
    </div>
  );
}

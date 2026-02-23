import { useEffect } from 'react';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { FileText } from 'lucide-react';
import Quotes from './Quotes';
import ProposalsWithDetail from './ProposalsWithDetail';

export type SalesTab = 'quotes' | 'proposals';

type Props = {
  activeTab: SalesTab;
};

/**
 * Sales module wrapper: renders both Quotes and Proposals so tabs never unmount.
 * Same pattern as Directory.tsx — eliminates flash when switching tabs.
 */
export default function SalesDirectory({ activeTab }: Props) {
  const { registerSubmodules } = useSubmoduleNav();

  useEffect(() => {
    registerSubmodules('Sales', [
      { id: 'quotes', label: 'Quotes', href: '/sales/quotes', icon: FileText },
      { id: 'proposals', label: 'Proposals', href: '/sales/proposals', icon: FileText },
    ]);
  }, [registerSubmodules]);

  return (
    <>
      <div style={{ display: activeTab === 'quotes' ? undefined : 'none' }}>
        <Quotes />
      </div>
      <div style={{ display: activeTab === 'proposals' ? undefined : 'none' }}>
        <ProposalsWithDetail />
      </div>
    </>
  );
}

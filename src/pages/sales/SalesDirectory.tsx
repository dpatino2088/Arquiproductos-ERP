import { useEffect } from 'react';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { FileText, ShoppingBag } from 'lucide-react';
import Quotes from './Quotes';
import ProposalsWithDetail from './ProposalsWithDetail';
import SalesOrdersPage from './SalesOrdersPage';

export type SalesTab = 'quotes' | 'proposals' | 'orders';

type Props = {
  activeTab: SalesTab;
};

/** Unified Sales tabs: always [Quotes | Proposals | Orders] on every Sales route */
const SALES_SUBMODULES = [
  { id: 'quotes', label: 'Quotes', href: '/sales/quotes', icon: FileText },
  { id: 'proposals', label: 'Proposals', href: '/sales/proposals', icon: FileText },
  { id: 'orders', label: 'Orders', href: '/sales/orders', icon: ShoppingBag },
];

export default function SalesDirectory({ activeTab }: Props) {
  const { registerSubmodules } = useSubmoduleNav();

  useEffect(() => {
    registerSubmodules('Sales', SALES_SUBMODULES);
  }, [registerSubmodules]);

  if (activeTab === 'orders') {
    return <SalesOrdersPage />;
  }

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

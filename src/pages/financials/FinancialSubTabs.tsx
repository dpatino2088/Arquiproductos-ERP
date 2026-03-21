import { useMemo } from 'react';
import { router } from '../../lib/router';
import { getFinancialGroup, getFinancialSubTabs } from './financialSubmodules';

export default function FinancialSubTabs() {
  const pathname = window.location.pathname;

  const group = useMemo(() => getFinancialGroup(pathname), [pathname]);
  const subTabs = useMemo(() => getFinancialSubTabs(group), [group]);

  const activeTabId = useMemo(() => {
    const match = subTabs.filter(
      t => pathname === t.href || pathname.startsWith(t.href + '/'),
    );
    if (match.length === 0) return subTabs[0]?.id;
    return match.reduce((a, b) => (b.href.length > a.href.length ? b : a)).id;
  }, [pathname, subTabs]);

  return (
    <nav className="flex items-center gap-1 mb-6" role="tablist" aria-label={`${group === 'ar' ? 'Receivable' : 'Payable'} sub-navigation`}>
      {subTabs.map(tab => {
        const isActive = tab.id === activeTabId;
        return (
          <button
            key={tab.id}
            role="tab"
            aria-selected={isActive}
            onClick={() => router.navigate(tab.href)}
            className={`relative px-4 py-2 text-sm rounded-md transition-colors ${
              isActive
                ? 'bg-white text-gray-900 font-medium shadow-sm border border-gray-200'
                : 'text-gray-500 hover:text-gray-700 hover:bg-gray-100'
            }`}
          >
            {tab.label}
          </button>
        );
      })}
    </nav>
  );
}

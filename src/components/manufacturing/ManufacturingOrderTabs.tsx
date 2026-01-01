import { useState } from 'react';
import SummaryTab from './tabs/SummaryTab';
import MaterialsTab from './tabs/MaterialsTab';
import CutListTab from './tabs/CutListTab';
import ProductionStepsTab from './tabs/ProductionStepsTab';
import NotesTab from './tabs/NotesTab';
import DocumentsTab from './tabs/DocumentsTab';
import { useManufacturingOrder } from '../../hooks/useManufacturing';

interface ManufacturingOrderTabsProps {
  moId: string;
}

const TABS = [
  { id: 'summary', label: 'Summary' },
  { id: 'materials', label: 'Materials' },
  { id: 'cut-list', label: 'Cut List' },
  { id: 'production-steps', label: 'Production Steps' },
  { id: 'notes', label: 'Notes' },
  { id: 'documents', label: 'Documents' },
] as const;

export default function ManufacturingOrderTabs({ moId }: ManufacturingOrderTabsProps) {
  const [activeTab, setActiveTab] = useState<string>('summary');
  const { manufacturingOrder } = useManufacturingOrder(moId);

  return (
    <div className="bg-white border border-gray-200 rounded-lg overflow-hidden">
      {/* Tabs Navigation */}
      <div className="border-b border-gray-200">
        <div className="flex overflow-x-auto">
          {TABS.map((tab) => (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className={`px-6 py-3 text-sm font-medium border-b-2 transition-colors whitespace-nowrap ${
                activeTab === tab.id
                  ? 'border-transparent text-gray-600 hover:text-gray-900 hover:border-gray-300'
                  : 'border-transparent text-gray-600 hover:text-gray-900 hover:border-gray-300'
              }`}
              style={
                activeTab === tab.id
                  ? {
                      borderBottomColor: 'var(--primary-brand-hex)',
                      color: 'var(--primary-brand-hex)',
                    }
                  : undefined
              }
            >
              {tab.label}
            </button>
          ))}
        </div>
      </div>

      {/* Tab Content */}
      <div>
        {activeTab === 'summary' && <SummaryTab moId={moId} />}
        {activeTab === 'materials' && (
          <MaterialsTab
            moId={moId}
            saleOrderId={manufacturingOrder?.sale_order_id || null}
            moStatus={manufacturingOrder?.status || 'draft'}
            currency={manufacturingOrder?.SalesOrders?.currency || 'USD'}
          />
        )}
        {activeTab === 'cut-list' && (
          <CutListTab
            moId={moId}
            moStatus={manufacturingOrder?.status || 'draft'}
          />
        )}
        {activeTab === 'production-steps' && <ProductionStepsTab moId={moId} />}
        {activeTab === 'notes' && <NotesTab moId={moId} />}
        {activeTab === 'documents' && <DocumentsTab />}
      </div>
    </div>
  );
}

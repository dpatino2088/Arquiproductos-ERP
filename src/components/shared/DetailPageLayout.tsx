import { ArrowLeft } from 'lucide-react';

export interface DetailTab {
  id: string;
  label: string;
  count?: number;
}

export interface DetailPageLayoutProps {
  title: string;
  subtitle?: string;
  status?: React.ReactNode;
  paymentStatus?: React.ReactNode;
  actions?: React.ReactNode;
  summaryItems?: { label: string; value: React.ReactNode }[];
  tabs: DetailTab[];
  activeTab: string;
  onTabChange: (tabId: string) => void;
  onBack?: () => void;
  children: React.ReactNode;
  contentClassName?: string;
}

export default function DetailPageLayout({
  title,
  subtitle,
  status,
  paymentStatus,
  actions,
  summaryItems,
  tabs,
  activeTab,
  onTabChange,
  onBack,
  children,
  contentClassName,
}: DetailPageLayoutProps) {
  const handleBack = () => {
    if (onBack) onBack();
    else window.history.back();
  };

  return (
    <div className="flex flex-col h-full min-h-0">
      {/* Header */}
      <header className="flex justify-center py-4 shrink-0">
        <div className="flex items-center gap-4 w-full max-w-6xl mx-auto px-4 md:px-6">
          <button
          type="button"
          onClick={handleBack}
          className="p-1 -ml-1 text-gray-600 hover:text-gray-900 hover:bg-gray-100 rounded transition-colors"
          aria-label="Go back"
        >
          <ArrowLeft className="w-5 h-5" />
        </button>
        <div className="flex-1 min-w-0">
          <h1 className="text-xl font-bold text-gray-900 truncate">{title}</h1>
          {subtitle && <p className="text-sm text-gray-500 truncate">{subtitle}</p>}
        </div>
        <div className="flex items-center gap-2 shrink-0">
          {status}
          {paymentStatus}
          {actions}
        </div>
        </div>
      </header>

      {/* Summary bar — mismo ancho máximo que el contenido para alinear QT..Total con el form */}
      {summaryItems && summaryItems.length > 0 && (
        <div className="py-3 bg-gray-50 border-b border-gray-200 shrink-0">
          <div className="w-full max-w-6xl mx-auto px-4 md:px-6">
            <div className="flex flex-wrap gap-x-6 gap-y-1">
              {summaryItems.map(({ label, value }) => (
                <div key={label} className="flex items-center gap-2 text-sm">
                  <span className="text-gray-500">{label}:</span>
                  <span className="font-medium text-gray-900">{value}</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* Tabs — idéntico a StatusTabs (Standard View A); detalle en Standard View B */}
      <div className="shrink-0 w-full max-w-6xl mx-auto px-4 md:px-6">
        <div className="overflow-x-auto border border-gray-200 rounded-lg mb-4 bg-white">
          <nav className="flex min-w-0" role="tablist">
            {tabs.map((tab) => {
              const isActive = tab.id === activeTab;
              return (
                <button
                  key={tab.id}
                  type="button"
                  role="tab"
                  aria-selected={isActive}
                  onClick={() => onTabChange(tab.id)}
                  className={`flex shrink-0 items-center gap-1.5 px-4 transition-colors whitespace-nowrap border-r ${
                    isActive ? 'bg-white font-semibold' : 'font-normal hover:bg-white/50'
                  }`}
                  style={{
                    fontSize: '12px',
                    padding: '0 16px',
                    height: '40px',
                    color: '#1c1f26',
                    borderColor: 'var(--gray-250)',
                    borderBottom: isActive ? '2px solid var(--sidebar-base)' : '2px solid var(--gray-250)',
                  }}
                >
                  <span>{tab.label}</span>
                  {tab.count != null && <span className="text-gray-500 font-normal">({tab.count})</span>}
                </button>
              );
            })}
          </nav>
        </div>
      </div>

      {/* Content — mismo ancho que tabs; min-w-0 evita que el form desborde */}
      <div className={`flex-1 min-w-0 overflow-auto ${contentClassName ?? 'py-6'}`}>
        <div className="w-full max-w-6xl mx-auto px-4 md:px-6 min-w-0 overflow-x-auto">{children}</div>
      </div>
    </div>
  );
}

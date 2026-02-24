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
}: DetailPageLayoutProps) {
  const handleBack = () => {
    if (onBack) onBack();
    else window.history.back();
  };

  return (
    <div className="flex flex-col h-full min-h-0">
      {/* Header */}
      <header className="flex items-center gap-4 py-4 px-6 border-b border-gray-200 shrink-0">
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
      </header>

      {/* Summary bar */}
      {summaryItems && summaryItems.length > 0 && (
        <div className="px-6 py-3 bg-gray-50 border-b border-gray-200 shrink-0">
          <div className="flex flex-wrap gap-x-6 gap-y-1">
            {summaryItems.map(({ label, value }) => (
              <div key={label} className="flex items-center gap-2 text-sm">
                <span className="text-gray-500">{label}:</span>
                <span className="font-medium text-gray-900">{value}</span>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Tabs — design system: Detail Page Tabs — px-4 py-2.5, text 12px, color #1c1f26 */}
      <div className="border-b border-gray-200 shrink-0 bg-gray-100" style={{ borderColor: 'var(--gray-250)' }}>
        <nav className="flex gap-1 px-6" role="tablist">
          {tabs.map((tab) => {
            const isActive = tab.id === activeTab;
            return (
              <button
                key={tab.id}
                type="button"
                role="tab"
                aria-selected={isActive}
                onClick={() => onTabChange(tab.id)}
                className={`px-4 py-2.5 text-xs font-medium border-b-2 transition-colors -mb-px ${
                  isActive
                    ? 'bg-white font-semibold border-[var(--sidebar-base)]'
                    : 'border-transparent text-gray-500 hover:bg-white/50 hover:text-gray-700'
                }`}
                style={{ color: isActive ? '#1c1f26' : undefined }}
                >
                  {tab.label}
                </button>
            );
          })}
        </nav>
      </div>

      {/* Content — padding reducido para simular hoja de carta */}
      <div className="flex-1 overflow-auto py-6 px-4 md:px-6">{children}</div>
    </div>
  );
}

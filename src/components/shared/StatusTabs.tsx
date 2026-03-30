export interface StatusTab {
  label: string;
  value: string;
  count: number;
}

export interface StatusTabsProps {
  tabs: StatusTab[];
  activeTab: string;
  onChange: (value: string) => void;
}

export default function StatusTabs({ tabs, activeTab, onChange }: StatusTabsProps) {
  return (
    <div className="overflow-x-auto border border-gray-200 rounded-t-lg mb-4 bg-white">
      <nav className="flex min-w-0" role="tablist">
        {tabs.map((tab) => {
          const isActive = tab.value === activeTab;
          return (
            <button
              key={tab.value}
              type="button"
              role="tab"
              aria-selected={isActive}
              onClick={() => onChange(tab.value)}
              className={`flex shrink-0 items-center gap-1.5 px-4 transition-colors whitespace-nowrap border-r ${
                isActive ? 'bg-white font-semibold' : 'font-normal hover:bg-white/50'
              }`}
              style={{
                fontSize: '12px',
                padding: '0 16px',
                height: '40px',
                color: '#1c1f26',
                borderColor: 'var(--gray-250)',
                borderRightWidth: '1px',
                borderRightStyle: 'solid',
                boxShadow: isActive ? 'inset 0 -2px 0 var(--sidebar-base)' : 'none',
              }}
            >
              <span>{tab.label}</span>
              {tab.count > 0 && (
                <span className="text-[11px] tabular-nums" style={{ color: isActive ? 'var(--sidebar-base)' : 'var(--gray-400)' }}>
                  {tab.count}
                </span>
              )}
            </button>
          );
        })}
      </nav>
      <div className="h-px w-full bg-gray-200" />
    </div>
  );
}

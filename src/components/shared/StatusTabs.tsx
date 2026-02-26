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
    <div className="overflow-x-auto border border-gray-200 rounded-lg mb-4 bg-white">
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
                borderBottom: isActive ? '2px solid var(--sidebar-base)' : '2px solid transparent',
              }}
            >
              <span>{tab.label}</span>
            </button>
          );
        })}
      </nav>
    </div>
  );
}

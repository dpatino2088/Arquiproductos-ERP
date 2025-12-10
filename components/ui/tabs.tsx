import { cn } from './cn';

interface TabsProps {
  tabs: { id: string; label: string }[];
  activeId: string;
  onChange?: (id: string) => void;
}

export function Tabs({ tabs, activeId, onChange }: TabsProps) {
  return (
    <div className="flex gap-2 rounded-lg bg-muted p-1 text-sm font-medium">
      {tabs.map((tab) => (
        <button
          key={tab.id}
          onClick={() => onChange?.(tab.id)}
          className={cn(
            'px-3 py-2 rounded-md transition-colors',
            activeId === tab.id ? 'bg-card shadow-sm text-foreground' : 'text-muted-foreground'
          )}
        >
          {tab.label}
        </button>
      ))}
    </div>
  );
}


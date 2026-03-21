import { Package, Wrench, Zap, Scissors as ScissorsIcon, Box, Settings2, CheckCircle2, Clock } from 'lucide-react';

export interface PickListItem {
  id: string;
  sku: string | null;
  item_name: string | null;
  component_role: string | null;
  qty: number;
  uom: string;
  cut_length_mm: number | null;
  cut_width_mm: number | null;
  completed: boolean;
}

export type ReadinessStatus = 'ready' | 'pending' | 'unknown';

interface AssemblyPickListProps {
  lines: PickListItem[];
  onToggle: (lineId: string, completed: boolean) => void;
  mode?: 'checklist' | 'readiness';
  readinessMap?: Record<string, ReadinessStatus>;
}

const ROLE_CATEGORIES: Record<string, { label: string; icon: typeof Package; color: string; roles: string[] }> = {
  structure: {
    label: 'Structure',
    icon: Box,
    color: 'text-blue-600 bg-blue-50',
    roles: ['tube', 'headbox', 'top_rail', 'track'],
  },
  hardware: {
    label: 'Hardware & Brackets',
    icon: Wrench,
    color: 'text-gray-700 bg-gray-100',
    roles: ['bracket', 'idler', 'end_cap', 'adapter', 'filler', 'mounting_clip', 'end_plug', 'connector', 'guide', 'rail_connector', 'spring', 'stopper', 'bearing'],
  },
  operating: {
    label: 'Operating System',
    icon: Zap,
    color: 'text-amber-600 bg-amber-50',
    roles: ['drive', 'motor', 'chain', 'chain_stop', 'chain_tensioner', 'wand', 'belt', 'belt_connector'],
  },
  fabric: {
    label: 'Fabric & Tape',
    icon: ScissorsIcon,
    color: 'text-purple-600 bg-purple-50',
    roles: ['fabric', 'tape'],
  },
  finish: {
    label: 'Bottom & Side Rails',
    icon: Settings2,
    color: 'text-teal-600 bg-teal-50',
    roles: ['bottom_bar', 'bottom_channel', 'side_channel', 'hem_weight'],
  },
  accessories: {
    label: 'Accessories & Consumables',
    icon: Package,
    color: 'text-orange-600 bg-orange-50',
    roles: ['accessory', 'consumable', 'fastener', 'carrier', 'hook', 'brush'],
  },
};

function categorize(role: string | null): string {
  if (!role) return 'accessories';
  for (const [catKey, cat] of Object.entries(ROLE_CATEGORIES)) {
    if (cat.roles.includes(role)) return catKey;
  }
  return 'accessories';
}

function ReadinessIndicator({ status }: { status: ReadinessStatus }) {
  if (status === 'ready') {
    return <CheckCircle2 className="w-3.5 h-3.5 text-green-500" />;
  }
  return <Clock className="w-3.5 h-3.5 text-amber-400" />;
}

export default function AssemblyPickList({ lines, onToggle, mode = 'checklist', readinessMap }: AssemblyPickListProps) {
  const grouped = new Map<string, PickListItem[]>();
  const catOrder = Object.keys(ROLE_CATEGORIES);

  for (const line of lines) {
    const cat = categorize(line.component_role);
    if (!grouped.has(cat)) grouped.set(cat, []);
    grouped.get(cat)!.push(line);
  }

  const isReadiness = mode === 'readiness';
  const readyCount = isReadiness && readinessMap
    ? lines.filter(l => (readinessMap[l.component_role ?? ''] ?? 'ready') === 'ready').length
    : lines.filter(l => l.completed).length;
  const pct = lines.length > 0 ? Math.round((readyCount / lines.length) * 100) : 0;

  return (
    <div className="space-y-3">
      <div className="flex items-center justify-between">
        <h4 className="text-xs font-semibold text-gray-700 uppercase tracking-wider">
          {isReadiness ? 'Materials' : 'Pick List'}
        </h4>
        <div className="flex items-center gap-2">
          <div className="w-24 h-1.5 bg-gray-200 rounded-full overflow-hidden">
            <div
              className={`h-full rounded-full transition-all ${pct === 100 ? 'bg-green-500' : 'bg-blue-500'}`}
              style={{ width: `${pct}%` }}
            />
          </div>
          <span className="text-[10px] text-gray-500">{readyCount}/{lines.length}</span>
        </div>
      </div>

      {catOrder.map(catKey => {
        const catLines = grouped.get(catKey);
        if (!catLines || catLines.length === 0) return null;
        const cat = ROLE_CATEGORIES[catKey];
        const Icon = cat.icon;
        const catReady = isReadiness && readinessMap
          ? catLines.filter(l => (readinessMap[l.component_role ?? ''] ?? 'ready') === 'ready').length
          : catLines.filter(l => l.completed).length;

        return (
          <div key={catKey} className="border border-gray-200 rounded-lg overflow-hidden">
            <div className="flex items-center gap-2 px-3 py-2 bg-gray-50 border-b border-gray-100">
              <span className={`p-1 rounded ${cat.color}`}>
                <Icon className="w-3 h-3" />
              </span>
              <span className="text-xs font-semibold text-gray-700">{cat.label}</span>
              <span className="text-[10px] text-gray-400 ml-auto">{catReady}/{catLines.length}</span>
            </div>
            <div className="divide-y divide-gray-50">
              {catLines.map(line => {
                const status: ReadinessStatus = readinessMap?.[line.component_role ?? ''] ?? 'ready';
                const isReady = isReadiness ? status === 'ready' : line.completed;

                return (
                  <div
                    key={line.id}
                    className={`flex items-center gap-3 px-3 py-2 ${isReady ? 'bg-green-50/30' : ''}`}
                  >
                    {isReadiness ? (
                      <ReadinessIndicator status={status} />
                    ) : (
                      <input
                        type="checkbox"
                        checked={line.completed}
                        onChange={e => onToggle(line.id, e.target.checked)}
                        className="rounded border-gray-300 text-green-600 w-3.5 h-3.5"
                      />
                    )}
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2">
                        <span className="text-xs font-mono text-gray-800">
                          {line.sku ?? '—'}
                        </span>
                        {line.component_role && (
                          <span className="text-[9px] px-1 py-0.5 rounded bg-gray-100 text-gray-500">
                            {line.component_role.replace(/_/g, ' ')}
                          </span>
                        )}
                      </div>
                      <p className="text-[11px] truncate text-gray-600">
                        {line.item_name ?? '—'}
                      </p>
                    </div>
                    <div className="text-right shrink-0">
                      <span className="text-xs font-medium text-gray-800">
                        {Number(line.qty).toFixed(line.uom === 'ea' ? 0 : 2)}
                      </span>
                      <span className="text-[10px] text-gray-400 ml-1">{line.uom}</span>
                    </div>
                    {(line.cut_length_mm != null || line.cut_width_mm != null) && (
                      <div className="text-[10px] text-blue-500 shrink-0">
                        {line.cut_length_mm != null ? `${Math.round(line.cut_length_mm)}` : ''}
                        {line.cut_length_mm != null && line.cut_width_mm != null ? '×' : ''}
                        {line.cut_width_mm != null ? `${Math.round(line.cut_width_mm)}` : ''}mm
                      </div>
                    )}
                    {isReadiness && (
                      isReady
                        ? <span className="text-[9px] px-1.5 py-0.5 rounded bg-green-50 text-green-600 shrink-0 font-medium">Ready</span>
                        : <span className="text-[9px] px-1.5 py-0.5 rounded bg-amber-50 text-amber-600 shrink-0">Pending</span>
                    )}
                  </div>
                );
              })}
            </div>
          </div>
        );
      })}
    </div>
  );
}

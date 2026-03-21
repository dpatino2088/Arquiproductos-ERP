import { useMemo, useState } from 'react';
import { ChevronLeft, ChevronRight } from 'lucide-react';
import type { WorkCenter, WorkloadMap } from '../../hooks/useWorkCenterWorkload';
import { toDateKey } from '../../hooks/useWorkCenterWorkload';

interface WorkloadHeatmapProps {
  workCenters: WorkCenter[];
  workload: WorkloadMap;
  startDate: Date;
  days: number;
  compact?: boolean;
  simulatedLoad?: Map<string, Map<string, number>>;
  selectedTaskWorkCenterId?: string | null;
  onCellClick?: (dateKey: string, date: Date) => void;
}

const COL_W = 56;
const LABEL_W = 200;
const DAYS_PER_VIEW = 12;

const LEVEL_STYLES = {
  ok: 'bg-emerald-100 text-emerald-800 border-emerald-200',
  warning: 'bg-amber-100 text-amber-800 border-amber-200',
  overload: 'bg-red-100 text-red-800 border-red-200',
} as const;

const LEVEL_DOT = {
  ok: 'bg-emerald-500',
  warning: 'bg-amber-500',
  overload: 'bg-red-500',
} as const;

function computeLevel(total: number): 'ok' | 'warning' | 'overload' {
  if (total <= 8) return 'ok';
  if (total <= 12) return 'warning';
  return 'overload';
}

function formatHours(h: number): string {
  if (h === 0) return '—';
  return h % 1 === 0 ? `${h}h` : `${h.toFixed(1)}h`;
}

function formatMonthRange(dates: { date: Date }[]): string {
  if (dates.length === 0) return '';
  const first = dates[0].date;
  const last = dates[dates.length - 1].date;
  const fMonth = first.toLocaleDateString(undefined, { month: 'short' });
  const lMonth = last.toLocaleDateString(undefined, { month: 'short' });
  const year = first.getFullYear();
  if (fMonth === lMonth) return `${fMonth} ${year}`;
  return `${fMonth} – ${lMonth} ${year}`;
}

export default function WorkloadHeatmap({
  workCenters,
  workload,
  startDate,
  days,
  compact = false,
  simulatedLoad,
  selectedTaskWorkCenterId,
  onCellClick,
}: WorkloadHeatmapProps) {
  const [hoveredCell, setHoveredCell] = useState<{ wcId: string; dateKey: string; rect: DOMRect } | null>(null);
  const [viewOffset, setViewOffset] = useState(0);

  const allWorkingDays = useMemo(() => {
    const result: { key: string; date: Date; isSaturday: boolean; label: string; dayNum: number }[] = [];
    const cursor = new Date(startDate);
    cursor.setHours(0, 0, 0, 0);
    for (let i = 0; i < Math.max(days, 60); i++) {
      const dow = cursor.getDay();
      if (dow !== 0) {
        result.push({
          key: toDateKey(cursor),
          date: new Date(cursor),
          isSaturday: dow === 6,
          label: cursor.toLocaleDateString(undefined, { weekday: 'short' }),
          dayNum: cursor.getDate(),
        });
      }
      cursor.setDate(cursor.getDate() + 1);
    }
    return result;
  }, [startDate, days]);

  const visibleDays = useMemo(() => {
    const start = viewOffset * DAYS_PER_VIEW;
    return allWorkingDays.slice(start, start + DAYS_PER_VIEW);
  }, [allWorkingDays, viewOffset]);

  const maxPages = Math.max(1, Math.ceil(allWorkingDays.length / DAYS_PER_VIEW));

  const relevantWCs = useMemo(() => {
    return workCenters.filter((wc) => {
      const wcData = workload.get(wc.id);
      const simData = simulatedLoad?.get(wc.id);
      if (wcData && wcData.size > 0) return true;
      if (simData && simData.size > 0) return true;
      return false;
    });
  }, [workCenters, workload, simulatedLoad]);

  if (relevantWCs.length === 0 && !simulatedLoad) {
    return null;
  }

  const displayWCs = relevantWCs.length > 0 ? relevantWCs : workCenters;
  const isInteractive = !!onCellClick && !!selectedTaskWorkCenterId;

  return (
    <div className="rounded-lg border border-gray-200 bg-white p-4">
      <div className="flex items-center justify-between mb-3">
        <h3 className="text-sm font-semibold text-gray-900 flex items-center gap-2">
          <svg className="w-4 h-4 text-gray-500" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" d="M3.75 3v11.25A2.25 2.25 0 006 16.5h2.25M3.75 3h-1.5m1.5 0h16.5m0 0h1.5m-1.5 0v11.25A2.25 2.25 0 0118 16.5h-2.25m-7.5 0h7.5m-7.5 0l-1 3m8.5-3l1 3m0 0l.5 1.5m-.5-1.5h-9.5m0 0l-.5 1.5M9 11.25v1.5M12 9v3.75m3-6v6" />
          </svg>
          Workload Overview
          {isInteractive && (
            <span className="text-[10px] font-normal text-primary ml-1">
              — click a cell to move selected task
            </span>
          )}
        </h3>

        <div className="flex items-center gap-3">
          {/* Navigation */}
          <div className="flex items-center gap-1">
            <button
              type="button"
              onClick={() => setViewOffset((v) => Math.max(0, v - 1))}
              disabled={viewOffset === 0}
              className="p-1 rounded hover:bg-gray-100 disabled:opacity-30 disabled:cursor-not-allowed transition-colors"
              title="Previous 2 weeks"
            >
              <ChevronLeft className="w-4 h-4 text-gray-600" />
            </button>
            <span className="text-xs font-medium text-gray-600 min-w-[100px] text-center">
              {formatMonthRange(visibleDays)}
            </span>
            <button
              type="button"
              onClick={() => setViewOffset((v) => Math.min(maxPages - 1, v + 1))}
              disabled={viewOffset >= maxPages - 1}
              className="p-1 rounded hover:bg-gray-100 disabled:opacity-30 disabled:cursor-not-allowed transition-colors"
              title="Next 2 weeks"
            >
              <ChevronRight className="w-4 h-4 text-gray-600" />
            </button>
          </div>

          {/* Legend */}
          <div className="flex items-center gap-3 text-[10px] text-gray-500">
            <div className="flex items-center gap-1"><div className={`w-2.5 h-2.5 rounded-sm ${LEVEL_STYLES.ok.split(' ')[0]}`} /> ≤ 8h</div>
            <div className="flex items-center gap-1"><div className={`w-2.5 h-2.5 rounded-sm ${LEVEL_STYLES.warning.split(' ')[0]}`} /> 8–12h</div>
            <div className="flex items-center gap-1"><div className={`w-2.5 h-2.5 rounded-sm ${LEVEL_STYLES.overload.split(' ')[0]}`} /> &gt; 12h</div>
          </div>
        </div>
      </div>

      <table
        className="border-collapse text-xs w-full"
        style={{ tableLayout: 'fixed' }}
      >
        <thead>
          <tr>
            <th
              className="text-left px-2 py-1 text-[10px] font-medium text-gray-500 uppercase tracking-wider bg-white"
              style={{ width: LABEL_W }}
            >
              Station
            </th>
            {visibleDays.map(({ key, label, dayNum, isSaturday }) => (
              <th
                key={key}
                className={`text-center px-0.5 py-1 text-[10px] font-medium ${
                  isSaturday ? 'text-amber-500' : 'text-gray-500'
                }`}
              >
                <div>{label}</div>
                <div className={isSaturday ? 'text-amber-400' : 'text-gray-400'}>{dayNum}</div>
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {displayWCs.map((wc) => {
            const isTargetRow = isInteractive && wc.id === selectedTaskWorkCenterId;
            return (
              <tr key={wc.id} className={`border-t border-gray-100 ${isTargetRow ? 'bg-primary/5' : ''}`}>
                <td className={`px-2 py-1.5 text-xs font-medium text-gray-700 ${isTargetRow ? 'bg-blue-50' : 'bg-white'}`} style={{ width: LABEL_W }} title={wc.name}>
                  {wc.name}
                  <span className="text-[10px] text-gray-400 ml-1">({wc.capacity_hours_per_day}h)</span>
                </td>
                {visibleDays.map(({ key, date }) => {
                  const existing = workload.get(wc.id)?.get(key);
                  const simHours = simulatedLoad?.get(wc.id)?.get(key) ?? 0;
                  const baseHours = existing?.totalHours ?? 0;
                  const totalHours = baseHours + simHours;
                  const capacity = wc.capacity_hours_per_day;
                  const level = totalHours > 0 ? computeLevel(totalHours) : null;
                  const isHovered = hoveredCell?.wcId === wc.id && hoveredCell?.dateKey === key;
                  const clickable = isTargetRow;
                  const hasRoom = totalHours < capacity * 1.5;

                  return (
                    <td
                      key={key}
                      className={`px-0.5 py-1 text-center relative ${
                        clickable ? (hasRoom ? 'cursor-pointer' : 'cursor-not-allowed') : ''
                      }`}
                      onMouseEnter={(e) => setHoveredCell({ wcId: wc.id, dateKey: key, rect: e.currentTarget.getBoundingClientRect() })}
                      onMouseLeave={() => setHoveredCell(null)}
                      onClick={() => {
                        if (clickable && hasRoom) {
                          onCellClick?.(key, date);
                        }
                      }}
                    >
                      {totalHours > 0 ? (
                        <div
                          className={`rounded px-1 py-0.5 border text-[11px] font-semibold tabular-nums ${level ? LEVEL_STYLES[level] : ''} ${
                            clickable && hasRoom ? 'ring-1 ring-primary/30 hover:ring-2 hover:ring-primary transition-all' : ''
                          }`}
                        >
                          {formatHours(totalHours)}
                        </div>
                      ) : (
                        <div
                          className={`text-[10px] rounded px-1 py-0.5 ${
                            clickable
                              ? 'text-primary/50 border border-dashed border-primary/30 hover:border-primary hover:bg-primary/5 transition-all cursor-pointer'
                              : 'text-gray-300'
                          }`}
                        >
                          {clickable ? '+' : '—'}
                        </div>
                      )}

                      {isHovered && totalHours > 0 && hoveredCell && (
                        <div
                          className="fixed z-[9999] w-44 bg-gray-900 text-white rounded-lg shadow-lg p-2 text-left pointer-events-none"
                          style={{
                            left: hoveredCell.rect.left + hoveredCell.rect.width / 2 - 88,
                            top: hoveredCell.rect.top - 4,
                            transform: 'translateY(-100%)',
                          }}
                        >
                          <div className="text-[10px] font-semibold mb-1 flex items-center justify-between">
                            <span>{wc.name}</span>
                            <span className={`w-2 h-2 rounded-full ${level ? LEVEL_DOT[level] : ''}`} />
                          </div>
                          <div className="text-[10px] text-gray-300 mb-1">
                            {formatHours(totalHours)} / {formatHours(capacity)} capacity
                          </div>
                          {existing && existing.tasks.length > 0 && (
                            <div className="space-y-0.5 border-t border-gray-700 pt-1 mt-1">
                              {existing.tasks.map((t) => (
                                <div key={t.id} className="flex items-center justify-between text-[9px]">
                                  <span className="text-gray-300 truncate mr-1">{t.moNo ?? '—'}</span>
                                  <span className="text-gray-400 shrink-0">{formatHours(t.hours)}</span>
                                </div>
                              ))}
                            </div>
                          )}
                          {simHours > 0 && (
                            <div className="flex items-center justify-between text-[9px] border-t border-gray-700 pt-1 mt-1">
                              <span className="text-blue-300 italic">This MO</span>
                              <span className="text-blue-300">{formatHours(simHours)}</span>
                            </div>
                          )}
                        </div>
                      )}
                    </td>
                  );
                })}
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}

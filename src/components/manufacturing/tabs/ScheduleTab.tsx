import { useEffect, useMemo, useState } from 'react';
import { ChevronLeft, ChevronRight, CalendarDays } from 'lucide-react';
import { useManufacturingOrder, useUpdateManufacturingOrder } from '../../../hooks/useManufacturing';
import { useUIStore } from '../../../stores/ui-store';

interface ScheduleTabProps {
  moId: string;
  canEdit: boolean;
}

function toInputDate(value?: string | null): string {
  if (!value) {
    return '';
  }
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) {
    return '';
  }
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function toStartIso(dateValue: string): string | null {
  if (!dateValue) {
    return null;
  }
  return new Date(`${dateValue}T00:00:00`).toISOString();
}

function toEndIso(dateValue: string): string | null {
  if (!dateValue) {
    return null;
  }
  return new Date(`${dateValue}T23:59:59`).toISOString();
}

function toMonthStart(d: Date): Date {
  return new Date(d.getFullYear(), d.getMonth(), 1);
}

function isSameDay(a: Date, b: Date): boolean {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}

export default function ScheduleTab({ moId, canEdit }: ScheduleTabProps) {
  const { manufacturingOrder: mo, loading, refetch } = useManufacturingOrder(moId);
  const { updateManufacturingOrder, isUpdating } = useUpdateManufacturingOrder();
  const addNotification = useUIStore((s) => s.addNotification);
  const [monthCursor, setMonthCursor] = useState(() => toMonthStart(new Date()));
  const [plannedStartDate, setPlannedStartDate] = useState('');
  const [plannedEndDate, setPlannedEndDate] = useState('');

  const startDate = useMemo(() => (plannedStartDate ? new Date(`${plannedStartDate}T00:00:00`) : null), [plannedStartDate]);
  const endDate = useMemo(() => (plannedEndDate ? new Date(`${plannedEndDate}T23:59:59`) : null), [plannedEndDate]);

  const calendarDays = useMemo(() => {
    const start = toMonthStart(monthCursor);
    const firstWeekday = (start.getDay() + 6) % 7;
    const gridStart = new Date(start);
    gridStart.setDate(start.getDate() - firstWeekday);
    return Array.from({ length: 42 }, (_, idx) => {
      const d = new Date(gridStart);
      d.setDate(gridStart.getDate() + idx);
      return d;
    });
  }, [monthCursor]);

  useEffect(() => {
    if (!mo) {
      return;
    }
    setPlannedStartDate(toInputDate(mo.planned_start_at ?? mo.scheduled_start_date ?? null));
    setPlannedEndDate(toInputDate(mo.planned_end_at ?? mo.scheduled_end_date ?? null));
  }, [mo]);

  const handleSave = async () => {
    if (!mo) {
      return;
    }
    if (plannedStartDate && plannedEndDate && plannedEndDate < plannedStartDate) {
      addNotification({
        type: 'error',
        title: 'Validation',
        message: 'End date cannot be earlier than start date.',
      });
      return;
    }
    try {
      await updateManufacturingOrder(mo.id, {
        planned_start_at: toStartIso(plannedStartDate),
        planned_end_at: toEndIso(plannedEndDate),
      });
      addNotification({ type: 'success', title: 'Schedule Saved', message: 'Manufacturing schedule was updated.' });
      refetch();
    } catch (err) {
      const message =
        typeof err === 'object' && err !== null && 'message' in err
          ? String((err as { message?: unknown }).message ?? 'Failed to save schedule.')
          : 'Failed to save schedule.';
      addNotification({
        type: 'error',
        title: 'Error',
        message,
      });
    }
  };

  if (loading) {
    return (
      <div className="p-6">
        <div className="animate-pulse space-y-4">
          <div className="h-10 bg-gray-200 rounded" />
          <div className="h-64 bg-gray-200 rounded" />
        </div>
      </div>
    );
  }

  if (!mo) {
    return <div className="p-6 text-center text-gray-500">Manufacturing order not found</div>;
  }

  const monthLabel = monthCursor.toLocaleDateString(undefined, { month: 'long', year: 'numeric' });

  return (
    <div className="p-6 space-y-4">
      <div className="rounded-lg border border-gray-200 bg-white p-4">
        <div className="flex items-center justify-between gap-3 mb-3">
          <h3 className="text-sm font-semibold text-gray-900 flex items-center gap-2">
            <CalendarDays className="w-4 h-4 text-gray-500" />
            Schedule
          </h3>
          {canEdit && (
            <button
              type="button"
              onClick={handleSave}
              disabled={isUpdating}
              className="px-3 py-1.5 text-sm font-medium text-white bg-primary rounded-lg hover:bg-primary/90 disabled:opacity-50"
            >
              {isUpdating ? 'Saving...' : 'Save Schedule'}
            </button>
          )}
        </div>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
          <label className="block">
            <span className="block text-xs font-medium text-gray-500 mb-1">Start</span>
            <input
              type="date"
              value={plannedStartDate}
              onChange={(e) => setPlannedStartDate(e.target.value)}
              disabled={!canEdit}
              className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 disabled:bg-gray-50"
            />
          </label>
          <label className="block">
            <span className="block text-xs font-medium text-gray-500 mb-1">End</span>
            <input
              type="date"
              value={plannedEndDate}
              onChange={(e) => setPlannedEndDate(e.target.value)}
              disabled={!canEdit}
              className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 disabled:bg-gray-50"
            />
          </label>
        </div>
      </div>

      <div className="rounded-lg border border-gray-200 bg-white p-4">
        <div className="flex items-center justify-between mb-3">
          <button
            type="button"
            onClick={() => setMonthCursor(new Date(monthCursor.getFullYear(), monthCursor.getMonth() - 1, 1))}
            className="p-1.5 rounded border border-gray-200 text-gray-600 hover:bg-gray-50"
          >
            <ChevronLeft className="w-4 h-4" />
          </button>
          <h4 className="text-sm font-semibold text-gray-900">{monthLabel}</h4>
          <button
            type="button"
            onClick={() => setMonthCursor(new Date(monthCursor.getFullYear(), monthCursor.getMonth() + 1, 1))}
            className="p-1.5 rounded border border-gray-200 text-gray-600 hover:bg-gray-50"
          >
            <ChevronRight className="w-4 h-4" />
          </button>
        </div>

        <div className="grid grid-cols-7 text-xs text-gray-500 mb-2">
          {['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((d) => (
            <div key={d} className="px-2 py-1 text-center">{d}</div>
          ))}
        </div>

        <div className="grid grid-cols-7 gap-1">
          {calendarDays.map((d) => {
            const inCurrentMonth = d.getMonth() === monthCursor.getMonth();
            const inRange =
              startDate &&
              endDate &&
              d >= new Date(startDate.getFullYear(), startDate.getMonth(), startDate.getDate()) &&
              d <= new Date(endDate.getFullYear(), endDate.getMonth(), endDate.getDate());
            const isStart = startDate ? isSameDay(d, startDate) : false;
            const isEnd = endDate ? isSameDay(d, endDate) : false;
            return (
              <div
                key={d.toISOString()}
                className={[
                  'h-10 rounded text-xs flex items-center justify-center border',
                  inCurrentMonth ? 'text-gray-900 border-gray-100' : 'text-gray-300 border-gray-100',
                  inRange ? 'bg-blue-50 border-blue-200' : 'bg-white',
                  (isStart || isEnd) ? 'font-semibold bg-blue-100 border-blue-300 text-blue-800' : '',
                ].join(' ')}
              >
                {d.getDate()}
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}

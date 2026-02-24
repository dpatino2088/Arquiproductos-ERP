import { cn } from '../../lib/utils';

export interface TimelineEvent {
  id: string;
  action: string;
  description: string;
  user_name?: string | null;
  created_at: string;
  metadata?: Record<string, unknown> | null;
}

function sortByNewestFirst(events: TimelineEvent[]): TimelineEvent[] {
  return [...events].sort(
    (a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime()
  );
}

export interface TimelineViewProps {
  events: TimelineEvent[];
  loading?: boolean;
  emptyMessage?: string;
}

const ACTION_DOT_COLORS: Record<string, string> = {
  created: 'bg-green-500',
  status_changed: 'bg-blue-500',
  payment_recorded: 'bg-emerald-500',
  converted: 'bg-purple-500',
};

function formatRelativeTime(createdAt: string): string {
  const date = new Date(createdAt);
  const now = new Date();
  const diffMs = now.getTime() - date.getTime();
  const diffSec = Math.floor(diffMs / 1000);
  const diffMin = Math.floor(diffSec / 60);
  const diffHours = Math.floor(diffMin / 60);
  const diffDays = Math.floor(diffHours / 24);

  if (diffSec < 60) return 'just now';
  if (diffMin < 60) return `${diffMin} min ago`;
  if (diffHours < 24) return `${diffHours} hours ago`;
  if (diffDays < 7) return `${diffDays} days ago`;
  return date.toLocaleDateString();
}

function getDotColor(action: string): string {
  return ACTION_DOT_COLORS[action] ?? 'bg-gray-500';
}

function toActionLabel(action: string): string {
  return action
    .split('_')
    .map((w) => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase())
    .join(' ');
}

export default function TimelineView({
  events,
  loading = false,
  emptyMessage = 'No activity yet',
}: TimelineViewProps) {
  if (loading) {
    return (
      <div className="relative pl-6 border-l-2 border-gray-200">
        {[1, 2, 3].map((i) => (
          <div key={i} className="relative pb-6 last:pb-0">
            <div className="absolute -left-[25px] size-3 rounded-full bg-gray-200 animate-pulse" />
            <div className="space-y-2">
              <div className="h-4 w-24 bg-gray-200 rounded animate-pulse" />
              <div className="h-4 w-full max-w-xs bg-gray-100 rounded animate-pulse" />
              <div className="h-3 w-20 bg-gray-100 rounded animate-pulse" />
            </div>
          </div>
        ))}
      </div>
    );
  }

  if (events.length === 0) {
    return (
      <div className="max-w-xl mx-auto py-12 px-6 text-center">
        <div className="rounded-lg border border-gray-200 bg-gray-50 p-6">
          <p className="text-sm text-gray-600 mb-3">{emptyMessage}</p>
          <p className="text-xs text-gray-500">
            El timeline muestra la actividad automática del documento: creación, cambios de estado, envío, aceptación, etc. Los eventos aparecen cuando creas, editas o envías el documento.
          </p>
        </div>
      </div>
    );
  }

  const sortedEvents = sortByNewestFirst(events);

  return (
    <div className="relative pl-6 border-l-2 border-gray-200">
      {sortedEvents.map((event) => (
        <div key={event.id} className="relative pb-6 last:pb-0">
          <div
            className={cn(
              'absolute -left-[25px] size-3 shrink-0 rounded-full ring-2 ring-white',
              getDotColor(event.action)
            )}
          />
          <div className="rounded-lg border border-gray-100 bg-white p-3 shadow-sm">
            <div className="flex items-start justify-between gap-2">
              <div className="min-w-0 flex-1">
                <p className="font-semibold text-gray-900">{event.description}</p>
                {event.user_name && (
                  <p className="mt-0.5 text-sm text-gray-500">{event.user_name}</p>
                )}
              </div>
              <span
                className="shrink-0 text-xs text-gray-500"
                title={new Date(event.created_at).toLocaleDateString()}
              >
                {formatRelativeTime(event.created_at)}
              </span>
            </div>
            <span className="mt-2 inline-block rounded px-1.5 py-0.5 text-[10px] font-medium uppercase tracking-wide text-gray-500 bg-gray-100">
              {toActionLabel(event.action)}
            </span>
          </div>
        </div>
      ))}
    </div>
  );
}

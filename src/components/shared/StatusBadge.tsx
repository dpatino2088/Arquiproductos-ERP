import { cn } from '../../lib/utils';

export interface StatusBadgeProps {
  status: string;
  type: 'quote' | 'proposal' | 'salesOrder' | 'payment' | 'invoice' | 'manufacturing' | 'moType' | 'moLineStatus' | 'priority';
  size?: 'sm' | 'md';
}

const COLOR_CLASSES: Record<string, string> = {
  gray: 'bg-gray-100 text-gray-700',
  blue: 'bg-blue-100 text-blue-700',
  amber: 'bg-amber-100 text-amber-700',
  green: 'bg-green-100 text-green-700',
  red: 'bg-red-100 text-red-700',
  orange: 'bg-orange-100 text-orange-700',
  purple: 'bg-purple-100 text-purple-700',
  indigo: 'bg-indigo-100 text-indigo-700',
  slate: 'bg-slate-100 text-slate-700',
  emerald: 'bg-emerald-100 text-emerald-700',
};

const DOT_CLASSES: Record<string, string> = {
  gray: 'bg-gray-500',
  blue: 'bg-blue-500',
  amber: 'bg-amber-500',
  green: 'bg-green-500',
  red: 'bg-red-500',
  orange: 'bg-orange-500',
  purple: 'bg-purple-500',
  indigo: 'bg-indigo-500',
  slate: 'bg-slate-500',
  emerald: 'bg-emerald-500',
};

const STATUS_MAPS: Record<StatusBadgeProps['type'], Record<string, string>> = {
  quote: {
    draft: 'gray',
    sent: 'blue',
    approved: 'amber',
    converted: 'green',
    cancelled: 'red',
    canceled: 'red',
    expired: 'orange',
  },
  proposal: {
    draft: 'gray',
    sent: 'blue',
    accepted: 'green',
    rejected: 'red',
    cancelled: 'red',
    expired: 'orange',
  },
  salesOrder: {
    draft: 'gray',
    confirmed: 'blue',
    on_hold: 'amber',
    delivered: 'green',
    closed: 'slate',
    cancelled: 'red',
    in_production: 'indigo',
    ready_for_delivery: 'emerald',
  },
  payment: {
    pending: 'gray',
    partial: 'amber',
    paid: 'green',
    refunded: 'purple',
    overdue: 'red',
    unassigned: 'orange',
    unapplied: 'blue',
    applied: 'green',
  },
  invoice: {
    draft: 'gray',
    issued: 'blue',
    partial: 'amber',
    paid: 'green',
    void: 'red',
    overdue: 'orange',
  },
  manufacturing: {
    draft: 'gray',
    'pending review': 'gray',
    pending_review: 'gray',
    planned: 'blue',
    'in production': 'indigo',
    in_production: 'indigo',
    'quality check': 'amber',
    quality_check: 'amber',
    completed: 'green',
    'ready for pickup': 'emerald',
    ready_for_pickup: 'emerald',
    delivered: 'slate',
    cancelled: 'red',
  },
  moLineStatus: {
    planned: 'gray',
    in_production: 'indigo',
    completed: 'green',
    cancelled: 'red',
  },
  moType: {
    primary: 'blue',
    split: 'purple',
    backorder: 'orange',
    rework: 'orange',
  },
  priority: {
    low: 'gray',
    normal: 'blue',
    high: 'amber',
    urgent: 'red',
    rush: 'red',
  },
};

function toTitleCase(value: string): string {
  return value
    .split('_')
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
    .join(' ');
}

export default function StatusBadge({ status, type, size = 'sm' }: StatusBadgeProps) {
  const normalized = status?.toLowerCase().trim() ?? '';
  const colorKey = STATUS_MAPS[type]?.[normalized] ?? 'gray';
  const colorClasses = COLOR_CLASSES[colorKey] ?? COLOR_CLASSES.gray;
  const dotClasses = DOT_CLASSES[colorKey] ?? DOT_CLASSES.gray;
  const label = toTitleCase(normalized);

  return (
    <span
      className={cn(
        'inline-flex items-center gap-1.5 rounded-full font-medium',
        size === 'sm' && 'px-2 py-0.5 text-xs',
        size === 'md' && 'px-2.5 py-1 text-sm',
        colorClasses
      )}
    >
      <span className={cn('size-1.5 shrink-0 rounded-full', dotClasses)} aria-hidden />
      {label}
    </span>
  );
}

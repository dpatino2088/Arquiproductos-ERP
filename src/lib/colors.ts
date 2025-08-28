export const STATUS = {
  success: 'bg-status-green-10 text-status-green',
  info: 'bg-status-blue-10 text-status-blue',
  warning: 'bg-status-amber-10 text-status-amber',
  error: 'bg-status-red-10 text-status-red',
  neutral: 'bg-neutral-gray-10 text-neutral-gray',
} as const;

export function getStatusClasses(status?: string) {
  if (!status) return STATUS.neutral;
  switch ((status || '').toLowerCase()) {
    case 'completed':
    case 'success':
    case 'active':
    case 'done':
      return STATUS.success;
    case 'in progress':
    case 'processing':
    case 'working':
    case 'info':
      return STATUS.info;
    case 'pending':
    case 'waiting':
    case 'warning':
      return STATUS.warning;
    case 'error':
    case 'failed':
    case 'critical':
    case 'urgent':
      return STATUS.error;
    default:
      return STATUS.neutral;
  }
}

export function getWidgetIconColors(type: 'total' | 'active' | 'pending' | 'urgent') {
  switch (type) {
    case 'total':
      return 'bg-status-blue-10 text-status-blue';
    case 'active':
      return 'bg-status-green-10 text-status-green';
    case 'pending':
      return 'bg-status-amber-10 text-status-amber';
    case 'urgent':
      return 'bg-status-red-10 text-status-red';
    default:
      return 'bg-neutral-gray-10 text-neutral-gray';
  }
}

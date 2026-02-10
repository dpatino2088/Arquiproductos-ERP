import type { AvailabilityType } from '../../hooks/useInventoryAvailability';

interface AvailabilityBadgeProps {
  type: AvailabilityType;
  /** Risk modifier: show "· Risk" next to principal state (e.g. In transit · Risk). */
  isRisk?: boolean;
  className?: string;
  /** Optional: show short label (default true) */
  showLabel?: boolean;
}

const LABELS: Record<AvailabilityType, string> = {
  IN_STOCK: 'In stock',
  IN_TRANSIT: 'In transit',
  IMPORT: 'Import',
  UNKNOWN: '—',
};

const STYLES: Record<AvailabilityType, string> = {
  IN_STOCK: 'bg-green-50 text-green-700 border-green-200',
  IN_TRANSIT: 'bg-blue-50 text-blue-700 border-blue-200',
  IMPORT: 'bg-amber-50 text-amber-700 border-amber-200',
  UNKNOWN: 'bg-gray-50 text-gray-500 border-gray-200',
};

/**
 * Informative availability badge. Principal state + optional Risk modifier.
 * Do NOT persist in QuoteLine. Use only for critical materials (fabrics, rolls, special items).
 */
export function AvailabilityBadge({
  type,
  isRisk = false,
  className = '',
  showLabel = true,
}: AvailabilityBadgeProps) {
  const style = STYLES[type] ?? STYLES.UNKNOWN;
  const label = LABELS[type] ?? type;
  if (type === 'UNKNOWN' && !showLabel && !isRisk) return null;
  const principal = showLabel ? label : type;
  return (
    <span
      className={`inline-flex items-center gap-1 rounded border px-1.5 py-0.5 text-xs font-medium ${style} ${className}`}
      title="Availability is informational only; lead time comes from Manufacturing"
    >
      {principal && <span>{principal}</span>}
      {isRisk && <span className="opacity-90">· Risk</span>}
    </span>
  );
}

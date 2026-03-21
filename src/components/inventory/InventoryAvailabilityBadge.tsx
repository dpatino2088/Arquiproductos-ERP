import type { InventoryAvailabilityRow, InventoryAvailabilityStatus } from '../../types/inventory';
import { Tooltip } from '../ui/Tooltip';

function formatDate(isoOrDate: string | null): string {
  if (!isoOrDate) return '';
  try {
    const d = new Date(isoOrDate);
    if (Number.isNaN(d.getTime())) return isoOrDate;
    return d.toISOString().slice(0, 10);
  } catch {
    return isoOrDate;
  }
}

function formatLeadTime(minDays: number | null, maxDays: number | null): string {
  if (minDays == null && maxDays == null) return '';
  if (minDays != null && maxDays != null && minDays !== maxDays) {
    return `Lead time: ${minDays}–${maxDays} days`;
  }
  const d = minDays ?? maxDays;
  return d != null ? `Lead time: ${d} day${d === 1 ? '' : 's'}` : '';
}

function capitalizeRiskLevel(riskLevel: string | null): string {
  if (!riskLevel) return '';
  return riskLevel.charAt(0).toUpperCase() + riskLevel.slice(1).toLowerCase();
}

const LABELS: Record<InventoryAvailabilityStatus, string> = {
  IN_STOCK: 'In Stock',
  ON_ORDER: 'On Order',
  OUT_OF_STOCK: 'Out of Stock',
};

const STYLES: Record<InventoryAvailabilityStatus, string> = {
  IN_STOCK: 'bg-green-50 text-green-700 border-green-200',
  ON_ORDER: 'bg-yellow-50 text-yellow-800 border-yellow-200',
  OUT_OF_STOCK: 'bg-red-50 text-red-700 border-red-200',
};

function buildTooltip(row: InventoryAvailabilityRow): string {
  const lines: string[] = [];
  if (row.is_risk && row.risk_level) {
    lines.push(`Risk: ${capitalizeRiskLevel(row.risk_level)}`);
  }
  if (row.next_eta) {
    lines.push(`Next ETA: ${formatDate(row.next_eta)}`);
  }
  const leadTime = formatLeadTime(row.import_lead_time_min_days, row.import_lead_time_max_days);
  if (leadTime) lines.push(leadTime);
  if (row.is_special_order) {
    lines.push('Special order');
  }
  return lines.length > 0 ? lines.join(' · ') : 'Availability is informational only.';
}

interface InventoryAvailabilityBadgeProps {
  row?: InventoryAvailabilityRow | null;
}

/**
 * Displays availability badge from inventory_availability view.
 * If no row: shows "—" or "Unknown". Risk shows ⚠️ and tooltip with risk_level, next_eta, lead time, special order.
 * Do NOT persist in QuoteLine. Display only.
 */
export function InventoryAvailabilityBadge({ row }: InventoryAvailabilityBadgeProps) {
  if (row == null) {
    return (
      <span
        className={`inline-flex items-center rounded border px-1.5 py-0.5 text-xs font-medium ${STYLES.OUT_OF_STOCK}`}
        title="No inventory record"
      >
        {LABELS.OUT_OF_STOCK}
      </span>
    );
  }

  const status = (row.availability ?? 'OUT_OF_STOCK') as InventoryAvailabilityStatus;
  const label = LABELS[status] ?? 'Unknown';
  const style = STYLES[status] ?? 'bg-gray-50 text-gray-600 border-gray-200';
  const tooltipContent = buildTooltip(row);

  const badge = (
    <span
      className={`inline-flex items-center gap-1 rounded border px-1.5 py-0.5 text-xs font-medium ${style}`}
    >
      {row.is_risk && <span title={`Risk: ${capitalizeRiskLevel(row.risk_level)}`}>⚠️</span>}
      <span>{label}</span>
    </span>
  );

  return (
    <Tooltip content={tooltipContent} side="top">
      {badge}
    </Tooltip>
  );
}

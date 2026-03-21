// Utility functions

/**
 * Formats a date string to dd/mm/yyyy (Latin America format).
 * Accepts ISO strings (2026-03-18 or 2026-03-18T...) or Date objects.
 */
export function formatDate(dateStr: string | null | undefined | Date): string {
  if (!dateStr) return '—';
  let d: Date;
  if (dateStr instanceof Date) {
    d = dateStr;
  } else {
    // If it's a date-only string (yyyy-mm-dd), append T00:00:00 to avoid timezone shifts
    d = new Date(dateStr.length === 10 ? dateStr + 'T00:00:00' : dateStr);
  }
  if (isNaN(d.getTime())) return '—';
  const dd = String(d.getDate()).padStart(2, '0');
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  const yyyy = d.getFullYear();
  return `${dd}/${mm}/${yyyy}`;
}

/**
 * Formats a date+time string to dd/mm/yyyy, HH:MM.
 */
export function formatDateTime(dateStr: string | null | undefined | Date): string {
  if (!dateStr) return '—';
  const d = dateStr instanceof Date ? dateStr : new Date(dateStr as string);
  if (isNaN(d.getTime())) return '—';
  const dd = String(d.getDate()).padStart(2, '0');
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  const yyyy = d.getFullYear();
  const h = String(d.getHours()).padStart(2, '0');
  const m = String(d.getMinutes()).padStart(2, '0');
  return `${dd}/${mm}/${yyyy}, ${h}:${m}`;
}

export function formatCurrency(amount: number, currency: string = 'USD'): string {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: currency,
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(amount);
}

export function cn(...classes: (string | undefined | null | false)[]): string {
  return classes.filter(Boolean).join(' ');
}











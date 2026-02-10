import React from 'react';
import { getDimensionsStructured, type DimensionsSource } from '../lib/formatDimensions';

/**
 * MEASUREMENTS (mm) – Formato: 1200 x 3000, 1500 (sin etiquetas w/h)
 */
export default function DimensionsStackView({
  source,
  className = '',
  unitSuffix = '',
}: {
  source: DimensionsSource;
  className?: string;
  unitSuffix?: string;
}) {
  const data = getDimensionsStructured(source);
  if (!data || data.widths.length === 0) {
    return <span className={className}>—</span>;
  }

  const { widths, heightMm } = data;
  const heightPart = `${heightMm}${unitSuffix}`;

  return (
    // ✅ Layout rules:
    // - widths stacked vertically
    // - spacing between width and "x" MUST equal spacing between "x" and height
    // - vertical spacing between rows slightly increased (requested)
    <div className={`flex flex-col gap-1 leading-none ${className}`}>
      {widths.map((w, i) => (
        <div key={i} className="flex items-baseline">
          {/* Right-align inside fixed width so (width↔x) spacing is symmetric */}
          <span className="tabular-nums min-w-[6ch] text-right shrink-0">
            {w}
          </span>
          {i === 0 && (
            <>
              <span className="shrink-0 px-1" aria-hidden>
                {' '}x{' '}
              </span>
              <span className="tabular-nums whitespace-nowrap shrink-0">
                {heightPart}
              </span>
            </>
          )}
        </div>
      ))}
    </div>
  );
}

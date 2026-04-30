import React from 'react';

interface AdaptioMarkProps {
  size?: number;
  color?: string;
  className?: string;
  style?: React.CSSProperties;
}

const ADAPTIO_MARK_SRC = '/ChatGPT%20Image%2029%20abr%202026,%2016_23_09.png';

export default function AdaptioMark({
  size = 27,
  color = 'var(--primary-brand-hex)',
  className,
  style,
}: AdaptioMarkProps) {
  return (
    <span
      className={className}
      style={{
        width: size,
        height: size,
        minWidth: size,
        minHeight: size,
        display: 'inline-flex',
        overflow: 'hidden',
        alignItems: 'center',
        justifyContent: 'center',
        lineHeight: 0,
        ...style,
      }}
      // Keep API backwards-compatible; color is intentionally ignored because
      // user requested this exact uploaded file.
      data-color={color}
      aria-hidden="true"
    >
      <img
        src={ADAPTIO_MARK_SRC}
        alt="Adaptio mark"
        width={size}
        height={size}
        style={{
          width: '100%',
          height: '100%',
          objectFit: 'cover',
          objectPosition: 'center',
          display: 'block',
        }}
      />
    </span>
  );
}

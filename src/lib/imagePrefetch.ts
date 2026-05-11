const prefetchedImageUrls = new Set<string>();

function canPrefetchUrl(raw: string): boolean {
  const url = raw.trim();
  if (!url) return false;
  // Accept http(s) and local assets.
  return /^https?:\/\//i.test(url) || url.startsWith('/') || url.startsWith('./');
}

/**
 * Lightweight image prefetch for visible cards.
 * - deduped globally
 * - bounded by maxCount to avoid flooding
 */
export function prefetchImageUrls(urls: Array<string | null | undefined>, maxCount = 10): void {
  if (typeof window === 'undefined') return;
  if (!Array.isArray(urls) || urls.length === 0) return;

  let queued = 0;
  for (const candidate of urls) {
    if (queued >= maxCount) break;
    const url = String(candidate || '').trim();
    if (!canPrefetchUrl(url)) continue;
    if (prefetchedImageUrls.has(url)) continue;

    prefetchedImageUrls.add(url);
    const img = new Image();
    img.decoding = 'async';
    img.src = url;
    queued += 1;
  }
}


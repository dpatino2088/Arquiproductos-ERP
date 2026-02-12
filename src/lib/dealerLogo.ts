/**
 * Dealer logo: path is dealer-logos/{dealer_id}/{filename}.
 * Use getPublicUrl only; do not build URLs manually or use createSignedUrl.
 */

/** Extract storage path from full logo_url. Returns "dealer-logos/{dealer_id}/{filename}" or null. No querystring. */
export function getLogoPathFromUrl(logoUrl: string | null | undefined): string | null {
  if (!logoUrl || typeof logoUrl !== 'string') return null;
  const trimmed = logoUrl.trim();
  if (!trimmed) return null;

  if (!/^https?:\/\//i.test(trimmed)) {
    return trimmed.replace(/^\/+/, '');
  }

  try {
    const u = new URL(trimmed);
    const pathname = u.pathname;
    const marker = '/catalog-images/';
    const idx = pathname.indexOf(marker);
    if (idx === -1) return null;
    const path = pathname.slice(idx + marker.length);
    return path.replace(/^\/+/, '');
  } catch {
    return null;
  }
}

type SupabaseStorage = {
  storage: {
    from: (bucket: string) => {
      getPublicUrl: (path: string) => { data: { publicUrl: string } };
    };
  };
};

/**
 * Set dealer logo on a given img element. Use this with a ref to avoid duplicate-ID issues.
 * Normalizes path (removes leading slashes) and sets onerror for debugging.
 */
export function setDealerLogoOnElement(
  supabase: SupabaseStorage,
  img: HTMLImageElement | null,
  logoPath: string | null
): void {
  if (!img) return;

  if (!logoPath) {
    img.style.display = 'none';
    img.removeAttribute('src');
    return;
  }

  const cleanPath = logoPath.replace(/^\/+/, '');
  const { data } = supabase.storage.from('catalog-images').getPublicUrl(cleanPath);

  img.crossOrigin = 'anonymous';
  img.onerror = () => {
    console.error('Dealer logo failed to load', { logoPath, cleanPath, publicUrl: data.publicUrl });
    img.style.display = 'none';
  };
  img.src = data.publicUrl;
  img.style.display = 'block';
}

/**
 * Set dealer logo on element by id. Use elementId to avoid duplicate IDs (e.g. dealerLogoDetail vs dealerLogoPrint).
 */
export function setDealerLogo(
  supabase: SupabaseStorage,
  logoPath: string | null,
  elementId: string = 'dealerLogo'
): void {
  const img = document.getElementById(elementId) as HTMLImageElement | null;
  setDealerLogoOnElement(supabase, img, logoPath);
}

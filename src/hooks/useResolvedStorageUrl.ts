import { useMemo } from 'react';
import { supabase } from '../lib/supabase/client';

/** True if string is a Supabase storage public URL (do not sign; use as-is). */
function isSupabasePublicStorageUrl(url: string): boolean {
  return /^https?:\/\/[^/]*\/storage\/v1\/object\/public\//i.test(url.trim());
}

/** Local static assets served by Vite/public (must NOT be rewritten to Supabase Storage). */
function isLocalStaticAssetPath(path: string): boolean {
  const normalized = path.trim().toLowerCase();
  return (
    normalized.startsWith('/images/') ||
    normalized.startsWith('images/') ||
    normalized.startsWith('/assets/') ||
    normalized.startsWith('assets/')
  );
}

/**
 * Resolves a logo_url for display in UI (Proposal, Print).
 * - If already a Supabase public URL (/storage/v1/object/public/...): return it as-is.
 *   Do NOT create signed URLs; they often fail for dealer/portal roles and are unnecessary for public buckets.
 * - If it's a path (e.g. "dealer-logos/...") without http: build public URL via getPublicUrl(catalog-images).
 */
export function useResolvedStorageUrl(url: string | null | undefined): string | null {
  return useMemo(() => {
    if (!url || !url.trim()) return null;

    const trimmed = url.trim();
    const cached = resolvedUrlCache.get(trimmed);
    if (cached !== undefined) return cached;

    let resolved: string | null = null;

    // Already a public storage URL → use as-is (no signing)
    if (isSupabasePublicStorageUrl(trimmed)) {
      resolved = trimmed;
    } else if (isLocalStaticAssetPath(trimmed)) {
      // Local static image in /public (e.g. /images/DR_2.0.png)
      // Respect Vite BASE_URL for deployments under subpaths.
      const base = (import.meta.env.BASE_URL || '/').replace(/\/$/, '');
      const localPath = trimmed.replace(/^\/+/, '');
      resolved = `${base}/${localPath}`;
    } else if (!/^https?:\/\//i.test(trimmed)) {
      // Path only (e.g. dealer-logos/org/dealer/file.png) → build public URL
      const path = trimmed.replace(/^\/+/, '');
      const { data } = supabase.storage.from('catalog-images').getPublicUrl(path);
      resolved = data.publicUrl || null;
    } else {
      // Other URL (external, etc.)
      resolved = trimmed;
    }

    resolvedUrlCache.set(trimmed, resolved);
    return resolved;
  }, [url]);
}

// Shared cache to avoid repeated URL resolution across large lists (zero-loading friendly).
const resolvedUrlCache = new Map<string, string | null>();

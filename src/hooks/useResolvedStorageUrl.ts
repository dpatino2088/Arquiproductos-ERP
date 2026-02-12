import { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase/client';

/** True if string is a Supabase storage public URL (do not sign; use as-is). */
function isSupabasePublicStorageUrl(url: string): boolean {
  return /^https?:\/\/[^/]*\/storage\/v1\/object\/public\//i.test(url.trim());
}

/**
 * Resolves a logo_url for display in UI (Proposal, Print).
 * - If already a Supabase public URL (/storage/v1/object/public/...): return it as-is.
 *   Do NOT create signed URLs; they often fail for dealer/portal roles and are unnecessary for public buckets.
 * - If it's a path (e.g. "dealer-logos/...") without http: build public URL via getPublicUrl(catalog-images).
 */
export function useResolvedStorageUrl(url: string | null | undefined): string | null {
  const [resolved, setResolved] = useState<string | null>(url || null);

  useEffect(() => {
    if (!url || !url.trim()) {
      setResolved(null);
      return;
    }
    const trimmed = url.trim();

    // Already a public storage URL → use as-is (no signing)
    if (isSupabasePublicStorageUrl(trimmed)) {
      setResolved(trimmed);
      return;
    }

    // Path only (e.g. dealer-logos/org/dealer/file.png) → build public URL
    if (!/^https?:\/\//i.test(trimmed)) {
      const path = trimmed.replace(/^\/+/, '');
      const { data } = supabase.storage.from('catalog-images').getPublicUrl(path);
      setResolved(data.publicUrl || null);
      return;
    }

    // Other URL (external, etc.)
    setResolved(trimmed);
  }, [url]);

  return resolved;
}

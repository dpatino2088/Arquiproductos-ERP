interface ReturnToRouter {
  navigate: (path: string, pushState?: boolean) => void;
}

export const CATALOG_ITEMS_LIST_STATE_KEY = 'catalogItems:listState:v1';
export const CATALOG_ITEMS_RESTORE_ON_BACK_KEY = 'catalogItems:restoreOnBack:v1';
export const CATALOG_ITEMS_RETURN_TO_KEY = 'catalogItems:returnTo:v1';

interface ResolveReturnToParams {
  queryReturnTo?: string | null;
  storageReturnTo?: string | null;
  fallback: string;
}

function sanitizeInternalPath(path: string | null | undefined): string | null {
  if (!path) return null;
  const value = path.trim();
  if (!value.startsWith('/')) return null;
  if (value.startsWith('//')) return null;
  return value;
}

export function buildReturnTo(): string {
  return `${window.location.pathname}${window.location.search}`;
}

export function withReturnTo(path: string, returnTo: string = buildReturnTo()): string {
  const url = new URL(path, window.location.origin);
  const safeReturnTo = sanitizeInternalPath(returnTo);
  if (safeReturnTo) {
    url.searchParams.set('returnTo', safeReturnTo);
  }
  return `${url.pathname}${url.search}`;
}

export function resolveReturnTo({
  queryReturnTo,
  storageReturnTo,
  fallback,
}: ResolveReturnToParams): string {
  return (
    sanitizeInternalPath(queryReturnTo) ||
    sanitizeInternalPath(storageReturnTo) ||
    sanitizeInternalPath(fallback) ||
    '/'
  );
}

export function getReturnToFromCurrentQuery(): string | null {
  const params = new URLSearchParams(window.location.search);
  return sanitizeInternalPath(params.get('returnTo'));
}

export function navigateBackContextual(
  router: ReturnToRouter,
  {
    queryReturnTo,
    storageReturnTo,
    fallback,
  }: ResolveReturnToParams
): void {
  const target = resolveReturnTo({ queryReturnTo, storageReturnTo, fallback });
  router.navigate(target);
}

export function setCatalogItemsRestoreOnBack(shouldRestore: boolean): void {
  try {
    if (shouldRestore) {
      window.sessionStorage.setItem(CATALOG_ITEMS_RESTORE_ON_BACK_KEY, '1');
      return;
    }
    window.sessionStorage.removeItem(CATALOG_ITEMS_RESTORE_ON_BACK_KEY);
  } catch {
    // no-op
  }
}

export function setCatalogItemsReturnTo(path: string | null): void {
  try {
    const safe = sanitizeInternalPath(path);
    if (!safe) {
      window.sessionStorage.removeItem(CATALOG_ITEMS_RETURN_TO_KEY);
      return;
    }
    window.sessionStorage.setItem(CATALOG_ITEMS_RETURN_TO_KEY, safe);
  } catch {
    // no-op
  }
}

export function getCatalogItemsReturnTo(): string | null {
  try {
    return sanitizeInternalPath(window.sessionStorage.getItem(CATALOG_ITEMS_RETURN_TO_KEY));
  } catch {
    return null;
  }
}

export function withCatalogItemsRestore(path: string): string {
  const safe = sanitizeInternalPath(path);
  if (!safe || !safe.startsWith('/catalog/items')) return path;
  const url = new URL(safe, window.location.origin);
  url.searchParams.set('restoreList', '1');
  return `${url.pathname}${url.search}`;
}

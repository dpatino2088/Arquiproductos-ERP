interface ReturnToRouter {
  navigate: (path: string, pushState?: boolean) => void;
}

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

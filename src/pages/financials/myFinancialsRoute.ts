export function isMyFinancialsPath(pathname: string = window.location.pathname): boolean {
  return pathname === '/my-financials' || pathname.startsWith('/my-financials/');
}

export function toMyFinancialsPath(path: string): string {
  if (!path.startsWith('/financials')) return path;
  return path.replace('/financials', '/my-financials');
}

export function getFinancialBasePath(pathname: string = window.location.pathname): '/financials' | '/my-financials' {
  return isMyFinancialsPath(pathname) ? '/my-financials' : '/financials';
}

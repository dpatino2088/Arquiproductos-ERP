/**
 * Portal Access Control Helpers
 *
 * Role-based access control for Dealer Portal Users
 * Roles: dealer_manager | dealer_member
 */

export type CompanyPortalRole = 'dealer_manager' | 'dealer_member';

export interface PortalQuote {
  id: string;
  dealer_id: string;
  created_by_user_id: string | null;
  status: 'draft' | 'sent' | 'approved' | 'rejected' | 'cancelled' | 'converted' | 'superseded';
  [key: string]: any;
}

/**
 * Check if a role can create quotes
 * Both dealer_member and dealer_manager can create quotes
 */
export function canCreateQuote(role: CompanyPortalRole | string | null | undefined): boolean {
  if (!role) return false;
  const normalizedRole = normalizeRole(role);
  return normalizedRole === 'dealer_member' || normalizedRole === 'dealer_manager';
}

/**
 * Check if a role can edit a specific quote
 * - dealer_member: only if they own the quote AND status is draft
 * - dealer_manager: can edit all
 */
export function canEditQuote(
  role: CompanyPortalRole | string | null | undefined,
  quote: PortalQuote | null | undefined,
  authUserId: string | null | undefined
): boolean {
  if (!role || !quote || !authUserId) return false;

  const normalizedRole = normalizeRole(role);

  if (normalizedRole === 'dealer_manager') return true;

  if (normalizedRole === 'dealer_member') {
    return (
      quote.created_by_user_id === authUserId &&
      quote.status === 'draft'
    );
  }

  return false;
}

/**
 * Check if a role can view a specific quote
 * - dealer_manager: can view all quotes for their dealer
 * - dealer_member: can only view quotes they created
 */
export function canViewQuote(
  role: CompanyPortalRole | string | null | undefined,
  quote: PortalQuote | null | undefined,
  authUserId: string | null | undefined
): boolean {
  if (!role || !quote) return false;

  const normalizedRole = normalizeRole(role);

  if (normalizedRole === 'dealer_manager') return true;

  if (normalizedRole === 'dealer_member') {
    return quote.created_by_user_id === authUserId;
  }

  return false;
}

/**
 * Check if a role can approve/reject a quote
 * - dealer_manager: can approve if quote status allows
 * - dealer_member: cannot approve
 */
export function canApproveQuote(
  role: CompanyPortalRole | string | null | undefined,
  quote: PortalQuote | null | undefined
): boolean {
  if (!role || !quote) return false;

  const normalizedRole = normalizeRole(role);

  if (normalizedRole !== 'dealer_manager') return false;

  const approvableStatuses: string[] = ['sent', 'draft'];
  return approvableStatuses.includes(quote.status);
}

/**
 * Normalize role string to dealer_manager | dealer_member.
 * Only `dealer_manager` is recognized as the manager role — legacy values
 * (`manager`, `member_manager`) are no longer valid.
 */
export function normalizeRole(role: string | null | undefined): CompanyPortalRole {
  if (!role) return 'dealer_member';
  const normalized = role.toLowerCase().trim();
  return normalized === 'dealer_manager' ? 'dealer_manager' : 'dealer_member';
}

/**
 * Get role label for display
 */
export function getRoleLabel(role: CompanyPortalRole | string | null | undefined): string {
  const normalized = normalizeRole(role);

  switch (normalized) {
    case 'dealer_manager':
      return 'Dealer Manager';
    case 'dealer_member':
      return 'Dealer Member';
    default:
      return 'Dealer Member';
  }
}

/**
 * Get role description for display
 */
export function getRoleDescription(role: CompanyPortalRole | string | null | undefined): string {
  const normalized = normalizeRole(role);

  switch (normalized) {
    case 'dealer_manager':
      return 'Can view all dealer quotes, approve/reject, and delete quotes/proposals/directory.';
    case 'dealer_member':
      return 'Can create/edit/delete their own quotes and proposals; delete directory (contacts/customers). Cannot approve quotes.';
    default:
      return 'Can create/edit/delete their own quotes and proposals; delete directory. Cannot approve quotes.';
  }
}

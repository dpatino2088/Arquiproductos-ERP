/**
 * Portal Access Control Helpers
 * 
 * Role-based access control for Company Portal Users
 * Roles: member_manager | member
 */

export type CompanyPortalRole = 'member_manager' | 'member';

export interface PortalQuote {
  id: string;
  company_id: string;
  created_by_portal_user_id: string | null;
  status: 'draft' | 'sent' | 'approved' | 'rejected' | 'cancelled';
  [key: string]: any; // Allow additional quote fields
}

/**
 * Check if a role can create quotes
 * Both member and member_manager can create quotes
 */
export function canCreateQuote(role: CompanyPortalRole | string | null | undefined): boolean {
  if (!role) return false;
  const normalizedRole = normalizeRole(role);
  return normalizedRole === 'member' || normalizedRole === 'member_manager';
}

/**
 * Check if a role can edit a specific quote
 * - member: only if they own the quote AND status is draft
 * - member_manager: can edit (optional, but minimum is view + approve)
 */
export function canEditQuote(
  role: CompanyPortalRole | string | null | undefined,
  quote: PortalQuote | null | undefined,
  portalUserId: string | null | undefined
): boolean {
  if (!role || !quote || !portalUserId) return false;
  
  const normalizedRole = normalizeRole(role);
  
  if (normalizedRole === 'member_manager') {
    // Managers can edit (optional, but allowed)
    return true;
  }
  
  if (normalizedRole === 'member') {
    // Members can only edit their own quotes in draft
    return (
      quote.created_by_portal_user_id === portalUserId &&
      quote.status === 'draft'
    );
  }
  
  return false;
}

/**
 * Check if a role can view a specific quote
 * - member_manager: can view all quotes for their company
 * - member: can only view quotes they created
 */
export function canViewQuote(
  role: CompanyPortalRole | string | null | undefined,
  quote: PortalQuote | null | undefined,
  portalUserId: string | null | undefined
): boolean {
  if (!role || !quote) return false;
  
  const normalizedRole = normalizeRole(role);
  
  if (normalizedRole === 'member_manager') {
    // Managers can view all company quotes
    return true;
  }
  
  if (normalizedRole === 'member') {
    // Members can only view their own quotes
    return quote.created_by_portal_user_id === portalUserId;
  }
  
  return false;
}

/**
 * Check if a role can approve/reject a quote
 * - member_manager: can approve if quote status allows
 * - member: cannot approve
 */
export function canApproveQuote(
  role: CompanyPortalRole | string | null | undefined,
  quote: PortalQuote | null | undefined
): boolean {
  if (!role || !quote) return false;
  
  const normalizedRole = normalizeRole(role);
  
  if (normalizedRole !== 'member_manager') {
    return false;
  }
  
  // Can approve/reject if quote is in a state that allows it
  // Typically: 'sent' or 'draft' (adjust based on your workflow)
  const approvableStatuses: string[] = ['sent', 'draft'];
  return approvableStatuses.includes(quote.status);
}

/**
 * Normalize legacy role values to current roles
 * - 'manager' -> 'member_manager'
 * - anything else -> 'member'
 */
export function normalizeRole(role: string | null | undefined): CompanyPortalRole {
  if (!role) return 'member';
  
  const normalized = role.toLowerCase().trim();
  
  if (normalized === 'manager' || normalized === 'member_manager') {
    return 'member_manager';
  }
  
  return 'member';
}

/**
 * Get role label for display
 */
export function getRoleLabel(role: CompanyPortalRole | string | null | undefined): string {
  const normalized = normalizeRole(role);
  
  switch (normalized) {
    case 'member_manager':
      return 'Member Manager';
    case 'member':
      return 'Member';
    default:
      return 'Member';
  }
}

/**
 * Get role description for display
 */
export function getRoleDescription(role: CompanyPortalRole | string | null | undefined): string {
  const normalized = normalizeRole(role);
  
  switch (normalized) {
    case 'member_manager':
      return 'Can view all company quotes and approve/reject';
    case 'member':
      return 'Can create/edit their own quotes; cannot approve';
    default:
      return 'Can create/edit their own quotes; cannot approve';
  }
}

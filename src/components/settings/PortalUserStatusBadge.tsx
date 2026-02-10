import React from 'react';

export interface PortalUserStatusBadgeProps {
  status: string;
  invitationStatus?: string | null;
  className?: string;
}

/**
 * Status badge for Dealer Users
 * Shows both account status and invitation status with color coding
 */
export function PortalUserStatusBadge({ 
  status, 
  invitationStatus, 
  className = '' 
}: PortalUserStatusBadgeProps) {
  const statusColors: Record<string, { bg: string; text: string; label: string }> = {
    draft: { bg: 'bg-gray-50', text: 'text-gray-700', label: 'Draft' },
    authorized: { bg: 'bg-blue-50', text: 'text-blue-700', label: 'Authorized' },
    invited: { bg: 'bg-amber-50', text: 'text-amber-700', label: 'Invited' }, // Amber for invited
    active: { bg: 'bg-green-50', text: 'text-green-700', label: 'Active' }, // Green for active
    inactive: { bg: 'bg-gray-50', text: 'text-gray-700', label: 'Inactive' },
    disabled: { bg: 'bg-gray-50', text: 'text-gray-700', label: 'Disabled' }, // Gray for disabled
    pending: { bg: 'bg-yellow-50', text: 'text-yellow-700', label: 'Pending' },
    suspended: { bg: 'bg-red-50', text: 'text-red-700', label: 'Suspended' },
  };

  const invitationStatusColors: Record<string, { bg: string; text: string; label: string }> = {
    pending: { bg: 'bg-gray-50', text: 'text-gray-600', label: 'Not Sent' },
    sent: { bg: 'bg-amber-50', text: 'text-amber-700', label: 'Sent' },
    accepted: { bg: 'bg-green-50', text: 'text-green-700', label: 'Accepted' },
    expired: { bg: 'bg-red-50', text: 'text-red-700', label: 'Expired' },
  };

  const normalizedStatus = (status || 'unknown').toLowerCase();
  const colors = statusColors[normalizedStatus] || statusColors.inactive;
  
  const normalizedInvitationStatus = invitationStatus?.toLowerCase();
  const invitationColors = normalizedInvitationStatus 
    ? invitationStatusColors[normalizedInvitationStatus] 
    : null;

  if (!colors) return null;

  return (
    <div className={`flex items-center gap-2 ${className}`}>
      <span 
        className={`px-2 py-1 rounded-full text-xs font-medium ${colors.bg} ${colors.text}`}
        title={`Status: ${colors.label}`}
      >
        {colors.label}
      </span>
      {invitationColors && (
        <span 
          className={`px-2 py-1 rounded-full text-xs font-medium ${invitationColors.bg} ${invitationColors.text}`}
          title={`Invitation: ${invitationColors.label}`}
        >
          {invitationColors.label}
        </span>
      )}
    </div>
  );
}

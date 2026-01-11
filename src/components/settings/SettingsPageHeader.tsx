import React from 'react';
import { Plus } from 'lucide-react';
import { useOrganizationContext } from '../../context/OrganizationContext';

interface SettingsPageHeaderProps {
  title: string;
  subtitle: string;
  actionLabel?: string;
  onAction?: () => void;
  actionDisabled?: boolean;
  contextInfo?: string | number; // e.g., "X users" or organization name
}

export function SettingsPageHeader({
  title,
  subtitle,
  actionLabel,
  onAction,
  actionDisabled = false,
  contextInfo,
}: SettingsPageHeaderProps) {
  const { activeOrganizationId, activeOrganization } = useOrganizationContext();

  return (
    <div className="flex items-center justify-between mb-6">
      <div className="flex-1">
        <h1 className="text-xl font-semibold text-foreground mb-1">{title}</h1>
        <div className="flex items-center gap-2">
          <p className="text-xs" style={{ color: 'var(--gray-500)' }}>
            {subtitle}
          </p>
          {contextInfo && (
            <>
              <span className="text-xs" style={{ color: 'var(--gray-400)' }}>•</span>
              <span className="text-xs" style={{ color: 'var(--gray-500)' }}>
                {typeof contextInfo === 'number' ? `${contextInfo} ${contextInfo === 1 ? 'user' : 'users'}` : contextInfo}
              </span>
            </>
          )}
          {!activeOrganizationId && (
            <>
              <span className="text-xs" style={{ color: 'var(--gray-400)' }}>•</span>
              <span className="text-xs text-amber-600">Select an organization</span>
            </>
          )}
        </div>
      </div>
      
      {actionLabel && onAction && (
        <div className="flex items-center gap-3">
          <button
            type="button"
            onClick={onAction}
            disabled={actionDisabled || !activeOrganizationId}
            className="flex items-center gap-2 px-2 py-1 rounded text-white transition-colors text-sm hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed"
            style={{ backgroundColor: 'var(--primary-brand-hex)' }}
          >
            <Plus style={{ width: '14px', height: '14px' }} />
            {actionLabel}
          </button>
        </div>
      )}
    </div>
  );
}


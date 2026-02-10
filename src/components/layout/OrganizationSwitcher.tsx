import React, { useState, useEffect, useRef } from 'react';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useCurrentOrgRole } from '../../hooks/useCurrentOrgRole';
import { useAccessContext } from '../../hooks/useAccessContext';
import { Building2, ChevronDown, Check, AlertCircle, Loader2 } from 'lucide-react';
import { router } from '../../lib/router';

export function OrganizationSwitcher() {
  const {
    organizations,
    activeOrganization,
    activeOrganizationId,
    setActiveOrganizationId,
    loading,
    error,
  } = useOrganizationContext();

  const { isSuperAdmin, role: currentOrgRole } = useCurrentOrgRole();
  const { userType, portalRole, internalRole } = useAccessContext();
  const [isOpen, setIsOpen] = useState(false);
  const dropdownRef = useRef<HTMLDivElement>(null);

  // Close dropdown when clicking outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        setIsOpen(false);
      }
    };

    if (isOpen) {
      document.addEventListener('mousedown', handleClickOutside);
    }

    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, [isOpen]);

  const handleSelectOrganization = (orgId: string) => {
    setActiveOrganizationId(orgId);
    setIsOpen(false);
  };

  // Get the actual role to display based on user type
  // For portal users: always use portalRole (ignores orgRole which is null)
  // For internal users: SuperAdmin always shows "SuperAdmin"; else use OrganizationUsers.role (org summary), never DealerUsers.role
  const getDisplayRole = (orgRole: string | null): string | null => {
    if (userType === "portal") {
      return portalRole || null;
    }
    if (userType === "internal") {
      // Internal SuperAdmin: always show SuperAdmin, do not use org.role (e.g. operator from membership)
      if (isSuperAdmin) return "superadmin";
      // Internal non-SuperAdmin: use org role from OrganizationUsers (already in org summary), fallback to internalRole
      return orgRole || internalRole || null;
    }
    return orgRole;
  };

  const getRoleBadge = (role: string | null) => {
    // Portal (dealer) roles: Dealer Member y Dealer Manager
    if (userType === 'portal' && role === 'member') {
      const roleInfo = { label: 'Dealer Member', color: 'text-green-700', bgColor: 'bg-green-50' };
      return (
        <span className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-medium ${roleInfo.color} ${roleInfo.bgColor}`}>
          {roleInfo.label}
        </span>
      );
    }
    if (userType === 'portal' && role === 'member_manager') {
      const roleInfo = { label: 'Dealer Manager', color: 'text-blue-700', bgColor: 'bg-blue-50' };
      return (
        <span className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-medium ${roleInfo.color} ${roleInfo.bgColor}`}>
          {roleInfo.label}
        </span>
      );
    }
    // Internal roles
    const roleMap: Record<string, { label: string; color: string; bgColor: string }> = {
      superadmin: { label: 'SuperAdmin', color: 'text-purple-700', bgColor: 'bg-purple-50' },
      owner: { label: 'Owner', color: 'text-purple-700', bgColor: 'bg-purple-50' },
      admin: { label: 'Admin', color: 'text-blue-700', bgColor: 'bg-blue-50' },
      operator: { label: 'Operator', color: 'text-green-700', bgColor: 'bg-green-50' },
      procurement: { label: 'Procurement', color: 'text-indigo-700', bgColor: 'bg-indigo-50' },
      finance: { label: 'Finance', color: 'text-teal-700', bgColor: 'bg-teal-50' },
      member: { label: 'Member', color: 'text-green-700', bgColor: 'bg-green-50' },
      viewer: { label: 'Viewer', color: 'text-gray-700', bgColor: 'bg-gray-50' },
    };

    const roleInfo = roleMap[role || ''] || { label: role || 'Unknown', color: 'text-gray-700', bgColor: 'bg-gray-50' };
    return (
      <span
        className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-medium ${roleInfo.color} ${roleInfo.bgColor}`}
      >
        {roleInfo.label}
      </span>
    );
  };

  // Loading state
  if (loading) {
    return (
      <div className="flex items-center gap-2 px-3 py-1.5 text-sm text-gray-500">
        <Loader2 className="w-4 h-4 animate-spin" />
        <span>Loading orgs…</span>
      </div>
    );
  }

  // Error state - solo mostrar si realmente hay un error crítico
  // La mayoría de errores son esperados (no hay organizaciones, RLS, etc.)
  if (error && import.meta.env.DEV) {
    // Solo mostrar error en desarrollo para debugging
    return (
      <div className="flex items-center gap-2 px-3 py-1.5 text-sm text-red-600">
        <AlertCircle className="w-4 h-4" />
        <span>Error loading organizations (dev only)</span>
      </div>
    );
  }
  
  // En producción, si hay error pero no es crítico, mostrar "No organizations" en lugar de error
  if (error && !import.meta.env.DEV) {
    // Tratar como "no organizations" en lugar de error
    if (organizations.length === 0) {
      return (
        <div
          className="flex items-center gap-2 px-3 py-1.5 text-sm text-yellow-600 bg-yellow-50 rounded-md border border-yellow-200"
          title="No organizations available - contact administrator"
        >
          <AlertCircle className="w-4 h-4" />
          <span>No organizations available</span>
        </div>
      );
    }
  }

  // No organizations - organizations are created directly in Supabase
  if (organizations.length === 0) {
    return (
      <div
        className="flex items-center gap-2 px-3 py-1.5 text-sm text-yellow-600 bg-yellow-50 rounded-md border border-yellow-200"
        title="No organizations available - contact administrator"
      >
        <AlertCircle className="w-4 h-4" />
        <span>No organizations available</span>
      </div>
    );
  }

  return (
    <div className="relative" ref={dropdownRef}>
      {/* Main Button */}
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="flex items-center gap-2 px-3 py-1.5 rounded-md hover:bg-gray-50 transition-colors text-sm font-medium"
        style={{ color: 'var(--gray-950)' }}
        aria-label={`Current organization: ${activeOrganization?.name || 'Select organization'}`}
        aria-expanded={isOpen}
        aria-haspopup="listbox"
      >
        <Building2 className="w-4 h-4" style={{ color: 'var(--gray-950)' }} />
        <span className="max-w-[200px] truncate">
          {activeOrganization?.name || 'Select organization'}
        </span>
        {/* Show role badge in header for current organization */}
        {activeOrganization && (() => {
          const displayRole = getDisplayRole(activeOrganization.role || null);
          if (!displayRole) return null;
          if (userType === "internal" && displayRole === "superadmin") {
            return (
              <span className="inline-flex items-center px-1.5 py-0.5 rounded text-xs font-medium bg-purple-100 text-purple-700">
                SuperAdmin
              </span>
            );
          }
          return getRoleBadge(displayRole);
        })()}
        <ChevronDown
          className={`w-4 h-4 transition-transform ${isOpen ? 'rotate-180' : ''}`}
          style={{ color: 'var(--gray-950)' }}
        />
      </button>

      {/* Dropdown Menu */}
      {isOpen && (
        <div
          className="absolute left-0 mt-2 w-72 bg-white rounded-lg shadow-lg border border-gray-200 py-2 z-50"
          role="listbox"
          aria-label="Organization list"
        >
          <div className="px-3 py-2 border-b border-gray-100">
            <div className="text-xs font-medium text-gray-500 uppercase tracking-wider">Organizations</div>
          </div>

          <div className="max-h-64 overflow-y-auto">
            {organizations.map((org) => {
              const isActive = org.id === activeOrganizationId;
              return (
                <button
                  key={org.id}
                  onClick={() => handleSelectOrganization(org.id)}
                  className={`w-full px-4 py-2.5 text-left hover:bg-gray-50 flex items-center justify-between gap-2 transition-colors ${
                    isActive ? 'bg-gray-50' : ''
                  }`}
                  role="option"
                  aria-selected={isActive}
                  aria-label={`${isActive ? 'Current organization' : 'Switch to'} ${org.name}`}
                >
                  <div className="flex items-center gap-3 flex-1 min-w-0">
                    <Building2
                      className="w-4 h-4 flex-shrink-0"
                      style={{
                        color: isActive ? 'var(--primary-brand-hex)' : 'var(--gray-600)',
                      }}
                      aria-hidden="true"
                    />
                    <div className="flex-1 min-w-0">
                      <div
                        className={`font-medium truncate ${
                          isActive ? 'text-primary' : 'text-gray-900'
                        }`}
                        style={{
                          color: isActive ? 'var(--primary-brand-hex)' : undefined,
                        }}
                      >
                        {org.name}
                      </div>
                      <div className="mt-1">{getRoleBadge(getDisplayRole(org.role ?? null))}</div>
                    </div>
                  </div>
                  {isActive && (
                    <Check
                      className="w-4 h-4 flex-shrink-0"
                      style={{ color: 'var(--primary-brand-hex)' }}
                      aria-hidden="true"
                    />
                  )}
                </button>
              );
            })}
          </div>
        </div>
      )}
    </div>
  );
}

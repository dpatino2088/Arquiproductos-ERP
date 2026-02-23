import React, { useState, useEffect, useRef } from 'react';
import { useActingAsDealer } from '../../hooks/useActingAsDealer';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useDealers } from '../../hooks/useDealers';
import { ChevronDown, Check, Store, LayoutGrid, Loader2 } from 'lucide-react';

/**
 * Dealer filter for org users (SuperAdmin / Admin).
 * Calls set_acting_dealer RPC directly via useActingAsDealer.
 */
export function ActingAsSwitcher({ onAfterSelect, labelAbove }: { onAfterSelect?: () => void; labelAbove?: boolean } = {}) {
  const { activeDealerId, setActingDealer, clearActingDealer, isSaving, isLoading } = useActingAsDealer();
  const { activeOrganization } = useOrganizationContext();
  const { dealers } = useDealers();
  const [isOpen, setIsOpen] = useState(false);
  const dropdownRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const handleClickOutside = (e: MouseEvent) => {
      if (dropdownRef.current && !dropdownRef.current.contains(e.target as Node)) setIsOpen(false);
    };
    if (isOpen) document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, [isOpen]);

  const orgName = activeOrganization?.name || 'Organization';
  const activeDealer = activeDealerId ? dealers.find(d => d.id === activeDealerId) : null;
  const isViewingAll = !activeDealerId;
  const displayName = isViewingAll
    ? 'All dealers'
    : (activeDealer?.dealer_name || 'Dealer');

  const handleSelect = (dealerId: string | null) => {
    if (dealerId != null && dealerId !== '') {
      if (import.meta.env.DEV) {
        console.log('[ActingAs] selecting dealer', { dealerId });
      }
      setActingDealer(dealerId);
    } else if (dealerId === null) {
      if (import.meta.env.DEV) {
        console.log('[ActingAs] clearing dealer (All dealers)');
      }
      clearActingDealer();
    } else {
      console.warn('[ActingAs] no dealerId from selection (expected null or uuid)', { dealerId });
      return;
    }
    setIsOpen(false);
    onAfterSelect?.();
  };

  if (isLoading) return null;

  return (
    <div className={`relative flex gap-2 ${labelAbove ? 'flex-col' : 'flex-row items-center'}`} ref={dropdownRef}>
      <span className="text-xs text-gray-500 whitespace-nowrap">Dealer filter:</span>
      <button
        type="button"
        onClick={() => setIsOpen(!isOpen)}
        disabled={isSaving}
        className={`flex items-center gap-1.5 px-2.5 py-1 rounded-md border border-gray-200 bg-white hover:bg-gray-50 text-sm font-medium text-gray-800 ${labelAbove ? 'w-full justify-between' : ''} ${isSaving ? 'opacity-60 cursor-wait' : ''}`}
        aria-expanded={isOpen}
        aria-haspopup="listbox"
        aria-label={`Filter: ${displayName}. Click to change.`}
      >
        {isSaving
          ? <Loader2 className="w-3.5 h-3.5 text-gray-400 flex-shrink-0 animate-spin" />
          : isViewingAll
            ? <LayoutGrid className="w-3.5 h-3.5 text-indigo-500 flex-shrink-0" />
            : <Store className="w-3.5 h-3.5 text-gray-500 flex-shrink-0" />
        }
        <span className="max-w-[200px] truncate">{displayName}</span>
        <ChevronDown className={`w-3.5 h-3.5 text-gray-500 flex-shrink-0 transition-transform ${isOpen ? 'rotate-180' : ''}`} />
      </button>

      {isOpen && (
        <div
          className="absolute left-0 top-full mt-1 w-64 bg-white rounded-lg shadow-lg border border-gray-200 py-2 z-[100]"
          role="listbox"
          aria-label="Filter by dealer"
        >
          <div className="px-3 py-1.5 border-b border-gray-100">
            <div className="text-xs font-medium text-gray-500 uppercase tracking-wider">Filter by dealer</div>
          </div>
          <div className="max-h-64 overflow-y-auto">
            {/* All dealers (clear filter) */}
            <button
              type="button"
              onClick={() => handleSelect(null)}
              className="w-full px-4 py-2 text-left hover:bg-gray-50 flex items-center justify-between gap-2"
              role="option"
              aria-selected={isViewingAll}
            >
              <div className="flex items-center gap-2 min-w-0">
                <LayoutGrid className="w-4 h-4 flex-shrink-0 text-indigo-500" />
                <div className="min-w-0">
                  <span className="truncate font-medium text-gray-900 block">All dealers</span>
                  <span className="text-xs text-gray-400">View data from entire organization</span>
                </div>
              </div>
              {isViewingAll && <Check className="w-4 h-4 flex-shrink-0 text-indigo-500" />}
            </button>

            {dealers.length > 0 && (
              <div className="px-3 py-1 border-t border-gray-100 mt-1">
                <div className="text-xs font-medium text-gray-400 uppercase tracking-wider">{orgName}</div>
              </div>
            )}

            {dealers.map((d) => {
              const isActive = activeDealerId === d.id;
              return (
                <button
                  key={d.id}
                  type="button"
                  onClick={() => handleSelect(d.id)}
                  className="w-full px-4 py-2 text-left hover:bg-gray-50 flex items-center justify-between gap-2"
                  role="option"
                  aria-selected={isActive}
                >
                  <div className="flex items-center gap-2 min-w-0">
                    <Store className="w-4 h-4 flex-shrink-0 text-gray-500" />
                    <span className="truncate font-medium text-gray-900">{d.dealer_name}</span>
                  </div>
                  {isActive && <Check className="w-4 h-4 flex-shrink-0 text-indigo-500" />}
                </button>
              );
            })}
          </div>
        </div>
      )}
    </div>
  );
}

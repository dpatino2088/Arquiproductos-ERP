import React, { useState, useEffect, useRef } from 'react';
import { useActingAsContext } from '../../context/ActingAsContext';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useDealers } from '../../hooks/useDealers';
import { router } from '../../lib/router';
import { ChevronDown, Check, Building2, Store } from 'lucide-react';

/**
 * Shown only for Super Admin. Displays "Acting as: X" and allows switching
 * between Organization (Pertexco) and any Dealer. No DB; context + localStorage.
 * @param onAfterSelect - opcional: se llama después de elegir dealer/org (p. ej. para cerrar el menú usuario).
 * @param labelAbove - si true, la etiqueta "Dealer Account:" va arriba y el selector debajo.
 */
export function ActingAsSwitcher({ onAfterSelect, labelAbove }: { onAfterSelect?: () => void; labelAbove?: boolean } = {}) {
  const actingAs = useActingAsContext();
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

  const orgName = activeOrganization?.name || 'Organización';

  if (!actingAs) {
    return (
      <div className={`relative flex gap-2 ${labelAbove ? 'flex-col' : 'flex-row items-center'}`}>
        <span className="text-xs text-gray-500 whitespace-nowrap">Dealer Account:</span>
        <button
          type="button"
          onClick={() => router.navigate('/select-acting-dealer', true)}
          className={`flex items-center gap-1.5 px-2.5 py-1 rounded-md border border-dashed border-gray-300 bg-gray-50 hover:bg-gray-100 text-sm text-gray-600 ${labelAbove ? 'w-full justify-center' : ''}`}
        >
          <Store className="w-3.5 h-3.5 text-gray-400" />
          <span>Seleccionar…</span>
        </button>
      </div>
    );
  }

  const displayName = actingAs.activeDisplayName || (actingAs.activeDealerId ? 'Dealer' : orgName);
  const badgeText = `Dealer Account: ${displayName}`;

  const handleSelect = (dealerId: string | null, name: string) => {
    actingAs.setActiveDealer(dealerId, name);
    setIsOpen(false);
    onAfterSelect?.();
  };

  return (
    <div className={`relative flex gap-2 ${labelAbove ? 'flex-col' : 'flex-row items-center'}`} ref={dropdownRef}>
      <span className="text-xs text-gray-500 whitespace-nowrap">Dealer Account:</span>
      <button
        type="button"
        onClick={() => setIsOpen(!isOpen)}
        className={`flex items-center gap-1.5 px-2.5 py-1 rounded-md border border-gray-200 bg-white hover:bg-gray-50 text-sm font-medium text-gray-800 ${labelAbove ? 'w-full justify-between' : ''}`}
        aria-expanded={isOpen}
        aria-haspopup="listbox"
        aria-label={`${badgeText}. Click to change.`}
      >
        <Store className="w-3.5 h-3.5 text-gray-500 flex-shrink-0" />
        <span className="max-w-[200px] truncate" title={badgeText}>{displayName}</span>
        <ChevronDown className={`w-3.5 h-3.5 text-gray-500 flex-shrink-0 transition-transform ${isOpen ? 'rotate-180' : ''}`} />
      </button>

      {isOpen && (
        <div
          className="absolute left-0 top-full mt-1 w-64 bg-white rounded-lg shadow-lg border border-gray-200 py-2 z-[100]"
          role="listbox"
          aria-label="Seleccionar dealer u organización para operar"
        >
          <div className="px-3 py-1.5 border-b border-gray-100">
            <div className="text-xs font-medium text-gray-500 uppercase tracking-wider">Cuenta dealer u organización</div>
          </div>
          <div className="max-h-56 overflow-y-auto">
            <button
              type="button"
              onClick={() => handleSelect(null, orgName)}
              className="w-full px-4 py-2 text-left hover:bg-gray-50 flex items-center justify-between gap-2"
              role="option"
              aria-selected={!actingAs.activeDealerId}
            >
              <div className="flex items-center gap-2 min-w-0">
                <Building2 className="w-4 h-4 flex-shrink-0 text-gray-500" />
                <span className="truncate font-medium text-gray-900">{orgName}</span>
              </div>
              {!actingAs.activeDealerId && <Check className="w-4 h-4 flex-shrink-0 text-primary" />}
            </button>
            {dealers.map((d) => {
              const isActive = actingAs.activeDealerId === d.id;
              return (
                <button
                  key={d.id}
                  type="button"
                  onClick={() => handleSelect(d.id, d.dealer_name)}
                  className="w-full px-4 py-2 text-left hover:bg-gray-50 flex items-center justify-between gap-2"
                  role="option"
                  aria-selected={isActive}
                >
                  <div className="flex items-center gap-2 min-w-0">
                    <Store className="w-4 h-4 flex-shrink-0 text-gray-500" />
                    <span className="truncate font-medium text-gray-900">{d.dealer_name}</span>
                  </div>
                  {isActive && <Check className="w-4 h-4 flex-shrink-0 text-primary" />}
                </button>
              );
            })}
          </div>
        </div>
      )}
    </div>
  );
}

import React from 'react';
import { useActingAsContext } from '../context/ActingAsContext';
import { useOrganizationContext } from '../context/OrganizationContext';
import { useDealers } from '../hooks/useDealers';
import { router } from '../lib/router';
import { Building2, Store } from 'lucide-react';

/**
 * Pantalla obligatoria para Super Admin cuando no ha elegido "Acting as" (Dealer u organización).
 * Al elegir se guarda en context + localStorage y redirige al dashboard.
 */
export default function SelectActingDealer() {
  const actingAs = useActingAsContext();
  const { activeOrganization } = useOrganizationContext();
  const { dealers, isLoading } = useDealers();

  if (!actingAs) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50 p-6">
        <div className="text-gray-500">Loading…</div>
      </div>
    );
  }

  const orgName = activeOrganization?.name || 'Organización';

  const handleSelect = (dealerId: string | null, name: string) => {
    actingAs.setActiveDealer(dealerId, name);
    router.navigate('/dashboard', true);
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50 p-6">
      <div className="w-full max-w-md bg-white rounded-xl shadow-sm border border-gray-200 p-8">
        <h1 className="text-xl font-semibold text-gray-900 mb-1">
          Cuenta dealer u organización
        </h1>
        <p className="text-sm text-gray-500 mb-6">
          Como Super Admin de la organización puedes operar como la organización o como un Dealer. Solo verás datos (contactos, clientes, ventas) de la cuenta seleccionada.
        </p>

        {isLoading ? (
          <div className="py-8 text-center text-gray-500">Cargando dealers…</div>
        ) : (
          <div className="space-y-2">
            <button
              type="button"
              onClick={() => handleSelect(null, orgName)}
              className="w-full flex items-center gap-3 px-4 py-3 rounded-lg border border-gray-200 hover:bg-gray-50 hover:border-gray-300 text-left transition-colors"
            >
              <Building2 className="w-5 h-5 text-gray-500 flex-shrink-0" />
              <span className="font-medium text-gray-900">{orgName}</span>
            </button>
            {dealers.map((d) => (
              <button
                key={d.id}
                type="button"
                onClick={() => handleSelect(d.id, d.dealer_name)}
                className="w-full flex items-center gap-3 px-4 py-3 rounded-lg border border-gray-200 hover:bg-gray-50 hover:border-gray-300 text-left transition-colors"
              >
                <Store className="w-5 h-5 text-gray-500 flex-shrink-0" />
                <span className="font-medium text-gray-900">{d.dealer_name}</span>
              </button>
            ))}
          </div>
        )}

        {!isLoading && dealers.length === 0 && (
          <p className="mt-4 text-sm text-amber-600">
            No hay dealers en esta organización. Puedes operar como organización.
          </p>
        )}
      </div>
    </div>
  );
}

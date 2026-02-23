import React from 'react';
import { useActingAsContext } from '../context/ActingAsContext';
import { useOrganizationContext } from '../context/OrganizationContext';
import { useDealers } from '../hooks/useDealers';
import { router } from '../lib/router';
import { Building2, Store, LayoutGrid } from 'lucide-react';

/**
 * Página de filtro de dealer para Super Admin (opcional, ya no obligatoria).
 * Puedes llegar aquí desde el menú, pero ya no se redirige automáticamente.
 * Sin filtro = ver todos los dealers.
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
          Filtrar por dealer
        </h1>
        <p className="text-sm text-gray-500 mb-6">
          Como Super Admin ves todos los datos por defecto. Puedes filtrar por un dealer específico para ver solo sus cotizaciones, clientes y ventas.
        </p>

        {isLoading ? (
          <div className="py-8 text-center text-gray-500">Cargando dealers…</div>
        ) : (
          <div className="space-y-2">
            {/* Todos los dealers (sin filtro) */}
            <button
              type="button"
              onClick={() => handleSelect(null, orgName)}
              className="w-full flex items-center gap-3 px-4 py-3 rounded-lg border border-indigo-200 bg-indigo-50 hover:bg-indigo-100 text-left transition-colors"
            >
              <LayoutGrid className="w-5 h-5 text-indigo-500 flex-shrink-0" />
              <div>
                <span className="font-medium text-gray-900 block">Todos los dealers</span>
                <span className="text-xs text-gray-500">Ver toda la organización sin filtro</span>
              </div>
            </button>

            {dealers.length > 0 && (
              <div className="pt-2 pb-1">
                <span className="text-xs font-medium text-gray-400 uppercase tracking-wider">Dealers</span>
              </div>
            )}

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
          <p className="mt-4 text-sm text-gray-500">
            No hay dealers registrados en esta organización.
          </p>
        )}

        <button
          type="button"
          onClick={() => router.navigate('/dashboard', true)}
          className="mt-6 w-full text-sm text-gray-500 hover:text-gray-700 text-center"
        >
          Volver al dashboard
        </button>
      </div>
    </div>
  );
}

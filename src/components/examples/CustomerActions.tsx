// Ejemplo de uso: Acciones de Customer con permisos basados en roles
// Viewer solo puede ver, no editar
import { useCurrentOrgRole } from '../../hooks/useCurrentOrgRole';

interface CustomerActionsProps {
  organizationId: string;
  customerId: string;
  onEdit?: () => void;
  onView?: () => void;
}

export function CustomerActions({ organizationId, customerId, onEdit, onView }: CustomerActionsProps) {
  const { isMember, isAdmin, isOwner, isViewer, canEditCustomers, loading } = useCurrentOrgRole({ organizationId });

  // Viewer solo puede ver, no editar
  const canEdit = canEditCustomers && !isViewer;

  if (loading) {
    return (
      <div className="flex gap-2">
        <div className="px-3 py-1.5 bg-gray-100 rounded text-sm text-gray-400">Loading...</div>
      </div>
    );
  }

  return (
    <div className="flex gap-2">
      {canEdit && (
        <button
          className="px-3 py-1.5 border border-gray-300 rounded bg-white text-gray-700 hover:bg-gray-50 transition-colors text-sm"
          onClick={onEdit}
        >
          Editar Customer
        </button>
      )}

      {/* Botón de ver siempre permitido */}
      <button
        className="px-3 py-1.5 border border-gray-300 rounded bg-white text-gray-700 hover:bg-gray-50 transition-colors text-sm"
        onClick={onView}
      >
        Ver Detalle
      </button>

      {isViewer && (
        <span className="px-3 py-1.5 text-xs text-gray-500 italic">
          (Solo lectura)
        </span>
      )}
    </div>
  );
}

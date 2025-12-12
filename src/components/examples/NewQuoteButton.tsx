// Ejemplo de uso: Botón "Nueva Cotización" con permisos basados en roles
import { useCurrentOrgRole } from '../../hooks/useCurrentOrgRole';

interface NewQuoteButtonProps {
  organizationId: string;
  onClick?: () => void;
}

export function NewQuoteButton({ organizationId, onClick }: NewQuoteButtonProps) {
  const { canCreateQuotes, loading } = useCurrentOrgRole({ organizationId });

  if (loading) {
    return (
      <button
        className="px-4 py-2 rounded text-white transition-colors text-sm opacity-50 cursor-not-allowed"
        style={{ backgroundColor: 'var(--primary-brand-hex)' }}
        disabled
      >
        Loading...
      </button>
    );
  }

  return (
    <button
      className="px-4 py-2 rounded text-white transition-colors text-sm hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed"
      style={{ backgroundColor: 'var(--primary-brand-hex)' }}
      disabled={!canCreateQuotes}
      onClick={onClick}
      title={
        !canCreateQuotes
          ? 'No tienes permisos para crear cotizaciones'
          : undefined
      }
    >
      Nueva Cotización
    </button>
  );
}

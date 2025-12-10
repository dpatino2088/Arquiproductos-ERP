import { PageHeader } from '@/components/layout/page-header';
import { FilterBar } from '@/components/forms/filter-bar';
import { Card, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Table, THead, TH, TR, TBody, TD } from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';

const terms = [
  { name: 'Contado', days: 0, description: 'Pago inmediato' },
  { name: '30 días', days: 30, description: 'Crédito a 30 días' },
  { name: '50% anticipo', days: 30, description: 'Mitad anticipada, resto a 30 días' }
];

export default function PaymentTermsPage() {
  return (
    <div className="space-y-4">
      <PageHeader
        title="Configuración · Términos de pago"
        description="Parámetros de crédito para ventas y compras."
        actionLabel="Nuevo término"
      />
      <Card>
        <CardHeader className="items-start justify-between">
          <div>
            <CardTitle>Términos de pago</CardTitle>
            <CardDescription>Aplicables a órdenes de compra y facturas.</CardDescription>
          </div>
          <Badge tone="muted">days integer</Badge>
        </CardHeader>
        <div className="space-y-4">
          <FilterBar placeholder="Buscar término..." />
          <Table>
            <THead>
              <TR>
                <TH>Nombre</TH>
                <TH>Días</TH>
                <TH>Descripción</TH>
              </TR>
            </THead>
            <TBody>
              {terms.map((term) => (
                <TR key={term.name}>
                  <TD className="font-medium">{term.name}</TD>
                  <TD>{term.days}</TD>
                  <TD>{term.description}</TD>
                </TR>
              ))}
            </TBody>
          </Table>
        </div>
      </Card>
    </div>
  );
}


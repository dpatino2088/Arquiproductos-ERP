import { PageHeader } from '@/components/layout/page-header';
import { FilterBar } from '@/components/forms/filter-bar';
import { Card, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Table, THead, TH, TR, TBody, TD } from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';

const credits = [
  { ref: 'CR-01', customer: 'Grupo Andino', amount: 300, currency: 'USD', reason: 'Devolución', date: '2025-12-19' },
  { ref: 'CR-02', customer: 'Constructora Norte', amount: 150, currency: 'USD', reason: 'Descuento', date: '2025-12-22' }
];

export default function CreditsPage() {
  return (
    <div className="space-y-4">
      <PageHeader
        title="Finanzas · Notas de crédito"
        description="Notas aplicables a facturas o como saldo a favor."
        actionLabel="Nueva nota de crédito"
      />
      <Card>
        <CardHeader className="items-start justify-between">
          <div>
            <CardTitle>Notas de crédito</CardTitle>
            <CardDescription>Preparadas para aplicación parcial o total.</CardDescription>
          </div>
          <Badge tone="muted">currency + invoice_id opcional</Badge>
        </CardHeader>
        <div className="space-y-4">
          <FilterBar placeholder="Buscar crédito..." />
          <Table>
            <THead>
              <TR>
                <TH>Referencia</TH>
                <TH>Cliente</TH>
                <TH>Fecha</TH>
                <TH>Razón</TH>
                <TH>Monto</TH>
              </TR>
            </THead>
            <TBody>
              {credits.map((credit) => (
                <TR key={credit.ref}>
                  <TD className="font-medium">{credit.ref}</TD>
                  <TD>{credit.customer}</TD>
                  <TD>{credit.date}</TD>
                  <TD>{credit.reason}</TD>
                  <TD>
                    {credit.currency} ${credit.amount.toLocaleString()}
                  </TD>
                </TR>
              ))}
            </TBody>
          </Table>
        </div>
      </Card>
    </div>
  );
}


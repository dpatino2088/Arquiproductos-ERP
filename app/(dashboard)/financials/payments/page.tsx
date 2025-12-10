import { PageHeader } from '@/components/layout/page-header';
import { FilterBar } from '@/components/forms/filter-bar';
import { Card, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Table, THead, TH, TR, TBody, TD } from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';

const payments = [
  { ref: 'PMT-01', customer: 'Grupo Andino', amount: 1200, currency: 'USD', method: 'Transferencia', date: '2025-12-18' },
  { ref: 'PMT-02', customer: 'Constructora Norte', amount: 850, currency: 'USD', method: 'Tarjeta', date: '2025-12-20' }
];

export default function PaymentsPage() {
  return (
    <div className="space-y-4">
      <PageHeader
        title="Finanzas · Pagos"
        description="Pagos aplicados a facturas o anticipos."
        actionLabel="Registrar pago"
      />
      <Card>
        <CardHeader className="items-start justify-between">
          <div>
            <CardTitle>Pagos</CardTitle>
            <CardDescription>Preparado para conciliación con facturas y créditos.</CardDescription>
          </div>
          <Badge tone="muted">customer_id + invoice_id</Badge>
        </CardHeader>
        <div className="space-y-4">
          <FilterBar placeholder="Buscar pago..." />
          <Table>
            <THead>
              <TR>
                <TH>Referencia</TH>
                <TH>Cliente</TH>
                <TH>Fecha</TH>
                <TH>Método</TH>
                <TH>Monto</TH>
              </TR>
            </THead>
            <TBody>
              {payments.map((payment) => (
                <TR key={payment.ref}>
                  <TD className="font-medium">{payment.ref}</TD>
                  <TD>{payment.customer}</TD>
                  <TD>{payment.date}</TD>
                  <TD>{payment.method}</TD>
                  <TD>
                    {payment.currency} ${payment.amount.toLocaleString()}
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


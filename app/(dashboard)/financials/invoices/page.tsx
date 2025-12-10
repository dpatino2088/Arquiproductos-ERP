import { PageHeader } from '@/components/layout/page-header';
import { FilterBar } from '@/components/forms/filter-bar';
import { Card, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Table, THead, TH, TR, TBody, TD } from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';

const invoices = [
  { invoice: 'INV-1001', customer: 'Grupo Andino', status: 'BORRADOR', total: 2450, currency: 'USD', due: '2026-01-15' },
  { invoice: 'INV-1002', customer: 'Constructora Norte', status: 'ENVIADA', total: 3890, currency: 'USD', due: '2026-01-25' }
];

export default function InvoicesPage() {
  return (
    <div className="space-y-4">
      <PageHeader
        title="Finanzas · Facturas"
        description="Esqueleto de facturación con líneas libres o ligadas a catálogo."
        actionLabel="Nueva factura"
      />
      <Card>
        <CardHeader className="items-start justify-between">
          <div>
            <CardTitle>Facturas</CardTitle>
            <CardDescription>Estados: borrador, enviada, parcialmente pagada, pagada.</CardDescription>
          </div>
          <Button size="sm" variant="outline">
            Sincronizar pagos
          </Button>
        </CardHeader>
        <div className="space-y-4">
          <FilterBar placeholder="Buscar factura..." statusOptions={['BORRADOR', 'ENVIADA', 'PAGADA']} />
          <Table>
            <THead>
              <TR>
                <TH>Factura</TH>
                <TH>Cliente</TH>
                <TH>Estado</TH>
                <TH>Vence</TH>
                <TH>Total</TH>
              </TR>
            </THead>
            <TBody>
              {invoices.map((invoice) => (
                <TR key={invoice.invoice}>
                  <TD className="font-medium">{invoice.invoice}</TD>
                  <TD>{invoice.customer}</TD>
                  <TD>
                    <Badge tone={invoice.status === 'PAGADA' ? 'success' : 'muted'}>
                      {invoice.status}
                    </Badge>
                  </TD>
                  <TD>{invoice.due}</TD>
                  <TD>
                    {invoice.currency} ${invoice.total.toLocaleString()}
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


import { PageHeader } from '@/components/layout/page-header';
import { FilterBar } from '@/components/forms/filter-bar';
import { Card, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Table, THead, TH, TR, TBody, TD } from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';

const receipts = [
  { receipt: 'RC-0001', po: 'PO-0001', warehouse: 'WH-BOG', date: '2025-12-12', status: 'Parcial' },
  { receipt: 'RC-0002', po: 'PO-0002', warehouse: 'WH-MDE', date: '2025-12-14', status: 'Completo' }
];

export default function ReceiptsPage() {
  return (
    <div className="space-y-4">
      <PageHeader
        title="Inventario · Recepciones"
        description="Recepción de compras contra almacenes con soporte de cantidades parciales."
        actionLabel="Nueva recepción"
      />
      <Card>
        <CardHeader className="items-start justify-between">
          <div>
            <CardTitle>Recepciones</CardTitle>
            <CardDescription>Conecta con órdenes de compra y genera transacciones de ingreso.</CardDescription>
          </div>
          <Badge tone="muted">transaction_type = RECEIPT</Badge>
        </CardHeader>
        <div className="space-y-4">
          <FilterBar placeholder="Buscar recepción..." />
          <Table>
            <THead>
              <TR>
                <TH>Recepción</TH>
                <TH>OC</TH>
                <TH>Almacén</TH>
                <TH>Fecha</TH>
                <TH>Estado</TH>
              </TR>
            </THead>
            <TBody>
              {receipts.map((receipt) => (
                <TR key={receipt.receipt}>
                  <TD className="font-medium">{receipt.receipt}</TD>
                  <TD>{receipt.po}</TD>
                  <TD>{receipt.warehouse}</TD>
                  <TD>{receipt.date}</TD>
                  <TD>
                    <Badge tone={receipt.status === 'Completo' ? 'success' : 'warning'}>
                      {receipt.status}
                    </Badge>
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


import { PageHeader } from '@/components/layout/page-header';
import { FilterBar } from '@/components/forms/filter-bar';
import { Card, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Table, THead, TH, TR, TBody, TD } from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';

const transactions = [
  { ref: 'TRX-1001', type: 'RECEIPT', item: 'Perfil aluminio', qty: 120, uom: 'UN', warehouse: 'WH-BOG' },
  { ref: 'TRX-1002', type: 'ADJUSTMENT', item: 'Tela blackout', qty: -5, uom: 'M2', warehouse: 'WH-MDE' },
  { ref: 'TRX-1003', type: 'TRANSFER', item: 'Perfil aluminio', qty: -20, uom: 'UN', warehouse: 'WH-BOG → WH-MDE' }
];

export default function TransactionsPage() {
  return (
    <div className="space-y-4">
      <PageHeader
        title="Inventario · Transacciones"
        description="Bitácora de movimientos con cantidades positivas y negativas."
        actionLabel="Registrar movimiento"
      />
      <Card>
        <CardHeader className="items-start justify-between">
          <div>
            <CardTitle>Movimientos de inventario</CardTitle>
            <CardDescription>Tipos soportados: RECEIPT, ADJUSTMENT, TRANSFER, ISSUE.</CardDescription>
          </div>
          <Badge tone="muted">company_id + warehouse_id</Badge>
        </CardHeader>
        <div className="space-y-4">
          <FilterBar placeholder="Buscar movimiento..." statusOptions={['RECEIPT', 'ADJUSTMENT', 'TRANSFER', 'ISSUE']} />
          <Table>
            <THead>
              <TR>
                <TH>Referencia</TH>
                <TH>Tipo</TH>
                <TH>Item</TH>
                <TH>Cant.</TH>
                <TH>UOM</TH>
                <TH>Almacén</TH>
              </TR>
            </THead>
            <TBody>
              {transactions.map((trx) => (
                <TR key={trx.ref}>
                  <TD className="font-medium">{trx.ref}</TD>
                  <TD>
                    <Badge tone="muted">{trx.type}</Badge>
                  </TD>
                  <TD>{trx.item}</TD>
                  <TD className={trx.qty < 0 ? 'text-destructive' : ''}>{trx.qty}</TD>
                  <TD>{trx.uom}</TD>
                  <TD>{trx.warehouse}</TD>
                </TR>
              ))}
            </TBody>
          </Table>
        </div>
      </Card>
    </div>
  );
}


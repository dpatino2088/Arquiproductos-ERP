import { PageHeader } from '@/components/layout/page-header';
import { FilterBar } from '@/components/forms/filter-bar';
import { Card, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Table, THead, TH, TR, TBody, TD } from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';

const adjustments = [
  { ref: 'ADJ-01', warehouse: 'WH-BOG', reason: 'Conteo cíclico', qty: -3, uom: 'UN' },
  { ref: 'ADJ-02', warehouse: 'WH-MDE', reason: 'Daño', qty: -1, uom: 'M2' }
];

export default function AdjustmentsPage() {
  return (
    <div className="space-y-4">
      <PageHeader
        title="Inventario · Ajustes"
        description="Ajustes manuales con trazabilidad para auditoría."
        actionLabel="Nuevo ajuste"
      />
      <Card>
        <CardHeader className="items-start justify-between">
          <div>
            <CardTitle>Ajustes</CardTitle>
            <CardDescription>Generan transacciones de tipo ADJUSTMENT.</CardDescription>
          </div>
          <Badge tone="muted">Auditable</Badge>
        </CardHeader>
        <div className="space-y-4">
          <FilterBar placeholder="Buscar ajuste..." />
          <Table>
            <THead>
              <TR>
                <TH>Referencia</TH>
                <TH>Almacén</TH>
                <TH>Razón</TH>
                <TH>Cant.</TH>
                <TH>UOM</TH>
              </TR>
            </THead>
            <TBody>
              {adjustments.map((adj) => (
                <TR key={adj.ref}>
                  <TD className="font-medium">{adj.ref}</TD>
                  <TD>{adj.warehouse}</TD>
                  <TD>{adj.reason}</TD>
                  <TD className="text-destructive">{adj.qty}</TD>
                  <TD>{adj.uom}</TD>
                </TR>
              ))}
            </TBody>
          </Table>
        </div>
      </Card>
    </div>
  );
}


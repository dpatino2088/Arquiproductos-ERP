import { PageHeader } from '@/components/layout/page-header';
import { FilterBar } from '@/components/forms/filter-bar';
import { Card, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Table, THead, TH, TR, TBody, TD } from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';

const purchaseOrders = [
  { po: 'PO-0001', vendor: 'Proveedor Industrial', status: 'APROBADA', expected: '2025-12-20' },
  { po: 'PO-0002', vendor: 'Suministros del Norte', status: 'BORRADOR', expected: '2025-12-28' }
];

const lines = [
  { po: 'PO-0001', sku: 'SK-100', name: 'Perfil aluminio', qty: 120, uom: 'UN', cost: 8.5 },
  { po: 'PO-0001', sku: 'SK-220', name: 'Tela blackout', qty: 60, uom: 'M2', cost: 12.4 }
];

export default function PurchaseOrdersPage() {
  return (
    <div className="space-y-4">
      <PageHeader
        title="Inventario · Órdenes de compra"
        description="Flujo de abastecimiento listo para conectar a catálogos o descripciones libres."
        actionLabel="Nueva orden de compra"
      />
      <Card>
        <CardHeader className="items-start justify-between">
          <div>
            <CardTitle>Órdenes</CardTitle>
            <CardDescription>Estados soportados: borrador, aprobada, recibida, cerrada.</CardDescription>
          </div>
          <Badge tone="muted">catalog_item_id opcional</Badge>
        </CardHeader>
        <div className="space-y-4">
          <FilterBar placeholder="Buscar OC..." statusOptions={['BORRADOR', 'APROBADA']} />
          <Table>
            <THead>
              <TR>
                <TH>PO</TH>
                <TH>Proveedor</TH>
                <TH>Estado</TH>
                <TH>Entrega esperada</TH>
              </TR>
            </THead>
            <TBody>
              {purchaseOrders.map((po) => (
                <TR key={po.po}>
                  <TD className="font-medium">{po.po}</TD>
                  <TD>{po.vendor}</TD>
                  <TD>
                    <Badge tone={po.status === 'APROBADA' ? 'success' : 'muted'}>{po.status}</Badge>
                  </TD>
                  <TD>{po.expected}</TD>
                </TR>
              ))}
            </TBody>
          </Table>
        </div>
      </Card>

      <Card>
        <CardHeader className="items-start justify-between">
          <div>
            <CardTitle>Líneas (detalle)</CardTitle>
            <CardDescription>Listo para interfaz de edición rápida de líneas.</CardDescription>
          </div>
          <Button size="sm" variant="outline">
            Editar líneas
          </Button>
        </CardHeader>
        <Table>
          <THead>
            <TR>
              <TH>PO</TH>
              <TH>SKU / Item</TH>
              <TH>Descripción</TH>
              <TH>Cantidad</TH>
              <TH>UOM</TH>
              <TH>Costo</TH>
            </TR>
          </THead>
          <TBody>
            {lines.map((line) => (
              <TR key={`${line.po}-${line.sku}`}>
                <TD>{line.po}</TD>
                <TD className="font-medium">{line.sku}</TD>
                <TD>{line.name}</TD>
                <TD>{line.qty}</TD>
                <TD>{line.uom}</TD>
                <TD>${line.cost.toFixed(2)}</TD>
              </TR>
            ))}
          </TBody>
        </Table>
      </Card>
    </div>
  );
}


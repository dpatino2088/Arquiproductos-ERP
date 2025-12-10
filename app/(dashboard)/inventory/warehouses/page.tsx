import { PageHeader } from '@/components/layout/page-header';
import { FilterBar } from '@/components/forms/filter-bar';
import { Card, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Table, THead, TH, TR, TBody, TD } from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';

const warehouses = [
  { name: 'Principal Bogotá', code: 'WH-BOG', location: 'Zona Industrial', status: 'Activo' },
  { name: 'Centro Medellín', code: 'WH-MDE', location: 'Itagüí', status: 'Activo' }
];

export default function WarehousesPage() {
  return (
    <div className="space-y-4">
      <PageHeader
        title="Inventario · Almacenes"
        description="Definición de almacenes físicos o lógicos para recepciones y movimientos."
        actionLabel="Nuevo almacén"
      />
      <Card>
        <CardHeader className="items-start justify-between">
          <div>
            <CardTitle>Listado de almacenes</CardTitle>
            <CardDescription>Base para transacciones y existencias.</CardDescription>
          </div>
          <Button variant="ghost" size="sm">
            Exportar
          </Button>
        </CardHeader>
        <div className="space-y-4">
          <FilterBar placeholder="Buscar almacén..." />
          <Table>
            <THead>
              <TR>
                <TH>Nombre</TH>
                <TH>Código</TH>
                <TH>Ubicación</TH>
                <TH>Estado</TH>
              </TR>
            </THead>
            <TBody>
              {warehouses.map((warehouse) => (
                <TR key={warehouse.code}>
                  <TD className="font-medium">{warehouse.name}</TD>
                  <TD>{warehouse.code}</TD>
                  <TD>{warehouse.location}</TD>
                  <TD>
                    <Badge tone="success">{warehouse.status}</Badge>
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


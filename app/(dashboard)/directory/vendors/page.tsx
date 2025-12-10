import { PageHeader } from '@/components/layout/page-header';
import { FilterBar } from '@/components/forms/filter-bar';
import { Card, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Table, THead, TH, TR, TBody, TD } from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';

const vendors = [
  { name: 'Proveedor Industrial', code: 'PRV-001', email: 'ventas@industrial.com', phone: '+57 300 123 4567' },
  { name: 'Suministros del Norte', code: 'PRV-002', email: 'soporte@norte.com', phone: '+57 302 987 6543' }
];

export default function VendorsPage() {
  return (
    <div className="space-y-4">
      <PageHeader
        title="Directorio · Proveedores"
        description="Administra proveedores para órdenes de compra y abastecimiento."
        actionLabel="Nuevo proveedor"
      />
      <Card>
        <CardHeader className="items-start justify-between">
          <div>
            <CardTitle>Listado de proveedores</CardTitle>
            <CardDescription>Relación directa con órdenes de compra e inventario.</CardDescription>
          </div>
          <Badge tone="muted">RLS pendiente</Badge>
        </CardHeader>
        <div className="space-y-4">
          <FilterBar placeholder="Buscar proveedor..." />
          <Table>
            <THead>
              <TR>
                <TH>Nombre</TH>
                <TH>Código</TH>
                <TH>Correo</TH>
                <TH>Teléfono</TH>
              </TR>
            </THead>
            <TBody>
              {vendors.map((vendor) => (
                <TR key={vendor.code}>
                  <TD className="font-medium">{vendor.name}</TD>
                  <TD>{vendor.code}</TD>
                  <TD>{vendor.email}</TD>
                  <TD>{vendor.phone}</TD>
                </TR>
              ))}
            </TBody>
          </Table>
        </div>
      </Card>
    </div>
  );
}


import { PageHeader } from '@/components/layout/page-header';
import { FilterBar } from '@/components/forms/filter-bar';
import { Card, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Table, THead, TH, TR, TBody, TD } from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';

const sites = [
  { name: 'Proyecto Torre Norte', linkedTo: 'Cliente · Grupo Andino', city: 'Bogotá', country: 'Colombia' },
  { name: 'Planta Bodega 12', linkedTo: 'Proveedor · Industrial', city: 'Medellín', country: 'Colombia' }
];

export default function SitesPage() {
  return (
    <div className="space-y-4">
      <PageHeader
        title="Directorio · Sitios"
        description="Sitios vinculados a clientes, proveedores o contratistas."
        actionLabel="Nuevo sitio"
      />
      <Card>
        <CardHeader className="items-start justify-between">
          <div>
            <CardTitle>Listado de sitios</CardTitle>
            <CardDescription>Diseñado para referencia cruzada con contactos e inventario.</CardDescription>
          </div>
          <Badge tone="muted">customer/vendor/contractor</Badge>
        </CardHeader>
        <div className="space-y-4">
          <FilterBar placeholder="Buscar sitio..." />
          <Table>
            <THead>
              <TR>
                <TH>Nombre</TH>
                <TH>Vinculado a</TH>
                <TH>Ciudad</TH>
                <TH>País</TH>
              </TR>
            </THead>
            <TBody>
              {sites.map((site) => (
                <TR key={site.name}>
                  <TD className="font-medium">{site.name}</TD>
                  <TD>{site.linkedTo}</TD>
                  <TD>{site.city}</TD>
                  <TD>{site.country}</TD>
                </TR>
              ))}
            </TBody>
          </Table>
        </div>
      </Card>
    </div>
  );
}


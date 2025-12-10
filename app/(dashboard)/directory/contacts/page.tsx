import { PageHeader } from '@/components/layout/page-header';
import { FilterBar } from '@/components/forms/filter-bar';
import { Card, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Table, THead, TH, TR, TBody, TD } from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';

const contacts = [
  { name: 'María Rodríguez', relation: 'Cliente · Grupo Andino', email: 'maria@andino.com', phone: '+57 300 888 0000' },
  { name: 'Juan Torres', relation: 'Proveedor · Industrial', email: 'juan@industrial.com', phone: '+57 300 999 1111' }
];

export default function ContactsPage() {
  return (
    <div className="space-y-4">
      <PageHeader
        title="Directorio · Contactos"
        description="Contactos vinculados a clientes, proveedores, contratistas o sitios."
        actionLabel="Nuevo contacto"
      />
      <Card>
        <CardHeader className="items-start justify-between">
          <div>
            <CardTitle>Listado de contactos</CardTitle>
            <CardDescription>Base para fichas detalladas y comunicaciones.</CardDescription>
          </div>
          <Badge tone="muted">Relaciones múltiples</Badge>
        </CardHeader>
        <div className="space-y-4">
          <FilterBar placeholder="Buscar contacto..." />
          <Table>
            <THead>
              <TR>
                <TH>Nombre</TH>
                <TH>Relación</TH>
                <TH>Correo</TH>
                <TH>Teléfono</TH>
              </TR>
            </THead>
            <TBody>
              {contacts.map((contact) => (
                <TR key={contact.email}>
                  <TD className="font-medium">{contact.name}</TD>
                  <TD>{contact.relation}</TD>
                  <TD>{contact.email}</TD>
                  <TD>{contact.phone}</TD>
                </TR>
              ))}
            </TBody>
          </Table>
        </div>
      </Card>
    </div>
  );
}


import { PageHeader } from '@/components/layout/page-header';
import { FilterBar } from '@/components/forms/filter-bar';
import { Card, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Table, THead, TH, TR, TBody, TD } from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';

const customers = [
  { name: 'Grupo Andino', code: 'CLI-001', email: 'compras@andino.com', phone: '+57 310 000 000' },
  { name: 'Constructora Norte', code: 'CLI-002', email: 'contacto@norte.com', phone: '+57 311 222 222' }
];

export default function CustomersPage() {
  return (
    <div className="space-y-4">
      <PageHeader
        title="Directorio · Clientes"
        description="Gestiona clientes, sitios y contactos vinculados a cada compañía."
        actionLabel="Nuevo cliente"
      />
      <Card>
        <CardHeader className="items-start justify-between">
          <div>
            <CardTitle>Listado de clientes</CardTitle>
            <CardDescription>Filtros, búsqueda y paginación listos para conectar a Supabase.</CardDescription>
          </div>
          <Badge tone="muted">company_id scoped</Badge>
        </CardHeader>
        <div className="space-y-4">
          <FilterBar placeholder="Buscar cliente..." />
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
              {customers.map((customer) => (
                <TR key={customer.code}>
                  <TD className="font-medium">{customer.name}</TD>
                  <TD>{customer.code}</TD>
                  <TD>{customer.email}</TD>
                  <TD>{customer.phone}</TD>
                </TR>
              ))}
            </TBody>
          </Table>
        </div>
      </Card>
    </div>
  );
}


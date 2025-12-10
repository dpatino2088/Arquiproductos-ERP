import { PageHeader } from '@/components/layout/page-header';
import { FilterBar } from '@/components/forms/filter-bar';
import { Card, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Table, THead, TH, TR, TBody, TD } from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';

const contractors = [
  { name: 'Montajes del Sur', code: 'CNT-001', email: 'operaciones@sur.com', phone: '+57 300 555 1111' },
  { name: 'Servicios Técnicos', code: 'CNT-002', email: 'info@servtecnicos.com', phone: '+57 301 444 2222' }
];

export default function ContractorsPage() {
  return (
    <div className="space-y-4">
      <PageHeader
        title="Directorio · Contratistas"
        description="Contratistas vinculados a proyectos y sitios."
        actionLabel="Nuevo contratista"
      />
      <Card>
        <CardHeader className="items-start justify-between">
          <div>
            <CardTitle>Listado de contratistas</CardTitle>
            <CardDescription>Preparado para relacionar con sitios y contactos.</CardDescription>
          </div>
          <Badge tone="muted">Scope multiempresa</Badge>
        </CardHeader>
        <div className="space-y-4">
          <FilterBar placeholder="Buscar contratista..." />
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
              {contractors.map((contractor) => (
                <TR key={contractor.code}>
                  <TD className="font-medium">{contractor.name}</TD>
                  <TD>{contractor.code}</TD>
                  <TD>{contractor.email}</TD>
                  <TD>{contractor.phone}</TD>
                </TR>
              ))}
            </TBody>
          </Table>
        </div>
      </Card>
    </div>
  );
}


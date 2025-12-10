import { PageHeader } from '@/components/layout/page-header';
import { FilterBar } from '@/components/forms/filter-bar';
import { Card, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Table, THead, TH, TR, TBody, TD } from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';

const employees = [
  { name: 'Laura Gómez', role: 'Gerente de proyectos', email: 'laura@arquiproductos.com', phone: '+57 310 123 4567' },
  { name: 'Carlos Pérez', role: 'Coordinador logístico', email: 'carlos@arquiproductos.com', phone: '+57 313 765 4321' }
];

export default function EmployeesPage() {
  return (
    <div className="space-y-4">
      <PageHeader
        title="Directorio · Empleados"
        description="Perfiles internos relacionados con auth.users y roles."
        actionLabel="Nuevo empleado"
      />
      <Card>
        <CardHeader className="items-start justify-between">
          <div>
            <CardTitle>Listado de empleados</CardTitle>
            <CardDescription>Conecta con UserProfiles y roles para RLS.</CardDescription>
          </div>
          <Badge tone="muted">UserProfiles</Badge>
        </CardHeader>
        <div className="space-y-4">
          <FilterBar placeholder="Buscar empleado..." />
          <Table>
            <THead>
              <TR>
                <TH>Nombre</TH>
                <TH>Rol</TH>
                <TH>Correo</TH>
                <TH>Teléfono</TH>
              </TR>
            </THead>
            <TBody>
              {employees.map((employee) => (
                <TR key={employee.email}>
                  <TD className="font-medium">{employee.name}</TD>
                  <TD>{employee.role}</TD>
                  <TD>{employee.email}</TD>
                  <TD>{employee.phone}</TD>
                </TR>
              ))}
            </TBody>
          </Table>
        </div>
      </Card>
    </div>
  );
}


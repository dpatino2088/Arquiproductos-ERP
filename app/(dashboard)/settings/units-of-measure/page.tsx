import { PageHeader } from '@/components/layout/page-header';
import { FilterBar } from '@/components/forms/filter-bar';
import { Card, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Table, THead, TH, TR, TBody, TD } from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';

const uoms = [
  { name: 'Unidad', abbr: 'UN' },
  { name: 'Metro cuadrado', abbr: 'M2' },
  { name: 'Metro lineal', abbr: 'ML' }
];

export default function UnitsOfMeasurePage() {
  return (
    <div className="space-y-4">
      <PageHeader
        title="Configuración · Unidades de medida"
        description="Unidades estándar para inventario y facturación."
        actionLabel="Nueva unidad"
      />
      <Card>
        <CardHeader className="items-start justify-between">
          <div>
            <CardTitle>Unidades</CardTitle>
            <CardDescription>Compatibles con transacciones y líneas financieras.</CardDescription>
          </div>
          <Badge tone="muted">abbreviation requerido</Badge>
        </CardHeader>
        <div className="space-y-4">
          <FilterBar placeholder="Buscar unidad..." />
          <Table>
            <THead>
              <TR>
                <TH>Nombre</TH>
                <TH>Abreviatura</TH>
              </TR>
            </THead>
            <TBody>
              {uoms.map((uom) => (
                <TR key={uom.abbr}>
                  <TD className="font-medium">{uom.name}</TD>
                  <TD>{uom.abbr}</TD>
                </TR>
              ))}
            </TBody>
          </Table>
        </div>
      </Card>
    </div>
  );
}


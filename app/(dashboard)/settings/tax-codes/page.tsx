import { PageHeader } from '@/components/layout/page-header';
import { FilterBar } from '@/components/forms/filter-bar';
import { Card, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Table, THead, TH, TR, TBody, TD } from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';

const taxes = [
  { name: 'IVA 19%', rate: 0.19 },
  { name: 'IVA 5%', rate: 0.05 },
  { name: 'Exento', rate: 0 }
];

export default function TaxCodesPage() {
  return (
    <div className="space-y-4">
      <PageHeader
        title="Configuración · Impuestos"
        description="Códigos de impuesto reutilizables en líneas de compra y venta."
        actionLabel="Nuevo código"
      />
      <Card>
        <CardHeader className="items-start justify-between">
          <div>
            <CardTitle>Códigos de impuesto</CardTitle>
            <CardDescription>Definición de tasas estandarizadas.</CardDescription>
          </div>
          <Badge tone="muted">rate numeric</Badge>
        </CardHeader>
        <div className="space-y-4">
          <FilterBar placeholder="Buscar impuesto..." />
          <Table>
            <THead>
              <TR>
                <TH>Nombre</TH>
                <TH>Tasa</TH>
              </TR>
            </THead>
            <TBody>
              {taxes.map((tax) => (
                <TR key={tax.name}>
                  <TD className="font-medium">{tax.name}</TD>
                  <TD>{(tax.rate * 100).toFixed(2)}%</TD>
                </TR>
              ))}
            </TBody>
          </Table>
        </div>
      </Card>
    </div>
  );
}


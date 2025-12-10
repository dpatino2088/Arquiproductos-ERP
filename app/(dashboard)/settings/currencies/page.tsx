import { PageHeader } from '@/components/layout/page-header';
import { FilterBar } from '@/components/forms/filter-bar';
import { Card, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Table, THead, TH, TR, TBody, TD } from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';

const currencies = [
  { code: 'USD', name: 'Dólar estadounidense', symbol: '$' },
  { code: 'COP', name: 'Peso colombiano', symbol: '$' },
  { code: 'EUR', name: 'Euro', symbol: '€' }
];

export default function CurrenciesPage() {
  return (
    <div className="space-y-4">
      <PageHeader
        title="Configuración · Monedas"
        description="Soporte multimoneda para ventas y compras."
        actionLabel="Nueva moneda"
      />
      <Card>
        <CardHeader className="items-start justify-between">
          <div>
            <CardTitle>Monedas</CardTitle>
            <CardDescription>Diseñadas para convivir con catálogos y facturación.</CardDescription>
          </div>
          <Badge tone="muted">code + symbol</Badge>
        </CardHeader>
        <div className="space-y-4">
          <FilterBar placeholder="Buscar moneda..." />
          <Table>
            <THead>
              <TR>
                <TH>Código</TH>
                <TH>Nombre</TH>
                <TH>Símbolo</TH>
              </TR>
            </THead>
            <TBody>
              {currencies.map((currency) => (
                <TR key={currency.code}>
                  <TD className="font-medium">{currency.code}</TD>
                  <TD>{currency.name}</TD>
                  <TD>{currency.symbol}</TD>
                </TR>
              ))}
            </TBody>
          </Table>
        </div>
      </Card>
    </div>
  );
}


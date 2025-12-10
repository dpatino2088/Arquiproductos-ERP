import { PageHeader } from '@/components/layout/page-header';
import { FilterBar } from '@/components/forms/filter-bar';
import { Card, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Table, THead, TH, TR, TBody, TD } from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';

const categories = [
  { name: 'Telas', code: 'CAT-TE', items: 34 },
  { name: 'Herrajes', code: 'CAT-HE', items: 18 }
];

export default function ItemCategoriesPage() {
  return (
    <div className="space-y-4">
      <PageHeader
        title="Configuración · Categorías"
        description="Catálogo maestro para clasificar productos o ítems libres."
        actionLabel="Nueva categoría"
      />
      <Card>
        <CardHeader className="items-start justify-between">
          <div>
            <CardTitle>Categorías</CardTitle>
            <CardDescription>Utilizadas por subcategorías y líneas de inventario.</CardDescription>
          </div>
          <Badge tone="muted">company_id</Badge>
        </CardHeader>
        <div className="space-y-4">
          <FilterBar placeholder="Buscar categoría..." />
          <Table>
            <THead>
              <TR>
                <TH>Nombre</TH>
                <TH>Código</TH>
                <TH># Ítems</TH>
              </TR>
            </THead>
            <TBody>
              {categories.map((cat) => (
                <TR key={cat.code}>
                  <TD className="font-medium">{cat.name}</TD>
                  <TD>{cat.code}</TD>
                  <TD>{cat.items}</TD>
                </TR>
              ))}
            </TBody>
          </Table>
        </div>
      </Card>
    </div>
  );
}


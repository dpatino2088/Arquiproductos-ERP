import { PageHeader } from '@/components/layout/page-header';
import { FilterBar } from '@/components/forms/filter-bar';
import { Card, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Table, THead, TH, TR, TBody, TD } from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';

const subcategories = [
  { name: 'Blackout', category: 'Telas', code: 'SUB-BL', items: 12 },
  { name: 'Traslúcida', category: 'Telas', code: 'SUB-TR', items: 10 },
  { name: 'Accesorios', category: 'Herrajes', code: 'SUB-AC', items: 6 }
];

export default function ItemSubcategoriesPage() {
  return (
    <div className="space-y-4">
      <PageHeader
        title="Configuración · Subcategorías"
        description="Jerarquía de catálogos para productos configurables."
        actionLabel="Nueva subcategoría"
      />
      <Card>
        <CardHeader className="items-start justify-between">
          <div>
            <CardTitle>Subcategorías</CardTitle>
            <CardDescription>Asociadas a categorías y listas para catálogo futuro.</CardDescription>
          </div>
          <Badge tone="muted">FK → SettingsItemCategories</Badge>
        </CardHeader>
        <div className="space-y-4">
          <FilterBar placeholder="Buscar subcategoría..." />
          <Table>
            <THead>
              <TR>
                <TH>Nombre</TH>
                <TH>Categoría</TH>
                <TH>Código</TH>
                <TH># Ítems</TH>
              </TR>
            </THead>
            <TBody>
              {subcategories.map((sub) => (
                <TR key={sub.code}>
                  <TD className="font-medium">{sub.name}</TD>
                  <TD>{sub.category}</TD>
                  <TD>{sub.code}</TD>
                  <TD>{sub.items}</TD>
                </TR>
              ))}
            </TBody>
          </Table>
        </div>
      </Card>
    </div>
  );
}


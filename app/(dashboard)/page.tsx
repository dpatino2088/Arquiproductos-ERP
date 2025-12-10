import { Card, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Table, TBody, TD, TH, THead, TR } from '@/components/ui/table';

const summaries = [
  { title: 'Directorio', value: 'Clientes, proveedores y contactos', badge: 'Core' },
  { title: 'Inventario', value: 'Almacenes y órdenes de compra', badge: 'Core' },
  { title: 'Finanzas', value: 'Facturas, pagos y notas de crédito', badge: 'Core' },
  { title: 'Configuración', value: 'Catálogos y parámetros maestros', badge: 'Core' }
];

const timeline = [
  { label: 'Catálogo de productos', status: 'Pendiente' },
  { label: 'Módulo de ventas', status: 'Pendiente' },
  { label: 'Manufactura', status: 'Pendiente' }
];

export default function DashboardHome() {
  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <div>
          <p className="text-xs uppercase tracking-[0.25em] text-muted-foreground">Arquiproductos</p>
          <h1 className="text-2xl font-semibold text-foreground">Panel general</h1>
          <p className="text-sm text-muted-foreground">
            Núcleo, Directorio, Inventario, Finanzas y Configuración listos para extender.
          </p>
        </div>
        <Button variant="primary">Crear registro rápido</Button>
      </div>

      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        {summaries.map((item) => (
          <Card key={item.title}>
            <CardHeader className="flex-col items-start gap-2">
              <Badge tone="muted">{item.badge}</Badge>
              <CardTitle>{item.title}</CardTitle>
              <CardDescription>{item.value}</CardDescription>
            </CardHeader>
          </Card>
        ))}
      </div>

      <Card>
        <CardHeader className="items-start justify-between">
          <div>
            <CardTitle>Línea de tiempo</CardTitle>
            <CardDescription>Módulos futuros para incorporar (no implementar aún)</CardDescription>
          </div>
          <Badge>Roadmap</Badge>
        </CardHeader>
        <Table>
          <THead>
            <TR>
              <TH>Módulo</TH>
              <TH>Estado</TH>
            </TR>
          </THead>
          <TBody>
            {timeline.map((item) => (
              <TR key={item.label}>
                <TD>{item.label}</TD>
                <TD>
                  <Badge tone="muted">{item.status}</Badge>
                </TD>
              </TR>
            ))}
          </TBody>
        </Table>
      </Card>
    </div>
  );
}


import Link from 'next/link';
import { Suspense } from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';

export default function LoginPage() {
  return (
    <div className="min-h-screen bg-gradient-to-br from-muted to-background flex items-center justify-center px-4">
      <div className="surface w-full max-w-md p-8">
        <div className="mb-6 text-center">
          <p className="text-xs uppercase tracking-[0.2em] text-muted-foreground">Arquiproductos</p>
          <h1 className="mt-2 text-2xl font-semibold text-foreground">Ingreso al ERP</h1>
          <p className="text-sm text-muted-foreground">Accede con tu correo corporativo</p>
        </div>
        <Suspense fallback={<div>Cargando...</div>}>
          <LoginForm />
        </Suspense>
        <p className="mt-6 text-center text-xs text-muted-foreground">
          ¿Necesitas ayuda?{' '}
          <Link href="#" className="text-primary hover:underline">
            Contacta al administrador
          </Link>
        </p>
      </div>
    </div>
  );
}

function LoginForm() {
  return (
    <form className="space-y-4" action="/api/auth/login" method="post">
      <div className="space-y-2">
        <Label htmlFor="email">Correo electrónico</Label>
        <Input id="email" name="email" type="email" required />
      </div>
      <div className="space-y-2">
        <Label htmlFor="password">Contraseña</Label>
        <Input id="password" name="password" type="password" required />
      </div>
      <Button type="submit" className="w-full">
        Entrar
      </Button>
    </form>
  );
}


import { User } from '@supabase/supabase-js';
import { signOut } from '@/lib/auth';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';

interface TopbarProps {
  user?: User | null;
}

export function Topbar({ user }: TopbarProps) {
  return (
    <header className="glass sticky top-4 z-10 flex h-16 items-center justify-between rounded-2xl px-4">
      <div className="flex items-center gap-3 w-1/2">
        <div className="relative w-full">
          <Input placeholder="Buscar en todo el ERP" className="pl-4" />
        </div>
      </div>
      <div className="flex items-center gap-3">
        <div className="text-right">
          <p className="text-sm font-medium text-foreground">
            {user?.email ?? 'Usuario invitado'}
          </p>
          <p className="text-xs text-muted-foreground">{user ? 'Conectado' : 'Autenticación'}</p>
        </div>
        <form action={signOut}>
          <Button variant="ghost" size="sm" type="submit">
            Cerrar sesión
          </Button>
        </form>
      </div>
    </header>
  );
}


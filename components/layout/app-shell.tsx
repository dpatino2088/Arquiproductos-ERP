import { ReactNode } from 'react';
import { User } from '@supabase/supabase-js';
import { Sidebar } from './sidebar';
import { Topbar } from './topbar';

interface AppShellProps {
  children: ReactNode;
  user?: User | null;
}

export function AppShell({ children, user }: AppShellProps) {
  return (
    <div className="min-h-screen bg-muted/60">
      <div className="mx-auto flex max-w-[1400px] gap-6 px-6 py-6">
        <Sidebar />
        <main className="flex-1 space-y-4 pb-10">
          <Topbar user={user} />
          <div className="space-y-4">{children}</div>
        </main>
      </div>
    </div>
  );
}


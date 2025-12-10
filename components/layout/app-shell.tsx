import * as React from 'react';

type AppShellProps = {
  children: React.ReactNode;
};

export function AppShell({ children }: AppShellProps) {
  return (
    <div className="flex min-h-screen bg-slate-950 text-slate-50">
      {/* Sidebar */}
      <aside className="hidden w-64 flex-col border-r border-slate-800 bg-slate-950/90 px-4 py-6 md:flex">
        <div className="mb-6 text-xs font-semibold uppercase tracking-[0.25em] text-slate-400">
          Arquiproductos ERP
        </div>
        <nav className="space-y-1 text-sm">
          <button className="flex w-full items-center justify-between rounded-md px-3 py-2 text-left text-slate-100 hover:bg-slate-800">
            <span>Dashboard</span>
          </button>
          <button className="flex w-full items-center justify-between rounded-md px-3 py-2 text-left text-slate-300 hover:bg-slate-800">
            <span>Quotes</span>
          </button>
          <button className="flex w-full items-center justify-between rounded-md px-3 py-2 text-left text-slate-300 hover:bg-slate-800">
            <span>Systems</span>
          </button>
          <button className="flex w-full items-center justify-between rounded-md px-3 py-2 text-left text-slate-300 hover:bg-slate-800">
            <span>Collections</span>
          </button>
        </nav>
      </aside>

      {/* Main area */}
      <div className="flex flex-1 flex-col">
        {/* Topbar */}
        <header className="flex items-center justify-between border-b border-slate-800 bg-slate-950/80 px-4 py-3">
          <div>
            <p className="text-xs uppercase tracking-[0.25em] text-slate-400">Quote Builder</p>
            <h1 className="text-sm font-semibold text-slate-50">WApunch-style layout</h1>
          </div>
          <div className="text-xs text-slate-400">User menu / actions</div>
        </header>

        {/* Content */}
        <main className="flex-1 overflow-y-auto px-6 py-6">
          <div className="mx-auto w-full max-w-6xl space-y-6">{children}</div>
        </main>
      </div>
    </div>
  );
}


import { useEffect } from 'react';
import { useSubmoduleNav } from '../../../../../hooks/useSubmoduleNav';
import { Calendar, Wallet } from 'lucide-react';

export default function MyBalance() {
  const { registerSubmodules } = useSubmoduleNav();

  useEffect(() => {
    // Register submodule tabs for PTO & Leaves
    registerSubmodules('PTO & Leaves', [
      { id: 'my-balance', label: 'My Balance', href: '/employee/pto-and-leaves/my-balance', icon: Wallet },
      { id: 'my-requests', label: 'My Requests', href: '/employee/pto-and-leaves/my-requests', icon: Calendar }
    ]);
  }, [registerSubmodules]);

  return (
    <div className="p-6">
      {/* Header */}
      <div className="mb-8">
        <h1 className="text-xl font-semibold text-foreground mb-1">My Balance</h1>
        <p className="text-xs text-muted-foreground">View your PTO and leave balances</p>
      </div>

      {/* Content */}
      <div className="flex items-center justify-center min-h-[400px]">
        <div className="text-center">
          <h2 className="text-2xl font-semibold text-muted-foreground mb-2">Coming Soon</h2>
          <p className="text-muted-foreground">This feature is under development</p>
        </div>
      </div>
    </div>
  );
}

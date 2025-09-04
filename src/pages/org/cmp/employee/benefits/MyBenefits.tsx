import { useEffect } from 'react';
import { useSubmoduleNav } from '../../../../../hooks/useSubmoduleNav';
import { WalletCards } from 'lucide-react';

export default function MyBenefits() {
  const { registerSubmodules } = useSubmoduleNav();

  useEffect(() => {
    // Register submodule tabs for Benefits
    registerSubmodules('Benefits', [
      { id: 'my-benefits', label: 'My Benefits', href: '/employee/benefits/my-benefits', icon: WalletCards }
    ]);
  }, [registerSubmodules]);

  return (
    <div className="p-6">
      {/* Header */}
      <div className="mb-8">
        <h1 className="text-xl font-semibold text-foreground mb-1">My Benefits</h1>
        <p className="text-xs text-muted-foreground">View and manage your personal benefits and coverage</p>
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

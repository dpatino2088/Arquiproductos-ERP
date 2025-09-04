import { useEffect } from 'react';
import { useSubmoduleNav } from '../../../../../hooks/useSubmoduleNav';
import { DollarSign, Brain, Dumbbell, Apple } from 'lucide-react';

export default function FinancialWellness() {
  const { registerSubmodules } = useSubmoduleNav();

  useEffect(() => {
    // Register submodule tabs for Wellness
    registerSubmodules('Wellness', [
      { id: 'fitness', label: 'Fitness', href: '/employee/wellness/fitness', icon: Dumbbell },
      { id: 'nutrition', label: 'Nutrition', href: '/employee/wellness/nutrition', icon: Apple },
      { id: 'mental-health', label: 'Mental Health', href: '/employee/wellness/mental-health', icon: Brain },
      { id: 'financial-wellness', label: 'Financial Wellness', href: '/employee/wellness/financial-wellness', icon: DollarSign }
    ]);
  }, [registerSubmodules]);

  return (
    <div className="p-6">
      <div className="mb-8">
        <h1 className="text-xl font-semibold text-foreground mb-1">Financial Wellness</h1>
        <p className="text-xs text-muted-foreground">Manage your financial health and planning</p>
      </div>
      <div className="flex items-center justify-center min-h-[400px]">
        <div className="text-center">
          <h2 className="text-2xl font-semibold text-muted-foreground mb-2">Coming Soon</h2>
          <p className="text-muted-foreground">This feature is under development</p>
        </div>
      </div>
    </div>
  );
}

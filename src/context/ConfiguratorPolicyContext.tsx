import React, { createContext, useContext } from 'react';
import type { DealerConfiguratorPolicy } from '../hooks/useDealerConfiguratorPolicy';

type ConfiguratorPolicyContextValue = {
  policy: DealerConfiguratorPolicy | null;
  loading: boolean;
};

const ConfiguratorPolicyContext = createContext<ConfiguratorPolicyContextValue | null>(null);

export function ConfiguratorPolicyProvider({
  children,
  value,
}: {
  children: React.ReactNode;
  value: ConfiguratorPolicyContextValue;
}) {
  return (
    <ConfiguratorPolicyContext.Provider value={value}>
      {children}
    </ConfiguratorPolicyContext.Provider>
  );
}

/**
 * Use policy and loading from context (when inside ProductConfigurator).
 * Falls back to null / false when used outside the provider.
 */
export function useConfiguratorPolicy(): ConfiguratorPolicyContextValue {
  const ctx = useContext(ConfiguratorPolicyContext);
  return ctx ?? { policy: null, loading: false };
}

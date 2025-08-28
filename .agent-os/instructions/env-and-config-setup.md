# Instruction: Environment & Configuration Setup

## Overview

Implement a comprehensive environment and configuration management system that supports multiple environments, feature flags, and runtime configuration. This setup should provide flexibility for different deployment scenarios while maintaining security and consistency.

## Core Requirements

### 1. Environment Management

- Multiple environment support (dev, staging, prod)
- Environment-specific configuration
- Secure handling of sensitive data
- Runtime configuration updates

### 2. Feature Flags

- Boolean and configuration-based flags
- Runtime feature enablement/disablement
- A/B testing support
- Gradual rollout capabilities

### 3. Configuration Management

- Centralized configuration
- Type-safe configuration access
- Configuration validation
- Default value management

## Implementation Steps

### Step 1: Environment Configuration

```typescript
// src/lib/env.ts
export function getEnvVar(key: string, defaultValue?: string): string {
  const value = import.meta.env[key];
  if (value === undefined && defaultValue === undefined) {
    throw new Error(`Environment variable ${key} is required`);
  }
  return value || defaultValue || "";
}

export function getEnvVarAsNumber(key: string, defaultValue?: number): number {
  const value = getEnvVar(key);
  if (!value && defaultValue !== undefined) {
    return defaultValue;
  }
  const num = Number(value);
  if (isNaN(num)) {
    throw new Error(`Environment variable ${key} must be a number`);
  }
  return num;
}

export function getEnvVarAsBoolean(
  key: string,
  defaultValue?: boolean
): boolean {
  const value = getEnvVar(key);
  if (!value && defaultValue !== undefined) {
    return defaultValue;
  }
  return value === "true";
}

export const env = {
  NODE_ENV: getEnvVar("NODE_ENV", "development"),
  API_URL: getEnvVar("VITE_API_URL", "http://localhost:3000"),
  APP_NAME: getEnvVar("VITE_APP_NAME", "REMO Frontend"),
  APP_VERSION: getEnvVar("VITE_APP_VERSION", "1.0.0"),
  ENVIRONMENT: getEnvVar("VITE_ENVIRONMENT", "development"),
  FEATURE_AUTH: getEnvVarAsBoolean("VITE_FEATURE_AUTH", true),
  FEATURE_ANALYTICS: getEnvVarAsBoolean("VITE_FEATURE_ANALYTICS", false),
  FEATURE_NOTIFICATIONS: getEnvVarAsBoolean("VITE_FEATURE_NOTIFICATIONS", true),
  SENTRY_DSN: getEnvVar("VITE_SENTRY_DSN", ""),
  GOOGLE_ANALYTICS_ID: getEnvVar("VITE_GOOGLE_ANALYTICS_ID", ""),
  LOG_LEVEL: getEnvVar("VITE_LOG_LEVEL", "info"),
  API_TIMEOUT: getEnvVarAsNumber("VITE_API_TIMEOUT", 10000),
  CACHE_TTL: getEnvVarAsNumber("VITE_CACHE_TTL", 300000),
} as const;

// src/config/environments.ts
export interface EnvironmentConfig {
  name: string;
  apiUrl: string;
  logLevel: string;
  features: Record<string, boolean>;
  analytics: {
    enabled: boolean;
    googleAnalyticsId?: string;
    sentryDsn?: string;
  };
  security: {
    cspEnabled: boolean;
    trustedTypesEnabled: boolean;
    sriEnabled: boolean;
  };
  performance: {
    cacheEnabled: boolean;
    cacheTtl: number;
    apiTimeout: number;
  };
}

export const environments: Record<string, EnvironmentConfig> = {
  development: {
    name: "development",
    apiUrl: "http://localhost:3000",
    logLevel: "debug",
    features: {
      auth: true,
      analytics: false,
      notifications: true,
      debug: true,
    },
    analytics: {
      enabled: false,
    },
    security: {
      cspEnabled: false,
      trustedTypesEnabled: false,
      sriEnabled: false,
    },
    performance: {
      cacheEnabled: true,
      cacheTtl: 60000, // 1 minute
      apiTimeout: 10000,
    },
  },
  staging: {
    name: "staging",
    apiUrl: "https://api-staging.remo.com",
    logLevel: "info",
    features: {
      auth: true,
      analytics: true,
      notifications: true,
      debug: false,
    },
    analytics: {
      enabled: true,
      googleAnalyticsId: env.GOOGLE_ANALYTICS_ID,
      sentryDsn: env.SENTRY_DSN,
    },
    security: {
      cspEnabled: true,
      trustedTypesEnabled: false,
      sriEnabled: true,
    },
    performance: {
      cacheEnabled: true,
      cacheTtl: 300000, // 5 minutes
      apiTimeout: 15000,
    },
  },
  production: {
    name: "production",
    apiUrl: "https://api.remo.com",
    logLevel: "warn",
    features: {
      auth: true,
      analytics: true,
      notifications: true,
      debug: false,
    },
    analytics: {
      enabled: true,
      googleAnalyticsId: env.GOOGLE_ANALYTICS_ID,
      sentryDsn: env.SENTRY_DSN,
    },
    security: {
      cspEnabled: true,
      trustedTypesEnabled: true,
      sriEnabled: true,
    },
    performance: {
      cacheEnabled: true,
      cacheTtl: 900000, // 15 minutes
      apiTimeout: 20000,
    },
  },
};

export function getCurrentEnvironment(): EnvironmentConfig {
  const envName = env.ENVIRONMENT || "development";
  return environments[envName] || environments.development;
}
```

### Step 2: Feature Flags System

```typescript
// src/lib/featureFlags.ts
interface FeatureFlag {
  name: string;
  enabled: boolean;
  config?: Record<string, any>;
  rollout?: {
    percentage: number;
    users?: string[];
    groups?: string[];
  };
}

class FeatureFlagsManager {
  private flags: Map<string, FeatureFlag> = new Map();
  private userId?: string;
  private userGroups: string[] = [];

  constructor() {
    this.initializeFlags();
  }

  private initializeFlags() {
    const currentEnv = getCurrentEnvironment();

    // Initialize from environment
    Object.entries(currentEnv.features).forEach(([name, enabled]) => {
      this.flags.set(name, {
        name,
        enabled,
        config: {},
      });
    });

    // Load from localStorage for runtime overrides
    this.loadRuntimeFlags();
  }

  private loadRuntimeFlags() {
    try {
      const stored = localStorage.getItem("feature-flags");
      if (stored) {
        const runtimeFlags = JSON.parse(stored);
        Object.entries(runtimeFlags).forEach(([name, flag]) => {
          this.flags.set(name, flag as FeatureFlag);
        });
      }
    } catch (error) {
      console.warn("Failed to load runtime feature flags:", error);
    }
  }

  setUser(userId: string, groups: string[] = []) {
    this.userId = userId;
    this.userGroups = groups;
  }

  isEnabled(flagName: string): boolean {
    const flag = this.flags.get(flagName);
    if (!flag) return false;

    // Check if flag is globally enabled
    if (!flag.enabled) return false;

    // Check rollout percentage
    if (flag.rollout?.percentage) {
      const userHash = this.hashUserId(this.userId || "anonymous");
      const userPercentage = userHash % 100;
      if (userPercentage >= flag.rollout.percentage) {
        return false;
      }
    }

    // Check specific users
    if (flag.rollout?.users && this.userId) {
      if (flag.rollout.users.includes(this.userId)) {
        return true;
      }
    }

    // Check user groups
    if (flag.rollout?.groups && this.userGroups.length > 0) {
      if (
        flag.rollout.groups.some((group) => this.userGroups.includes(group))
      ) {
        return true;
      }
    }

    return flag.enabled;
  }

  getConfig(flagName: string): Record<string, any> | undefined {
    const flag = this.flags.get(flagName);
    return flag?.config;
  }

  private hashUserId(userId: string): number {
    let hash = 0;
    for (let i = 0; i < userId.length; i++) {
      const char = userId.charCodeAt(i);
      hash = (hash << 5) - hash + char;
      hash = hash & hash; // Convert to 32-bit integer
    }
    return Math.abs(hash);
  }

  // Runtime flag management (for development/testing)
  setRuntimeFlag(name: string, enabled: boolean, config?: Record<string, any>) {
    this.flags.set(name, { name, enabled, config });
    this.saveRuntimeFlags();
  }

  private saveRuntimeFlags() {
    try {
      const runtimeFlags: Record<string, FeatureFlag> = {};
      this.flags.forEach((flag, name) => {
        runtimeFlags[name] = flag;
      });
      localStorage.setItem("feature-flags", JSON.stringify(runtimeFlags));
    } catch (error) {
      console.warn("Failed to save runtime feature flags:", error);
    }
  }
}

export const featureFlags = new FeatureFlagsManager();

// src/hooks/useFeatureFlag.ts
import { useState, useEffect } from "react";
import { featureFlags } from "@/lib/featureFlags";

export function useFeatureFlag(flagName: string): boolean {
  const [isEnabled, setIsEnabled] = useState(() =>
    featureFlags.isEnabled(flagName)
  );

  useEffect(() => {
    // Check flag status when user changes
    setIsEnabled(featureFlags.isEnabled(flagName));
  }, [flagName]);

  return isEnabled;
}

export function useFeatureConfig<T = Record<string, any>>(
  flagName: string
): T | undefined {
  const [config, setConfig] = useState(() => featureFlags.getConfig(flagName));

  useEffect(() => {
    setConfig(featureFlags.getConfig(flagName));
  }, [flagName]);

  return config as T;
}
```

### Step 3: Configuration Management

```typescript
// src/config/index.ts
import { getCurrentEnvironment } from "./environments";
import { featureFlags } from "@/lib/featureFlags";

export interface AppConfig {
  environment: string;
  api: {
    baseUrl: string;
    timeout: number;
    retries: number;
  };
  features: {
    auth: boolean;
    analytics: boolean;
    notifications: boolean;
    debug: boolean;
  };
  security: {
    cspEnabled: boolean;
    trustedTypesEnabled: boolean;
    sriEnabled: boolean;
  };
  performance: {
    cacheEnabled: boolean;
    cacheTtl: number;
    apiTimeout: number;
  };
  analytics: {
    enabled: boolean;
    googleAnalyticsId?: string;
    sentryDsn?: string;
  };
}

class ConfigurationManager {
  private config: AppConfig;

  constructor() {
    this.config = this.buildConfig();
  }

  private buildConfig(): AppConfig {
    const env = getCurrentEnvironment();

    return {
      environment: env.name,
      api: {
        baseUrl: env.apiUrl,
        timeout: env.performance.apiTimeout,
        retries: 3,
      },
      features: {
        auth: featureFlags.isEnabled("auth"),
        analytics: featureFlags.isEnabled("analytics"),
        notifications: featureFlags.isEnabled("notifications"),
        debug: featureFlags.isEnabled("debug"),
      },
      security: env.security,
      performance: env.performance,
      analytics: env.analytics,
    };
  }

  get(): AppConfig {
    return this.config;
  }

  getValue<T>(path: string): T | undefined {
    return path.split(".").reduce((obj, key) => obj?.[key], this.config) as T;
  }

  refresh() {
    this.config = this.buildConfig();
  }

  // Runtime configuration updates
  updateFeatureFlag(name: string, enabled: boolean) {
    featureFlags.setRuntimeFlag(name, enabled);
    this.refresh();
  }
}

export const config = new ConfigurationManager();

// src/hooks/useConfig.ts
import { useState, useEffect } from "react";
import { config } from "@/config";

export function useConfig() {
  const [appConfig, setAppConfig] = useState(config.get());

  useEffect(() => {
    // Refresh config when needed
    const refreshConfig = () => {
      config.refresh();
      setAppConfig(config.get());
    };

    // Listen for config changes (e.g., feature flag updates)
    window.addEventListener("config:refresh", refreshConfig);

    return () => {
      window.removeEventListener("config:refresh", refreshConfig);
    };
  }, []);

  return appConfig;
}

export function useConfigValue<T>(path: string): T | undefined {
  const [value, setValue] = useState(() => config.getValue<T>(path));

  useEffect(() => {
    setValue(config.getValue<T>(path));
  }, [path]);

  return value;
}
```

### Step 4: Environment-Specific Builds

```typescript
// vite.config.ts
import { defineConfig, loadEnv } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')

  return {
    plugins: [react()],
    resolve: {
      alias: {
        '@': path.resolve(__dirname, './src'),
      },
    },
    define: {
      __APP_VERSION__: JSON.stringify(env.VITE_APP_VERSION || '1.0.0'),
      __ENVIRONMENT__: JSON.stringify(env.VITE_ENVIRONMENT || 'development'),
    },
    build: {
      target: 'es2015',
      minify: mode === 'production' ? 'terser' : false,
      sourcemap: mode !== 'production',
      rollupOptions: {
        output: {
          manualChunks: {
            vendor: ['react', 'react-dom'],
            router: ['react-router-dom'],
            query: ['@tanstack/react-query'],
          },
        },
      },
    },
    server: {
      port: 3000,
      host: true,
    },
  }
})

// .env.development
VITE_ENVIRONMENT=development
VITE_API_URL=http://localhost:3000
VITE_FEATURE_AUTH=true
VITE_FEATURE_ANALYTICS=false
VITE_FEATURE_NOTIFICATIONS=true
VITE_LOG_LEVEL=debug

// .env.staging
VITE_ENVIRONMENT=staging
VITE_API_URL=https://api-staging.remo.com
VITE_FEATURE_AUTH=true
VITE_FEATURE_ANALYTICS=true
VITE_FEATURE_NOTIFICATIONS=true
VITE_LOG_LEVEL=info
VITE_SENTRY_DSN=your-sentry-dsn
VITE_GOOGLE_ANALYTICS_ID=your-ga-id

// .env.production
VITE_ENVIRONMENT=production
VITE_API_URL=https://api.remo.com
VITE_FEATURE_AUTH=true
VITE_FEATURE_ANALYTICS=true
VITE_FEATURE_NOTIFICATIONS=true
VITE_LOG_LEVEL=warn
VITE_SENTRY_DSN=your-sentry-dsn
VITE_GOOGLE_ANALYTICS_ID=your-ga-id
```

### Step 5: Runtime Configuration

```typescript
// src/lib/runtimeConfig.ts
interface RuntimeConfig {
  apiUrl?: string;
  features?: Record<string, boolean>;
  analytics?: {
    enabled?: boolean;
    googleAnalyticsId?: string;
  };
}

class RuntimeConfigurationManager {
  private config: RuntimeConfig = {};
  private listeners: Set<() => void> = new Set();

  setConfig(newConfig: RuntimeConfig) {
    this.config = { ...this.config, ...newConfig };
    this.notifyListeners();
  }

  getConfig(): RuntimeConfig {
    return { ...this.config };
  }

  subscribe(listener: () => void) {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  private notifyListeners() {
    this.listeners.forEach((listener) => listener());
  }

  // Load configuration from external source
  async loadFromExternalSource(url: string) {
    try {
      const response = await fetch(url);
      const config = await response.json();
      this.setConfig(config);
    } catch (error) {
      console.warn("Failed to load runtime configuration:", error);
    }
  }
}

export const runtimeConfig = new RuntimeConfigurationManager();

// src/hooks/useRuntimeConfig.ts
import { useState, useEffect } from "react";
import { runtimeConfig } from "@/lib/runtimeConfig";

export function useRuntimeConfig() {
  const [config, setConfig] = useState(runtimeConfig.getConfig());

  useEffect(() => {
    const unsubscribe = runtimeConfig.subscribe(() => {
      setConfig(runtimeConfig.getConfig());
    });

    return unsubscribe;
  }, []);

  return config;
}
```

## Best Practices

### 1. Environment Management

- Use environment-specific files
- Validate required variables
- Provide sensible defaults
- Secure sensitive data

### 2. Feature Flags

- Use descriptive flag names
- Implement gradual rollouts
- Monitor flag usage
- Clean up unused flags

### 3. Configuration

- Centralize configuration
- Validate configuration values
- Support runtime updates
- Document all options

### 4. Security

- Never expose secrets in client
- Validate configuration inputs
- Use secure defaults
- Monitor configuration changes

## Quality Gates

### 1. Environment Setup

- All environments are configured
- Required variables are present
- Default values are sensible
- No secrets are exposed

### 2. Feature Flags

- Flags work correctly
- Rollouts function properly
- Configuration is accessible
- Performance impact is minimal

### 3. Configuration

- Configuration is type-safe
- Values are validated
- Runtime updates work
- Defaults are appropriate

### 4. Build Process

- Environment-specific builds work
- Variables are properly injected
- Source maps are configured
- Bundle optimization is active

## Next Steps

After completing environment and configuration setup:

1. Set up CI/CD environment variables
2. Configure monitoring for config changes
3. Implement configuration validation
4. Add configuration documentation
5. Set up feature flag analytics

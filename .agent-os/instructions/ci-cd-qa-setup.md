# Instruction: CI/CD & QA Setup

## Overview

Implement a comprehensive CI/CD pipeline with quality assurance gates, automated testing, and deployment strategies. This setup should ensure code quality, prevent regressions, and enable reliable deployments across different environments.

## Core Requirements

### 1. CI/CD Pipeline

- Automated build and test process
- Quality gates and checks
- Environment-specific deployments
- Rollback capabilities

### 2. Quality Assurance

- Automated testing (unit, integration, E2E)
- Code quality checks (linting, formatting)
- Performance testing
- Security scanning

### 3. Deployment Strategy

- Blue-green deployments
- Canary releases
- Feature flag rollouts
- Monitoring and alerting

## Implementation Steps

### Step 1: GitHub Actions CI/CD Pipeline

```yaml
# .github/workflows/ci.yml
name: CI/CD Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

env:
  NODE_VERSION: "18"
  PNPM_VERSION: "8"

jobs:
  quality-checks:
    name: Quality Checks
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}

      - name: Setup pnpm
        uses: pnpm/action-setup@v2
        with:
          version: ${{ env.PNPM_VERSION }}

      - name: Install dependencies
        run: pnpm install --frozen-lockfile

      - name: Run linting
        run: pnpm lint

      - name: Check formatting
        run: pnpm format:check

      - name: Type checking
        run: pnpm type-check

      - name: Security audit
        run: pnpm audit

  test:
    name: Run Tests
    runs-on: ubuntu-latest
    needs: quality-checks

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}

      - name: Setup pnpm
        uses: pnpm/action-setup@v2
        with:
          version: ${{ env.PNPM_VERSION }}

      - name: Install dependencies
        run: pnpm install --frozen-lockfile

      - name: Run unit tests
        run: pnpm test:run

      - name: Run integration tests
        run: pnpm test:integration

      - name: Generate coverage report
        run: pnpm test:coverage

      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v3
        with:
          file: ./coverage/lcov.info
          flags: unittests
          name: codecov-umbrella

  build:
    name: Build Application
    runs-on: ubuntu-latest
    needs: test

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}

      - name: Setup pnpm
        uses: pnpm/action-setup@v2
        with:
          version: ${{ env.PNPM_VERSION }}

      - name: Install dependencies
        run: pnpm install --frozen-lockfile

      - name: Build application
        run: pnpm build
        env:
          VITE_ENVIRONMENT: staging

      - name: Upload build artifacts
        uses: actions/upload-artifact@v4
        with:
          name: build-files
          path: dist/

  performance:
    name: Performance Testing
    runs-on: ubuntu-latest
    needs: build

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Download build artifacts
        uses: actions/download-artifact@v4
        with:
          name: build-files
          path: dist/

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}

      - name: Install Lighthouse CI
        run: npm install -g @lhci/cli@0.12.x

      - name: Run Lighthouse CI
        run: lhci autorun

  security:
    name: Security Scanning
    runs-on: ubuntu-latest
    needs: build

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Run Snyk security scan
        uses: snyk/actions/node@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
        with:
          args: --severity-threshold=high

      - name: Run OWASP ZAP scan
        uses: zaproxy/action-full-scan@v0.8.0
        with:
          target: "http://localhost:3000"
          rules_file_name: ".zap/rules.tsv"
          cmd_options: "-a"

  deploy-staging:
    name: Deploy to Staging
    runs-on: ubuntu-latest
    needs: [performance, security]
    if: github.ref == 'refs/heads/develop'
    environment: staging

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Download build artifacts
        uses: actions/download-artifact@v4
        with:
          name: build-files
          path: dist/

      - name: Deploy to staging
        run: |
          # Add your staging deployment logic here
          echo "Deploying to staging environment"
          # Example: aws s3 sync dist/ s3://staging-bucket/
          # Example: aws cloudfront create-invalidation --distribution-id $STAGING_DISTRIBUTION_ID --paths "/*"

  deploy-production:
    name: Deploy to Production
    runs-on: ubuntu-latest
    needs: [performance, security]
    if: github.ref == 'refs/heads/main'
    environment: production

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Download build artifacts
        uses: actions/download-artifact@v4
        with:
          name: build-files
          path: dist/

      - name: Deploy to production
        run: |
          # Add your production deployment logic here
          echo "Deploying to production environment"
          # Example: aws s3 sync dist/ s3://production-bucket/
          # Example: aws cloudfront create-invalidation --distribution-id $PRODUCTION_DISTRIBUTION_ID --paths "/*"

      - name: Run smoke tests
        run: |
          # Add smoke tests after deployment
          echo "Running smoke tests"
          # Example: npm run test:smoke
```

### Step 2: Quality Gates Configuration

```typescript
// scripts/quality-gates.ts
interface QualityGate {
  name: string;
  check: () => Promise<boolean>;
  threshold: number;
  current: number;
}

class QualityGateManager {
  private gates: QualityGate[] = [];

  addGate(gate: QualityGate) {
    this.gates.push(gate);
  }

  async runAllGates(): Promise<{ passed: boolean; results: any[] }> {
    const results = [];
    let allPassed = true;

    for (const gate of this.gates) {
      try {
        const passed = await gate.check();
        const result = {
          name: gate.name,
          passed,
          threshold: gate.threshold,
          current: gate.current,
          status: passed ? "PASSED" : "FAILED",
        };

        results.push(result);

        if (!passed) {
          allPassed = false;
        }
      } catch (error) {
        const result = {
          name: gate.name,
          passed: false,
          error: error.message,
          status: "ERROR",
        };

        results.push(result);
        allPassed = false;
      }
    }

    return { passed: allPassed, results };
  }
}

// Test coverage gate
const coverageGate: QualityGate = {
  name: "Test Coverage",
  check: async () => {
    // Read coverage report and check threshold
    const coverage = await getCoveragePercentage();
    return coverage >= 80; // 80% threshold
  },
  threshold: 80,
  current: 0,
};

// Bundle size gate
const bundleSizeGate: QualityGate = {
  name: "Bundle Size",
  check: async () => {
    const bundleSize = await getBundleSize();
    return bundleSize <= 500 * 1024; // 500KB threshold
  },
  threshold: 500 * 1024,
  current: 0,
};

// Performance gate
const performanceGate: QualityGate = {
  name: "Performance Score",
  check: async () => {
    const score = await getLighthouseScore();
    return score >= 90; // 90+ threshold
  },
  threshold: 90,
  current: 0,
};

export const qualityGates = new QualityGateManager();
qualityGates.addGate(coverageGate);
qualityGates.addGate(bundleSizeGate);
qualityGates.addGate(performanceGate);
```

### Step 3: Testing Configuration

```typescript
// vitest.config.ts
import { defineConfig } from "vitest/config";
import react from "@vitejs/plugin-react";
import path from "path";

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
  test: {
    globals: true,
    environment: "jsdom",
    setupFiles: ["./src/test/setup.ts"],
    css: true,
    coverage: {
      provider: "v8",
      reporter: ["text", "json", "html", "lcov"],
      thresholds: {
        global: {
          branches: 80,
          functions: 80,
          lines: 80,
          statements: 80,
        },
      },
      exclude: [
        "node_modules/",
        "src/test/",
        "**/*.d.ts",
        "**/*.config.*",
        "**/coverage/**",
      ],
    },
    testTimeout: 10000,
    hookTimeout: 10000,
  },
});

// src/test/setup.ts
import "@testing-library/jest-dom";
import { beforeAll, afterEach, afterAll } from "vitest";
import { server } from "./mocks/server";

// Establish API mocking before all tests
beforeAll(() => server.listen());

// Reset any request handlers that we may add during the tests
afterEach(() => server.resetHandlers());

// Clean up after the tests are finished
afterAll(() => server.close());

// Global test utilities
global.ResizeObserver = vi.fn().mockImplementation(() => ({
  observe: vi.fn(),
  unobserve: vi.fn(),
  disconnect: vi.fn(),
}));

// Mock IntersectionObserver
global.IntersectionObserver = vi.fn().mockImplementation(() => ({
  observe: vi.fn(),
  unobserve: vi.fn(),
  disconnect: vi.fn(),
}));

// src/test/utils.tsx
import React, { ReactElement } from "react";
import { render, RenderOptions } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { BrowserRouter } from "react-router-dom";

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: false,
    },
    mutations: {
      retry: false,
    },
  },
});

interface CustomRenderOptions extends Omit<RenderOptions, "wrapper"> {
  route?: string;
}

function customRender(
  ui: ReactElement,
  options: CustomRenderOptions = {}
): ReturnType<typeof render> {
  const { route = "/", ...renderOptions } = options;

  const AllTheProviders = ({ children }: { children: React.ReactNode }) => {
    return (
      <QueryClientProvider client={queryClient}>
        <BrowserRouter>{children}</BrowserRouter>
      </QueryClientProvider>
    );
  };

  return render(ui, { wrapper: AllTheProviders, ...renderOptions });
}

export * from "@testing-library/react";
export { customRender as render };
```

### Step 4: Performance Testing

```typescript
// scripts/performance-test.ts
import lighthouse from "lighthouse";
import chromeLauncher from "chrome-launcher";
import fs from "fs";
import path from "path";

interface PerformanceBudget {
  fcp: number;
  lcp: number;
  fid: number;
  cls: number;
  ttfb: number;
  bundleSize: number;
}

const PERFORMANCE_BUDGET: PerformanceBudget = {
  fcp: 1800, // 1.8s
  lcp: 2500, // 2.5s
  fid: 100, // 100ms
  cls: 0.1, // 0.1
  ttfb: 800, // 800ms
  bundleSize: 500 * 1024, // 500KB
};

async function runLighthouse(url: string): Promise<any> {
  const chrome = await chromeLauncher.launch({ chromeFlags: ["--headless"] });
  const options = {
    logLevel: "info",
    output: "json",
    onlyCategories: ["performance"],
    port: chrome.port,
  };

  try {
    const runnerResult = await lighthouse(url, options);
    const report = runnerResult.lhr;
    await chrome.kill();
    return report;
  } catch (error) {
    await chrome.kill();
    throw error;
  }
}

async function checkPerformanceBudget(
  report: any
): Promise<{ passed: boolean; results: any[] }> {
  const results = [];
  let allPassed = true;

  // Check Core Web Vitals
  const metrics = report.audits.metrics.details.items[0];

  const checks = [
    {
      name: "FCP",
      current: metrics.firstContentfulPaint,
      threshold: PERFORMANCE_BUDGET.fcp,
    },
    {
      name: "LCP",
      current: metrics.largestContentfulPaint,
      threshold: PERFORMANCE_BUDGET.lcp,
    },
    {
      name: "FID",
      current: metrics.maxPotentialFID,
      threshold: PERFORMANCE_BUDGET.fid,
    },
    {
      name: "CLS",
      current: metrics.cumulativeLayoutShift,
      threshold: PERFORMANCE_BUDGET.cls,
    },
    {
      name: "TTFB",
      current: metrics.serverResponseTime,
      threshold: PERFORMANCE_BUDGET.ttfb,
    },
  ];

  for (const check of checks) {
    const passed = check.current <= check.threshold;
    results.push({
      metric: check.name,
      current: check.current,
      threshold: check.threshold,
      passed,
      status: passed ? "PASSED" : "FAILED",
    });

    if (!passed) {
      allPassed = false;
    }
  }

  return { passed: allPassed, results };
}

async function runPerformanceTests() {
  try {
    console.log("Running performance tests...");

    const report = await runLighthouse("http://localhost:3000");
    const budgetCheck = await checkPerformanceBudget(report);

    console.log("Performance test results:");
    budgetCheck.results.forEach((result) => {
      console.log(`${result.metric}: ${result.current}ms (${result.status})`);
    });

    if (!budgetCheck.passed) {
      console.error("Performance budget exceeded!");
      process.exit(1);
    }

    console.log("All performance tests passed!");
  } catch (error) {
    console.error("Performance test failed:", error);
    process.exit(1);
  }
}

// Run if called directly
if (require.main === module) {
  runPerformanceTests();
}

export { runPerformanceTests, checkPerformanceBudget };
```

### Step 5: Deployment Scripts

```typescript
// scripts/deploy.ts
import { execSync } from "child_process";
import fs from "fs";
import path from "path";

interface DeploymentConfig {
  environment: string;
  buildCommand: string;
  deployCommand: string;
  healthCheckUrl: string;
  rollbackCommand?: string;
}

const DEPLOYMENT_CONFIGS: Record<string, DeploymentConfig> = {
  staging: {
    environment: "staging",
    buildCommand: "pnpm build:staging",
    deployCommand: "aws s3 sync dist/ s3://staging-bucket/",
    healthCheckUrl: "https://staging.remo.com/health",
  },
  production: {
    environment: "production",
    buildCommand: "pnpm build:production",
    deployCommand: "aws s3 sync dist/ s3://production-bucket/",
    healthCheckUrl: "https://remo.com/health",
    rollbackCommand:
      "aws s3 sync s3://production-bucket-backup/ s3://production-bucket/",
  },
};

class DeploymentManager {
  private config: DeploymentConfig;

  constructor(environment: string) {
    this.config = DEPLOYMENT_CONFIGS[environment];
    if (!this.config) {
      throw new Error(`Unknown environment: ${environment}`);
    }
  }

  async deploy(): Promise<void> {
    try {
      console.log(`Starting deployment to ${this.config.environment}...`);

      // Step 1: Build application
      await this.build();

      // Step 2: Run quality gates
      await this.runQualityGates();

      // Step 3: Deploy application
      await this.deployApplication();

      // Step 4: Health check
      await this.healthCheck();

      console.log(
        `Deployment to ${this.config.environment} completed successfully!`
      );
    } catch (error) {
      console.error(`Deployment failed: ${error.message}`);
      await this.rollback();
      throw error;
    }
  }

  private async build(): Promise<void> {
    console.log("Building application...");
    execSync(this.config.buildCommand, { stdio: "inherit" });
  }

  private async runQualityGates(): Promise<void> {
    console.log("Running quality gates...");
    execSync("pnpm quality:check", { stdio: "inherit" });
  }

  private async deployApplication(): Promise<void> {
    console.log("Deploying application...");
    execSync(this.config.deployCommand, { stdio: "inherit" });
  }

  private async healthCheck(): Promise<void> {
    console.log("Running health check...");

    const maxRetries = 10;
    const retryDelay = 5000;

    for (let i = 0; i < maxRetries; i++) {
      try {
        const response = await fetch(this.config.healthCheckUrl);
        if (response.ok) {
          console.log("Health check passed!");
          return;
        }
      } catch (error) {
        console.log(`Health check attempt ${i + 1} failed: ${error.message}`);
      }

      if (i < maxRetries - 1) {
        await new Promise((resolve) => setTimeout(resolve, retryDelay));
      }
    }

    throw new Error("Health check failed after maximum retries");
  }

  private async rollback(): Promise<void> {
    if (!this.config.rollbackCommand) {
      console.log("No rollback command configured");
      return;
    }

    console.log("Rolling back deployment...");
    try {
      execSync(this.config.rollbackCommand, { stdio: "inherit" });
      console.log("Rollback completed");
    } catch (error) {
      console.error("Rollback failed:", error.message);
    }
  }
}

// CLI interface
async function main() {
  const environment = process.argv[2];

  if (!environment) {
    console.error("Usage: pnpm deploy <environment>");
    process.exit(1);
  }

  try {
    const deployer = new DeploymentManager(environment);
    await deployer.deploy();
  } catch (error) {
    console.error("Deployment failed:", error.message);
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}

export { DeploymentManager };
```

## Best Practices

### 1. CI/CD Pipeline

- Automate all repetitive tasks
- Use quality gates to prevent bad deployments
- Implement proper rollback mechanisms
- Monitor deployment success rates

### 2. Quality Assurance

- Set realistic quality thresholds
- Run tests in parallel when possible
- Use consistent testing patterns
- Monitor test coverage trends

### 3. Performance Testing

- Set performance budgets
- Monitor Core Web Vitals
- Test on realistic devices
- Track performance trends

### 4. Deployment Strategy

- Use blue-green deployments
- Implement canary releases
- Monitor deployment health
- Have rollback procedures

## Quality Gates

### 1. Code Quality

- Linting passes with no errors
- Code formatting is consistent
- Type checking passes
- Security audit passes

### 2. Testing

- Unit test coverage >= 80%
- Integration tests pass
- E2E tests pass
- Performance tests pass

### 3. Build Quality

- Build completes successfully
- Bundle size within limits
- No critical vulnerabilities
- Performance scores meet thresholds

### 4. Deployment

- Health checks pass
- No critical errors in logs
- Performance metrics are stable
- User experience is maintained

## Next Steps

After completing CI/CD and QA setup:

1. Configure monitoring and alerting
2. Set up deployment dashboards
3. Implement advanced testing strategies
4. Add performance monitoring
5. Set up incident response procedures

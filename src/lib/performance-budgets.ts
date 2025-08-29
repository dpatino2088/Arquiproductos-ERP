// Performance budgets configuration and monitoring

// Type definitions for Web APIs
interface LayoutShift extends PerformanceEntry {
  value: number;
  hadRecentInput: boolean;
}

export const PERFORMANCE_BUDGETS = {
  // Bundle sizes (gzipped)
  totalBundle: 250, // KB
  css: 70,          // KB  
  javascript: 150,  // KB
  
  // Core Web Vitals
  lcp: 2500,        // ms
  cls: 0.1,         // score
  inp: 200,         // ms
  
  // Network
  ttfb: 600,        // ms
  fcp: 1800,        // ms
} as const;

export interface PerformanceBudgetViolation {
  metric: string;
  actual: number;
  budget: number;
  severity: 'warning' | 'error';
  timestamp: number;
}

class PerformanceBudgetMonitor {
  private violations: PerformanceBudgetViolation[] = [];

  checkBudget(metric: string, value: number): boolean {
    const budget = PERFORMANCE_BUDGETS[metric as keyof typeof PERFORMANCE_BUDGETS];
    if (!budget) return true;

    const isWithinBudget = value <= budget;
    
    if (!isWithinBudget) {
      const violation: PerformanceBudgetViolation = {
        metric,
        actual: value,
        budget,
        severity: value > budget * 1.5 ? 'error' : 'warning',
        timestamp: Date.now()
      };
      
      this.violations.push(violation);
      console.warn(`Performance budget exceeded for ${metric}:`, violation);
      
      // Report to monitoring service
      if (typeof window !== 'undefined' && 'gtag' in window) {
        (window as unknown as { gtag: (event: string, action: string, params: Record<string, unknown>) => void }).gtag('event', 'performance_budget_violation', {
          event_category: 'Performance',
          event_label: metric,
          value: Math.round(value),
          custom_map: {
            budget,
            severity: violation.severity
          }
        });
      }
    }
    
    return isWithinBudget;
  }

  getViolations(): PerformanceBudgetViolation[] {
    return [...this.violations];
  }

  clearViolations(): void {
    this.violations = [];
  }

  // Check bundle sizes from build stats
  checkBundleSizes(stats: { css: number; js: number; total: number }): void {
    this.checkBudget('css', stats.css);
    this.checkBudget('javascript', stats.js);
    this.checkBudget('totalBundle', stats.total);
  }

  // Monitor Core Web Vitals against budgets
  monitorWebVitals(): void {
    if (typeof window === 'undefined') return;

    // Monitor LCP
    new PerformanceObserver((list) => {
      for (const entry of list.getEntries()) {
        if (entry.entryType === 'largest-contentful-paint') {
          this.checkBudget('lcp', entry.startTime);
        }
      }
    }).observe({ entryTypes: ['largest-contentful-paint'] });

    // Monitor CLS
    new PerformanceObserver((list) => {
      let clsValue = 0;
      for (const entry of list.getEntries()) {
        const layoutShiftEntry = entry as LayoutShift;
        if (!layoutShiftEntry.hadRecentInput) {
          clsValue += layoutShiftEntry.value;
        }
      }
      if (clsValue > 0) {
        this.checkBudget('cls', clsValue);
      }
    }).observe({ entryTypes: ['layout-shift'] });

    // Monitor FCP
    new PerformanceObserver((list) => {
      for (const entry of list.getEntries()) {
        if (entry.name === 'first-contentful-paint') {
          this.checkBudget('fcp', entry.startTime);
        }
      }
    }).observe({ entryTypes: ['paint'] });
  }
}

export const performanceBudgetMonitor = new PerformanceBudgetMonitor();

// Initialize monitoring
if (typeof window !== 'undefined') {
  performanceBudgetMonitor.monitorWebVitals();
}

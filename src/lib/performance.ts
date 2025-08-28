/// <reference types="vite/client" />
import { onCLS, onINP, onFCP, onLCP, onTTFB, type Metric } from 'web-vitals';
import { logger } from './logger';
import { externalMonitoring } from './external-monitoring';

interface PerformanceMetric {
  name: string;
  value: number;
  rating: 'good' | 'needs-improvement' | 'poor';
  delta: number;
  id: string;
  timestamp: number;
  url: string;
}

class PerformanceMonitor {
  private metrics: PerformanceMetric[] = [];
  private isInitialized = false;

  init() {
    if (this.isInitialized) {
      return;
    }

    this.isInitialized = true;
    this.setupWebVitalsTracking();
    this.setupCustomMetrics();
    
    logger.info('Performance monitoring initialized');
  }

  private setupWebVitalsTracking() {
    // Cumulative Layout Shift
    onCLS((metric) => {
      this.trackMetric(metric);
    });

    // Interaction to Next Paint (replaces First Input Delay)
    onINP((metric) => {
      this.trackMetric(metric);
    });

    // First Contentful Paint
    onFCP((metric) => {
      this.trackMetric(metric);
    });

    // Largest Contentful Paint
    onLCP((metric) => {
      this.trackMetric(metric);
    });

    // Time to First Byte
    onTTFB((metric) => {
      this.trackMetric(metric);
    });
  }

  private setupCustomMetrics() {
    // Track route changes
    this.trackRouteChange();
    
    // Track resource loading
    this.trackResourceLoading();
    
    // Track user interactions
    this.trackUserInteractions();
  }

  private trackMetric(metric: Metric) {
    const performanceMetric: PerformanceMetric = {
      name: metric.name,
      value: metric.value,
      rating: metric.rating,
      delta: metric.delta,
      id: metric.id,
      timestamp: Date.now(),
      url: window.location.href,
    };

    this.metrics.push(performanceMetric);
    
    // Log performance metric
    logger.info(`Performance metric: ${metric.name}`, {
      value: metric.value,
      rating: metric.rating,
      url: window.location.href,
    });

    // Send to analytics service
    this.sendMetricToAnalytics(performanceMetric);
    
    // Send to external monitoring services
    externalMonitoring.sendPerformanceMetric(performanceMetric);
  }

  private trackRouteChange() {
    const startTime = performance.now();
    
    // Track initial page load
    window.addEventListener('load', () => {
      const loadTime = performance.now() - startTime;
      this.trackCustomMetric('page_load_time', loadTime);
    });

    // Track navigation timing
    if ('navigation' in performance && 'getEntriesByType' in performance) {
      const navigationEntries = performance.getEntriesByType('navigation') as PerformanceNavigationTiming[];
      if (navigationEntries.length > 0) {
        const nav = navigationEntries[0];
        if (nav) {
          this.trackCustomMetric('dom_content_loaded', nav.domContentLoadedEventEnd - nav.domContentLoadedEventStart);
          this.trackCustomMetric('dom_complete', nav.domComplete - nav.fetchStart);
        }
      }
    }
  }

  private trackResourceLoading() {
    // Track resource loading performance
    const observer = new PerformanceObserver((list) => {
      list.getEntries().forEach((entry) => {
        if (entry.entryType === 'resource') {
          const resourceEntry = entry as PerformanceResourceTiming;
          this.trackCustomMetric(`resource_${this.getResourceType(resourceEntry.name)}`, resourceEntry.duration);
        }
      });
    });

    observer.observe({ entryTypes: ['resource'] });
  }

  private trackUserInteractions() {
    // Track click interactions
    document.addEventListener('click', () => {
      const startTime = performance.now();
      
      // Use requestAnimationFrame to measure interaction response
      requestAnimationFrame(() => {
        const responseTime = performance.now() - startTime;
        this.trackCustomMetric('interaction_response_time', responseTime);
      });
    });
  }

  private trackCustomMetric(name: string, value: number, rating?: 'good' | 'needs-improvement' | 'poor') {
    const metric: PerformanceMetric = {
      name,
      value,
      rating: rating || this.calculateRating(name, value),
      delta: value,
      id: `${name}_${Date.now()}`,
      timestamp: Date.now(),
      url: window.location.href,
    };

    this.metrics.push(metric);
    
    logger.debug(`Custom performance metric: ${name}`, {
      value,
      rating: metric.rating,
    });
  }

  private calculateRating(metricName: string, value: number): 'good' | 'needs-improvement' | 'poor' {
    // Define thresholds for different metrics
    const thresholds: Record<string, { good: number; poor: number }> = {
      page_load_time: { good: 1000, poor: 3000 },
      interaction_response_time: { good: 100, poor: 300 },
      dom_content_loaded: { good: 500, poor: 1500 },
      dom_complete: { good: 1000, poor: 3000 },
      resource_script: { good: 200, poor: 1000 },
      resource_stylesheet: { good: 200, poor: 1000 },
      resource_image: { good: 500, poor: 2000 },
    };

    const threshold = thresholds[metricName];
    if (!threshold) {
      return 'good'; // Default for unknown metrics
    }

    if (value <= threshold.good) return 'good';
    if (value <= threshold.poor) return 'needs-improvement';
    return 'poor';
  }

  private getResourceType(url: string): string {
    if (url.includes('.js')) return 'script';
    if (url.includes('.css')) return 'stylesheet';
    if (url.match(/\.(png|jpg|jpeg|gif|svg|webp)$/)) return 'image';
    if (url.match(/\.(woff|woff2|ttf|otf)$/)) return 'font';
    return 'other';
  }

  private sendMetricToAnalytics(metric: PerformanceMetric) {
    // In production, send to analytics service
    if (!import.meta.env.DEV) {
      // Example: Google Analytics, DataDog, New Relic, etc.
      console.log('Would send to analytics:', metric);
    }
  }

  getMetrics(): PerformanceMetric[] {
    return [...this.metrics];
  }

  getMetricsByName(name: string): PerformanceMetric[] {
    return this.metrics.filter(metric => metric.name === name);
  }

  clearMetrics() {
    this.metrics = [];
  }

  // Performance budget checking
  checkPerformanceBudget(): { passed: boolean; violations: string[] } {
    const budgets = {
      LCP: 2500, // Largest Contentful Paint should be under 2.5s
      INP: 200,  // Interaction to Next Paint should be under 200ms
      CLS: 0.1,  // Cumulative Layout Shift should be under 0.1
      FCP: 1800, // First Contentful Paint should be under 1.8s
      TTFB: 600, // Time to First Byte should be under 600ms
    };

    const violations: string[] = [];
    
    Object.entries(budgets).forEach(([metricName, budget]) => {
      const latestMetric = this.metrics
        .filter(m => m.name === metricName)
        .sort((a, b) => b.timestamp - a.timestamp)[0];
      
      if (latestMetric && latestMetric.value > budget) {
        violations.push(`${metricName}: ${latestMetric.value}ms > ${budget}ms`);
      }
    });

    return {
      passed: violations.length === 0,
      violations,
    };
  }
}

// Export singleton instance
export const performanceMonitor = new PerformanceMonitor();

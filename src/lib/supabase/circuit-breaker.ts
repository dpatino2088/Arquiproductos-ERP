import { logger } from '../logger';

export enum CircuitState {
  CLOSED = 'CLOSED',      // Normal operation
  OPEN = 'OPEN',          // Failing, reject requests immediately
  HALF_OPEN = 'HALF_OPEN' // Testing if service recovered
}

interface CircuitBreakerConfig {
  failureThreshold: number;      // Failures before opening
  successThreshold: number;       // Successes before closing
  timeout: number;                // Time before trying again (ms)
  resetTimeout: number;           // Time before attempting half-open (ms)
}

interface CircuitBreakerStats {
  state: CircuitState;
  failures: number;
  successes: number;
  lastFailureTime: number | null;
  totalRequests: number;
  totalFailures: number;
}

export class CircuitBreaker {
  private state: CircuitState = CircuitState.CLOSED;
  private failures: number = 0;
  private successes: number = 0;
  private lastFailureTime: number | null = null;
  private totalRequests: number = 0;
  private totalFailures: number = 0;

  constructor(private config: CircuitBreakerConfig) {}

  async execute<T>(fn: () => Promise<T>): Promise<T> {
    this.totalRequests++;

    // Check if circuit should be opened/closed
    this.updateState();

    // If circuit is open, reject immediately
    if (this.state === CircuitState.OPEN) {
      const error = new Error('Circuit breaker is OPEN - service unavailable');
      (error as any).code = 'CIRCUIT_OPEN';
      (error as any).timestamp = new Date().toISOString();
      throw error;
    }

    try {
      const result = await fn();
      this.onSuccess();
      return result;
    } catch (error: any) {
      this.onFailure();
      throw error;
    }
  }

  private updateState(): void {
    const now = Date.now();

    switch (this.state) {
      case CircuitState.OPEN:
        // Try to recover after reset timeout
        if (this.lastFailureTime && 
            now - this.lastFailureTime >= this.config.resetTimeout) {
          this.state = CircuitState.HALF_OPEN;
          this.successes = 0;
          logger.info('Circuit breaker entering HALF_OPEN state', {
            timestamp: new Date().toISOString(),
          });
        }
        break;

      case CircuitState.HALF_OPEN:
        // If we've had enough successes, close the circuit
        if (this.successes >= this.config.successThreshold) {
          this.state = CircuitState.CLOSED;
          this.failures = 0;
          logger.info('Circuit breaker CLOSED - service recovered', {
            timestamp: new Date().toISOString(),
            totalFailures: this.totalFailures,
          });
        }
        break;

      case CircuitState.CLOSED:
        // If we've had too many failures, open the circuit
        if (this.failures >= this.config.failureThreshold) {
          this.state = CircuitState.OPEN;
          this.lastFailureTime = now;
          logger.error('Circuit breaker OPENED - service failing', {
            timestamp: new Date().toISOString(),
            failures: this.failures,
            threshold: this.config.failureThreshold,
          });
        }
        break;
    }
  }

  private onSuccess(): void {
    if (this.state === CircuitState.HALF_OPEN) {
      this.successes++;
    } else if (this.state === CircuitState.CLOSED) {
      // Reset failure count on success
      this.failures = 0;
    }
  }

  private onFailure(): void {
    this.totalFailures++;
    this.failures++;
    this.lastFailureTime = Date.now();
    this.successes = 0;
  }

  getStats(): CircuitBreakerStats {
    return {
      state: this.state,
      failures: this.failures,
      successes: this.successes,
      lastFailureTime: this.lastFailureTime,
      totalRequests: this.totalRequests,
      totalFailures: this.totalFailures,
    };
  }

  reset(): void {
    this.state = CircuitState.CLOSED;
    this.failures = 0;
    this.successes = 0;
    this.lastFailureTime = null;
    logger.info('Circuit breaker manually reset');
  }
}

// Singleton instance for Supabase
export const supabaseCircuitBreaker = new CircuitBreaker({
  failureThreshold: 5,        // 5 failures before opening
  successThreshold: 2,         // 2 successes before closing
  timeout: 5000,               // 5 seconds timeout
  resetTimeout: 30000,        // 30 seconds before trying again
});


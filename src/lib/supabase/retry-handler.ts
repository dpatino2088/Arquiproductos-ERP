import { logger } from '../logger';

export interface RetryConfig {
  maxRetries: number;
  baseDelay: number;
  maxDelay: number;
  retryableStatuses: number[];
  retryableErrors: string[];
}

const DEFAULT_CONFIG: RetryConfig = {
  maxRetries: 3,
  baseDelay: 1000,        // 1 second
  maxDelay: 10000,        // 10 seconds max
  retryableStatuses: [500, 502, 503, 504, 429], // Server errors + rate limit
  retryableErrors: ['ECONNRESET', 'ETIMEDOUT', 'ENOTFOUND'],
};

export function isRetryableError(error: any, config: RetryConfig = DEFAULT_CONFIG): boolean {
  // Check status code
  const status = error?.status || error?.code;
  if (status && config.retryableStatuses.includes(status)) {
    return true;
  }

  // Check error message/code
  const message = error?.message || '';
  const errorCode = error?.code || '';
  
  return config.retryableErrors.some(
    retryable => message.includes(retryable) || errorCode.includes(retryable)
  );
}

export async function retryWithBackoff<T>(
  fn: () => Promise<T>,
  config: Partial<RetryConfig> = {},
  onRetry?: (attempt: number, error: any) => void
): Promise<T> {
  const finalConfig = { ...DEFAULT_CONFIG, ...config };
  let lastError: Error | null = null;
  const timestamp = new Date().toISOString();

  for (let attempt = 0; attempt <= finalConfig.maxRetries; attempt++) {
    try {
      return await fn();
    } catch (error: any) {
      lastError = error;

      // Don't retry if error is not retryable
      if (!isRetryableError(error, finalConfig)) {
        logger.debug('Error not retryable', {
          timestamp,
          attempt,
          status: error?.status,
          message: error?.message,
        });
        throw error;
      }

      // Don't retry on last attempt
      if (attempt === finalConfig.maxRetries) {
        break;
      }

      // Calculate delay with exponential backoff + jitter
      const exponentialDelay = finalConfig.baseDelay * Math.pow(2, attempt);
      const jitter = Math.random() * 1000; // 0-1 second jitter
      const delay = Math.min(exponentialDelay + jitter, finalConfig.maxDelay);

      logger.warn(`Retrying after ${Math.round(delay)}ms (attempt ${attempt + 1}/${finalConfig.maxRetries + 1})`, {
        timestamp,
        attempt: attempt + 1,
        maxRetries: finalConfig.maxRetries + 1,
        error: error?.message,
        status: error?.status,
        delay: Math.round(delay),
      });

      if (onRetry) {
        onRetry(attempt + 1, error);
      }

      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }

  // Log final failure
  logger.error('All retry attempts exhausted', lastError as Error, {
    timestamp,
    totalAttempts: finalConfig.maxRetries + 1,
    status: (lastError as any)?.status,
  });

  throw lastError || new Error('Unknown error after retries');
}


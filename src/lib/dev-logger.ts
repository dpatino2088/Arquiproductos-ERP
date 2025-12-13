/**
 * Development Logger
 * Only logs in development mode to avoid exposing sensitive data in production
 * and to improve performance.
 * 
 * Usage:
 * import { devLog, devWarn, devError } from '@/lib/dev-logger';
 * devLog('Debug info', data);
 */

const isDev = import.meta.env.DEV;

export const devLog = (...args: any[]) => {
  if (isDev) {
    console.log(...args);
  }
};

export const devWarn = (...args: any[]) => {
  if (isDev) {
    console.warn(...args);
  }
};

export const devError = (...args: any[]) => {
  if (isDev) {
    console.error(...args);
  }
};

export const devTable = (data: any) => {
  if (isDev) {
    console.table(data);
  }
};

export const devGroup = (label: string, fn: () => void) => {
  if (isDev) {
    console.group(label);
    fn();
    console.groupEnd();
  }
};

// For production, always use the logger module for critical errors
export { logger } from './logger';


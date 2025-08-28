// Structured logging system for observability compliance

export type LogLevel = 'debug' | 'info' | 'warn' | 'error';

interface LogEntry {
  level: LogLevel;
  message: string;
  timestamp: string;
  data?: any;
  error?: Error;
  context?: Record<string, any>;
}

class Logger {
  private logLevel: LogLevel = 'info';
  private isDevelopment = import.meta.env.DEV;

  setLogLevel(level: LogLevel) {
    this.logLevel = level;
  }

  debug(message: string, data?: any, context?: Record<string, any>) {
    this.log('debug', message, data, undefined, context);
  }

  info(message: string, data?: any, context?: Record<string, any>) {
    this.log('info', message, data, undefined, context);
  }

  warn(message: string, data?: any, context?: Record<string, any>) {
    this.log('warn', message, data, undefined, context);
  }

  error(message: string, error?: Error, context?: Record<string, any>) {
    this.log('error', message, undefined, error, context);
  }

  private log(level: LogLevel, message: string, data?: any, error?: Error, context?: Record<string, any>) {
    if (!this.shouldLog(level)) {
      return;
    }

    const logEntry: LogEntry = {
      level,
      message,
      timestamp: new Date().toISOString(),
      data,
      error,
      context,
    };

    // In development, use console with colors
    if (this.isDevelopment) {
      this.logToConsole(logEntry);
    } else {
      // In production, log structured JSON
      this.logStructured(logEntry);
    }
  }

  private shouldLog(level: LogLevel): boolean {
    const levels = { debug: 0, info: 1, warn: 2, error: 3 };
    return levels[level] >= levels[this.logLevel];
  }

  private logToConsole(entry: LogEntry) {
    const colors = {
      debug: '\x1b[36m', // Cyan
      info: '\x1b[32m',  // Green
      warn: '\x1b[33m',  // Yellow
      error: '\x1b[31m', // Red
    };
    const reset = '\x1b[0m';
    
    const prefix = `${colors[entry.level]}[${entry.level.toUpperCase()}]${reset}`;
    const timestamp = `\x1b[90m${entry.timestamp}${reset}`;
    
    console.log(`${timestamp} ${prefix} ${entry.message}`);
    
    if (entry.data) {
      console.log('Data:', entry.data);
    }
    
    if (entry.error) {
      console.error('Error:', entry.error);
    }
    
    if (entry.context) {
      console.log('Context:', entry.context);
    }
  }

  private logStructured(entry: LogEntry) {
    // Remove undefined values for cleaner JSON
    const cleanEntry = Object.fromEntries(
      Object.entries(entry).filter(([_, value]) => value !== undefined)
    );
    
    console.log(JSON.stringify(cleanEntry));
  }
}

// Export singleton instance
export const logger = new Logger();

// Set log level based on environment
if (import.meta.env.DEV) {
  logger.setLogLevel('debug');
} else {
  logger.setLogLevel('info');
}

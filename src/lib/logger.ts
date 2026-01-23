/**
 * Production-safe logging utility
 * 
 * All logs are automatically suppressed in production builds.
 * Use these instead of console.log/console.error for cleaner production output.
 */

const isDev = import.meta.env.DEV;

type LogLevel = 'info' | 'warn' | 'error' | 'debug';

/**
 * Structured logger that only outputs in development
 */
export const logger = {
  /**
   * Log informational messages (dev only)
   */
  info: (context: string, message: string, data?: unknown) => {
    if (isDev) {
      console.log(`[${context}] ${message}`, data !== undefined ? data : '');
    }
  },

  /**
   * Log warning messages (dev only)
   */
  warn: (context: string, message: string, data?: unknown) => {
    if (isDev) {
      console.warn(`[${context}] ⚠️ ${message}`, data !== undefined ? data : '');
    }
  },

  /**
   * Log error messages (dev only)
   */
  error: (context: string, message: string, error?: unknown) => {
    if (isDev) {
      console.error(`[${context}] ❌ ${message}`, error !== undefined ? error : '');
    }
  },

  /**
   * Log debug messages (dev only, verbose)
   */
  debug: (context: string, message: string, data?: unknown) => {
    if (isDev) {
      console.debug(`[${context}] 🔍 ${message}`, data !== undefined ? data : '');
    }
  },

  /**
   * Log expense automation events
   */
  expense: (action: string, details: { item?: string; amount?: number; result?: string }) => {
    if (isDev) {
      const { item, amount, result } = details;
      const amountStr = amount !== undefined ? `₹${amount.toFixed(2)}` : '';
      console.log(`[Expense Automation] ${action}: ${item || ''} ${amountStr} ${result || ''}`);
    }
  },

  /**
   * Log database operation events
   */
  db: (operation: string, table: string, details?: unknown) => {
    if (isDev) {
      console.log(`[DB:${operation}] ${table}`, details !== undefined ? details : '');
    }
  },

  /**
   * Log authentication events
   */
  auth: (event: string, details?: unknown) => {
    if (isDev) {
      console.log(`[Auth] ${event}`, details !== undefined ? details : '');
    }
  },

  /**
   * Create a scoped logger for a specific context
   */
  scope: (context: string) => ({
    info: (message: string, data?: unknown) => logger.info(context, message, data),
    warn: (message: string, data?: unknown) => logger.warn(context, message, data),
    error: (message: string, error?: unknown) => logger.error(context, message, error),
    debug: (message: string, data?: unknown) => logger.debug(context, message, data),
  }),
};

/**
 * Format an error for logging without exposing sensitive details
 */
export function formatError(error: unknown): string {
  if (error instanceof Error) {
    return error.message;
  }
  if (typeof error === 'string') {
    return error;
  }
  return 'Unknown error occurred';
}

export default logger;

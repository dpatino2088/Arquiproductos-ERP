/**
 * Utilities for extracting user-friendly error messages from Supabase errors
 */

import { PostgrestError } from '@supabase/supabase-js';

/**
 * Extract a user-friendly error message from a Supabase error
 * 
 * Handles:
 * - RLS (Row Level Security) errors
 * - Permission denied errors
 * - Constraint violations
 * - Generic PostgrestError
 * 
 * @param error - The error object (PostgrestError, Error, or unknown)
 * @returns A user-friendly error message
 */
export function getSupabaseErrorMessage(error: unknown): string {
  if (!error) {
    return 'Error desconocido';
  }

  // Handle PostgrestError (Supabase client errors)
  if (typeof error === 'object' && 'code' in error && 'message' in error) {
    const pgError = error as PostgrestError;
    
    // RLS (Row Level Security) errors
    if (pgError.code === '42501' || pgError.message?.includes('permission denied') || pgError.message?.includes('new row violates row-level security')) {
      return 'No tienes permisos para realizar esta acción. Por favor, contacta al administrador.';
    }
    
    // Constraint violations
    if (pgError.code === '23505') {
      return 'Ya existe un registro con estos datos.';
    }
    
    if (pgError.code === '23503') {
      return 'No se puede eliminar porque está siendo usado en otro lugar.';
    }
    
    // Use hint if available (often more descriptive)
    if (pgError.hint) {
      return pgError.hint;
    }
    
    // Use message if available
    if (pgError.message) {
      return pgError.message;
    }
    
    // Use code as fallback
    if (pgError.code) {
      return `Error ${pgError.code}`;
    }
  }
  
  // Handle standard Error objects
  if (error instanceof Error) {
    // Check for RLS-related messages
    if (error.message.includes('permission denied') || 
        error.message.includes('row-level security') ||
        error.message.includes('RLS')) {
      return 'No tienes permisos para realizar esta acción. Por favor, contacta al administrador.';
    }
    
    return error.message;
  }
  
  // Fallback
  return 'Error desconocido';
}

/**
 * Check if an error is an RLS (Row Level Security) error
 */
export function isRLSError(error: unknown): boolean {
  if (!error) return false;
  
  if (typeof error === 'object' && 'code' in error) {
    const pgError = error as PostgrestError;
    return pgError.code === '42501' || 
           pgError.message?.includes('permission denied') || 
           pgError.message?.includes('new row violates row-level security') ||
           pgError.message?.includes('row-level security');
  }
  
  if (error instanceof Error) {
    return error.message.includes('permission denied') || 
           error.message.includes('row-level security') ||
           error.message.includes('RLS');
  }
  
  return false;
}

/**
 * Safe error serializer to avoid [circular] errors when logging
 * Extracts only safe, serializable properties from error objects
 * 
 * @param e - Error object (Supabase error, Error, or any)
 * @returns Safe object with only serializable properties
 */
export function safeError(e: any): {
  message?: string;
  details?: string;
  hint?: string;
  code?: string;
  name?: string;
} {
  if (!e) return {};
  
  return {
    message: e?.message,
    details: e?.details,
    hint: e?.hint,
    code: e?.code,
    name: e?.name,
  };
}
/**
 * Normalizes UUID strings by removing invalid characters and whitespace.
 * Prevents 22P02 errors (invalid input syntax for type uuid) caused by
 * invisible characters, zero-width spaces, or hidden whitespace.
 * 
 * @param input - UUID string that may contain invalid characters
 * @returns Normalized UUID string or null if input is empty/invalid
 * 
 * @example
 * normalizeUUID(' 550e8400-e29b-41d4-a716-446655440000 ') 
 * // => '550e8400-e29b-41d4-a716-446655440000'
 * 
 * normalizeUUID('550e8400\u200B-e29b-41d4-a716-446655440000')
 * // => '550e8400-e29b-41d4-a716-446655440000'
 */
export function normalizeUUID(input?: string | null): string | null {
  if (!input) return null;

  // Remove all whitespace (including invisible characters)
  // Keep only valid UUID characters: 0-9, a-f, A-F, and hyphens
  const normalized = input
    .trim()
    .replace(/[^\da-fA-F-]/g, '');

  // Validate basic UUID format (8-4-4-4-12 hex groups)
  // This is a basic check, not strict validation
  const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  
  if (!uuidPattern.test(normalized)) {
    if (import.meta.env.DEV) {
      console.warn('⚠️ Invalid UUID format after normalization:', {
        original: input,
        normalized,
        originalLength: input.length,
        normalizedLength: normalized.length,
      });
    }
    return null;
  }

  return normalized;
}

/**
 * Normalizes multiple UUIDs from an array or object.
 * Useful for bulk operations or when processing multiple IDs.
 * 
 * @param inputs - Array of UUID strings or object with UUID values
 * @returns Normalized UUIDs (null values are filtered out for arrays)
 */
export function normalizeUUIDs(inputs: (string | null | undefined)[]): (string | null)[] {
  return inputs.map(normalizeUUID);
}

/**
 * Validates if a string is a valid UUID format (after normalization).
 * 
 * @param input - UUID string to validate
 * @returns true if valid UUID format, false otherwise
 */
export function isValidUUID(input?: string | null): boolean {
  return normalizeUUID(input) !== null;
}


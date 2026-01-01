import { supabase } from './supabase/client';

/**
 * Generates the next sequential number for a given document type
 * Format: PREFIX-NNNNNN (e.g., QT-000019, OR-000001)
 * 
 * @param prefix - The prefix for the number (e.g., 'QT' for Quotes, 'OR' for Orders)
 * @param tableName - The table name to query (e.g., 'Quotes', 'SaleOrders')
 * @param numberField - The field name that contains the number (e.g., 'quote_no', 'order_no')
 * @param organizationId - The organization ID to filter by
 * @returns The next sequential number (e.g., 'QT-000020')
 */
export async function generateNextSequentialNumber(
  prefix: string,
  tableName: string,
  numberField: string,
  organizationId: string
): Promise<string> {
  try {
    // Get the last number for this organization
    const { data, error } = await supabase
      .from(tableName)
      .select(numberField)
      .eq('organization_id', organizationId)
      .eq('deleted', false)
      .order('created_at', { ascending: false })
      .limit(1);

    if (error) throw error;

    let nextNumber = 1;
    if (data && data.length > 0) {
      const lastNo = (data[0] as any)[numberField];
      if (lastNo) {
        // Extract number from format PREFIX-NNNNNN
        const match = String(lastNo).match(new RegExp(`${prefix}-(\\d+)`));
        if (match) {
          nextNumber = parseInt(match[1], 10) + 1;
        }
      }
    }

    // Format: PREFIX-NNNNNN (6 digits)
    return `${prefix}-${String(nextNumber).padStart(6, '0')}`;
  } catch (err) {
    console.error(`Error generating ${prefix} number:`, err);
    // Fallback: use timestamp-based number
    return `${prefix}-${Date.now().toString().slice(-6)}`;
  }
}

/**
 * Generates the next Quote number
 */
export async function generateNextQuoteNumber(organizationId: string): Promise<string> {
  return generateNextSequentialNumber('QT', 'Quotes', 'quote_no', organizationId);
}

/**
 * Generates the next Order number
 */
export async function generateNextOrderNumber(organizationId: string): Promise<string> {
  return generateNextSequentialNumber('OR', 'SaleOrders', 'order_no', organizationId);
}









import { supabase } from './supabase/client';

/**
 * Generates the next sequential number for a given document type
 * Format: PREFIX-NNNNNN (e.g., QT-000019, OR-000001)
 * When dealerId is provided, numbering is per dealer (each dealer has independent sequence).
 *
 * @param prefix - The prefix for the number (e.g., 'QT' for Quotes)
 * @param tableName - The table name to query
 * @param numberField - The field name that contains the number
 * @param organizationId - The organization ID to filter by
 * @param dealerId - Optional. When set, sequence is per dealer (Quotes/Proposals)
 */
export async function generateNextSequentialNumber(
  prefix: string,
  tableName: string,
  numberField: string,
  organizationId: string,
  dealerId?: string | null
): Promise<string> {
  try {
    let query = supabase
      .from(tableName)
      .select(numberField)
      .eq('organization_id', organizationId)
      .eq('deleted', false);

    if (dealerId != null) {
      query = query.eq('dealer_id', dealerId);
    } else if (tableName === 'Quotes' || tableName === 'Proposals') {
      query = query.is('dealer_id', null);
    }

    const { data, error } = await query
      .order('created_at', { ascending: false })
      .limit(1);

    if (error) throw error;

    let nextNumber = 1;
    if (data && data.length > 0) {
      const lastNo = (data[0] as any)[numberField];
      if (lastNo) {
        const match = String(lastNo).match(new RegExp(`${prefix}-(\\d+)`));
        if (match && match[1] != null) {
          nextNumber = parseInt(match[1], 10) + 1;
        }
      }
    }

    return `${prefix}-${String(nextNumber).padStart(6, '0')}`;
  } catch (err) {
    console.error(`Error generating ${prefix} number:`, err);
    return `${prefix}-${Date.now().toString().slice(-6)}`;
  }
}

/**
 * Generates the next Quote number. Per dealer when dealerId is provided.
 */
export async function generateNextQuoteNumber(
  organizationId: string,
  dealerId?: string | null
): Promise<string> {
  return generateNextSequentialNumber('QT', 'Quotes', 'quote_no', organizationId, dealerId);
}

/**
 * Generates the next Order number
 */
export async function generateNextOrderNumber(organizationId: string): Promise<string> {
  return generateNextSequentialNumber('OR', 'SaleOrders', 'order_no', organizationId);
}

/** Minimum proposal number (PRO-0100, PRO-0101, ...) */
const PROPOSAL_NUMBER_START = 100;

/**
 * Generates the next Proposal number. Per dealer when dealerId is provided.
 * Format: PRO-NNNN starting at PRO-0100.
 */
export async function generateNextProposalNumber(
  organizationId: string,
  dealerId: string
): Promise<string> {
  try {
    const { data, error } = await supabase
      .from('Proposals')
      .select('proposal_no')
      .eq('organization_id', organizationId)
      .eq('dealer_id', dealerId)
      .eq('deleted', false)
      .not('proposal_no', 'is', null);

    if (error) throw error;

    let nextNumber = PROPOSAL_NUMBER_START;
    if (data && data.length > 0) {
      const numbers = (data as { proposal_no: string | null }[])
        .map((row: { proposal_no: string | null }) => {
          const no = row.proposal_no;
          if (!no) return null;
          const m = String(no).match(/^PRO-(\d+)$/i);
          return m ? parseInt(m[1], 10) : null;
        })
        .filter((n: number | null): n is number => n != null);
      if (numbers.length > 0) {
        nextNumber = Math.max(PROPOSAL_NUMBER_START, Math.max(...numbers) + 1);
      }
    }

    return `PRO-${String(nextNumber).padStart(4, '0')}`;
  } catch (err) {
    console.error('Error generating PRO number:', err);
    return `PRO-${String(PROPOSAL_NUMBER_START + Math.floor(Math.random() * 900)).padStart(4, '0')}`;
  }
}











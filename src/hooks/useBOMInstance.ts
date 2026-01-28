/**
 * React Hook for BOM Instance Management
 * 
 * Hook para gestionar BOMInstances y BOMInstanceLines desde QuoteLines.
 * Modelo A: BOMInstances SIEMPRE se crea desde QuoteLine (quote_line_id es NOT NULL).
 */

import { useState, useCallback } from 'react';
import { useOrganizationContext } from '../context/OrganizationContext';
import {
  getOrCreateBomInstanceForQuoteLine,
  getBomInstanceByQuoteLine,
  getBomInstanceLines,
  upsertBomLine,
  upsertBomLines,
  deleteBomInstance,
  deleteBomInstanceLine,
} from '../lib/bom/bomInstance';
import type { BOMInstance, BOMInstanceLine, GetOrCreateBomInstanceParams, UpsertBomLineParams, UpsertBomLinesParams } from '../types/bom';

/**
 * Hook para obtener o crear BOMInstance para un QuoteLine
 */
export function useBOMInstance() {
  const { activeOrganizationId } = useOrganizationContext();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const getOrCreate = useCallback(
    async (params: Omit<GetOrCreateBomInstanceParams, 'organizationId'>): Promise<BOMInstance> => {
      if (!activeOrganizationId) {
        throw new Error('No organization selected');
      }

      setLoading(true);
      setError(null);
      try {
        const instance = await getOrCreateBomInstanceForQuoteLine({
          ...params,
          organizationId: activeOrganizationId,
        });
        return instance;
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error getting or creating BOM instance';
        setError(errorMessage);
        throw err;
      } finally {
        setLoading(false);
      }
    },
    [activeOrganizationId]
  );

  const getByQuoteLine = useCallback(
    async (quoteLineId: string): Promise<BOMInstance | null> => {
      if (!activeOrganizationId) {
        throw new Error('No organization selected');
      }

      setLoading(true);
      setError(null);
      try {
        const instance = await getBomInstanceByQuoteLine(activeOrganizationId, quoteLineId);
        return instance;
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error fetching BOM instance';
        setError(errorMessage);
        throw err;
      } finally {
        setLoading(false);
      }
    },
    [activeOrganizationId]
  );

  const getLines = useCallback(
    async (bomInstanceId: string): Promise<BOMInstanceLine[]> => {
      if (!activeOrganizationId) {
        throw new Error('No organization selected');
      }

      setLoading(true);
      setError(null);
      try {
        const lines = await getBomInstanceLines(activeOrganizationId, bomInstanceId);
        return lines;
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error fetching BOM instance lines';
        setError(errorMessage);
        throw err;
      } finally {
        setLoading(false);
      }
    },
    [activeOrganizationId]
  );

  const upsertLine = useCallback(
    async (params: Omit<UpsertBomLineParams, 'organizationId'>): Promise<BOMInstanceLine> => {
      if (!activeOrganizationId) {
        throw new Error('No organization selected');
      }

      setLoading(true);
      setError(null);
      try {
        const line = await upsertBomLine({
          ...params,
          organizationId: activeOrganizationId,
        });
        return line;
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error upserting BOM line';
        setError(errorMessage);
        throw err;
      } finally {
        setLoading(false);
      }
    },
    [activeOrganizationId]
  );

  const upsertLines = useCallback(
    async (params: Omit<UpsertBomLinesParams, 'organizationId'>): Promise<BOMInstanceLine[]> => {
      if (!activeOrganizationId) {
        throw new Error('No organization selected');
      }

      setLoading(true);
      setError(null);
      try {
        const lines = await upsertBomLines({
          ...params,
          organizationId: activeOrganizationId,
        });
        return lines;
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error upserting BOM lines';
        setError(errorMessage);
        throw err;
      } finally {
        setLoading(false);
      }
    },
    [activeOrganizationId]
  );

  const remove = useCallback(
    async (bomInstanceId: string): Promise<void> => {
      if (!activeOrganizationId) {
        throw new Error('No organization selected');
      }

      setLoading(true);
      setError(null);
      try {
        await deleteBomInstance(activeOrganizationId, bomInstanceId);
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error deleting BOM instance';
        setError(errorMessage);
        throw err;
      } finally {
        setLoading(false);
      }
    },
    [activeOrganizationId]
  );

  const removeLine = useCallback(
    async (lineId: string): Promise<void> => {
      if (!activeOrganizationId) {
        throw new Error('No organization selected');
      }

      setLoading(true);
      setError(null);
      try {
        await deleteBomInstanceLine(activeOrganizationId, lineId);
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Error deleting BOM line';
        setError(errorMessage);
        throw err;
      } finally {
        setLoading(false);
      }
    },
    [activeOrganizationId]
  );

  return {
    getOrCreate,
    getByQuoteLine,
    getLines,
    upsertLine,
    upsertLines,
    remove,
    removeLine,
    loading,
    error,
  };
}

import { useState, useCallback } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';
import { useUIStore } from '../stores/ui-store';

export function useProposalActions() {
  useOrganizationContext();
  const [isActing, setIsActing] = useState(false);
  const addNotification = useUIStore((s) => s.addNotification);

  const acceptProposal = useCallback(
    async (proposalId: string, userId: string, userName?: string) => {
      setIsActing(true);
      try {
        const { data, error } = await supabase.rpc('accept_proposal', {
          p_proposal_id: proposalId,
          p_user_id: userId,
          p_user_name: userName ?? null,
        });
        if (error) throw error;
        addNotification({ type: 'success', title: 'Accepted', message: 'Proposal accepted.' });
        return data;
      } catch (err: unknown) {
        const msg = err instanceof Error ? err.message : 'Failed to accept proposal';
        addNotification({ type: 'error', title: 'Error', message: msg });
        throw err;
      } finally {
        setIsActing(false);
      }
    },
    [addNotification]
  );

  const declineProposal = useCallback(
    async (proposalId: string, userId: string, reason?: string, userName?: string) => {
      setIsActing(true);
      try {
        const { data, error } = await supabase.rpc('decline_proposal', {
          p_proposal_id: proposalId,
          p_user_id: userId,
          p_reason: reason ?? null,
          p_user_name: userName ?? null,
        });
        if (error) throw error;
        addNotification({ type: 'success', title: 'Declined', message: 'Proposal declined.' });
        return data;
      } catch (err: unknown) {
        const msg = err instanceof Error ? err.message : 'Failed to decline proposal';
        addNotification({ type: 'error', title: 'Error', message: msg });
        throw err;
      } finally {
        setIsActing(false);
      }
    },
    [addNotification]
  );

  return { acceptProposal, declineProposal, isActing };
}

export function useSOActions() {
  useOrganizationContext();
  const [isActing, setIsActing] = useState(false);
  const addNotification = useUIStore((s) => s.addNotification);

  const createSOFromQuote = useCallback(
    async (quoteId: string, userId: string, userName?: string) => {
      setIsActing(true);
      try {
        const { data, error } = await supabase.rpc('create_sales_order_from_quote', {
          p_quote_id: quoteId,
          p_user_id: userId,
          p_user_name: userName ?? null,
        });
        if (error) throw error;
        addNotification({ type: 'success', title: 'Sales Order Created', message: 'Sales order created from quote.' });
        return data as { sales_order_id: string; so_number: string };
      } catch (err: unknown) {
        const msg =
          err && typeof err === 'object' && 'message' in err && typeof (err as { message: unknown }).message === 'string'
            ? (err as { message: string }).message
            : err instanceof Error
              ? err.message
              : 'Failed to create sales order';
        addNotification({ type: 'error', title: 'Error', message: msg });
        throw err;
      } finally {
        setIsActing(false);
      }
    },
    [addNotification]
  );

  const transitionSOStatus = useCallback(
    async (soId: string, newStatus: string, userId: string, userName?: string) => {
      setIsActing(true);
      try {
        const { data, error } = await supabase.rpc('transition_so_status', {
          p_so_id: soId,
          p_new_status: newStatus,
          p_user_id: userId,
          p_user_name: userName ?? null,
        });
        if (error) throw error;
        addNotification({ type: 'success', title: 'Status Updated', message: `Sales order status updated to ${newStatus}.` });
        return data;
      } catch (err: unknown) {
        const msg = err instanceof Error ? err.message : 'Failed to update status';
        addNotification({ type: 'error', title: 'Error', message: msg });
        throw err;
      } finally {
        setIsActing(false);
      }
    },
    [addNotification]
  );

  const createMO = useCallback(
    async (soId: string, userId: string, soLineId?: string, userName?: string) => {
      setIsActing(true);
      try {
        const { data, error } = await supabase.rpc('create_manufacturing_order', {
          p_sales_order_id: soId,
          p_user_id: userId,
          p_sales_order_line_id: soLineId ?? null,
          p_user_name: userName ?? null,
        });
        if (error) throw error;
        const mo = data as { mo_id?: string; mo_number?: string; existing?: boolean } | null;
        if (mo?.mo_id && !mo?.existing) {
          // Compatibility fallback: if backend RPC does not auto-generate BOM yet,
          // generate it explicitly after MO creation.
          const { data: bomData, error: bomError } = await supabase.rpc('generate_bom_for_manufacturing_order', {
            p_manufacturing_order_id: mo.mo_id,
          });
          if (bomError) throw new Error(`MO created but BOM generation failed: ${bomError.message}`);
          const bomOk = Boolean((bomData as { ok?: boolean } | null)?.ok);
          if (!bomOk) {
            const bomErrors = (bomData as { errors?: string[] } | null)?.errors ?? [];
            throw new Error(`MO created but BOM generation failed: ${bomErrors.join('; ') || 'Unknown error'}`);
          }
        }
        addNotification({
          type: 'success',
          title: mo?.existing ? 'MO Exists' : 'MO Created',
          message: mo?.existing ? `Using existing manufacturing order ${mo.mo_number ?? ''}.` : 'Manufacturing order created.',
        });
        return data as { mo_id: string; mo_number: string; existing?: boolean };
      } catch (err: unknown) {
        const msg = err instanceof Error ? err.message : 'Failed to create manufacturing order';
        addNotification({ type: 'error', title: 'Error', message: msg });
        throw err;
      } finally {
        setIsActing(false);
      }
    },
    [addNotification]
  );

  return { createSOFromQuote, transitionSOStatus, createMO, isActing };
}

export function useMOActions() {
  useOrganizationContext();
  const [isActing, setIsActing] = useState(false);
  const addNotification = useUIStore((s) => s.addNotification);

  const transitionMOStatus = useCallback(
    async (moId: string, newStatus: string, userId: string, userName?: string) => {
      setIsActing(true);
      try {
        const { data, error } = await supabase.rpc('transition_mo_status', {
          p_mo_id: moId,
          p_new_status: newStatus,
          p_user_id: userId,
          p_user_name: userName ?? null,
        });
        if (error) throw error;
        addNotification({ type: 'success', title: 'Status Updated', message: `Manufacturing order status updated to ${newStatus}.` });
        return data;
      } catch (err: unknown) {
        const msg = err instanceof Error ? err.message : 'Failed to update MO status';
        addNotification({ type: 'error', title: 'Error', message: msg });
        throw err;
      } finally {
        setIsActing(false);
      }
    },
    [addNotification]
  );

  return { transitionMOStatus, isActing };
}

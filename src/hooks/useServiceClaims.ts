import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase/client';
import { useOrganizationContext } from '../context/OrganizationContext';
import { useAuth } from './useAuth';

export type ClaimStatus = 'draft' | 'under_review' | 'approved' | 'in_progress' | 'resolved' | 'closed' | 'rejected';
export type ClaimType = 'defect' | 'damage' | 'wrong_size' | 'wrong_color' | 'missing_parts' | 'other';
export type ClaimPriority = 'low' | 'medium' | 'high' | 'urgent';
export type ClaimResolution = 'repair' | 'replace' | 'credit' | 'none';

export interface ServiceClaim {
  id: string;
  claim_no: string;
  organization_id: string;
  dealer_id: string | null;
  sales_order_id: string | null;
  status: ClaimStatus;
  claim_type: ClaimType;
  priority: ClaimPriority;
  description: string | null;
  resolution_type: ClaimResolution;
  resolution_notes: string | null;
  resolution_mo_id: string | null;
  reported_by: string | null;
  assigned_to: string | null;
  chargeable: boolean;
  created_at: string;
  updated_at: string | null;
  resolved_at: string | null;
  deleted: boolean;
  SalesOrders?: { id: string; sales_order_no: string } | null;
  Dealers?: { dealer_name: string } | null;
  ReportedByUser?: { display_name: string } | null;
  AssignedToUser?: { display_name: string } | null;
}

export interface ServiceClaimLine {
  id: string;
  claim_id: string;
  sale_order_line_id: string | null;
  configured_product_id: string | null;
  description: string | null;
  qty_affected: number;
  claim_reason: string | null;
  SaleOrderLine?: {
    description: string | null;
    product_type: string | null;
    quantity: number;
    unit_price: number | null;
    line_total: number | null;
  } | null;
  ConfiguredProduct?: {
    config_snapshot: Record<string, any>;
    width_mm: number | null;
    height_mm: number | null;
  } | null;
}

export interface ServiceClaimAttachment {
  id: string;
  claim_id: string;
  file_name: string;
  file_path: string;
  uploaded_by: string | null;
  created_at: string;
}

export function useServiceClaims() {
  const { activeOrganizationId } = useOrganizationContext();
  const [claims, setClaims] = useState<ServiceClaim[]>([]);
  const [loading, setLoading] = useState(true);

  const fetchClaims = useCallback(async () => {
    if (!activeOrganizationId) return;
    setLoading(true);
    try {
      const { data: rawClaims, error } = await supabase
        .from('ServiceClaims')
        .select(`
          id, claim_no, organization_id, dealer_id, sales_order_id,
          status, claim_type, priority, description,
          resolution_type, resolution_notes, resolution_mo_id,
          reported_by, assigned_to, chargeable,
          created_at, updated_at, resolved_at, deleted
        `)
        .eq('organization_id', activeOrganizationId)
        .eq('deleted', false)
        .order('created_at', { ascending: false });

      if (error) {
        console.warn('[useServiceClaims] fetch error:', error);
        setClaims([]);
        setLoading(false);
        return;
      }

      const rows = (rawClaims ?? []) as any[];
      const soIds = [...new Set(rows.map((r) => r.sales_order_id).filter(Boolean))];
      const dealerIds = [...new Set(rows.map((r) => r.dealer_id).filter(Boolean))];

      const soMap = new Map<string, { id: string; sales_order_no: string }>();
      const dealerMap = new Map<string, { dealer_name: string }>();

      if (soIds.length > 0) {
        const { data: sos } = await supabase
          .from('SalesOrders')
          .select('id, sales_order_no')
          .in('id', soIds);
        (sos ?? []).forEach((s: any) => soMap.set(s.id, s));
      }
      if (dealerIds.length > 0) {
        const { data: dealers } = await supabase
          .from('Dealers')
          .select('id, dealer_name')
          .in('id', dealerIds);
        (dealers ?? []).forEach((d: any) => dealerMap.set(d.id, d));
      }

      setClaims(rows.map((r) => ({
        ...r,
        SalesOrders: r.sales_order_id ? soMap.get(r.sales_order_id) ?? null : null,
        Dealers: r.dealer_id ? dealerMap.get(r.dealer_id) ?? null : null,
      })) as ServiceClaim[]);
    } catch (err) {
      console.warn('[useServiceClaims] unexpected error:', err);
      setClaims([]);
    }
    setLoading(false);
  }, [activeOrganizationId]);

  useEffect(() => { fetchClaims(); }, [fetchClaims]);

  return { claims, loading, refetch: fetchClaims };
}

export function useServiceClaimDetail(claimId: string | null) {
  const { activeOrganizationId } = useOrganizationContext();
  const [claim, setClaim] = useState<ServiceClaim | null>(null);
  const [lines, setLines] = useState<ServiceClaimLine[]>([]);
  const [attachments, setAttachments] = useState<ServiceClaimAttachment[]>([]);
  const [timeline, setTimeline] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  const fetchDetail = useCallback(async () => {
    if (!claimId || !activeOrganizationId) return;
    setLoading(true);

    const [claimRes, linesRes, attachRes, timelineRes] = await Promise.all([
      supabase
        .from('ServiceClaims')
        .select(`
          id, claim_no, organization_id, dealer_id, sales_order_id,
          status, claim_type, priority, description,
          resolution_type, resolution_notes, resolution_mo_id,
          reported_by, assigned_to, chargeable,
          created_at, updated_at, resolved_at, deleted,
          SalesOrders:sales_order_id (id, sales_order_no),
          Dealers:dealer_id (dealer_name)
        `)
        .eq('id', claimId)
        .eq('deleted', false)
        .single(),
      supabase
        .from('ServiceClaimLines')
        .select('id, claim_id, sale_order_line_id, configured_product_id, description, qty_affected, claim_reason')
        .eq('claim_id', claimId)
        .eq('deleted', false),
      supabase
        .from('ServiceClaimAttachments')
        .select('id, claim_id, file_name, file_path, uploaded_by, created_at')
        .eq('claim_id', claimId)
        .eq('deleted', false)
        .order('created_at', { ascending: false }),
      supabase
        .from('ActivityTimeline')
        .select('id, action, description, user_name, created_at, metadata')
        .eq('entity_type', 'service_claim')
        .eq('entity_id', claimId)
        .order('created_at', { ascending: false }),
    ]);

    if (claimRes.data) setClaim(claimRes.data as unknown as ServiceClaim);
    if (linesRes.data) {
      const rawLines = linesRes.data as any[];
      const solIds = rawLines.map((l: any) => l.sale_order_line_id).filter(Boolean);
      const cpIds = rawLines.map((l: any) => l.configured_product_id).filter(Boolean);

      const solMap = new Map<string, any>();
      const cpMap = new Map<string, any>();

      if (solIds.length > 0) {
        const { data: sols } = await supabase
          .from('SaleOrderLines')
          .select('id, description, product_type, quantity, unit_price, line_total')
          .in('id', solIds);
        (sols ?? []).forEach((s: any) => solMap.set(s.id, s));
      }
      if (cpIds.length > 0) {
        const { data: cps } = await supabase
          .from('ConfiguredProducts')
          .select('id, config_snapshot, width_mm, height_mm')
          .in('id', cpIds);
        (cps ?? []).forEach((c: any) => cpMap.set(c.id, c));
      }

      setLines(rawLines.map((l: any) => ({
        ...l,
        SaleOrderLine: l.sale_order_line_id ? solMap.get(l.sale_order_line_id) ?? null : null,
        ConfiguredProduct: l.configured_product_id ? cpMap.get(l.configured_product_id) ?? null : null,
      })));
    }
    if (attachRes.data) setAttachments(attachRes.data as ServiceClaimAttachment[]);
    if (timelineRes.data) setTimeline(timelineRes.data);
    setLoading(false);
  }, [claimId, activeOrganizationId]);

  useEffect(() => { fetchDetail(); }, [fetchDetail]);

  return { claim, lines, attachments, timeline, loading, refetch: fetchDetail };
}

export function useClaimActions() {
  const { user } = useAuth();
  const [isActing, setIsActing] = useState(false);

  const transitionStatus = useCallback(async (claimId: string, newStatus: ClaimStatus) => {
    setIsActing(true);
    try {
      if (user?.name) {
        await supabase.rpc('set_config', { setting_name: 'app.current_user_name', setting_value: user.name }).catch(() => {});
      }
      const updates: Record<string, any> = { status: newStatus };
      if (newStatus === 'resolved' || newStatus === 'closed') {
        updates.resolved_at = new Date().toISOString();
      }
      const { error } = await supabase
        .from('ServiceClaims')
        .update(updates)
        .eq('id', claimId);
      if (error) throw error;
    } finally {
      setIsActing(false);
    }
  }, [user]);

  const updateResolution = useCallback(async (claimId: string, resolutionType: ClaimResolution, notes: string, moId?: string) => {
    setIsActing(true);
    try {
      const updates: Record<string, any> = {
        resolution_type: resolutionType,
        resolution_notes: notes,
      };
      if (moId) updates.resolution_mo_id = moId;
      const { error } = await supabase
        .from('ServiceClaims')
        .update(updates)
        .eq('id', claimId);
      if (error) throw error;
    } finally {
      setIsActing(false);
    }
  }, []);

  const createServiceMO = useCallback(async (
    claimId: string,
    moType: 'rework' | 'replacement',
  ): Promise<{ mo_id: string; mo_number: string } | null> => {
    if (!user) return null;
    setIsActing(true);
    try {
      if (user.name) {
        await supabase.rpc('set_config', { setting_name: 'app.current_user_name', setting_value: user.name }).catch(() => {});
      }
      const { data, error } = await supabase.rpc('create_service_mo', {
        p_claim_id: claimId,
        p_mo_type: moType,
        p_user_id: user.id,
        p_user_name: user.name ?? null,
      });
      if (error) throw error;
      const result = data as { ok?: boolean; mo_id?: string; mo_number?: string } | null;
      if (!result?.ok) throw new Error('Failed to create service MO');
      return { mo_id: result.mo_id!, mo_number: result.mo_number! };
    } finally {
      setIsActing(false);
    }
  }, [user]);

  return { transitionStatus, updateResolution, createServiceMO, isActing };
}

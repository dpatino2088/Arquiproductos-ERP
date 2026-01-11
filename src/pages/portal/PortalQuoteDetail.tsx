/**
 * Portal Quote Detail Component
 * 
 * Shows quote details with role-based actions:
 * - member: can edit own quotes (draft only), cannot approve
 * - member_manager: can approve/reject, can edit
 */

import { useEffect, useState } from 'react';
import { supabase } from '../../lib/supabase/client';
import { router } from '../../lib/router';
import { useAuthStore } from '../../stores/auth-store';
import {
  canEditQuote,
  canApproveQuote,
  normalizeRole,
  type CompanyPortalRole,
  type PortalQuote,
} from '../../portal/portalAccess';
import { Edit, CheckCircle, XCircle, ArrowLeft, Loader2 } from 'lucide-react';

interface PortalUser {
  id: string;
  company_id: string;
  portal_user_role: CompanyPortalRole | null;
}

export default function PortalQuoteDetail() {
  // Get quote ID from URL - adjust based on your routing
  const quoteId = window.location.pathname.split('/').pop() || '';
  const { user } = useAuthStore();
  const [quote, setQuote] = useState<PortalQuote | null>(null);
  const [portalUser, setPortalUser] = useState<PortalUser | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [approving, setApproving] = useState(false);

  // Load portal user info
  useEffect(() => {
    const loadPortalUser = async () => {
      if (!user?.id) {
        setLoading(false);
        return;
      }

      try {
        // IMPORTANT: Use 'role' and 'status' columns (matches actual DB schema)
        const { data, error: userError } = await supabase
          .from('CompanyPortalUsers')
          .select('id, company_id, role, status')
          .eq('user_id', user.id)
          .eq('deleted', false)
          .in('status', ['active', 'invited'])
          .maybeSingle();

        if (userError) {
          console.error('[PortalQuoteDetail] CompanyPortalUsers lookup error', {
            message: userError.message,
            details: userError.details,
            hint: userError.hint,
            code: userError.code,
          });
          throw userError;
        }

        if (data) {
          // Use 'role' column, fallback to 'portal_user_role' for legacy data
          const rawRole = data.role || data.portal_user_role;
          setPortalUser({
            id: data.id,
            company_id: data.company_id,
            portal_user_role: normalizeRole(rawRole || 'member'),
          });
        }
      } catch (err: any) {
        console.error('Error loading portal user:', err);
        setError(err.message || 'Failed to load portal user');
      }
    };

    loadPortalUser();
  }, [user]);

  // Load quote
  useEffect(() => {
    const loadQuote = async () => {
      if (!id || !portalUser) {
        setLoading(false);
        return;
      }

      try {
        setLoading(true);
        setError(null);

        const { data, error: quoteError } = await supabase
          .from('Quotes')
          .select('*')
          .eq('id', quoteId)
          .eq('deleted', false)
          .maybeSingle();

        if (quoteError) throw quoteError;

      if (!data || !quoteId) {
        setError('Quote not found');
        return;
      }

        // Check if user can view this quote
        if (!canViewQuote(portalUser.portal_user_role, data, portalUser.id)) {
          setError('You do not have permission to view this quote');
          return;
        }

        setQuote(data as PortalQuote);
      } catch (err: any) {
        console.error('Error loading quote:', err);
        setError(err.message || 'Failed to load quote');
      } finally {
        setLoading(false);
      }
    };

    loadQuote();
  }, [quoteId, portalUser]);

  const handleApprove = async (action: 'approve' | 'reject') => {
    if (!quote || !portalUser || approving) return;

    if (!canApproveQuote(portalUser.portal_user_role, quote)) {
      alert('You do not have permission to approve/reject this quote');
      return;
    }

    const confirmed = window.confirm(
      `Are you sure you want to ${action} this quote?`
    );

    if (!confirmed) return;

    setApproving(true);
    try {
      const { data, error: rpcError } = await supabase.rpc('approve_quote_portal', {
        p_quote_id: quote.id,
        p_action: action,
      });

      if (rpcError) throw rpcError;

      if (data?.success) {
        // Reload quote to get updated status
        const { data: updatedQuote, error: reloadError } = await supabase
          .from('Quotes')
          .select('*')
          .eq('id', quote.id)
          .eq('deleted', false)
          .maybeSingle();

        if (reloadError) throw reloadError;
        if (updatedQuote) {
          setQuote(updatedQuote as PortalQuote);
        }

        alert(`Quote ${action}d successfully`);
      } else {
        throw new Error(data?.error || 'Failed to approve/reject quote');
      }
    } catch (err: any) {
      console.error('Error approving quote:', err);
      alert(err.message || 'Failed to approve/reject quote');
    } finally {
      setApproving(false);
    }
  };

  if (loading) {
    return (
      <div className="p-6">
        <div className="flex items-center justify-center py-12">
          <div className="text-center">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary mx-auto mb-4"></div>
            <p className="text-sm text-gray-500">Loading quote...</p>
          </div>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="p-6">
        <div className="bg-red-50 border border-red-200 rounded-lg p-4">
          <p className="text-sm text-red-800 font-medium mb-2">Error</p>
          <p className="text-sm text-red-700">{error}</p>
        </div>
        <button
          onClick={() => window.history.back()}
          className="mt-4 flex items-center gap-2 text-sm text-gray-600 hover:text-gray-900"
        >
          <ArrowLeft className="w-4 h-4" />
          Back to Quotes
        </button>
      </div>
    );
  }

  if (!quote || !portalUser) {
    return (
      <div className="p-6">
        <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
          <p className="text-sm text-yellow-800">Quote not found or you do not have access.</p>
        </div>
      </div>
    );
  }

  const canEdit = canEditQuote(portalUser.portal_user_role, quote, portalUser.id);
  const canApprove = canApproveQuote(portalUser.portal_user_role, quote);

  return (
    <div className="p-6">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <button
            onClick={() => window.history.back()}
            className="flex items-center gap-2 text-sm text-gray-600 hover:text-gray-900 mb-2"
          >
            <ArrowLeft className="w-4 h-4" />
            Back to Quotes
          </button>
          <h1 className="text-xl font-semibold text-gray-900">{quote.quote_no}</h1>
          <p className="text-sm text-gray-500 mt-1">
            Status: <span className="font-medium capitalize">{quote.status}</span>
          </p>
        </div>
        <div className="flex items-center gap-2">
          {canEdit && (
            <button
              onClick={() => {
                window.location.href = `/portal/quotes/${quote.id}/edit`;
              }}
              className="flex items-center gap-2 px-4 py-2 bg-gray-100 text-gray-700 rounded-md hover:bg-gray-200 transition-colors"
            >
              <Edit className="w-4 h-4" />
              Edit
            </button>
          )}
          {canApprove && (
            <>
              <button
                onClick={() => handleApprove('approve')}
                disabled={approving}
                className="flex items-center gap-2 px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {approving ? (
                  <Loader2 className="w-4 h-4 animate-spin" />
                ) : (
                  <CheckCircle className="w-4 h-4" />
                )}
                Approve
              </button>
              <button
                onClick={() => handleApprove('reject')}
                disabled={approving}
                className="flex items-center gap-2 px-4 py-2 bg-red-600 text-white rounded-md hover:bg-red-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {approving ? (
                  <Loader2 className="w-4 h-4 animate-spin" />
                ) : (
                  <XCircle className="w-4 h-4" />
                )}
                Reject
              </button>
            </>
          )}
        </div>
      </div>

      {/* Quote Details */}
      <div className="bg-white border border-gray-200 rounded-lg p-6">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Quote Number</label>
            <p className="text-sm text-gray-900">{quote.quote_no}</p>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Status</label>
            <p className="text-sm text-gray-900 capitalize">{quote.status}</p>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Created At</label>
            <p className="text-sm text-gray-900">
              {quote.created_at
                ? new Date(quote.created_at).toLocaleString()
                : 'N/A'}
            </p>
          </div>
          {/* Add more quote fields as needed */}
        </div>
      </div>

      {/* Note: Add quote lines, customer info, etc. as needed */}
    </div>
  );
}

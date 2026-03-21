/**
 * Portal Quotes List Component
 * 
 * Displays quotes for portal users with role-based access:
 * - member: sees only own quotes
 * - member_manager: sees all company quotes
 */

import { useEffect, useState } from 'react';
import { supabase } from '../../lib/supabase/client';
import { formatDate } from '../../lib/utils';
import { useAuthStore } from '../../stores/auth-store';
import { useUIStore } from '../../stores/ui-store';
import { 
  canCreateQuote, 
  canViewQuote, 
  normalizeRole,
  type CompanyPortalRole,
  type PortalQuote 
} from '../../portal/portalAccess';
import { Plus, FileText, CheckCircle, XCircle, Clock } from 'lucide-react';

interface PortalUser {
  id: string;
  dealer_id: string;
  portal_user_role: CompanyPortalRole | null;
}

export default function PortalQuotesList() {
  const { user } = useAuthStore();
  const [quotes, setQuotes] = useState<PortalQuote[]>([]);
  const [portalUser, setPortalUser] = useState<PortalUser | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const setGlobalLoading = useUIStore((s) => s.setGlobalLoading);

  useEffect(() => {
    setGlobalLoading(loading);
    return () => setGlobalLoading(false);
  }, [loading, setGlobalLoading]);

  // Load portal user info
  useEffect(() => {
    const loadPortalUser = async () => {
      if (!user?.id) {
        setLoading(false);
        return;
      }

      try {
        const { data, error: userError } = await supabase
          .from('DealerUsers')
          // IMPORTANT: Use 'role' and 'status' columns (matches actual DB schema)
          .select('id, dealer_id, role, status')
          .eq('user_id', user.id)
          .eq('deleted', false)
          .in('status', ['active', 'invited'])
          .maybeSingle();

        if (userError) {
          console.error('[PortalQuotesList] DealerUsers lookup error', {
            message: userError.message,
            details: userError.details,
            hint: userError.hint,
            code: userError.code,
          });
          throw userError;
        }

        if (data) {
          // Use 'role' column (matches actual DB schema)
          const rawRole = data.role;
          setPortalUser({
            id: data.id,
            dealer_id: data.dealer_id,
            portal_user_role: normalizeRole(rawRole || 'member'),
          });
        }
      } catch (err: any) {
        console.error('Error loading portal user:', err);
        setError(err.message || 'Failed to load portal user');
      } finally {
        setLoading(false);
      }
    };

    loadPortalUser();
  }, [user]);

  // Load quotes
  useEffect(() => {
    const loadQuotes = async () => {
      if (!portalUser || !user?.id) {
        setQuotes([]);
        return;
      }

      try {
        setLoading(true);
        setError(null);

        // RLS will automatically filter based on role
        const { data, error: quotesError } = await supabase
          .from('Quotes')
          .select('id, quote_no, status, dealer_id, created_by_user_id, created_at')
          .eq('dealer_id', portalUser.dealer_id)
          .eq('deleted', false)
          .order('created_at', { ascending: false });

        if (quotesError) throw quotesError;

        // Filter by role (additional client-side check)
        const filteredQuotes = (data || []).filter((quote: any) =>
          canViewQuote(portalUser.portal_user_role, quote, user?.id)
        ) as PortalQuote[];

        setQuotes(filteredQuotes);
      } catch (err: any) {
        console.error('Error loading quotes:', err);
        setError(err.message || 'Failed to load quotes');
        setQuotes([]);
      } finally {
        setLoading(false);
      }
    };

    loadQuotes();
  }, [portalUser, user]);

  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'approved':
        return <CheckCircle className="w-4 h-4 text-green-600" />;
      case 'rejected':
        return <XCircle className="w-4 h-4 text-red-600" />;
      case 'sent':
        return <Clock className="w-4 h-4 text-yellow-600" />;
      default:
        return <FileText className="w-4 h-4 text-gray-600" />;
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'approved':
        return 'bg-green-50 text-green-700 border-green-200';
      case 'rejected':
        return 'bg-red-50 text-red-700 border-red-200';
      case 'sent':
        return 'bg-yellow-50 text-yellow-700 border-yellow-200';
      default:
        return 'bg-gray-50 text-gray-700 border-gray-200';
    }
  };

  if (loading) return <div className="p-6" />;

  if (error) {
    return (
      <div className="p-6">
        <div className="bg-red-50 border border-red-200 rounded-lg p-4">
          <p className="text-sm text-red-800 font-medium mb-2">Error</p>
          <p className="text-sm text-red-700">{error}</p>
        </div>
      </div>
    );
  }

  if (!portalUser) {
    return (
      <div className="p-6">
        <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
          <p className="text-sm text-yellow-800">You are not a portal user or your account is not active.</p>
        </div>
      </div>
    );
  }

  const canCreate = canCreateQuote(portalUser.portal_user_role);

  return (
    <div className="p-6">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-gray-900 mb-1">Quotes</h1>
          <p className="text-sm text-gray-500">
            {portalUser.portal_user_role === 'dealer_manager'
              ? 'All company quotes'
              : 'Your quotes'}
          </p>
        </div>
        {canCreate && (
          <button
            onClick={() => {
              // Navigate to create quote page
              window.location.href = '/portal/quotes/new';
            }}
            className="flex items-center gap-2 px-4 py-2 bg-primary text-white rounded-md hover:opacity-90 transition-opacity"
          >
            <Plus className="w-4 h-4" />
            New Quote
          </button>
        )}
      </div>

      {/* Quotes List */}
      {quotes.length === 0 ? (
        <div className="bg-white border border-gray-200 rounded-lg p-12 text-center">
          <FileText className="w-12 h-12 text-gray-400 mx-auto mb-4" />
          <p className="text-gray-600 mb-2">No quotes found</p>
          <p className="text-sm text-gray-500">
            {canCreate
              ? 'Create your first quote to get started'
              : 'Quotes will appear here once they are created'}
          </p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {quotes.map((quote) => (
            <div
              key={quote.id}
              onClick={() => {
                // Navigate to quote detail
                window.location.href = `/portal/quotes/${quote.id}`;
              }}
              className="bg-white border border-gray-200 rounded-lg p-6 hover:shadow-lg transition-shadow cursor-pointer"
            >
              <div className="flex items-start justify-between mb-4">
                <div>
                  <h3 className="text-lg font-semibold text-gray-900">{quote.quote_no}</h3>
                  <p className="text-xs text-gray-500 mt-1">
                    {quote.created_at
                      ? formatDate(quote.created_at)
                      : 'N/A'}
                  </p>
                </div>
                <div className={`flex items-center gap-1 px-2 py-1 rounded border ${getStatusColor(quote.status)}`}>
                  {getStatusIcon(quote.status)}
                  <span className="text-xs font-medium capitalize">{quote.status}</span>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

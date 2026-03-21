import { useEffect, useMemo, useState } from 'react';
import { formatDate } from '../../lib/utils';
import { Building, Building2, FileText, Store } from 'lucide-react';
import DetailPageLayout from '../../components/shared/DetailPageLayout';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { useDealerFinancialDetail } from '../../hooks/useDealerFinancialDetail';
import { useDealerFinancialTimeline } from '../../hooks/useDealerFinancialTimeline';
import { formatCurrency } from '../../lib/utils';
import TimelineView from '../../components/shared/TimelineView';
import DealerTermsTab from '../settings/DealerTermsTab';
import { supabase } from '../../lib/supabase/client';
import { router } from '../../lib/router';
import { withReturnTo } from '../../lib/navigation/returnTo';

const PARTNERS_SUBMODULES = [
  { id: 'dealers', label: 'Dealers', href: '/partners/dealers', icon: Building },
  { id: 'vendors', label: 'Vendors', href: '/partners/vendors', icon: Store },
  { id: 'manufacturers', label: 'Manufacturers', href: '/partners/manufacturers', icon: Building2 },
];

interface DealerUserRow {
  id: string;
  display_name: string | null;
  email: string | null;
  role_code: string | null;
  status: string | null;
  created_at: string | null;
}

function getDealerIdFromPath(): string | null {
  const match = window.location.pathname.match(/\/partners\/dealers\/([^/]+)/);
  return match ? match[1] : null;
}

export default function DealerDetail() {
  const dealerId = getDealerIdFromPath();
  const { registerSubmodules } = useSubmoduleNav();
  const { activeOrganizationId } = useOrganizationContext();
  const [activeTab, setActiveTab] = useState('profile');
  const [users, setUsers] = useState<DealerUserRow[]>([]);
  const [usersLoading, setUsersLoading] = useState(true);
  const [usersError, setUsersError] = useState<string | null>(null);

  useEffect(() => {
    registerSubmodules('Partners', PARTNERS_SUBMODULES);
  }, [registerSubmodules]);

  const { detail, isInitialLoading, error } = useDealerFinancialDetail(dealerId);
  const { events, isInitialLoading: timelineLoading } = useDealerFinancialTimeline(dealerId);

  useEffect(() => {
    if (!activeOrganizationId || !dealerId) {
      setUsers([]);
      setUsersLoading(false);
      return;
    }
    setUsersLoading(true);
    setUsersError(null);
    supabase
      .from('AppUsers')
      .select('id, display_name, email, role_code, status, created_at')
      .eq('organization_id', activeOrganizationId)
      .eq('dealer_id', dealerId)
      .eq('user_type', 'dealer')
      .eq('deleted', false)
      .order('created_at', { ascending: false })
      .then(({ data, error: usersErr }: { data: DealerUserRow[] | null; error: unknown }) => {
        if (usersErr) {
          setUsersError(usersErr instanceof Error ? usersErr.message : 'Failed to load dealer users');
          setUsers([]);
        } else {
          setUsers(data ?? []);
        }
      })
      .finally(() => setUsersLoading(false));
  }, [activeOrganizationId, dealerId]);

  const tabs = useMemo(() => [
    { id: 'profile', label: 'Profile' },
    { id: 'users', label: `Users (${users.length})` },
    { id: 'terms', label: 'Terms' },
    { id: 'financial', label: 'Financial Summary' },
    { id: 'timeline', label: 'Timeline' },
  ], [users.length]);

  if (!dealerId) {
    return (
      <div className="p-6">
        <div className="bg-red-50 border border-red-200 rounded-lg p-4 text-sm text-red-700">Invalid dealer route.</div>
      </div>
    );
  }

  return (
    <DetailPageLayout
      title={detail?.dealer_name ?? 'Dealer Detail'}
      subtitle={detail?.dealer_no ? `Dealer #${detail.dealer_no}` : 'Dealer 360'}
      status={null}
      tabs={tabs}
      activeTab={activeTab}
      onTabChange={setActiveTab}
      onBack={() => router.navigate('/partners/dealers')}
      contentClassName="pt-2 pb-6"
      actions={(
        <button
          type="button"
          onClick={() => router.navigate(withReturnTo(`/financials/accounts/${dealerId}`))}
          className="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium text-white bg-primary rounded-lg hover:bg-primary/90"
        >
          Open Financial Detail
        </button>
      )}
    >
      {(isInitialLoading || usersLoading) && (
        <div className="rounded-lg border border-gray-200 bg-white p-6 text-sm text-gray-500">Loading dealer...</div>
      )}
      {(error || usersError) && (
        <div className="rounded-lg border border-red-200 bg-red-50 p-4 text-sm text-red-700">
          {error || usersError}
        </div>
      )}

      {activeTab === 'profile' && detail && (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm">
            <h3 className="text-sm font-semibold text-gray-900 mb-3">Dealer Profile</h3>
            <dl className="space-y-2 text-sm">
              <div className="flex justify-between"><dt className="text-gray-500">Name</dt><dd className="font-medium">{detail.dealer_name}</dd></div>
              <div className="flex justify-between"><dt className="text-gray-500">Dealer #</dt><dd>{detail.dealer_no ?? '—'}</dd></div>
              <div className="flex justify-between"><dt className="text-gray-500">Email</dt><dd>{detail.dealer_email ?? '—'}</dd></div>
              <div className="flex justify-between"><dt className="text-gray-500">Phone</dt><dd>{detail.dealer_phone ?? '—'}</dd></div>
            </dl>
          </div>
          <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm">
            <h3 className="text-sm font-semibold text-gray-900 mb-3">Commercial Snapshot</h3>
            <dl className="space-y-2 text-sm">
              <div className="flex justify-between"><dt className="text-gray-500">Open SO</dt><dd>{detail.open_so_count}</dd></div>
              <div className="flex justify-between"><dt className="text-gray-500">Open Invoices</dt><dd>{detail.open_invoices_count}</dd></div>
              <div className="flex justify-between"><dt className="text-gray-500">Open AR</dt><dd className="font-mono">{formatCurrency(detail.open_ar, 'USD')}</dd></div>
              <div className="flex justify-between"><dt className="text-gray-500">Past Due</dt><dd className="font-mono">{formatCurrency(detail.past_due_amount, 'USD')}</dd></div>
            </dl>
          </div>
        </div>
      )}

      {activeTab === 'users' && (
        <div className="rounded-lg border border-gray-200 bg-white overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b">
              <tr>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Name</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Email</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Role</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Status</th>
                <th className="px-4 py-3 text-left font-medium text-gray-700">Created</th>
              </tr>
            </thead>
            <tbody>
              {users.length === 0 ? (
                <tr><td colSpan={5} className="px-4 py-8 text-center text-gray-500">No dealer users</td></tr>
              ) : users.map((user) => (
                <tr key={user.id} className="border-t">
                  <td className="px-4 py-4">{user.display_name ?? '—'}</td>
                  <td className="px-4 py-4">{user.email ?? '—'}</td>
                  <td className="px-4 py-4">{user.role_code ?? '—'}</td>
                  <td className="px-4 py-4">{user.status ?? '—'}</td>
                  <td className="px-4 py-4">{formatDate(user.created_at)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {activeTab === 'terms' && (
        <div className="rounded-lg border border-gray-200 bg-white p-6">
          <DealerTermsTab dealerId={dealerId} mode="admin" />
        </div>
      )}

      {activeTab === 'financial' && detail && (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm">
            <h3 className="text-sm font-semibold text-gray-900 mb-3">Financial Summary</h3>
            <dl className="space-y-2 text-sm">
              <div className="flex justify-between"><dt className="text-gray-500">Total Invoiced</dt><dd className="font-mono">{formatCurrency(detail.total_invoiced_lifetime, 'USD')}</dd></div>
              <div className="flex justify-between"><dt className="text-gray-500">Total Paid</dt><dd className="font-mono">{formatCurrency(detail.total_paid_lifetime, 'USD')}</dd></div>
              <div className="flex justify-between"><dt className="text-gray-500">Open AR</dt><dd className="font-mono">{formatCurrency(detail.open_ar, 'USD')}</dd></div>
              <div className="flex justify-between"><dt className="text-gray-500">Past Due</dt><dd className="font-mono">{formatCurrency(detail.past_due_amount, 'USD')}</dd></div>
              <div className="flex justify-between"><dt className="text-gray-500">Unapplied</dt><dd className="font-mono">{formatCurrency(detail.unapplied_amount, 'USD')}</dd></div>
            </dl>
          </div>
          <div className="rounded-lg border border-gray-200 bg-white p-6 shadow-sm">
            <h3 className="text-sm font-semibold text-gray-900 mb-3">Aging</h3>
            <dl className="space-y-2 text-sm">
              <div className="flex justify-between"><dt className="text-gray-500">Current</dt><dd className="font-mono">{formatCurrency(detail.aging_current, 'USD')}</dd></div>
              <div className="flex justify-between"><dt className="text-gray-500">1-30</dt><dd className="font-mono">{formatCurrency(detail.aging_1_30, 'USD')}</dd></div>
              <div className="flex justify-between"><dt className="text-gray-500">31-60</dt><dd className="font-mono">{formatCurrency(detail.aging_31_60, 'USD')}</dd></div>
              <div className="flex justify-between"><dt className="text-gray-500">61-90</dt><dd className="font-mono">{formatCurrency(detail.aging_61_90, 'USD')}</dd></div>
              <div className="flex justify-between"><dt className="text-gray-500">90+</dt><dd className="font-mono">{formatCurrency(detail.aging_90_plus, 'USD')}</dd></div>
            </dl>
          </div>
        </div>
      )}

      {activeTab === 'timeline' && (
        <TimelineView
          events={events.map((event) => ({
            id: `${event.entity_type}-${event.entity_id}-${event.event_type}`,
            action: event.event_type,
            description: `${event.reference_no ?? 'Movement'} ${formatCurrency(event.amount, 'USD')}`,
            user_name: null,
            created_at: event.event_at,
            metadata: null,
          }))}
          loading={timelineLoading}
          emptyMessage="No activity yet"
        />
      )}
    </DetailPageLayout>
  );
}

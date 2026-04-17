/**
 * Dealer Account - Portal area for Dealer Manager only.
 * Tabs: Profile (read-only) | Dealer Users | Terms & Conditions.
 */

import { useEffect, useMemo, useState } from 'react';
import { router } from '../../lib/router';
import { useSubmoduleNav } from '../../hooks/useSubmoduleNav';
import { useAccessContext } from '../../hooks/useAccessContext';
import { useOrganizationContext } from '../../context/OrganizationContext';
import { supabase } from '../../lib/supabase/client';
import DealerUsers from './DealerUsers';
import DealerTermsTab from './DealerTermsTab';

interface DealerProfileView {
  dealer_name: string | null;
  identification_number: string | null;
  status: string | null;
  website: string | null;
  dealer_email: string | null;
  dealer_phone: string | null;
  alt_phone: string | null;
  notes: string | null;
  street_address_line_1: string | null;
  street_address_line_2: string | null;
  city: string | null;
  state: string | null;
  zip_code: string | null;
  country: string | null;
  billing_street_address_line_1: string | null;
  billing_street_address_line_2: string | null;
  billing_city: string | null;
  billing_state: string | null;
  billing_zip_code: string | null;
  billing_country: string | null;
  dealer_tier_id: string | null;
  primary_contact_app_user_id: string | null;
}

function InfoRow({ label, value }: { label: string; value: string | null | undefined }) {
  return (
    <div className="grid grid-cols-12 gap-3 py-2 border-b border-gray-100 last:border-b-0">
      <div className="col-span-4 text-xs text-gray-500">{label}</div>
      <div className="col-span-8 text-sm text-gray-900">{value && value.trim() ? value : '—'}</div>
    </div>
  );
}

export default function DealerAccount() {
  const { registerSubmodules } = useSubmoduleNav();
  const { userType, portalRole, portalDealerId } = useAccessContext();
  const { activeOrganizationId } = useOrganizationContext();
  const currentRoute = router.getCurrentRoute() || window.location.pathname;
  const isUsersRoute = currentRoute.includes('/settings/dealer-account/users');
  const isTermsRoute = currentRoute.includes('/settings/dealer-account/terms');
  const isProfileRoute = !isUsersRoute && !isTermsRoute;
  const isDealerManager = portalRole === 'dealer_manager';
  const [profile, setProfile] = useState<DealerProfileView | null>(null);
  const [tierLabel, setTierLabel] = useState<string | null>(null);
  const [primaryContactLabel, setPrimaryContactLabel] = useState<string | null>(null);
  const [loadingProfile, setLoadingProfile] = useState(false);

  const locationAddress = useMemo(() => {
    if (!profile) return null;
    return [
      profile.street_address_line_1,
      profile.street_address_line_2,
      [profile.city, profile.state, profile.zip_code].filter(Boolean).join(', '),
      profile.country,
    ]
      .filter((v) => v && String(v).trim().length > 0)
      .join(' · ');
  }, [profile]);

  const billingAddress = useMemo(() => {
    if (!profile) return null;
    return [
      profile.billing_street_address_line_1,
      profile.billing_street_address_line_2,
      [profile.billing_city, profile.billing_state, profile.billing_zip_code].filter(Boolean).join(', '),
      profile.billing_country,
    ]
      .filter((v) => v && String(v).trim().length > 0)
      .join(' · ');
  }, [profile]);

  // Solo Dealer Manager puede acceder; Member se redirige
  if (userType === 'portal' && !isDealerManager) {
    return (
      <div className="py-6 px-6">
        <div className="bg-amber-50 border border-amber-200 rounded-lg p-4">
          <p className="text-sm text-amber-800 font-medium">Access restricted</p>
          <p className="text-sm text-amber-700 mt-1">Only Dealer Managers can access Dealer Account settings.</p>
          <button
            type="button"
            onClick={() => router.navigate('/')}
            className="mt-2 text-sm text-amber-700 underline"
          >
            Go to dashboard
          </button>
        </div>
      </div>
    );
  }

  useEffect(() => {
    const tabs: { id: string; label: string; href: string }[] = [
      { id: 'profile', label: 'Profile', href: '/settings/dealer-account' },
      { id: 'dealer-users', label: 'Dealer Users', href: '/settings/dealer-account/users' },
    ];
    if (isDealerManager) {
      tabs.push({ id: 'terms', label: 'Terms & Conditions', href: '/settings/dealer-account/terms' });
    }
    registerSubmodules('Dealer Account', tabs);
  }, [registerSubmodules, isDealerManager]);

  useEffect(() => {
    const loadProfile = async () => {
      if (!isProfileRoute || !portalDealerId || !activeOrganizationId) return;
      setLoadingProfile(true);
      try {
        const { data: dealerRow, error: dealerErr } = await supabase
          .from('Dealers')
          .select(`
            dealer_name, identification_number, status,
            website, dealer_email, dealer_phone, alt_phone, notes,
            street_address_line_1, street_address_line_2, city, state, zip_code, country,
            billing_street_address_line_1, billing_street_address_line_2, billing_city, billing_state, billing_zip_code, billing_country,
            dealer_tier_id, primary_contact_app_user_id
          `)
          .eq('id', portalDealerId)
          .eq('organization_id', activeOrganizationId)
          .eq('deleted', false)
          .maybeSingle();

        if (dealerErr) throw dealerErr;
        setProfile((dealerRow as DealerProfileView | null) ?? null);

        if (dealerRow?.dealer_tier_id) {
          const { data: tierRow } = await supabase
            .from('DealerTiers')
            .select('name, discount_pct')
            .eq('id', dealerRow.dealer_tier_id)
            .eq('organization_id', activeOrganizationId)
            .maybeSingle();
          setTierLabel(tierRow ? `${tierRow.name} (${tierRow.discount_pct}%)` : null);
        } else {
          setTierLabel('Default: Bronze (35%)');
        }

        if (dealerRow?.primary_contact_app_user_id) {
          const { data: appUserRow } = await supabase
            .from('AppUsers')
            .select('display_name, email')
            .eq('id', dealerRow.primary_contact_app_user_id)
            .eq('organization_id', activeOrganizationId)
            .maybeSingle();
          setPrimaryContactLabel(appUserRow?.display_name || appUserRow?.email || null);
        } else {
          // Fallback: first active dealer manager for this dealer.
          const { data: managerRow } = await supabase
            .from('AppUsers')
            .select('display_name, email')
            .eq('organization_id', activeOrganizationId)
            .eq('dealer_id', portalDealerId)
            .eq('user_type', 'dealer')
            .eq('role_code', 'dealer_manager')
            .eq('deleted', false)
            .in('status', ['active', 'invited'])
            .order('created_at', { ascending: true })
            .limit(1)
            .maybeSingle();
          setPrimaryContactLabel(managerRow?.display_name || managerRow?.email || null);
        }
      } catch (err) {
        console.error('[DealerAccount] Failed loading dealer profile', err);
        setProfile(null);
        setTierLabel(null);
        setPrimaryContactLabel(null);
      } finally {
        setLoadingProfile(false);
      }
    };

    loadProfile();
  }, [isProfileRoute, portalDealerId, activeOrganizationId]);

  // Terms tab: only for Dealer Manager, need dealer ID
  if (isTermsRoute) {
    if (!isDealerManager) {
      return (
        <div className="py-6 px-6">
          <div className="bg-amber-50 border border-amber-200 rounded-lg p-4">
            <p className="text-sm text-amber-800">Only Dealer Managers can manage Terms & Conditions.</p>
            <button
              type="button"
              onClick={() => router.navigate('/settings/dealer-account')}
              className="mt-2 text-sm text-amber-700 underline"
            >
              Back to Dealer Users
            </button>
          </div>
        </div>
      );
    }
    if (!portalDealerId || !activeOrganizationId) {
      return (
        <div className="py-6 px-6">
          <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
            <p className="text-sm text-yellow-800">Dealer context is required. Please contact your administrator.</p>
          </div>
        </div>
      );
    }
    return (
      <div className="py-6 px-6">
        <div className="bg-white border border-gray-200 rounded-lg p-6">
          <DealerTermsTab dealerId={portalDealerId} mode="dealerSelf" />
        </div>
      </div>
    );
  }

  if (isUsersRoute) {
    return <DealerUsers />;
  }

  if (!portalDealerId || !activeOrganizationId) {
    return (
      <div className="py-6 px-6">
        <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
          <p className="text-sm text-yellow-800">Dealer context is required. Please contact your administrator.</p>
        </div>
      </div>
    );
  }

  return (
    <div className="py-6 px-6">
      <div className="bg-white border border-gray-200 rounded-lg p-6">
        <h3 className="text-sm font-semibold text-gray-900 mb-4">Dealer Profile</h3>
        {loadingProfile ? (
          <p className="text-sm text-gray-500">Loading dealer profile...</p>
        ) : !profile ? (
          <p className="text-sm text-gray-500">No dealer profile found.</p>
        ) : (
          <div className="space-y-6">
            <div>
              <h4 className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-2">General</h4>
              <InfoRow label="Dealer Name" value={profile.dealer_name} />
              <InfoRow label="ID Number" value={profile.identification_number} />
              <InfoRow label="Status" value={profile.status} />
              <InfoRow label="Tier" value={tierLabel} />
              <InfoRow label="Primary Contact" value={primaryContactLabel} />
              <InfoRow label="Website" value={profile.website} />
              <InfoRow label="Email" value={profile.dealer_email} />
              <InfoRow label="Phone" value={profile.dealer_phone} />
              <InfoRow label="Alt Phone" value={profile.alt_phone} />
              <InfoRow label="Notes" value={profile.notes} />
            </div>
            <div>
              <h4 className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-2">Addresses</h4>
              <InfoRow label="Location" value={locationAddress} />
              <InfoRow label="Billing" value={billingAddress} />
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

/**
 * Wrapper that keeps Proposals list and ProposalDetail mounted.
 * Toggles visibility by path so switching back to a proposal is instant (no reload).
 */
import { useEffect, useRef, useState } from 'react';
import { router } from '../../lib/router';
import Proposals from './Proposals';
import ProposalDetail from './ProposalDetail';

function getProposalIdFromPath(): string | null {
  const path = router.getCurrentRoute() || window.location.pathname;
  const m = path.match(/\/sales\/proposals\/([^/]+)(?:\/|$)/);
  return m ? m[1] : null;
}

function isProposalDetailPath(): boolean {
  const path = router.getCurrentRoute() || window.location.pathname;
  return /^\/sales\/proposals\/[^/]+(?:\/|$)/.test(path) && !path.includes('/print');
}

export default function ProposalsWithDetail() {
  const lastProposalIdRef = useRef<string | null>(null);
  const [, setPathVersion] = useState(0);

  useEffect(() => {
    const id = getProposalIdFromPath();
    if (id) lastProposalIdRef.current = id;
    const unsub = router.addListener(() => {
      const n = getProposalIdFromPath();
      if (n) lastProposalIdRef.current = n;
      setPathVersion((v) => v + 1); // force re-render when route changes
    });
    return () => {
      unsub();
    };
  }, []);

  const proposalId = getProposalIdFromPath();
  const showDetail = isProposalDetailPath();
  const effectiveProposalId = proposalId ?? lastProposalIdRef.current;

  return (
    <>
      <div hidden={showDetail} aria-hidden={showDetail}>
        <Proposals />
      </div>
      <div hidden={!showDetail} aria-hidden={!showDetail}>
        <ProposalDetail proposalIdOverride={effectiveProposalId ?? undefined} />
      </div>
    </>
  );
}

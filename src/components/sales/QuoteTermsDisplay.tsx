/**
 * Read-only display of Terms & Conditions for Quote.
 * Content comes from the default template set in Settings (Dealer Detail > Terms & Conditions).
 * Placed at the end of the Quote; not editable.
 */

import { useEffect, useState } from 'react';
import { resolveDefaultTermsTemplateId, fetchTermsTemplateById } from '../../lib/terms';
import { supabase } from '../../lib/supabase/client';

interface QuoteTermsDisplayProps {
  orgId: string | null;
  dealerId: string | null;
  /** If Quote already has snapshot terms, show these instead of fetching default */
  termsTitle?: string | null;
  termsContent?: string | null;
}

export default function QuoteTermsDisplay({
  orgId,
  dealerId,
  termsTitle,
  termsContent,
}: QuoteTermsDisplayProps) {
  const [fetchedTitle, setFetchedTitle] = useState<string>('');
  const [fetchedContent, setFetchedContent] = useState<string>('');
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!orgId || !dealerId) return;
    if ((termsTitle != null && termsTitle !== '') || (termsContent != null && termsContent !== '')) {
      setFetchedTitle(termsTitle ?? '');
      setFetchedContent(termsContent ?? '');
      return;
    }
    let cancelled = false;
    setLoading(true);
    (async () => {
      try {
        const templateId = await resolveDefaultTermsTemplateId(orgId, dealerId, 'quote');
        if (!cancelled && templateId) {
          const template = await fetchTermsTemplateById(templateId);
          if (!cancelled && template) {
            setFetchedTitle(template.title ?? '');
            setFetchedContent(template.content ?? '');
            return;
          }
        }

        // Fallback: if no dealer default is resolved, show active GLOBAL template.
        const { data: globalTemplate } = await supabase
          .from('DocumentTermsTemplates')
          .select('title, content')
          .eq('organization_id', orgId)
          .eq('doc_type', 'quote')
          .is('dealer_id', null)
          .eq('is_active', true)
          .order('updated_at', { ascending: false })
          .limit(1)
          .maybeSingle();

        if (!cancelled) {
          setFetchedTitle((globalTemplate as { title?: string } | null)?.title ?? '');
          setFetchedContent((globalTemplate as { content?: string } | null)?.content ?? '');
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => { cancelled = true; };
  }, [orgId, dealerId, termsTitle, termsContent]);

  const displayTitle = (termsTitle != null && termsTitle !== '') ? termsTitle : fetchedTitle;
  const displayContent = (termsContent != null && termsContent !== '') ? termsContent : fetchedContent;

  return (
    <div className="bg-white border border-gray-200 rounded-lg p-6">
      <h3 className="text-sm font-semibold text-gray-700 mb-2">Terms and Conditions</h3>
      <div className="text-sm text-gray-700 whitespace-pre-wrap">
        {loading && !displayContent
          ? 'Cargando términos...'
          : (displayContent || 'No hay términos configurados en Dealer Detail > Terms & Conditions.')}
      </div>
    </div>
  );
}

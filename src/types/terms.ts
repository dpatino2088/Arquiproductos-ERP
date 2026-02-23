/**
 * Types for Terms & Conditions (DocumentTermsTemplates, DealerDocumentTermsDefaults).
 * Backend: public.DocumentTermsTemplates, public.DealerDocumentTermsDefaults.
 */

export type DocTypeForTerms = 'quote' | 'proposal' | 'sales_order';

export interface DocumentTermsTemplate {
  id: string;
  organization_id: string;
  dealer_id: string | null;
  doc_type: DocTypeForTerms;
  title: string;
  content: string;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface DealerDocumentTermsDefault {
  id?: string;
  dealer_id: string;
  doc_type: DocTypeForTerms;
  template_id: string;
}

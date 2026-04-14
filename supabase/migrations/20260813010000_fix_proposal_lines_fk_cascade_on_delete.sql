-- Fix: deleting a QuoteLine with linked ProposalLines failed because
-- ON DELETE SET NULL would null out quote_line_id, violating
-- proposal_lines_type_chk (line_type='from_quote' requires quote_line_id NOT NULL).
-- Change to ON DELETE CASCADE: removing a QuoteLine also removes its ProposalLines.

ALTER TABLE public."ProposalLines"
  DROP CONSTRAINT "ProposalLines_quote_line_id_fkey";

ALTER TABLE public."ProposalLines"
  ADD CONSTRAINT "ProposalLines_quote_line_id_fkey"
    FOREIGN KEY (quote_line_id)
    REFERENCES public."QuoteLines"(id)
    ON DELETE CASCADE;

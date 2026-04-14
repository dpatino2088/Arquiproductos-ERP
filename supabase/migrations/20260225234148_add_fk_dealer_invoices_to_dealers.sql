
ALTER TABLE public."DealerInvoices"
  ADD CONSTRAINT dealer_invoices_dealer_id_fkey 
  FOREIGN KEY (dealer_id) REFERENCES public."Dealers"(id) ON DELETE RESTRICT;

ALTER TABLE public."Payments"
  ADD CONSTRAINT payments_dealer_id_fkey 
  FOREIGN KEY (dealer_id) REFERENCES public."Dealers"(id) ON DELETE RESTRICT;
;

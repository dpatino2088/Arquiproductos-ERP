ALTER TABLE "SalesOrders"
  ADD CONSTRAINT fk_salesorders_customer
    FOREIGN KEY (customer_id)
    REFERENCES "DirectoryCustomers" (id)
    ON DELETE SET NULL;

ALTER TABLE "SalesOrders"
  ADD CONSTRAINT fk_salesorders_contact
    FOREIGN KEY (contact_id)
    REFERENCES "DirectoryContacts" (id)
    ON DELETE SET NULL;;

-- ============================================================================
-- Reset transactional data only (for fresh testing)
-- ============================================================================
-- BORRA: Quotes, QuoteLines, QuoteLineComponents, Proposals, ProposalLines,
--        ProposalLineAddOns, PaymentApplications, Payments, DealerInvoiceLines,
--        DealerInvoices, SalesOrders, SaleOrderLines, ConfiguredProducts,
--        PurchaseOrderLines, PurchaseOrders, ManufacturingOrders, ManufacturingOrderLines,
--        WorkOrderTasks, WorkOrderTaskLines, BOMInstances, BOMInstanceLines, OrderList
--
-- CONSERVA: BOMTemplates, BOMTemplateSlots, BOMComponents, CatalogItemComponents,
--           RoleDependencies, CatalogItemRoles, Engineering rules, etc.
-- ============================================================================

SET search_path = public;

-- Work Order lines
DELETE FROM "WorkOrderTaskLines";

-- Work Order tasks
DELETE FROM "WorkOrderTasks";

-- MO lines
DELETE FROM "ManufacturingOrderLines";

-- BOM instance lines (datos de instancias, no templates)
DELETE FROM "BOMInstanceLines";

-- BOM instances (datos de órdenes concretas)
DELETE FROM "BOMInstances";

-- Purchase Order lines (referencian MO; borrar antes de MO)
DELETE FROM "PurchaseOrderLines";

-- Purchase Orders
DELETE FROM "PurchaseOrders";

-- Manufacturing Orders
DELETE FROM "ManufacturingOrders";

-- Proposal add-ons
DELETE FROM "ProposalLineAddOns";

-- Proposal lines
DELETE FROM "ProposalLines";

-- Proposals
DELETE FROM "Proposals";

-- Order list (mirror SO)
DELETE FROM "OrderList";

-- PaymentApplications (si referencian Payments)
DELETE FROM "PaymentApplications";

-- Payments (referencian SalesOrders)
DELETE FROM "Payments";

-- Invoice lines (referencian DealerInvoices)
DELETE FROM "DealerInvoiceLines";

-- Invoices (referencian SalesOrders)
DELETE FROM "DealerInvoices";

-- Sale Order lines
DELETE FROM "SaleOrderLines";

-- Sales Orders
DELETE FROM "SalesOrders";

-- Configured Products
DELETE FROM "ConfiguredProducts";

-- Quote line components
DELETE FROM "QuoteLineComponents";

-- Quote lines
DELETE FROM "QuoteLines";

-- Quotes
DELETE FROM "Quotes";

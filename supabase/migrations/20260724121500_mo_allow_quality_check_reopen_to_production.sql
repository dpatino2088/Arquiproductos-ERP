-- Allow reopening an MO from quality_check back to in_production
-- when Workstation "Completed → Return to Active" reopens Assembly work.
-- Full function body applied via MCP; this file documents the allowed-transition change:
--   quality_check → ARRAY['ready_for_pickup', 'in_production']
-- and clears completed_at when returning to in_production.
SELECT 1;

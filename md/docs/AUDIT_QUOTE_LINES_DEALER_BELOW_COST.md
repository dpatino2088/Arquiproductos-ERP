# Audit: Quote Lines with Dealer Price Below Cost

Run this query periodically (or before approving big quotes) to surface lines
where the dealer price is unintentionally below the unit cost. These should
never reach a Sale Order without a manual review.

## Query

```sql
SELECT
  ql.id,
  ql.sku,
  ql.name,
  ql.product_type,
  ql.unit_cost_total_snapshot       AS cost,
  ql.unit_dealer_price_snapshot     AS dealer,
  ql.unit_msrp_total_snapshot       AS msrp,
  ROUND((ql.unit_cost_total_snapshot - ql.unit_dealer_price_snapshot)::numeric, 2)
    AS deficit_per_unit,
  ql.dealer_tier_code_snapshot      AS dealer_tier,
  ql.pricing_locked,
  q.quote_number,
  q.status                          AS quote_status,
  q.created_at,
  q.last_priced_at
FROM public."QuoteLines" ql
JOIN public."Quotes" q ON q.id = ql.quote_id
WHERE ql.unit_dealer_price_snapshot < ql.unit_cost_total_snapshot
  AND ql.unit_dealer_price_snapshot > 0
ORDER BY (ql.unit_cost_total_snapshot - ql.unit_dealer_price_snapshot) DESC;
```

## How to remediate

1. **Quote in `draft` status, `pricing_locked = false`**
   - Open the quote in the UI.
   - On the offending line, click **"Update line"**.
   - This calls `update_catalog_quote_line_pricing` (catalog) or
     `update_window_film_quote_line_pricing` (film) and refreshes the
     dealer price from current `CatalogItemsMSRP`.

2. **Quote in `approved` / `sent` status, `pricing_locked = true`**
   - Do NOT mutate the line. Pricing is intentionally frozen at the moment
     of approval (see `pricing-protect.mdc`).
   - If the original dealer price was wrong, create a Quote V2 / Proposal V2
     and re-run pricing there.

3. **Sale Order already created**
   - The line has propagated to `SaleOrderLines.unit_price`. Issue a credit
     note or adjust on a follow-up SO; never edit history.

## Known historical cases (as of 2026-05-28)

| SKU              | Name             | Cost      | Dealer    | Deficit  |
|------------------|------------------|-----------|-----------|----------|
| RF-SALVADOR-1400 | Salvador Grey    | 234.5436  | 187.2740  |  −47.27  |
| RF-SALVADOR-0500 | Salvador Beige   | 186.9075  | 167.0378  |  −19.87  |
| RF-SALVADOR-0500 | Salvador Beige   | 186.9075  | 167.0378  |  −19.87  |

These three lines pre-date the pricing migrations that aligned Window Film
to linear meters. If they sit on a draft quote, hitting **Update line** in
the UI will fix them. If they're on an approved quote, leave them and
document any commercial decision separately.

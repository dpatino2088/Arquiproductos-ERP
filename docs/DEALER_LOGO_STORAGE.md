# Dealer Logo – Storage location

The image uploaded in **Settings → Dealer Detail → Dealer Logo** is stored in Supabase Storage as follows.

## Bucket and path

| Item   | Value |
|--------|--------|
| **Bucket** | `catalog-images` |
| **Path prefix** | `dealer-logos/{organizationId}/{dealerId}/` |
| **File name** | `{timestamp}-{random}.{ext}` |

Full storage path example:

```text
dealer-logos/<organization_id>/<dealer_id>/<timestamp>-<random>.<ext>
```

Dealer logos are stored **inside** the `catalog-images` bucket, under the **`dealer-logos/`** folder (same bucket as catalog items).

## Where it is used in code

- **Upload:** `src/pages/settings/DealerProfileForm.tsx` – `ImageUpload` with `bucket="catalog-images"` and `uploadPath` returning `dealer-logos/${organizationId}/${dealerId}/...`.
- **URL:** `supabase.storage.from('catalog-images').getPublicUrl(fileName)` → URL saved in **`Dealers.logo_url`**. The PDF flow can use a signed URL for the same path if needed.
- **Proposal PDF:** `ProposalDetail.tsx` loads `logo_url` from `Dealers`; for any Supabase storage URL it obtains a signed URL (1h) and uses it to load the image for the PDF.
- **Proposal UI / Print:** Same `logo_url` is used to show the logo in the detail and print views.

## CORS

To load the logo when generating the Proposal PDF in the browser, the **`catalog-images`** bucket must allow CORS from your app origin (e.g. `http://localhost:5173`).

In Supabase: **Storage → catalog-images → Configuration → CORS** and add the appropriate origins.

## RLS / policies

Storage policies for `catalog-images` must allow:

- **Upload:** insert for paths under `dealer-logos/{organizationId}/{dealerId}/*` (and under `catalog-items/...` for catalog images).
- **Read (and signed URL):** select for the same paths so the app can display and generate signed URLs for the PDF.

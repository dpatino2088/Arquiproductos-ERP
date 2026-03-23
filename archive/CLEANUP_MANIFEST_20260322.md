# Cleanup Manifest - 2026-03-22

This manifest documents archival cleanup actions executed in the repository.

## Goals

- Reduce root-level clutter.
- Keep production code paths (`src/`, `supabase/`, `public/`) untouched.
- Preserve historical files by moving to `archive/` instead of deleting.
- Keep a minimal set of recent database backups accessible under `backups/retained/`.

## Archived Locations

- `archive/cleanup-20260322/`
  - Root loose files and one mockup moved from active paths.
- `archive/cleanup-20260322-phase2/`
  - Empty/invalid backup artifacts and system clutter from folders.
- `archive/cleanup-20260322-phase3/backups-old/`
  - Historical backup SQL dumps, utility SQL scripts, and backup assets.
- `archive/cleanup-20260322-phase3/scripts-legacy/`
  - Legacy one-shot migration/import/diagnostic scripts no longer kept in active `scripts/`.

## Retained Active Backups

The following backups were intentionally kept active in:
`backups/retained/`

- `2026-02-18_0050_full.sql`
- `2026-02-18_0021_full.sql`
- `2026-02_12_full.sql`
- `2026-02_07_V17_full.sql`
- `2026-02_07_V16_full.sql`

## Restore Instructions

To restore any file from archive:

1. Locate it in `archive/...`
2. Move it back to original location, example:

```bash
mv "archive/cleanup-20260322/tmp_fix_generate_bom.sql" "tmp_fix_generate_bom.sql"
```

For retained backups moved back to root backups:

```bash
mv "backups/retained/<file>.sql" "backups/<file>.sql"
```

## Notes

- Cleanup intentionally favors reversibility over permanent deletion.
- Git status may show many deletes + untracked archive files until commit.
- If desired, split commit history by phase for better auditability.

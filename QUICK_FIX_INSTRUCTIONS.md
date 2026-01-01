# 🔧 Quick Fix: Missing Columns Error

## 🐛 Error

```
Error: column bil.cut_length_mm does not exist
```

## ✅ Solution

The columns `cut_length_mm`, `cut_width_mm`, `cut_height_mm`, and `calc_notes` are missing from the `BomInstanceLines` table.

### **STEP 1: Run Verification Script**

Execute `VERIFY_BOM_COLUMNS_EXIST.sql` to check current state:
- If it returns **0 rows** → columns don't exist, proceed to Step 2
- If it returns **4 rows** → columns exist, the error is something else

### **STEP 2: Add Missing Columns**

Execute `FIX_MISSING_BOM_COLUMNS.sql` in Supabase SQL Editor.

This script:
- ✅ Safely checks if columns exist before adding
- ✅ Adds all 4 required columns:
  - `cut_length_mm` (integer)
  - `cut_width_mm` (integer)
  - `cut_height_mm` (integer)
  - `calc_notes` (text)
- ✅ Adds helpful comments
- ✅ Verifies columns were added

### **STEP 3: Refresh Browser**

After running the script:
1. Refresh the browser page (F5 or Cmd+R)
2. The error should disappear
3. Materials and Cut List should work correctly

---

## 📝 Why This Happened

The `INTEGRATE_ENGINEERING_RULES_INTO_BOM.sql` script should have added these columns, but:
- It may not have been executed
- Or it failed silently
- Or the columns were removed/dropped

The fix script is **idempotent** - safe to run multiple times.

---

## ✅ After Fix

Once columns are added:
- ✅ Materials tab will load without errors
- ✅ Cut List can be generated
- ✅ Engineering Rules dimensions will be displayed
- ✅ All BOM-related features will work

---

**Status:** Ready to fix - Just run `FIX_MISSING_BOM_COLUMNS.sql`







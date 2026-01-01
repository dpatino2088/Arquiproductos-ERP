# 🚀 Execution Order - Cutting Logic

## 📋 Prerequisites

Before executing these scripts, ensure:
- ✅ Material Planning is complete (BomInstanceLines have cut dimensions)
- ✅ Manufacturing Orders exist with status = 'planned'
- ✅ You have access to Supabase SQL Editor

---

## 📝 Execution Steps

### **STEP 1: Create Tables** ⚠️ RUN FIRST

**File:** `CREATE_CUTJOBS_TABLES.sql`

**What it does:**
- Creates `CutJobs` table
- Creates `CutJobLines` table
- Sets up indexes
- Configures RLS policies

**How to execute:**
1. Open Supabase SQL Editor
2. Copy entire contents of `CREATE_CUTJOBS_TABLES.sql`
3. Paste into SQL Editor
4. Click "Run" or press Cmd/Ctrl + Enter
5. Verify: Should see "Success. No rows returned" or similar

**Verification:**
```sql
-- Run this after executing the script
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('CutJobs', 'CutJobLines');
-- Should return 2 rows
```

---

### **STEP 2: Create Function** ⚠️ RUN SECOND

**File:** `CREATE_GENERATE_CUT_LIST_FUNCTION.sql`

**What it does:**
- Creates `generate_cut_list_for_manufacturing_order(uuid)` function
- Grants execute permission to authenticated users

**How to execute:**
1. Open Supabase SQL Editor
2. Copy entire contents of `CREATE_GENERATE_CUT_LIST_FUNCTION.sql`
3. Paste into SQL Editor
4. Click "Run" or press Cmd/Ctrl + Enter
5. Verify: Should see "Success. No rows returned" or similar

**Verification:**
```sql
-- Run this after executing the script
SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name = 'generate_cut_list_for_manufacturing_order';
-- Should return 1 row
```

---

## ✅ Post-Execution Checklist

After executing both scripts:

- [ ] Tables `CutJobs` and `CutJobLines` exist
- [ ] Function `generate_cut_list_for_manufacturing_order` exists
- [ ] RLS policies are active
- [ ] Indexes are created
- [ ] Frontend can access the new tables (test in browser)

---

## 🧪 Testing the Implementation

### Test 1: Verify Tables Exist
```sql
SELECT 
    table_name,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name IN ('CutJobs', 'CutJobLines')
ORDER BY table_name, ordinal_position;
```

### Test 2: Verify Function Exists
```sql
SELECT 
    routine_name,
    routine_type,
    data_type as return_type
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name = 'generate_cut_list_for_manufacturing_order';
```

### Test 3: Find a Valid MO ID
```sql
-- Run FIND_MO_FOR_CUT_LIST_TEST.sql to find MOs ready for cut list generation
-- This will show you MO IDs with status = 'planned' and BOM lines
```

### Test 4: Test Function
**Option A: Use TEST_GENERATE_CUT_LIST.sql (Recommended)**
```sql
-- This script automatically finds and tests the first available MO
-- Just run the entire TEST_GENERATE_CUT_LIST.sql file
```

**Option B: Manual Test (Replace with actual UUID)**
```sql
-- First, get a MO ID from FIND_MO_FOR_CUT_LIST_TEST.sql
-- Then replace 'YOUR_MO_ID_HERE' with the actual UUID
SELECT public.generate_cut_list_for_manufacturing_order('YOUR_MO_ID_HERE');
-- ⚠️ IMPORTANT: Use actual UUID, not placeholder text!
```

### Test 5: Verify Cut List Created
```sql
-- This shows all recent cut lists (no need to replace anything)
SELECT 
    cj.id as cut_job_id,
    cj.manufacturing_order_id,
    mo.manufacturing_order_no,
    cj.status as cut_job_status,
    COUNT(cjl.id) as cut_lines_count
FROM "CutJobs" cj
INNER JOIN "ManufacturingOrders" mo ON mo.id = cj.manufacturing_order_id
LEFT JOIN "CutJobLines" cjl ON cjl.cut_job_id = cj.id AND cjl.deleted = false
WHERE cj.deleted = false
GROUP BY cj.id, cj.manufacturing_order_id, mo.manufacturing_order_no, cj.status
ORDER BY cj.created_at DESC
LIMIT 5;
```

---

## ⚠️ Common Issues

### Issue 1: "relation does not exist"
**Cause:** Tables not created yet  
**Solution:** Run `CREATE_CUTJOBS_TABLES.sql` first

### Issue 2: "function does not exist"
**Cause:** Function not created yet  
**Solution:** Run `CREATE_GENERATE_CUT_LIST_FUNCTION.sql`

### Issue 3: "permission denied"
**Cause:** RLS policies blocking access  
**Solution:** Verify you're authenticated and have organization access

### Issue 4: "status must be 'planned'"
**Cause:** Trying to generate cut list for MO with status != 'planned'  
**Solution:** Generate BOM first to change MO status to 'planned'

---

## 🎯 Next Steps After Execution

1. **Test in Frontend:**
   - Navigate to Manufacturing Order with status = 'planned'
   - Open "Cut List" tab
   - Click "Generate Cut List"
   - Verify cut list appears

2. **Verify Data:**
   - Check that CutJobLines match BomInstanceLines
   - Verify dimensions are copied correctly (1:1)
   - Confirm grouping by Role works

3. **Production Ready:**
   - System is ready for shop floor operations
   - Cut list shows exactly what to cut
   - Dimensions come from Engineering Rules

---

## 📝 Notes

- **Idempotent:** Function can be run multiple times safely (deletes previous lines)
- **No Breaking Changes:** Existing functionality remains intact
- **Backend Source of Truth:** All logic in database, frontend only displays
- **Multi-Tenant Safe:** RLS ensures data isolation

---

**Ready to execute?** Start with `CREATE_CUTJOBS_TABLES.sql`, then `CREATE_GENERATE_CUT_LIST_FUNCTION.sql`


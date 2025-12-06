# ⚙️ Whats Attendance – Complete Technical Database Documentation (Supabase)
A fully technical, production-grade, English-language reference of the Whats Attendance backend architecture, designed for engineering use in:

- **Frontend development** (React / Next.js / Cursor)
- **Backend services** (Supabase Edge Functions, n8n automations)
- **Security & Compliance** (Corporate RLS standards)
- **DevOps & Schema Evolution**

---

# 📚 1. SYSTEM OVERVIEW

Whats Attendance is a multi-company attendance platform driven by WhatsApp interactions. Employees perform Check‑In, Check‑Out, Break Sessions, and Transfer Sessions through natural-language commands processed via n8n and stored in Supabase.

The architecture supports:

- Multi‑tenant companies  
- Role‑based access control (RBAC)  
- Strict Row-Level-Security (RLS)  
- Employee session tracking (work, break, transfer)  
- WhatsApp ingestion pipeline  
- Geofencing & branch logic  
- GDPR-style anonymization  

---

# 🧩 2. ENTITY-RELATION DIAGRAM (ERD)

```
companies
   │
   ├──< company_users >── auth.users
   │
   ├──< employees >── auth.users
   │           │
   │           └── current_status: out | in | on_break | on_transfer
   │
   ├──< branches
   │
   └──< attendance_logs
                │
                ├── work_sessions
                │         └── break_sessions
                │
                └── transfer_sessions
```

---

# 🏛️ 3. DATABASE TABLES (TECHNICAL)

## 3.1 `companies`

| Column | Type | Notes |
|--------|------|--------|
| id | uuid PK |
| name | text |
| country | text |
| timezone | text |
| address | text |
| is_active | boolean |
| created_at | timestamptz |
| updated_at | timestamptz |

---

## 3.2 `company_users`

| Column | Type | Notes |
|--------|------|--------|
| id | uuid PK |
| user_id | uuid FK → auth.users |
| company_id | uuid FK → companies |
| role | text enum(`super_admin`, `admin`, `supervisor`, `employee`) |
| is_deleted | boolean |
| created_at | timestamptz |

---

## 3.3 `employees`

| Column | Type | Notes |
|--------|------|--------|
| id | uuid PK |
| company_id | uuid FK |
| user_id | uuid FK → auth.users **NOT NULL** |
| first_name | text |
| last_name | text |
| whatsapp_number | text UNIQUE |
| employee_code | text |
| position | text |
| current_status | enum (`out`,`in`,`on_break`,`on_transfer`) |
| is_active | boolean |
| archived | boolean |
| is_deleted | boolean |
| created_at | timestamptz |
| updated_at | timestamptz |
| anonymized_at | timestamptz |

---

## 3.4 `branches`

| Column | Type |
|--------|------|
| id | uuid PK |
| company_id | uuid FK |
| branch_name | text |
| branch_address | text |
| country | text |
| timezone | text |
| latitude | numeric |
| longitude | numeric |
| radius_meters | integer |
| type | text (`branch`,`site`) |
| is_active | boolean |
| is_deleted | boolean |
| archived | boolean |
| created_at | timestamptz |
| updated_at | timestamptz |

---

## 3.5 `attendance_logs`

| Column | Type |
|--------|------|
| id | uuid PK |
| employee_id | uuid FK |
| company_id | uuid FK |
| branch_id | uuid FK |
| log_type | enum (check_in, check_out, start_break, end_break, start_transfer, end_transfer) |
| log_time | timestamptz |
| latitude | numeric |
| longitude | numeric |
| source | text |
| raw_message | text |
| created_at | timestamptz |

---

## 3.6 `work_sessions`

| Column | Type |
|--------|------|
| id | uuid PK |
| employee_id | uuid FK |
| company_id | uuid FK |
| branch_id | uuid FK |
| check_in_log_id | uuid |
| check_out_log_id | uuid |
| check_in_time | timestamptz |
| check_out_time | timestamptz |
| duration_minutes | integer |
| status | text (`open`,`closed`,`invalid`) |
| created_at | timestamptz |
| updated_at | timestamptz |

---

## 3.7 `break_sessions`

| Column | Type |
|--------|------|
| id | uuid PK |
| work_session_id | uuid FK |
| employee_id | uuid FK |
| company_id | uuid FK |
| branch_id | uuid FK |
| start_break_log_id | uuid |
| end_break_log_id | uuid |
| start_time | timestamptz |
| end_time | timestamptz |
| duration_minutes | integer |
| status | text |
| created_at | timestamptz |
| updated_at | timestamptz |

---

## 3.8 `transfer_sessions`

| Column | Type |
|--------|------|
| id | uuid PK |
| work_session_id | uuid FK |
| employee_id | uuid FK |
| company_id | uuid FK |
| from_branch_id | uuid |
| to_branch_id | uuid |
| start_transfer_log_id | uuid |
| end_transfer_log_id | uuid |
| start_time | timestamptz |
| end_time | timestamptz |
| duration_minutes | integer |
| status | text |
| created_at | timestamptz |
| updated_at | timestamptz |

---

# 🧷 4. TYPESCRIPT TYPES (ALL TABLES)

Copy‑paste friendly types for Cursor or Next.js.

---

## `Company`
```ts
export interface Company {
  id: string;
  name: string;
  country?: string;
  timezone: string;
  address?: string;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}
```

---

## `CompanyUser`
```ts
export type CompanyRole =
  | "super_admin"
  | "admin"
  | "supervisor"
  | "employee";

export interface CompanyUser {
  id: string;
  user_id: string;
  company_id: string;
  role: CompanyRole;
  is_deleted: boolean;
  created_at: string;
}
```

---

## `Employee`
```ts
export type EmployeeStatus =
  | "out"
  | "in"
  | "on_break"
  | "on_transfer";

export interface Employee {
  id: string;
  company_id: string;
  user_id: string;
  first_name: string;
  last_name: string;
  whatsapp_number: string;
  employee_code?: string;
  position?: string;
  current_status: EmployeeStatus;
  is_active: boolean;
  archived: boolean;
  is_deleted: boolean;
  created_at: string;
  updated_at: string;
  anonymized_at?: string;
}
```

---

## `Branch`
```ts
export interface Branch {
  id: string;
  company_id: string;
  branch_name: string;
  branch_address: string;
  country: string;
  timezone: string;
  latitude?: number;
  longitude?: number;
  radius_meters: number;
  type: "branch" | "site";
  is_active: boolean;
  is_deleted: boolean;
  archived: boolean;
  created_at: string;
  updated_at: string;
}
```

---

## `AttendanceLog`
```ts
export type AttendanceLogType =
  | "check_in"
  | "check_out"
  | "start_break"
  | "end_break"
  | "start_transfer"
  | "end_transfer";

export interface AttendanceLog {
  id: string;
  employee_id: string;
  company_id: string;
  branch_id: string;
  log_type: AttendanceLogType;
  log_time: string;
  latitude?: number;
  longitude?: number;
  source: string;
  raw_message?: string;
  created_at: string;
}
```

---

## `WorkSession`
```ts
export interface WorkSession {
  id: string;
  employee_id: string;
  company_id: string;
  branch_id: string;
  check_in_log_id: string;
  check_out_log_id?: string;
  check_in_time: string;
  check_out_time?: string;
  duration_minutes?: number;
  status: "open" | "closed" | "invalid";
  created_at: string;
  updated_at: string;
}
```

---

## `BreakSession`
```ts
export interface BreakSession {
  id: string;
  work_session_id: string;
  employee_id: string;
  company_id: string;
  branch_id: string;
  start_break_log_id: string;
  end_break_log_id?: string;
  start_time: string;
  end_time?: string;
  duration_minutes?: number;
  status: string;
  created_at: string;
  updated_at: string;
}
```

---

## `TransferSession`
```ts
export interface TransferSession {
  id: string;
  work_session_id: string;
  employee_id: string;
  company_id: string;
  from_branch_id: string;
  to_branch_id: string;
  start_transfer_log_id: string;
  end_transfer_log_id?: string;
  start_time: string;
  end_time?: string;
  duration_minutes?: number;
  status: string;
  created_at: string;
  updated_at: string;
}
```

---

# 🔒 5. FULL RLS SECURITY MODEL (CORPORATE-GRADE)

This model enforces:

- **Strict multi‑tenant isolation**
- **Role-based access control**
- **Zero data leakage**
- **Auditable access patterns**

---

## 5.1 Base rule (deny all)
Every table starts with:

```sql
alter table <table> enable row level security;
create policy "deny_all" on <table> for all using (false);
```

---

## 5.2 Company Membership

```sql
create policy "company_members_can_select"
on companies for select
using (
  exists (
    select 1 from company_users cu
    where cu.company_id = companies.id
      and cu.user_id = auth.uid()
      and cu.is_deleted = false
  )
);
```

---

## 5.3 Employees table RLS

```sql
create policy "employee_self_read"
on employees for select
using (user_id = auth.uid());

create policy "company_admin_read_employees"
on employees for select
using (
  exists (
    select 1 from company_users cu
    where cu.company_id = employees.company_id
      and cu.user_id = auth.uid()
      and cu.role in ('super_admin','admin','supervisor')
  )
);
```

Write access:

```sql
create policy "admin_can_write_employees"
on employees for insert, update, delete
with check (
  exists (
    select 1 from company_users cu
    where cu.company_id = employees.company_id
      and cu.user_id = auth.uid()
      and cu.role in ('super_admin','admin')
  )
);
```

---

## 5.4 Attendance Logs RLS

Employees see their own logs:

```sql
create policy "employee_can_read_own_logs"
on attendance_logs for select
using (employee_id in (
  select id from employees where user_id = auth.uid()
));
```

Admins see all logs in company:

```sql
create policy "company_admin_logs"
on attendance_logs for select
using (
  exists (
    select 1 from company_users cu
    join employees e on e.company_id = cu.company_id
    where cu.user_id = auth.uid()
      and cu.role in ('super_admin','admin','supervisor')
      and e.id = attendance_logs.employee_id
  )
);
```

Only admins may write logs (bots use service_role):

```sql
create policy "admin_insert_logs"
on attendance_logs for insert
with_check (
  exists (
    select 1 from company_users cu
    where cu.user_id = auth.uid()
      and cu.role in ('super_admin','admin')
  )
);
```

---

## 5.5 Sessions (work/break/transfer)

Same pattern:

- Employees can only see their own sessions  
- Admins can see all  
- Only admins/systems can insert/update  

Example for work_sessions:

```sql
create policy "employee_read_own_work_sessions"
on work_sessions for select
using (
  employee_id in (
    select id from employees where user_id = auth.uid()
  )
);
```

Write:

```sql
create policy "admin_write_work_sessions"
on work_sessions for insert, update
with_check (
  exists (
    select 1 from company_users cu
    where cu.user_id = auth.uid()
      and cu.role in ('super_admin','admin')
  )
);
```

---

# 🧪 6. WHATSAPP BOT LOGIC (SUMMARY)

| Command | Effect |
|--------|--------|
| check in | creates work_session + sets employee status = in |
| check out | closes work_session + status = out |
| start break | creates break_session + status = on_break |
| end break | closes break_session + status = in |
| start transfer | creates transfer_session + status = on_transfer |
| end transfer | closes transfer_session + status = in |

Forbidden commands depend on `current_status`.

---

# 🏁 END OF DOCUMENT

This README is suitable for:

- GitHub repositories  
- Internal corporate documentation  
- Developer onboarding materials  
- Cursor / AI coding assistants  

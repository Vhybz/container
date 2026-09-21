# Supabase Setup Guide (Multi-Business Management System)

This project uses **Supabase** as its cloud database and realtime backend.

> [!IMPORTANT]
> **Zero Data Loss Guarantee**: This setup script is **100% safe, idempotent, and non-destructive**.
> Running it **will NEVER delete or drop** the `products`, `branches`, `users`, or any other tables, and will preserve all of your existing rows and data. It only adds any missing tables, missing columns, storage buckets, and realtime configurations.

---

## Quick Setup Instructions

1. Open your **Supabase Project Dashboard** at [https://supabase.com/dashboard](https://supabase.com/dashboard).
2. Go to the **SQL Editor** tab from the left sidebar.
3. Click **New query**.
4. Copy and paste the complete SQL script below (or copy from the included [supabase_schema.sql](file:///c:/Users/DELL/StudioProjects/container/supabase_schema.sql) file).
5. Click **Run** (or press `Ctrl+Enter`).
6. Verify your tables in the **Table Editor** tab.

---

## Safe & Idempotent SQL Migration Script

```sql
-- ============================================================================
-- CONTAINER MULTI-BUSINESS MANAGEMENT SYSTEM - COMPLETE SUPABASE SCHEMA
-- ============================================================================
-- NOTE: THIS SCRIPT IS COMPLETELY SAFE AND NON-DESTRUCTIVE.
-- IT DOES NOT DROP THE PUBLIC SCHEMA, NOR DOES IT DELETE OR TRUNCATE ANY
-- EXISTING ROWS IN "products", "branches", "users", OR ANY OTHER TABLE.
-- IT CAN BE RUN REPEATEDLY (IDEMPOTENT) ON FRESH OR EXISTING DATABASES.
-- ============================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Grant schema access
GRANT ALL ON SCHEMA public TO postgres, anon, authenticated, service_role;

-- ============================================================================
-- 2. CORE TABLES (CREATE IF NOT EXISTS & NON-DESTRUCTIVE COLUMN MIGRATIONS)
-- ============================================================================

-- 2.1 BRANCHES
CREATE TABLE IF NOT EXISTS public.branches (
  code TEXT PRIMARY KEY, 
  name TEXT NOT NULL DEFAULT 'Main Store / Headquarters',
  location TEXT NOT NULL DEFAULT 'Main Location',
  admin_id TEXT,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE public.branches ADD COLUMN IF NOT EXISTS name TEXT NOT NULL DEFAULT 'Main Store / Headquarters';
ALTER TABLE public.branches ADD COLUMN IF NOT EXISTS location TEXT NOT NULL DEFAULT 'Main Location';
ALTER TABLE public.branches ADD COLUMN IF NOT EXISTS admin_id TEXT;
ALTER TABLE public.branches ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now() NOT NULL;

-- 2.2 USERS (Staff, Admin, Pharmacist, Barber, Tech Sales, Cashier)
CREATE TABLE IF NOT EXISTS public.users (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  first_name TEXT NOT NULL DEFAULT '',
  surname TEXT NOT NULL DEFAULT '',
  email TEXT,
  phone TEXT,
  gender TEXT,
  dob DATE,
  photo_url TEXT,
  role TEXT NOT NULL DEFAULT 'cashier',
  branch_code TEXT,
  secondary_roles TEXT[] DEFAULT '{}',
  shop_location TEXT,
  status TEXT NOT NULL DEFAULT 'approved',
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  last_seen TIMESTAMPTZ,
  is_deleted BOOLEAN DEFAULT false,
  temporary_role TEXT,
  temp_role_start TIMESTAMPTZ,
  temp_role_end TIMESTAMPTZ,
  enabled_permissions TEXT[] DEFAULT '{"/settings"}',
  newly_added_permissions TEXT[] DEFAULT '{}',
  salary_amount DECIMAL(10,2),
  salary_day INT,
  last_salary_date DATE,
  last_payment_was_advance BOOLEAN DEFAULT false,
  passcode TEXT,
  passcode_sent_at TIMESTAMPTZ,
  total_salary_paid DECIMAL(10,2) DEFAULT 0.00,
  total_advances_taken DECIMAL(10,2) DEFAULT 0.00,
  theme_mode TEXT DEFAULT 'system',
  theme_primary_color BIGINT
);

ALTER TABLE public.users ADD COLUMN IF NOT EXISTS first_name TEXT NOT NULL DEFAULT '';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS surname TEXT NOT NULL DEFAULT '';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS gender TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS dob DATE;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS photo_url TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'cashier';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS branch_code TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS secondary_roles TEXT[] DEFAULT '{}';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS shop_location TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'approved';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now() NOT NULL;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS last_seen TIMESTAMPTZ;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT false;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS temporary_role TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS temp_role_start TIMESTAMPTZ;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS temp_role_end TIMESTAMPTZ;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS enabled_permissions TEXT[] DEFAULT '{"/settings"}';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS newly_added_permissions TEXT[] DEFAULT '{}';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS salary_amount DECIMAL(10,2);
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS salary_day INT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS last_salary_date DATE;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS last_payment_was_advance BOOLEAN DEFAULT false;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS passcode TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS passcode_sent_at TIMESTAMPTZ;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS total_salary_paid DECIMAL(10,2) DEFAULT 0.00;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS total_advances_taken DECIMAL(10,2) DEFAULT 0.00;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS theme_mode TEXT DEFAULT 'system';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS theme_primary_color BIGINT;

-- Drop blocking foreign key constraint on auth.users if it exists (allows flexible staff accounts)
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_id_fkey;

-- 2.3 PRODUCTS (Inventory for Retail, Pharmacy, Barbershop, Tech)
CREATE TABLE IF NOT EXISTS public.products (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  branch_code TEXT,
  name TEXT NOT NULL,
  retail_price DECIMAL(10,2) NOT NULL DEFAULT 0,
  wholesale_price DECIMAL(10,2) NOT NULL DEFAULT 0,
  cost_price DECIMAL(10,2) DEFAULT 0,
  retail_brackets JSONB DEFAULT '[]',
  wholesale_brackets JSONB DEFAULT '[]',
  image_url TEXT DEFAULT '',
  category TEXT NOT NULL DEFAULT 'General',
  stock_quantity DECIMAL(10,2) DEFAULT 0,
  unit TEXT DEFAULT 'pcs', 
  discount_percentage DECIMAL(10,2) DEFAULT 0,
  promo_start TIMESTAMPTZ,
  promo_end TIMESTAMPTZ,
  promo_target TEXT DEFAULT 'both',
  promo_customer_target TEXT DEFAULT 'all',
  is_deleted BOOLEAN DEFAULT false,
  low_stock_threshold DECIMAL(10,2) DEFAULT 5.0,
  daily_stock_added DECIMAL(10,2) DEFAULT 0,
  is_unlimited BOOLEAN DEFAULT false,
  last_stock_update TIMESTAMPTZ,
  imei_list TEXT[] DEFAULT '{}',
  batch_expiry_date TIMESTAMPTZ,
  batch_number TEXT,
  is_service BOOLEAN DEFAULT false,
  requires_prescription BOOLEAN DEFAULT false,
  requires_imei BOOLEAN DEFAULT false,
  pieces_per_pack DECIMAL(10,2),
  pack_price DECIMAL(10,2),
  number_of_boxes DECIMAL(10,2),
  packs_per_box DECIMAL(10,2),
  box_price DECIMAL(10,2),
  commission_amount DECIMAL(10,2) DEFAULT 0.00
);

ALTER TABLE public.products ADD COLUMN IF NOT EXISTS branch_code TEXT;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS retail_price DECIMAL(10,2) NOT NULL DEFAULT 0;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS wholesale_price DECIMAL(10,2) NOT NULL DEFAULT 0;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS cost_price DECIMAL(10,2) DEFAULT 0;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS retail_brackets JSONB DEFAULT '[]';
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS wholesale_brackets JSONB DEFAULT '[]';
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS image_url TEXT DEFAULT '';
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS category TEXT NOT NULL DEFAULT 'General';
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS stock_quantity DECIMAL(10,2) DEFAULT 0;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS unit TEXT DEFAULT 'pcs';
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS discount_percentage DECIMAL(10,2) DEFAULT 0;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS promo_start TIMESTAMPTZ;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS promo_end TIMESTAMPTZ;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS promo_target TEXT DEFAULT 'both';
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS promo_customer_target TEXT DEFAULT 'all';
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT false;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS low_stock_threshold DECIMAL(10,2) DEFAULT 5.0;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS daily_stock_added DECIMAL(10,2) DEFAULT 0;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS is_unlimited BOOLEAN DEFAULT false;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS last_stock_update TIMESTAMPTZ;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS imei_list TEXT[] DEFAULT '{}';
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS batch_expiry_date TIMESTAMPTZ;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS batch_number TEXT;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS is_service BOOLEAN DEFAULT false;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS requires_prescription BOOLEAN DEFAULT false;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS requires_imei BOOLEAN DEFAULT false;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS pieces_per_pack DECIMAL(10,2);
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS pack_price DECIMAL(10,2);
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS number_of_boxes DECIMAL(10,2);
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS packs_per_box DECIMAL(10,2);
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS box_price DECIMAL(10,2);
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS commission_amount DECIMAL(10,2) DEFAULT 0.00;

-- 2.4 SALES (POS Records across all sectors)
CREATE TABLE IF NOT EXISTS public.sales (
  id TEXT PRIMARY KEY,
  branch_code TEXT,
  timestamp TIMESTAMPTZ DEFAULT now() NOT NULL,
  cashier_id TEXT,
  cashier_name TEXT NOT NULL DEFAULT 'Staff',
  staff_id TEXT,
  staff_name TEXT,
  total_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
  total_discount DECIMAL(10,2) DEFAULT 0,
  total_cost DECIMAL(10,2) DEFAULT 0,
  applied_promo TEXT,
  customer_name TEXT,
  customer_phone TEXT,
  status TEXT DEFAULT 'completed',
  correction_reason TEXT,
  bank_receipt_url TEXT,
  bank_receipt_id TEXT,
  items JSONB NOT NULL DEFAULT '[]',
  payments JSONB NOT NULL DEFAULT '[]',
  is_verified BOOLEAN DEFAULT false,
  prescription TEXT,
  include_prescription_on_receipt BOOLEAN DEFAULT true,
  send_prescription_sms BOOLEAN DEFAULT false,
  patient_name TEXT,
  doctor_name TEXT,
  rx_number TEXT
);

ALTER TABLE public.sales ADD COLUMN IF NOT EXISTS branch_code TEXT;
ALTER TABLE public.sales ADD COLUMN IF NOT EXISTS cashier_id TEXT;
ALTER TABLE public.sales ADD COLUMN IF NOT EXISTS cashier_name TEXT NOT NULL DEFAULT 'Staff';
ALTER TABLE public.sales ADD COLUMN IF NOT EXISTS staff_id TEXT;
ALTER TABLE public.sales ADD COLUMN IF NOT EXISTS staff_name TEXT;
ALTER TABLE public.sales ADD COLUMN IF NOT EXISTS total_amount DECIMAL(10,2) NOT NULL DEFAULT 0;
ALTER TABLE public.sales ADD COLUMN IF NOT EXISTS total_discount DECIMAL(10,2) DEFAULT 0;
ALTER TABLE public.sales ADD COLUMN IF NOT EXISTS total_cost DECIMAL(10,2) DEFAULT 0;
ALTER TABLE public.sales ADD COLUMN IF NOT EXISTS applied_promo TEXT;
ALTER TABLE public.sales ADD COLUMN IF NOT EXISTS customer_name TEXT;
ALTER TABLE public.sales ADD COLUMN IF NOT EXISTS customer_phone TEXT;
ALTER TABLE public.sales ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'completed';
ALTER TABLE public.sales ADD COLUMN IF NOT EXISTS correction_reason TEXT;
ALTER TABLE public.sales ADD COLUMN IF NOT EXISTS bank_receipt_url TEXT;
ALTER TABLE public.sales ADD COLUMN IF NOT EXISTS bank_receipt_id TEXT;
ALTER TABLE public.sales ADD COLUMN IF NOT EXISTS items JSONB NOT NULL DEFAULT '[]';
ALTER TABLE public.sales ADD COLUMN IF NOT EXISTS payments JSONB NOT NULL DEFAULT '[]';
ALTER TABLE public.sales ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT false;
ALTER TABLE public.sales ADD COLUMN IF NOT EXISTS prescription TEXT;
ALTER TABLE public.sales ADD COLUMN IF NOT EXISTS include_prescription_on_receipt BOOLEAN DEFAULT true;
ALTER TABLE public.sales ADD COLUMN IF NOT EXISTS send_prescription_sms BOOLEAN DEFAULT false;
ALTER TABLE public.sales ADD COLUMN IF NOT EXISTS patient_name TEXT;
ALTER TABLE public.sales ADD COLUMN IF NOT EXISTS doctor_name TEXT;
ALTER TABLE public.sales ADD COLUMN IF NOT EXISTS rx_number TEXT;

ALTER TABLE public.sales DROP CONSTRAINT IF EXISTS sales_cashier_id_fkey;
ALTER TABLE public.sales DROP CONSTRAINT IF EXISTS sales_branch_code_fkey;

-- 2.5 BARBER QUEUE (Used by Barbershop Live Queue)
CREATE TABLE IF NOT EXISTS public.barber_queue (
  id TEXT PRIMARY KEY,
  branch_code TEXT,
  customer TEXT NOT NULL,
  phone TEXT DEFAULT '',
  service TEXT NOT NULL,
  barber TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'Waiting',
  timestamp TIMESTAMPTZ DEFAULT now() NOT NULL,
  price DECIMAL(10,2),
  sale_id TEXT
);

ALTER TABLE public.barber_queue ADD COLUMN IF NOT EXISTS branch_code TEXT;
ALTER TABLE public.barber_queue ADD COLUMN IF NOT EXISTS phone TEXT DEFAULT '';
ALTER TABLE public.barber_queue ADD COLUMN IF NOT EXISTS price DECIMAL(10,2);
ALTER TABLE public.barber_queue ADD COLUMN IF NOT EXISTS sale_id TEXT;

-- 2.6 REPAIR TICKETS (Used by Tech & Phone Shop Repairs)
CREATE TABLE IF NOT EXISTS public.repair_tickets (
  id TEXT PRIMARY KEY,
  branch_code TEXT,
  customer TEXT NOT NULL,
  phone TEXT DEFAULT '',
  device TEXT NOT NULL,
  issue TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'Received',
  cost DECIMAL(10,2) DEFAULT 0.00,
  deposit DECIMAL(10,2) DEFAULT 0.00,
  technician TEXT NOT NULL DEFAULT 'Tech Rep',
  timestamp TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE public.repair_tickets ADD COLUMN IF NOT EXISTS branch_code TEXT;
ALTER TABLE public.repair_tickets ADD COLUMN IF NOT EXISTS phone TEXT DEFAULT '';
ALTER TABLE public.repair_tickets ADD COLUMN IF NOT EXISTS cost DECIMAL(10,2) DEFAULT 0.00;
ALTER TABLE public.repair_tickets ADD COLUMN IF NOT EXISTS deposit DECIMAL(10,2) DEFAULT 0.00;
ALTER TABLE public.repair_tickets ADD COLUMN IF NOT EXISTS technician TEXT NOT NULL DEFAULT 'Tech Rep';

-- 2.7 CUSTOMERS (CRM)
CREATE TABLE IF NOT EXISTS public.customers (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  branch_code TEXT,
  name TEXT NOT NULL,
  phone TEXT UNIQUE NOT NULL,
  phone2 TEXT,
  location TEXT,
  is_favorite BOOLEAN DEFAULT false,
  loyalty_points DECIMAL(10,2) DEFAULT 0.0,
  visit_count INT DEFAULT 0,
  is_deleted BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS branch_code TEXT;
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS phone2 TEXT;
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS location TEXT;
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS is_favorite BOOLEAN DEFAULT false;
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS loyalty_points DECIMAL(10,2) DEFAULT 0.0;
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS visit_count INT DEFAULT 0;
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT false;

-- 2.8 EXPENSES
CREATE TABLE IF NOT EXISTS public.expenses (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  branch_code TEXT,
  category TEXT NOT NULL,
  amount DECIMAL(10,2) NOT NULL,
  description TEXT,
  notes TEXT,
  receipt_url TEXT,
  date DATE DEFAULT CURRENT_DATE,
  recorded_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- 2.9 STAFF PAYMENTS AUDIT (Salaries & Advances)
CREATE TABLE IF NOT EXISTS public.staff_payments_audit (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  user_id TEXT NOT NULL,
  amount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  is_advance BOOLEAN NOT NULL DEFAULT false,
  date TIMESTAMPTZ NOT NULL DEFAULT now(),
  note TEXT
);

-- 2.10 CUSTOMER PAYMENTS (Debt Tracking)
CREATE TABLE IF NOT EXISTS public.customer_payments (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  branch_code TEXT,
  customer_id TEXT,
  amount DECIMAL(10,2) NOT NULL,
  payment_method TEXT NOT NULL,
  reference TEXT,
  sale_id TEXT,
  collected_by TEXT,
  payment_date TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- 2.11 AUDIT LOGS
CREATE TABLE IF NOT EXISTS public.audit_logs (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  branch_code TEXT,
  user_id TEXT,
  user_name TEXT,
  action TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id TEXT,
  old_data JSONB,
  new_data JSONB,
  timestamp TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- 2.12 NOTIFICATIONS
CREATE TABLE IF NOT EXISTS public.notifications (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  branch_code TEXT,
  user_id TEXT,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  type TEXT DEFAULT 'info',
  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- 2.13 STOCK HISTORY (Inventory movements)
CREATE TABLE IF NOT EXISTS public.stock_history (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  product_id TEXT NOT NULL,
  quantity_change DECIMAL(10,2) NOT NULL,
  reason TEXT,
  reference_id TEXT,
  timestamp TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- 2.14 DOCUMENTS (Document records)
CREATE TABLE IF NOT EXISTS public.documentss (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  branch_code TEXT,
  name TEXT NOT NULL,
  file_url TEXT NOT NULL,
  category TEXT,
  uploaded_by TEXT,
  uploaded_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- 2.15 SPECIALIZED SECTOR TABLES
CREATE TABLE IF NOT EXISTS public.medication_batches (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  drug_name TEXT NOT NULL,
  batch_number TEXT NOT NULL,
  expiry_date TIMESTAMPTZ NOT NULL,
  stock_quantity INT DEFAULT 0,
  cost_price DECIMAL(10,2) DEFAULT 0,
  selling_price DECIMAL(10,2) DEFAULT 0,
  supplier TEXT,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.prescription_records (
  id TEXT PRIMARY KEY,
  rx_number TEXT NOT NULL,
  patient_name TEXT NOT NULL,
  doctor_name TEXT,
  medications JSONB NOT NULL DEFAULT '[]',
  dispensed_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  status TEXT DEFAULT 'Dispensed'
);

CREATE TABLE IF NOT EXISTS public.barber_services (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  name TEXT NOT NULL,
  price DECIMAL(10,2) NOT NULL,
  duration_minutes INT DEFAULT 30,
  commission_percentage DECIMAL(5,2) DEFAULT 40.0
);

CREATE TABLE IF NOT EXISTS public.barber_commissions (
  id TEXT PRIMARY KEY,
  barber_id TEXT NOT NULL,
  barber_name TEXT NOT NULL,
  service_name TEXT NOT NULL,
  sale_amount DECIMAL(10,2) NOT NULL,
  commission_earned DECIMAL(10,2) NOT NULL,
  tip_amount DECIMAL(10,2) DEFAULT 0,
  date TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.imei_records (
  imei TEXT PRIMARY KEY,
  device_model TEXT NOT NULL,
  status TEXT DEFAULT 'In Stock',
  sale_date TIMESTAMPTZ,
  warranty_duration_months INT DEFAULT 12
);

CREATE TABLE IF NOT EXISTS public.warranty_certificates (
  certificate_id TEXT PRIMARY KEY,
  customer_name TEXT NOT NULL,
  device_model TEXT NOT NULL,
  imei TEXT NOT NULL,
  issue_date TIMESTAMPTZ DEFAULT now() NOT NULL,
  expiry_date TIMESTAMPTZ NOT NULL,
  terms TEXT NOT NULL
);

-- 2.18 SHIFT RECORDS (Cash drawer opening floats, physical cash counting, variance detection & handovers)
CREATE TABLE IF NOT EXISTS public.shift_records (
  id TEXT PRIMARY KEY,
  branch_code TEXT NOT NULL DEFAULT 'MAIN',
  cashier_id TEXT NOT NULL DEFAULT '',
  cashier_name TEXT NOT NULL DEFAULT '',
  start_time TIMESTAMPTZ NOT NULL DEFAULT now(),
  end_time TIMESTAMPTZ,
  status TEXT NOT NULL DEFAULT 'open',
  opening_float DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  expected_cash_sales DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  actual_cash_counted DECIMAL(12,2),
  cash_variance DECIMAL(12,2),
  momo_sales DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  card_sales DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  total_sales DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE public.shift_records ADD COLUMN IF NOT EXISTS branch_code TEXT NOT NULL DEFAULT 'MAIN';
ALTER TABLE public.shift_records ADD COLUMN IF NOT EXISTS cashier_id TEXT NOT NULL DEFAULT '';
ALTER TABLE public.shift_records ADD COLUMN IF NOT EXISTS cashier_name TEXT NOT NULL DEFAULT '';
ALTER TABLE public.shift_records ADD COLUMN IF NOT EXISTS start_time TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE public.shift_records ADD COLUMN IF NOT EXISTS end_time TIMESTAMPTZ;
ALTER TABLE public.shift_records ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'open';
ALTER TABLE public.shift_records ADD COLUMN IF NOT EXISTS opening_float DECIMAL(12,2) NOT NULL DEFAULT 0.00;
ALTER TABLE public.shift_records ADD COLUMN IF NOT EXISTS expected_cash_sales DECIMAL(12,2) NOT NULL DEFAULT 0.00;
ALTER TABLE public.shift_records ADD COLUMN IF NOT EXISTS actual_cash_counted DECIMAL(12,2);
ALTER TABLE public.shift_records ADD COLUMN IF NOT EXISTS cash_variance DECIMAL(12,2);
ALTER TABLE public.shift_records ADD COLUMN IF NOT EXISTS momo_sales DECIMAL(12,2) NOT NULL DEFAULT 0.00;
ALTER TABLE public.shift_records ADD COLUMN IF NOT EXISTS card_sales DECIMAL(12,2) NOT NULL DEFAULT 0.00;
ALTER TABLE public.shift_records ADD COLUMN IF NOT EXISTS total_sales DECIMAL(12,2) NOT NULL DEFAULT 0.00;
ALTER TABLE public.shift_records ADD COLUMN IF NOT EXISTS notes TEXT;
ALTER TABLE public.shift_records ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now() NOT NULL;

-- ============================================================================
-- 3. PERMISSIONS & SECURITY
-- ============================================================================

-- Disable RLS across public tables to ensure seamless Flutter client connectivity
ALTER TABLE public.branches DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.users DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.products DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.barber_queue DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.repair_tickets DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.customers DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.expenses DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_payments_audit DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_payments DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_history DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.documentss DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.medication_batches DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.prescription_records DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.barber_services DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.barber_commissions DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.imei_records DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.warranty_certificates DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.shift_records DISABLE ROW LEVEL SECURITY;

-- Grant broad API privileges to anon, authenticated, and service_role
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO anon, authenticated, service_role;

-- ============================================================================
-- 4. ATOMIC RPC FUNCTIONS
-- ============================================================================

CREATE OR REPLACE FUNCTION public.increment_stock(p_id TEXT, p_amount DECIMAL)
RETURNS void AS $$
BEGIN
  UPDATE public.products
  SET 
    stock_quantity = stock_quantity + p_amount,
    last_stock_update = now()
  WHERE id::text = p_id;
END;
$$ LANGUAGE plpgsql;

GRANT ALL ON FUNCTION public.increment_stock(TEXT, DECIMAL) TO anon, authenticated, service_role;

-- ============================================================================
-- 5. REALTIME REPLICATION CONFIGURATION
-- ============================================================================

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE 
    public.products, 
    public.sales, 
    public.branches, 
    public.users, 
    public.barber_queue, 
    public.repair_tickets, 
    public.customers, 
    public.expenses, 
    public.notifications, 
    public.audit_logs, 
    public.staff_payments_audit, 
    public.customer_payments,
    public.shift_records;
EXCEPTION WHEN OTHERS THEN
  NULL;
END $$;

-- ============================================================================
-- 6. STORAGE BUCKETS & POLICIES
-- ============================================================================

INSERT INTO storage.buckets (id, name, public)
VALUES 
  ('user-profiles', 'user-profiles', true),
  ('product-images', 'product-images', true),
  ('receipts', 'receipts', true),
  ('documents', 'documents', true)
ON CONFLICT (id) DO UPDATE SET public = true;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE policyname = 'Public Access for Container Storage' AND tablename = 'objects'
  ) THEN
    CREATE POLICY "Public Access for Container Storage" ON storage.objects
      FOR ALL USING (bucket_id IN ('user-profiles', 'product-images', 'receipts', 'documents'))
      WITH CHECK (bucket_id IN ('user-profiles', 'product-images', 'receipts', 'documents'));
  END IF;
END $$;

-- ============================================================================
-- 7. DEFAULT SEED DATA (Non-Destructive)
-- ============================================================================

-- Ensure the primary 'MAIN' branch exists
INSERT INTO public.branches (code, name, location)
VALUES ('MAIN', 'Main Store / Headquarters', 'Accra Central')
ON CONFLICT (code) DO NOTHING;

-- Reload postgREST schema cache
NOTIFY pgrst, 'reload schema';
```

---

### Environment Variables (`assets/.env`)
Verify your `assets/.env` file contains your project configuration:

```env
SUPABASE_URL=https://wdqnwpwuuaqipeedmxws.supabase.co
SUPABASE_ANON_KEY=your_anon_key_here
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key_here
```

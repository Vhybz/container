# Supabase Setup Guide (Multi-Business Management System)

This project uses **Supabase** as its cloud backend. Copy and execute the following SQL script in your **Supabase SQL Editor** to perform a complete database setup.

> [!WARNING]
> Running Section 1 (Nuclear Reset) will drop and recreate the `public` schema. Use it only when setting up a fresh project or completely resetting the database.

---

```sql
-- =====================================================
-- 1. NUCLEAR RESET (Wipe & Recreate Schema)
-- =====================================================

DROP SCHEMA public CASCADE;
CREATE SCHEMA public;

-- Restore standard schema permissions
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO anon;
GRANT ALL ON SCHEMA public TO authenticated;
GRANT ALL ON SCHEMA public TO service_role;

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =====================================================
-- 2. CORE IDENTITY & BRANCH TABLES
-- =====================================================

-- BRANCHES (Business Locations / Sub-Units)
CREATE TABLE public.branches (
  code TEXT PRIMARY KEY, 
  name TEXT NOT NULL,
  location TEXT NOT NULL,
  admin_id UUID,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- USERS (Staff, Admin, Pharmacist, Barber, Phone Sales Profiles)
CREATE TABLE public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  first_name TEXT NOT NULL,
  surname TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  phone TEXT,
  gender TEXT,
  dob DATE,
  photo_url TEXT,
  role TEXT NOT NULL, -- 'admin', 'pharmacist', 'barber', 'phoneSales', 'cashier'
  branch_code TEXT REFERENCES public.branches(code),
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

-- =====================================================
-- 3. INVENTORY & RETAIL TABLES (Multi-Sector Extended)
-- =====================================================

-- PRODUCTS (Master Stock across Pharmacy, Barbershop, Tech, Retail)
CREATE TABLE public.products (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  branch_code TEXT REFERENCES public.branches(code),
  name TEXT NOT NULL,
  retail_price DECIMAL(10,2) NOT NULL,
  wholesale_price DECIMAL(10,2) NOT NULL,
  cost_price DECIMAL(10,2) DEFAULT 0,
  retail_brackets JSONB DEFAULT '[]',
  wholesale_brackets JSONB DEFAULT '[]',
  image_url TEXT,
  category TEXT NOT NULL,
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
  
  -- Multi-Sector Extension Columns
  imei_list TEXT[] DEFAULT '{}',
  batch_expiry_date TIMESTAMPTZ,
  batch_number TEXT,
  is_service BOOLEAN DEFAULT false,
  requires_prescription BOOLEAN DEFAULT false,
  requires_imei BOOLEAN DEFAULT false
);

-- SALES (Transactions & POS Records)
CREATE TABLE public.sales (
  id TEXT PRIMARY KEY,
  branch_code TEXT REFERENCES public.branches(code),
  timestamp TIMESTAMPTZ DEFAULT now() NOT NULL,
  cashier_id UUID REFERENCES public.users(id),
  cashier_name TEXT NOT NULL,
  total_amount DECIMAL(10,2) NOT NULL,
  total_discount DECIMAL(10,2) DEFAULT 0,
  total_cost DECIMAL(10,2) DEFAULT 0,
  applied_promo TEXT,
  customer_name TEXT,
  customer_phone TEXT,
  status TEXT DEFAULT 'completed',
  correction_reason TEXT,
  bank_receipt_url TEXT,
  bank_receipt_id TEXT,
  items JSONB NOT NULL,
  payments JSONB NOT NULL,
  is_verified BOOLEAN DEFAULT false
);

-- =====================================================
-- 4. PHARMACY SECTOR TABLES
-- =====================================================

-- MEDICATION BATCHES
CREATE TABLE public.medication_batches (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  drug_name TEXT NOT NULL,
  batch_number TEXT NOT NULL UNIQUE,
  expiry_date TIMESTAMPTZ NOT NULL,
  stock_quantity INT DEFAULT 0,
  cost_price DECIMAL(10,2) DEFAULT 0,
  selling_price DECIMAL(10,2) DEFAULT 0,
  supplier TEXT,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- PRESCRIPTION RECORDS
CREATE TABLE public.prescription_records (
  id TEXT PRIMARY KEY,
  rx_number TEXT NOT NULL,
  patient_name TEXT NOT NULL,
  doctor_name TEXT,
  medications JSONB NOT NULL,
  dispensed_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  status TEXT DEFAULT 'Dispensed'
);

-- =====================================================
-- 5. BARBERSHOP SECTOR TABLES
-- =====================================================

-- BARBER SERVICES
CREATE TABLE public.barber_services (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  price DECIMAL(10,2) NOT NULL,
  duration_minutes INT DEFAULT 30,
  commission_percentage DECIMAL(5,2) DEFAULT 40.0
);

-- APPOINTMENT QUEUE
CREATE TABLE public.appointment_queue (
  id TEXT PRIMARY KEY,
  customer_name TEXT NOT NULL,
  service_name TEXT NOT NULL,
  assigned_barber_id TEXT NOT NULL,
  assigned_barber_name TEXT NOT NULL,
  scheduled_time TEXT NOT NULL,
  status TEXT DEFAULT 'Waiting',
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- BARBER COMMISSIONS LOG
CREATE TABLE public.barber_commissions (
  id TEXT PRIMARY KEY,
  barber_id TEXT NOT NULL,
  barber_name TEXT NOT NULL,
  service_name TEXT NOT NULL,
  sale_amount DECIMAL(10,2) NOT NULL,
  commission_earned DECIMAL(10,2) NOT NULL,
  tip_amount DECIMAL(10,2) DEFAULT 0,
  date TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- =====================================================
-- 6. TECH & PHONE SHOP SECTOR TABLES
-- =====================================================

-- IMEI DEVICE INVENTORY
CREATE TABLE public.imei_records (
  imei TEXT PRIMARY KEY,
  device_model TEXT NOT NULL,
  status TEXT DEFAULT 'In Stock', -- 'In Stock', 'Sold', 'Under Repair'
  sale_date TIMESTAMPTZ,
  warranty_duration_months INT DEFAULT 12
);

-- REPAIR WORK ORDERS
CREATE TABLE public.repair_work_orders (
  ticket_id TEXT PRIMARY KEY,
  customer_name TEXT NOT NULL,
  customer_phone TEXT,
  device_model TEXT NOT NULL,
  issue_description TEXT NOT NULL,
  labor_cost DECIMAL(10,2) DEFAULT 0,
  parts_cost DECIMAL(10,2) DEFAULT 0,
  status TEXT DEFAULT 'In Progress',
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- WARRANTY CERTIFICATES
CREATE TABLE public.warranty_certificates (
  certificate_id TEXT PRIMARY KEY,
  customer_name TEXT NOT NULL,
  device_model TEXT NOT NULL,
  imei TEXT NOT NULL,
  issue_date TIMESTAMPTZ DEFAULT now() NOT NULL,
  expiry_date TIMESTAMPTZ NOT NULL,
  terms TEXT NOT NULL
);

-- =====================================================
-- 7. LOGISTICS, EXPENSES & CRM
-- =====================================================

-- CUSTOMERS (CRM)
CREATE TABLE public.customers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  branch_code TEXT REFERENCES public.branches(code),
  name TEXT NOT NULL,
  phone TEXT UNIQUE NOT NULL,
  location TEXT,
  is_favorite BOOLEAN DEFAULT false,
  loyalty_points DECIMAL(10,2) DEFAULT 0.0,
  visit_count INT DEFAULT 0,
  is_deleted BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- EXPENSES
CREATE TABLE public.expenses (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  branch_code TEXT REFERENCES public.branches(code),
  category TEXT NOT NULL,
  amount DECIMAL(10,2) NOT NULL,
  description TEXT,
  notes TEXT,
  receipt_url TEXT,
  date DATE DEFAULT CURRENT_DATE,
  recorded_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- STAFF PAYMENTS AUDIT
CREATE TABLE public.staff_payments_audit (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL,
  amount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  is_advance BOOLEAN NOT NULL DEFAULT false,
  date TIMESTAMPTZ NOT NULL DEFAULT now(),
  note TEXT
);

-- CUSTOMER PAYMENTS (Debt Tracking)
CREATE TABLE public.customer_payments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  branch_code TEXT REFERENCES public.branches(code),
  customer_id UUID REFERENCES public.customers(id),
  amount DECIMAL(10,2) NOT NULL,
  payment_method TEXT NOT NULL,
  reference TEXT,
  sale_id TEXT REFERENCES public.sales(id),
  collected_by UUID REFERENCES public.users(id),
  payment_date TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- AUDIT LOGS
CREATE TABLE public.audit_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  branch_code TEXT REFERENCES public.branches(code),
  user_id UUID REFERENCES public.users(id),
  user_name TEXT,
  action TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id TEXT,
  old_data JSONB,
  new_data JSONB,
  timestamp TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- NOTIFICATIONS
CREATE TABLE public.notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  branch_code TEXT REFERENCES public.branches(code),
  user_id UUID REFERENCES public.users(id),
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  type TEXT DEFAULT 'info',
  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- =====================================================
-- 8. SECURITY & PERMISSIONS
-- =====================================================

-- Disable RLS for rapid development
ALTER TABLE public.branches DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.users DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.products DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.medication_batches DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.prescription_records DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.barber_services DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.appointment_queue DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.barber_commissions DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.imei_records DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.repair_work_orders DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.warranty_certificates DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.expenses DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.customers DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_payments DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_payments_audit DISABLE ROW LEVEL SECURITY;

-- Grant permissions to standard API roles
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO anon, authenticated, service_role;

-- =====================================================
-- 9. REALTIME CONFIGURATION
-- =====================================================

ALTER PUBLICATION supabase_realtime ADD TABLE 
  public.notifications, 
  public.products, 
  public.sales, 
  public.medication_batches,
  public.appointment_queue,
  public.repair_work_orders,
  public.customers, 
  public.expenses, 
  public.users, 
  public.staff_payments_audit;

-- =====================================================
-- 10. RPC FUNCTIONS
-- =====================================================

-- Atomic stock increment function
CREATE OR REPLACE FUNCTION public.increment_stock(p_id UUID, p_amount DECIMAL)
RETURNS void AS $$
BEGIN
  UPDATE public.products
  SET 
    stock_quantity = stock_quantity + p_amount,
    last_stock_update = now()
  WHERE id = p_id;
END;
$$ LANGUAGE plpgsql;

GRANT ALL ON FUNCTION public.increment_stock TO anon, authenticated, service_role;

-- Notify schema reload
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

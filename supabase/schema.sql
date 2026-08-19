-- ============================================================
-- BEON COSMETIC — SUPABASE SCHEMA
-- Run this in your Supabase SQL Editor (Dashboard > SQL Editor)
-- ============================================================

-- ─── 1. PROFILES (extends auth.users) ─────────────────────
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL DEFAULT '',
  full_name TEXT NOT NULL DEFAULT '',
  role TEXT NOT NULL DEFAULT 'staff' CHECK (role IN ('admin', 'staff')),
  phone TEXT,
  avatar_url TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Auto-create profile on user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'role', 'staff')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ─── 2. STAFF ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.staff (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  staff_code TEXT NOT NULL DEFAULT '',
  name TEXT NOT NULL DEFAULT '',
  email TEXT,
  phone TEXT,
  commission_type TEXT NOT NULL DEFAULT 'fixed' CHECK (commission_type IN ('fixed', 'percentage')),
  commission_value NUMERIC(10,2) NOT NULL DEFAULT 100.00,
  return_penalty NUMERIC(10,2) NOT NULL DEFAULT 100.00,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id),
  UNIQUE(staff_code)
);

-- ─── 3. CLIENTS ───────────────────────────────────────────
-- ─── 4. PRODUCTS ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  sku TEXT UNIQUE,
  description TEXT,
  price NUMERIC(10,2) NOT NULL DEFAULT 0,
  cost_price NUMERIC(10,2),
  stock_quantity INTEGER NOT NULL DEFAULT 0,
  low_stock_threshold INTEGER NOT NULL DEFAULT 10,
  category TEXT,
  image_url TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ─── 5. COURIERS ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.couriers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Insert default couriers
INSERT INTO public.couriers (name) VALUES
  ('Leopards'), ('TCS'), ('PostEx'), ('TRAX'), ('M&P'), ('Call Courier')
ON CONFLICT (name) DO NOTHING;

-- ─── 6. DELIVERY CHARGES ─────────────────────────────────
CREATE TABLE IF NOT EXISTS public.delivery_charges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  city TEXT NOT NULL UNIQUE,
  charge NUMERIC(10,2) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Insert default city charges
INSERT INTO public.delivery_charges (city, charge) VALUES
  ('Lahore', 200), ('Karachi', 250), ('Islamabad', 220), ('Okara', 180)
ON CONFLICT (city) DO NOTHING;

-- ─── 7. ORDERS ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id TEXT UNIQUE, -- Display ID like "BO-00001"
  order_date TIMESTAMPTZ NOT NULL DEFAULT now(),
  staff_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  staff_name TEXT,
  staff_code TEXT,
  customer_name TEXT NOT NULL,
  customer_mobile TEXT NOT NULL,
  customer_whatsapp TEXT,
  address TEXT NOT NULL,
  city TEXT NOT NULL,
  product_name TEXT NOT NULL,
  quantity INTEGER NOT NULL DEFAULT 1,
  cod_amount NUMERIC(10,2) NOT NULL DEFAULT 0,
  delivery_charges NUMERIC(10,2) NOT NULL DEFAULT 0,
  discount NUMERIC(10,2) NOT NULL DEFAULT 0,
  courier_company TEXT,
  tracking_number TEXT,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','delivered','returned')),
  notes TEXT,
  proof_image_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Auto-generate order_id sequence
CREATE SEQUENCE IF NOT EXISTS order_id_seq START 1;

CREATE OR REPLACE FUNCTION public.generate_order_id()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.order_id IS NULL THEN
    NEW.order_id := 'BO-' || LPAD(nextval('order_id_seq')::TEXT, 5, '0');
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_order_id ON public.orders;
CREATE TRIGGER set_order_id
  BEFORE INSERT ON public.orders
  FOR EACH ROW EXECUTE FUNCTION public.generate_order_id();

-- ─── 8. ORDER LOGS (audit trail) ─────────────────────────
CREATE TABLE IF NOT EXISTS public.order_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  action TEXT NOT NULL, -- 'created', 'updated', 'status_changed', 'deleted'
  field_name TEXT,
  old_value TEXT,
  new_value TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Auto-log order status changes
CREATE OR REPLACE FUNCTION public.log_order_changes()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status THEN
    INSERT INTO public.order_logs (order_id, user_id, action, field_name, old_value, new_value)
    VALUES (NEW.id, auth.uid(), 'status_changed', 'status', OLD.status, NEW.status);
  END IF;
  NEW.updated_at := now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_order_updated ON public.orders;
CREATE TRIGGER on_order_updated
  BEFORE UPDATE ON public.orders
  FOR EACH ROW EXECUTE FUNCTION public.log_order_changes();

-- ─── 9. LOCK DELIVERED/RETURN STATUS ──────────────────────
-- Only admin can change delivered/returned orders, and proof must exist
CREATE OR REPLACE FUNCTION public.enforce_status_lock()
RETURNS TRIGGER AS $$
DECLARE
  user_role TEXT;
BEGIN
  -- If old status is locked (delivered/returned), check permissions
  IF OLD.status IN ('delivered', 'returned') AND OLD.status IS DISTINCT FROM NEW.status THEN
    SELECT role INTO user_role FROM public.profiles WHERE id = auth.uid();
    IF user_role != 'admin' THEN
      RAISE EXCEPTION 'Only admin can change delivered/returned status';
    END IF;
  END IF;

  -- If changing TO delivered/returned, proof image is required
  IF NEW.status IN ('delivered', 'returned') AND OLD.status IS DISTINCT FROM NEW.status THEN
    IF NEW.proof_image_url IS NULL OR NEW.proof_image_url = '' THEN
      RAISE EXCEPTION 'Proof image is required for delivered/returned status';
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS enforce_order_lock ON public.orders;
CREATE TRIGGER enforce_order_lock
  BEFORE UPDATE ON public.orders
  FOR EACH ROW EXECUTE FUNCTION public.enforce_status_lock();

-- Admin-only permanent staff deletion. Orders/logs remain as admin history.
CREATE OR REPLACE FUNCTION public.delete_staff_account(target_staff_id UUID)
RETURNS VOID AS $$
DECLARE
  target_user_id UUID;
  target_name TEXT;
  target_code TEXT;
BEGIN
  IF public.get_user_role() <> 'admin' THEN
    RAISE EXCEPTION 'Only admin can delete a staff account';
  END IF;
  SELECT user_id, name, staff_code INTO target_user_id, target_name, target_code
  FROM public.staff WHERE id = target_staff_id;
  IF target_user_id IS NULL OR target_user_id = auth.uid() THEN
    RAISE EXCEPTION 'Staff account cannot be deleted';
  END IF;
  UPDATE public.orders
  SET staff_name = COALESCE(NULLIF(staff_name, ''), target_name),
      staff_code = COALESCE(NULLIF(staff_code, ''), target_code),
      staff_id = NULL
  WHERE staff_id = target_user_id;
  DELETE FROM auth.users WHERE id = target_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth;

-- ─── 10. COD LEDGER ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.cod_ledger (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  total_cod NUMERIC(10,2) NOT NULL DEFAULT 0,
  delivered_cod NUMERIC(10,2) NOT NULL DEFAULT 0,
  pending_cod NUMERIC(10,2) NOT NULL DEFAULT 0,
  received_amount NUMERIC(10,2) NOT NULL DEFAULT 0,
  delivery_charges_deduction NUMERIC(10,2) NOT NULL DEFAULT 0,
  return_charges NUMERIC(10,2) NOT NULL DEFAULT 0,
  net_payable NUMERIC(10,2) NOT NULL DEFAULT 0,
  payment_date DATE,
  payment_proof TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ─── 11. SALARY RECORDS ──────────────────────────────────
CREATE TABLE IF NOT EXISTS public.salary_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  staff_id UUID NOT NULL REFERENCES public.staff(id),
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  delivered_count INTEGER NOT NULL DEFAULT 0,
  return_count INTEGER NOT NULL DEFAULT 0,
  commission_earned NUMERIC(10,2) NOT NULL DEFAULT 0,
  penalty_deducted NUMERIC(10,2) NOT NULL DEFAULT 0,
  final_salary NUMERIC(10,2) NOT NULL DEFAULT 0,
  is_paid BOOLEAN NOT NULL DEFAULT false,
  paid_date DATE,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ─── 12. SETTINGS ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key TEXT NOT NULL UNIQUE,
  value TEXT NOT NULL,
  description TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Insert defaults
INSERT INTO public.settings (key, value, description) VALUES
  ('default_commission_type', 'fixed', 'Default commission type for new staff'),
  ('default_commission_value', '100', 'Default commission value'),
  ('default_return_penalty', '100', 'Default return penalty amount'),
  ('low_stock_threshold', '10', 'Default low stock warning threshold')
ON CONFLICT (key) DO NOTHING;

-- ─── 13. BLACKLIST ───────────────────────────────────────

-- ─── 14. AUTO-UPDATE updated_at ──────────────────────────
CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to all tables with updated_at
DO $$ 
DECLARE
  t TEXT;
BEGIN
  FOR t IN SELECT unnest(ARRAY[
    'profiles','staff','products',
    'delivery_charges','orders','cod_ledger',
    'salary_records','settings'
  ]) LOOP
    EXECUTE format(
      'DROP TRIGGER IF EXISTS update_%s_updated_at ON public.%s;
       CREATE TRIGGER update_%s_updated_at
         BEFORE UPDATE ON public.%s
         FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();',
      t, t, t, t
    );
  END LOOP;
END $$;


-- ============================================================
-- ROW LEVEL SECURITY POLICIES
-- ============================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cod_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.salary_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.couriers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.delivery_charges ENABLE ROW LEVEL SECURITY;

-- ─── Helper function ─────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_user_role()
RETURNS TEXT AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ─── PROFILES ────────────────────────────────────────────
CREATE POLICY "Users can view own profile" ON public.profiles
  FOR SELECT USING (id = auth.uid());
CREATE POLICY "Admin can view all profiles" ON public.profiles
  FOR SELECT USING (public.get_user_role() = 'admin');
CREATE POLICY "Admin can manage profiles" ON public.profiles
  FOR ALL USING (public.get_user_role() = 'admin');
CREATE POLICY "Users can update own profile" ON public.profiles
  FOR UPDATE USING (id = auth.uid())
  WITH CHECK (
    id = auth.uid()
    AND role = (SELECT role FROM public.profiles WHERE id = auth.uid())
    AND is_active = (SELECT is_active FROM public.profiles WHERE id = auth.uid())
  );

-- ─── STAFF ───────────────────────────────────────────────
CREATE POLICY "Admin can manage staff" ON public.staff
  FOR ALL USING (public.get_user_role() = 'admin');
CREATE POLICY "Staff can view own record" ON public.staff
  FOR SELECT USING (user_id = auth.uid());

-- ─── CLIENTS ─────────────────────────────────────────────

-- ─── PRODUCTS ────────────────────────────────────────────
CREATE POLICY "Anyone authenticated can view products" ON public.products
  FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Admin can manage products" ON public.products
  FOR ALL USING (public.get_user_role() = 'admin');

-- ─── ORDERS ──────────────────────────────────────────────
CREATE POLICY "Admin can manage all orders" ON public.orders
  FOR ALL USING (public.get_user_role() = 'admin');
CREATE POLICY "Staff can view own orders" ON public.orders
  FOR SELECT USING (staff_id = auth.uid());
CREATE POLICY "Staff can create orders" ON public.orders
  FOR INSERT WITH CHECK (
    staff_id = auth.uid() AND
    public.get_user_role() = 'staff'
  );
CREATE POLICY "Staff can update own undispatched orders" ON public.orders
  FOR UPDATE USING (
    staff_id = auth.uid() AND
    status = 'pending' AND
    public.get_user_role() = 'staff'
  ) WITH CHECK (
    staff_id = auth.uid() AND
    status = 'pending' AND
    public.get_user_role() = 'staff'
  );

-- ─── ORDER LOGS ──────────────────────────────────────────
CREATE POLICY "Admin can view all logs" ON public.order_logs
  FOR SELECT USING (public.get_user_role() = 'admin');
CREATE POLICY "Staff can view own order logs" ON public.order_logs
  FOR SELECT USING (
    order_id IN (SELECT id FROM public.orders WHERE staff_id = auth.uid())
  );
CREATE POLICY "System can insert logs" ON public.order_logs
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- ─── COD LEDGER ──────────────────────────────────────────
CREATE POLICY "Admin can manage cod_ledger" ON public.cod_ledger
  FOR ALL USING (public.get_user_role() = 'admin');

-- ─── SALARY RECORDS ─────────────────────────────────────
CREATE POLICY "Admin can manage salary" ON public.salary_records
  FOR ALL USING (public.get_user_role() = 'admin');
CREATE POLICY "Staff can view own salary" ON public.salary_records
  FOR SELECT USING (
    staff_id IN (SELECT id FROM public.staff WHERE user_id = auth.uid())
  );

-- ─── SETTINGS (admin only) ──────────────────────────────
CREATE POLICY "Admin can manage settings" ON public.settings
  FOR ALL USING (public.get_user_role() = 'admin');
CREATE POLICY "Authenticated can read settings" ON public.settings
  FOR SELECT USING (auth.uid() IS NOT NULL);

-- ─── COURIERS ────────────────────────────────────────────
CREATE POLICY "Anyone can view couriers" ON public.couriers
  FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Admin can manage couriers" ON public.couriers
  FOR ALL USING (public.get_user_role() = 'admin');

-- ─── DELIVERY CHARGES ───────────────────────────────────
CREATE POLICY "Anyone can view charges" ON public.delivery_charges
  FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Admin can manage charges" ON public.delivery_charges
  FOR ALL USING (public.get_user_role() = 'admin');

-- ─── BLACKLIST ──────────────────────────────────────────

-- ─── INDEXES ────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_orders_staff_id ON public.orders(staff_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON public.orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_order_date ON public.orders(order_date);
CREATE INDEX IF NOT EXISTS idx_orders_customer_mobile ON public.orders(customer_mobile);
CREATE INDEX IF NOT EXISTS idx_orders_city ON public.orders(city);
CREATE INDEX IF NOT EXISTS idx_order_logs_order_id ON public.order_logs(order_id);
CREATE INDEX IF NOT EXISTS idx_salary_records_staff_id ON public.salary_records(staff_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_salary_records_period_unique
  ON public.salary_records(staff_id, period_start, period_end);

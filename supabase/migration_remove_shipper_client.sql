-- Run once in Supabase SQL Editor.
-- Removes Client/Shipper, enables permanent staff deletion, and keeps only
-- Pending, Delivered and Return order statuses.

UPDATE public.profiles
SET role = 'staff', is_active = false, updated_at = now()
WHERE role = 'shipper';

DROP POLICY IF EXISTS "Shipper can update assigned orders" ON public.orders;
DROP POLICY IF EXISTS orders_shipper_update ON public.orders;
DROP POLICY IF EXISTS "Shipper can view assigned orders" ON public.orders;
DROP POLICY IF EXISTS orders_shipper_select ON public.orders;
DROP POLICY IF EXISTS "Client can view own orders" ON public.orders;
DROP POLICY IF EXISTS "Client can view own cod ledger" ON public.cod_ledger;

ALTER TABLE public.orders DROP COLUMN IF EXISTS client_id;
ALTER TABLE public.orders DROP COLUMN IF EXISTS shipper_id;
ALTER TABLE public.cod_ledger DROP COLUMN IF EXISTS client_id;
DROP INDEX IF EXISTS public.idx_orders_client_id;
DROP INDEX IF EXISTS public.idx_orders_shipper_id;
DROP INDEX IF EXISTS public.idx_cod_ledger_client_id;
DROP TABLE IF EXISTS public.shippers CASCADE;

ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_role_check CHECK (role IN ('admin', 'staff'));

-- Convert all removed legacy statuses to Pending before applying the new rule.
UPDATE public.orders
SET status = 'pending'
WHERE status NOT IN ('pending', 'delivered', 'returned');
ALTER TABLE public.orders ALTER COLUMN status SET DEFAULT 'pending';
ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_status_check;
ALTER TABLE public.orders
  ADD CONSTRAINT orders_status_check
  CHECK (status IN ('pending', 'delivered', 'returned'));

-- Preserve orders and audit rows if a staff account is deleted.
ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_staff_id_fkey;
ALTER TABLE public.orders ALTER COLUMN staff_id DROP NOT NULL;
ALTER TABLE public.orders
  ADD CONSTRAINT orders_staff_id_fkey
  FOREIGN KEY (staff_id) REFERENCES public.profiles(id) ON DELETE SET NULL;

ALTER TABLE public.order_logs DROP CONSTRAINT IF EXISTS order_logs_user_id_fkey;
ALTER TABLE public.order_logs ALTER COLUMN user_id DROP NOT NULL;
ALTER TABLE public.order_logs
  ADD CONSTRAINT order_logs_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE SET NULL;

ALTER TABLE public.salary_records DROP CONSTRAINT IF EXISTS salary_records_staff_id_fkey;
ALTER TABLE public.salary_records
  ADD CONSTRAINT salary_records_staff_id_fkey
  FOREIGN KEY (staff_id) REFERENCES public.staff(id) ON DELETE CASCADE;

-- Inactive staff stay intact. Only a delete action permanently removes data.
DROP TRIGGER IF EXISTS clear_salary_on_staff_deactivation ON public.staff;
DROP FUNCTION IF EXISTS public.clear_salary_on_staff_deactivation();

-- Staff can edit only their own pending order. Admin can mark Delivered/Return.
DROP POLICY IF EXISTS "Staff can update own undispatched orders" ON public.orders;
CREATE POLICY "Staff can update own pending orders" ON public.orders
  FOR UPDATE USING (
    staff_id = auth.uid()
    AND status = 'pending'
    AND public.get_user_role() = 'staff'
  ) WITH CHECK (
    staff_id = auth.uid()
    AND status = 'pending'
    AND public.get_user_role() = 'staff'
  );

-- Called by Admin from Staff Management. Deleting auth.users cascades to the
-- public profile/staff rows; orders retain staff_name/staff_code for reports.
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
  IF target_user_id IS NULL THEN
    RAISE EXCEPTION 'Staff account not found';
  END IF;
  IF target_user_id = auth.uid() THEN
    RAISE EXCEPTION 'Admin cannot delete their own account';
  END IF;

  UPDATE public.orders
  SET staff_name = COALESCE(NULLIF(staff_name, ''), target_name),
      staff_code = COALESCE(NULLIF(staff_code, ''), target_code),
      staff_id = NULL
  WHERE staff_id = target_user_id;

  DELETE FROM auth.users WHERE id = target_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth;

REVOKE ALL ON FUNCTION public.delete_staff_account(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_staff_account(UUID) TO authenticated;

DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile" ON public.profiles
  FOR UPDATE USING (id = auth.uid())
  WITH CHECK (
    id = auth.uid()
    AND role = (SELECT role FROM public.profiles WHERE id = auth.uid())
    AND is_active = (SELECT is_active FROM public.profiles WHERE id = auth.uid())
  );

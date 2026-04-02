
-- 1. Profiles table
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL DEFAULT '',
  phone TEXT DEFAULT '',
  address TEXT DEFAULT '',
  coverage_areas TEXT DEFAULT '',
  notes TEXT DEFAULT '',
  salary NUMERIC DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can view profiles" ON public.profiles FOR SELECT TO authenticated USING (true);
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE TO authenticated USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile" ON public.profiles FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'full_name', ''));
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 2. User roles
CREATE TABLE public.user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'user',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, role)
);
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can view roles" ON public.user_roles FOR SELECT TO authenticated USING (true);
CREATE POLICY "Owners can manage roles" ON public.user_roles FOR ALL TO authenticated USING (
  EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = auth.uid() AND role = 'owner')
);

-- 3. User permissions
CREATE TABLE public.user_permissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  section TEXT NOT NULL,
  permission TEXT NOT NULL DEFAULT 'none',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.user_permissions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can view permissions" ON public.user_permissions FOR SELECT TO authenticated USING (true);
CREATE POLICY "Owners can manage permissions" ON public.user_permissions FOR ALL TO authenticated USING (
  EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = auth.uid() AND role = 'owner')
);

-- 4. Offices
CREATE TABLE public.offices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  specialty TEXT DEFAULT '',
  owner_name TEXT DEFAULT '',
  owner_phone TEXT DEFAULT '',
  address TEXT DEFAULT '',
  notes TEXT DEFAULT '',
  user_id UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.offices ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can view offices" ON public.offices FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can manage offices" ON public.offices FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- 5. Order statuses
CREATE TABLE public.order_statuses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  color TEXT DEFAULT '#6b7280',
  sort_order INT DEFAULT 0,
  is_locked BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.order_statuses ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can view statuses" ON public.order_statuses FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can manage statuses" ON public.order_statuses FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Insert default statuses
INSERT INTO public.order_statuses (name, color, sort_order) VALUES
  ('جديد', '#3b82f6', 0),
  ('قيد التوصيل', '#f59e0b', 1),
  ('تم التسليم', '#22c55e', 2),
  ('تسليم جزئي', '#06b6d4', 3),
  ('مؤجل', '#8b5cf6', 4),
  ('رفض ودفع شحن', '#ef4444', 5),
  ('رفض ولم يدفع شحن', '#dc2626', 6),
  ('تهرب', '#991b1b', 7),
  ('ملغي', '#6b7280', 8),
  ('لم يرد', '#9ca3af', 9),
  ('لايرد', '#d1d5db', 10);

-- 6. Products
CREATE TABLE public.products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  quantity INT DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can view products" ON public.products FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can manage products" ON public.products FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- 7. Companies
CREATE TABLE public.companies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  agreement_price NUMERIC DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.companies ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can view companies" ON public.companies FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can manage companies" ON public.companies FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- 8. Orders (main table)
CREATE TABLE public.orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tracking_id TEXT UNIQUE,
  barcode TEXT UNIQUE,
  customer_name TEXT NOT NULL,
  customer_phone TEXT DEFAULT '',
  customer_code TEXT DEFAULT '',
  product_name TEXT DEFAULT 'بدون منتج',
  product_id UUID REFERENCES public.products(id),
  quantity INT DEFAULT 1,
  price NUMERIC DEFAULT 0,
  delivery_price NUMERIC DEFAULT 0,
  partial_amount NUMERIC DEFAULT 0,
  color TEXT DEFAULT '',
  size TEXT DEFAULT '',
  address TEXT DEFAULT '',
  notes TEXT DEFAULT '',
  priority TEXT DEFAULT 'normal',
  office_id UUID REFERENCES public.offices(id),
  courier_id UUID REFERENCES auth.users(id),
  status_id UUID REFERENCES public.order_statuses(id),
  is_closed BOOLEAN DEFAULT false,
  is_courier_closed BOOLEAN DEFAULT false,
  is_settled BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can view orders" ON public.orders FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can manage orders" ON public.orders FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Auto-generate barcode
CREATE SEQUENCE IF NOT EXISTS barcode_seq START 1000;

CREATE OR REPLACE FUNCTION public.generate_barcode()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.barcode IS NULL OR NEW.barcode = '' THEN
    NEW.barcode := 'AS' || LPAD(nextval('barcode_seq')::TEXT, 6, '0');
  END IF;
  IF NEW.tracking_id IS NULL OR NEW.tracking_id = '' THEN
    NEW.tracking_id := NEW.barcode;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER generate_order_barcode
  BEFORE INSERT ON public.orders
  FOR EACH ROW EXECUTE FUNCTION public.generate_barcode();

-- 9. Order notes
CREATE TABLE public.order_notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  note TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.order_notes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can view order notes" ON public.order_notes FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can manage order notes" ON public.order_notes FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- 10. Diaries
CREATE TABLE public.diaries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  office_id UUID NOT NULL REFERENCES public.offices(id) ON DELETE CASCADE,
  diary_date DATE NOT NULL DEFAULT CURRENT_DATE,
  is_locked BOOLEAN DEFAULT false,
  is_archived BOOLEAN DEFAULT false,
  lock_status_updates BOOLEAN DEFAULT false,
  previous_due NUMERIC DEFAULT 0,
  show_postponed_due BOOLEAN DEFAULT true,
  manual_arrived_total NUMERIC,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(office_id, diary_date)
);
ALTER TABLE public.diaries ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can view diaries" ON public.diaries FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can manage diaries" ON public.diaries FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- 11. Diary orders
CREATE TABLE public.diary_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  diary_id UUID NOT NULL REFERENCES public.diaries(id) ON DELETE CASCADE,
  order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  status_inside_diary TEXT DEFAULT '',
  partial_amount NUMERIC DEFAULT 0,
  n_column TEXT DEFAULT '',
  manual_price NUMERIC DEFAULT 0,
  manual_shipping NUMERIC DEFAULT 0,
  manual_arrived NUMERIC DEFAULT 0,
  manual_return_status TEXT DEFAULT '',
  sort_order INT DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.diary_orders ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can view diary orders" ON public.diary_orders FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can manage diary orders" ON public.diary_orders FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- 12. Delivery prices
CREATE TABLE public.delivery_prices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  office_id UUID NOT NULL REFERENCES public.offices(id) ON DELETE CASCADE,
  governorate TEXT NOT NULL,
  price NUMERIC DEFAULT 0,
  pickup_price NUMERIC DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.delivery_prices ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can view delivery prices" ON public.delivery_prices FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can manage delivery prices" ON public.delivery_prices FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- 13. Advances
CREATE TABLE public.advances (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  amount NUMERIC NOT NULL DEFAULT 0,
  reason TEXT DEFAULT '',
  type TEXT DEFAULT 'advance',
  created_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.advances ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can view advances" ON public.advances FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can manage advances" ON public.advances FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- 14. Courier bonuses
CREATE TABLE public.courier_bonuses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  courier_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  amount NUMERIC NOT NULL DEFAULT 0,
  reason TEXT DEFAULT '',
  created_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.courier_bonuses ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can view courier bonuses" ON public.courier_bonuses FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can manage courier bonuses" ON public.courier_bonuses FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- 15. Courier collections
CREATE TABLE public.courier_collections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID REFERENCES public.orders(id) ON DELETE SET NULL,
  courier_id UUID REFERENCES auth.users(id),
  amount NUMERIC DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.courier_collections ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can view courier collections" ON public.courier_collections FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can manage courier collections" ON public.courier_collections FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- 16. Courier locations
CREATE TABLE public.courier_locations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  courier_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  accuracy DOUBLE PRECISION DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.courier_locations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can view courier locations" ON public.courier_locations FOR SELECT TO authenticated USING (true);
CREATE POLICY "Couriers can upsert their location" ON public.courier_locations FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- 17. Office payments
CREATE TABLE public.office_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  office_id UUID NOT NULL REFERENCES public.offices(id) ON DELETE CASCADE,
  amount NUMERIC NOT NULL DEFAULT 0,
  type TEXT DEFAULT 'advance',
  notes TEXT DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.office_payments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can view office payments" ON public.office_payments FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can manage office payments" ON public.office_payments FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- 18. Office daily closings
CREATE TABLE public.office_daily_closings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  office_id UUID NOT NULL REFERENCES public.offices(id) ON DELETE CASCADE,
  closing_date DATE NOT NULL DEFAULT CURRENT_DATE,
  data_json JSONB DEFAULT '[]',
  pickup_rate NUMERIC DEFAULT 0,
  is_locked BOOLEAN DEFAULT false,
  is_closed BOOLEAN DEFAULT false,
  prevent_add BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(office_id, closing_date)
);
ALTER TABLE public.office_daily_closings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can view closings" ON public.office_daily_closings FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can manage closings" ON public.office_daily_closings FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- 19. Expenses
CREATE TABLE public.expenses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  expense_name TEXT NOT NULL,
  amount NUMERIC NOT NULL DEFAULT 0,
  category TEXT DEFAULT 'أخرى',
  notes TEXT DEFAULT '',
  expense_date DATE NOT NULL DEFAULT CURRENT_DATE,
  office_id UUID REFERENCES public.offices(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can view expenses" ON public.expenses FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can manage expenses" ON public.expenses FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- 20. Cash flow entries
CREATE TABLE public.cash_flow_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type TEXT NOT NULL DEFAULT 'income',
  amount NUMERIC NOT NULL DEFAULT 0,
  reason TEXT DEFAULT '',
  notes TEXT DEFAULT '',
  entry_date DATE NOT NULL DEFAULT CURRENT_DATE,
  office_id UUID REFERENCES public.offices(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.cash_flow_entries ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can view cash flow" ON public.cash_flow_entries FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can manage cash flow" ON public.cash_flow_entries FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- 21. Messages (internal chat)
CREATE TABLE public.messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  receiver_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  message TEXT NOT NULL DEFAULT '',
  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view their messages" ON public.messages FOR SELECT TO authenticated USING (sender_id = auth.uid() OR receiver_id = auth.uid());
CREATE POLICY "Users can send messages" ON public.messages FOR INSERT TO authenticated WITH CHECK (sender_id = auth.uid());
CREATE POLICY "Users can update their received messages" ON public.messages FOR UPDATE TO authenticated USING (receiver_id = auth.uid());

-- Enable realtime for messages
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;

-- 22. Activity logs
CREATE TABLE public.activity_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id),
  action TEXT NOT NULL,
  details JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can view logs" ON public.activity_logs FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can insert logs" ON public.activity_logs FOR INSERT TO authenticated WITH CHECK (true);

-- log_activity RPC function
CREATE OR REPLACE FUNCTION public.log_activity(_action TEXT, _details JSONB DEFAULT '{}')
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.activity_logs (user_id, action, details)
  VALUES (auth.uid(), _action, _details);
END;
$$;

-- 23. App settings
CREATE TABLE public.app_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key TEXT NOT NULL UNIQUE,
  value TEXT DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can view settings" ON public.app_settings FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can manage settings" ON public.app_settings FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Updated_at trigger function
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- Apply updated_at triggers
CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_offices_updated_at BEFORE UPDATE ON public.offices FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_products_updated_at BEFORE UPDATE ON public.products FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_orders_updated_at BEFORE UPDATE ON public.orders FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_diaries_updated_at BEFORE UPDATE ON public.diaries FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_office_daily_closings_updated_at BEFORE UPDATE ON public.office_daily_closings FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_app_settings_updated_at BEFORE UPDATE ON public.app_settings FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

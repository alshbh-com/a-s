
-- Add missing columns to diaries
ALTER TABLE public.diaries ADD COLUMN is_closed BOOLEAN DEFAULT false;
ALTER TABLE public.diaries ADD COLUMN prevent_new_orders BOOLEAN DEFAULT false;
ALTER TABLE public.diaries ADD COLUMN diary_number INT;

-- Add missing columns to orders
ALTER TABLE public.orders ADD COLUMN company_id UUID REFERENCES public.companies(id);
ALTER TABLE public.orders ADD COLUMN shipping_paid BOOLEAN DEFAULT false;

-- Add missing column to profiles
ALTER TABLE public.profiles ADD COLUMN office_id UUID REFERENCES public.offices(id);

-- Add missing column to offices
ALTER TABLE public.offices ADD COLUMN can_add_orders BOOLEAN DEFAULT true;

-- Company payments table
CREATE TABLE public.company_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  amount NUMERIC NOT NULL DEFAULT 0,
  notes TEXT DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.company_payments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can view company payments" ON public.company_payments FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated users can manage company payments" ON public.company_payments FOR ALL TO authenticated USING (true) WITH CHECK (true);

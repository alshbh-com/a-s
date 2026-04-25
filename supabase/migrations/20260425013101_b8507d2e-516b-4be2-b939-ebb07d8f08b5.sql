ALTER TABLE public.diary_orders ADD COLUMN IF NOT EXISTS copied_from_diary_id uuid;
ALTER TABLE public.courier_collections ADD COLUMN IF NOT EXISTS collected_by uuid;
ALTER TABLE public.diaries ADD COLUMN IF NOT EXISTS closed_at timestamp with time zone;
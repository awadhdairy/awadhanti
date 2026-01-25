-- Insert default dairy settings if missing
INSERT INTO public.dairy_settings (dairy_name)
SELECT 'Awadh Dairy'
WHERE NOT EXISTS (SELECT 1 FROM public.dairy_settings);
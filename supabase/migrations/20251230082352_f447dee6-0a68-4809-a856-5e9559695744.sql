-- Add unique constraint to user_roles for upsert to work
ALTER TABLE public.user_roles ADD CONSTRAINT user_roles_user_id_unique UNIQUE (user_id);
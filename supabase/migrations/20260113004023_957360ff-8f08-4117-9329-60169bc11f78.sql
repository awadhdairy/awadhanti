-- Enable pg_cron extension if not already enabled
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Create a simple keep-alive function
CREATE OR REPLACE FUNCTION public.keep_alive_ping()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  -- Simple query to keep the database active
  PERFORM 1;
  
  -- Log the ping for monitoring (optional)
  INSERT INTO public.activity_logs (action, entity_type, details)
  VALUES ('keep_alive_ping', 'system', jsonb_build_object('timestamp', NOW(), 'type', 'scheduled_ping'));
END;
$$;

-- Schedule the keep-alive ping to run every alternate day at 3 AM UTC
SELECT cron.schedule(
  'keep-alive-ping',
  '0 3 */2 * *',  -- Every alternate day at 3:00 AM UTC
  $$SELECT public.keep_alive_ping()$$
);
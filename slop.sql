-- Create table
CREATE TABLE IF NOT EXISTS "public"."kv" (
    "k" text NOT NULL,
    "v" jsonb,
    "id" int8 NOT NULL,
    "created_at" timestamptz NOT NULL DEFAULT now(),
    "created_by" uuid DEFAULT auth.uid(),
    "expires_at" timestamptz CHECK ((expires_at IS NULL) OR (expires_at > now())),
    CONSTRAINT "public_kv_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id"),
    PRIMARY KEY ("k")
);

-- Enable RLS
ALTER TABLE IF EXISTS public.kv
    ENABLE ROW LEVEL SECURITY;

-- POLICY: Enable insert for authenticated users only

-- DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON public.kv;

CREATE POLICY "Enable insert for authenticated users only"
    ON public.kv
    AS PERMISSIVE
    FOR INSERT
    TO authenticated
    WITH CHECK (true);
-- POLICY: Users control their key-value pairs

-- DROP POLICY IF EXISTS "Users control their key-value pairs" ON public.kv;

CREATE POLICY "Users control their key-value pairs"
    ON public.kv
    AS PERMISSIVE
    FOR ALL
    TO authenticated
    USING ((auth.uid() = created_by))
    WITH CHECK ((auth.uid() = created_by));


-- FUNCTION: public.ttl(kv)

-- DROP FUNCTION IF EXISTS public.ttl(kv);

CREATE OR REPLACE FUNCTION public.ttl(kv)
 RETURNS double precision
 LANGUAGE sql
AS $function$
  SELECT EXTRACT(epoch FROM ($1.expires_at - now()))
$function$


-- SCHEDULE CLEANUP IN pg_cron 
-- change this to use soft-deletes

SELECT cron.schedule('0 * * * *', $$DELETE FROM public.kv WHERE id IN (SELECT id FROM public.kv kv WHERE ttl(kv) <= 0)$$);


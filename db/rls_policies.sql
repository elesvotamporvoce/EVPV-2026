-- Row Level Security: leitura pública, escrita bloqueada.
-- Aplicado no Supabase em 2026-07-04. A ingestão entra pela conexão de serviço
-- (bypassa RLS), então a carga continua funcionando normalmente.
-- Idempotente: pode rodar de novo sem erro.
--
--   (via psql)  psql "$DATABASE_URL" -f db/rls_policies.sql
--   (ou cole no SQL Editor do Supabase)

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'party','person','party_membership','proposition','division','vote',
    'party_orientation','party_vote_tally','policy','policy_division','agreement_score'
  ] LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY;', t);
    EXECUTE format('DROP POLICY IF EXISTS leitura_publica ON public.%I;', t);
    EXECUTE format(
      'CREATE POLICY leitura_publica ON public.%I FOR SELECT TO anon, authenticated USING (true);', t);
  END LOOP;
END $$;

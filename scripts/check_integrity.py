#!/usr/bin/env python3
"""
Teste de integridade dos dados — Eles Votam Por Você

Roda uma bateria de checagens READ-ONLY contra o banco e falha (exit 1) se
achar problema GRAVE. Serve para blindar cargas futuras: rode depois de cada
ingestao/backfill (localmente ou no CI) para pegar dado corrompido antes que
ele contamine os scores.

Severidades:
  FATAL  -> algo que pode corromper um score publicado. Faz o teste falhar.
  WARN   -> anomalia tolerada (fora de qualquer politica, ou diferenca pequena).
  OK     -> passou.

Regra de ouro: uma anomalia numa votacao que esta em ALGUMA politica e sempre
FATAL (afeta um score real); a mesma anomalia fora de politica e so WARN.

Uso:
  export DATABASE_URL="postgresql://..."
  python scripts/check_integrity.py
"""

import os
import sys

VOTE_OPTIONS = ("sim", "nao", "abstencao", "obstrucao", "artigo17", "ausente", "outro")
SCOREBOARD_TOL = 3        # diferenca aceitavel entre placar do texto e votos reais

fatal = 0
warn = 0


def line(sev, title, detail=""):
    global fatal, warn
    if sev == "FATAL":
        fatal += 1
    elif sev == "WARN":
        warn += 1
    tag = {"OK": "[ OK ]", "WARN": "[WARN]", "FATAL": "[FATAL]"}[sev]
    print(f"{tag} {title}" + (f" — {detail}" if detail else ""), flush=True)


def main():
    dsn = os.environ.get("DATABASE_URL")
    if not dsn:
        sys.exit("ERRO: defina DATABASE_URL.")
    import psycopg2
    conn = psycopg2.connect(dsn)
    conn.set_session(readonly=True, autocommit=True)
    cur = conn.cursor()

    print("=== Integridade dos dados — Eles Votam Por Você ===\n", flush=True)

    # -- 1) dominio da coluna vote.option ------------------------------------
    cur.execute(
        "SELECT option, count(*) FROM vote "
        "WHERE option IS NULL OR option <> ALL(%s) GROUP BY option",
        (list(VOTE_OPTIONS),))
    bad = cur.fetchall()
    if bad:
        line("FATAL", "Opcoes de voto invalidas",
             ", ".join(f"{o!r}={n}" for o, n in bad))
    else:
        line("OK", "Todas as opcoes de voto sao validas")

    # -- 2) votacoes nominais SEM votos (orfas) ------------------------------
    cur.execute("""
        SELECT count(*) FILTER (WHERE em_pol IS NULL),
               count(*) FILTER (WHERE em_pol IS NOT NULL)
        FROM (
          SELECT d.id,
                 (SELECT 1 FROM policy_division pd WHERE pd.division_id=d.id) AS em_pol
          FROM division d
          WHERE d.is_nominal AND NOT EXISTS (SELECT 1 FROM vote v WHERE v.division_id=d.id)
        ) s""")
    orf_fora, orf_pol = cur.fetchone()
    if orf_pol:
        line("FATAL", "Votacao nominal SEM votos usada em politica", f"{orf_pol} caso(s)")
    if orf_fora:
        line("WARN", "Votacoes nominais sem votos (fora de politica)", f"{orf_fora}")
    if not orf_pol and not orf_fora:
        line("OK", "Nenhuma votacao nominal orfa")

    # -- 3) placar do texto x contagem real (mismatch) -----------------------
    cur.execute("""
      WITH t AS (
        SELECT d.id,
          NULLIF((regexp_match(d.description,'Sim:?\\s*([0-9]+)','i'))[1],'')::int AS sim_txt,
          NULLIF((regexp_match(d.description,'N[ãa]o:?\\s*([0-9]+)','i'))[1],'')::int AS nao_txt,
          count(*) FILTER (WHERE v.option='sim') AS sim_real,
          count(*) FILTER (WHERE v.option='nao') AS nao_real,
          (SELECT 1 FROM policy_division pd WHERE pd.division_id=d.id) AS em_pol
        FROM division d LEFT JOIN vote v ON v.division_id=d.id
        WHERE d.is_nominal
        GROUP BY d.id, d.description
      )
      SELECT
        count(*) FILTER (WHERE mm AND em_pol IS NULL)  AS mm_fora,
        count(*) FILTER (WHERE mm AND em_pol IS NOT NULL) AS mm_pol,
        count(*) FILTER (WHERE inv AND em_pol IS NULL) AS inv_fora,
        count(*) FILTER (WHERE inv AND em_pol IS NOT NULL) AS inv_pol
      FROM (
        SELECT em_pol,
          (abs(sim_txt-sim_real)>%s OR abs(nao_txt-nao_real)>%s) AS mm,
          (sim_txt=nao_real AND nao_txt=sim_real AND sim_txt<>nao_txt) AS inv
        FROM t WHERE sim_txt IS NOT NULL AND nao_txt IS NOT NULL
      ) x
    """, (SCOREBOARD_TOL, SCOREBOARD_TOL))
    mm_fora, mm_pol, inv_fora, inv_pol = cur.fetchone()
    if inv_pol:
        line("FATAL", "Placar INVERTIDO (sim<->nao) em votacao de politica", f"{inv_pol}")
    if inv_fora:
        line("WARN", "Placar invertido fora de politica", f"{inv_fora}")
    if mm_pol:
        line("FATAL", "Placar do texto nao bate com os votos (em politica)", f"{mm_pol}")
    if mm_fora:
        line("WARN", "Placar do texto nao bate (fora de politica)",
             f"{mm_fora} — tolerancia {SCOREBOARD_TOL} votos")
    if not (inv_pol or inv_fora or mm_pol or mm_fora):
        line("OK", "Placar do texto confere com os votos em todas as votacoes")

    # -- 4) coerencia categoria x score no agreement_score -------------------
    cur.execute("""
      SELECT count(*) FROM agreement_score
      WHERE category <> CASE
        WHEN n_divisions < 2 THEN 'not_enough'
        WHEN score >= 95 THEN 'for3' WHEN score >= 85 THEN 'for2'
        WHEN score >= 60 THEN 'for1' WHEN score > 40 THEN 'mixture'
        WHEN score > 15 THEN 'against1' WHEN score > 5 THEN 'against2'
        ELSE 'against3' END
    """)
    incoerentes = cur.fetchone()[0]
    if incoerentes:
        line("FATAL", "Categoria nao corresponde ao score", f"{incoerentes} linha(s)")
    else:
        line("OK", "Categoria e score coerentes em todos os agreement_scores")

    # -- 5) integridade das politicas (vinculo aponta p/ votacao nominal) ----
    cur.execute("""
      SELECT count(*) FROM policy_division pd
      LEFT JOIN division d ON d.id=pd.division_id
      WHERE d.id IS NULL OR d.is_nominal = false
    """)
    pol_ruim = cur.fetchone()[0]
    if pol_ruim:
        line("FATAL", "Politica aponta p/ votacao inexistente ou nao-nominal", f"{pol_ruim}")
    else:
        line("OK", "Todos os vinculos de politica apontam p/ votacao nominal valida")

    # -- 6) votos duplicados por pessoa/votacao ------------------------------
    cur.execute("""
      SELECT count(*) FROM (
        SELECT division_id, person_id FROM vote GROUP BY 1,2 HAVING count(*)>1
      ) s""")
    dup = cur.fetchone()[0]
    if dup:
        line("FATAL", "Voto duplicado (mesma pessoa, mesma votacao)", f"{dup}")
    else:
        line("OK", "Nenhum voto duplicado")

    # -- 7) informativos (nunca falham) --------------------------------------
    cur.execute("SELECT count(*) FROM division WHERE is_nominal AND proposition_id IS NULL")
    sem_prop = cur.fetchone()[0]
    if sem_prop:
        line("WARN", "Votacoes nominais sem proposicao ligada", f"{sem_prop} (assunto ausente)")

    cur.execute("""
      SELECT count(*) FROM person p
      WHERE NOT EXISTS (SELECT 1 FROM party_membership pm
                        WHERE pm.person_id=p.id AND pm.end_date IS NULL)""")
    sem_part = cur.fetchone()[0]
    if sem_part:
        line("WARN", "Pessoas sem filiacao partidaria atual", f"{sem_part}")

    conn.close()
    print(f"\n=== Resumo: {fatal} FATAL, {warn} WARN ===", flush=True)
    if fatal:
        print("FALHOU: ha problema grave que pode corromper um score.", flush=True)
        sys.exit(1)
    print("OK: nenhum problema grave.", flush=True)


if __name__ == "__main__":
    main()

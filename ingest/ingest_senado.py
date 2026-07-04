#!/usr/bin/env python3
"""
Adaptador de ingestão — Senado Federal
Projeto: Eles Votam Por Você

Usa o endpoint MODERNO (sucessor, não depreciado):
    GET https://legis.senado.leg.br/dadosabertos/votacao
que retorna os votos nominais de parlamentares filtrados por query params.
(Os endpoints antigos /senador/{codigo}/votacoes, /plenario/lista/votacao/...
estão DEPRECIADOS e apontam todos para este.)

Formato confirmado ao vivo: a resposta é uma LISTA (camelCase) de votações;
cada votação tem os votos individuais em `votos[]`.

Uso:
  # Teste de parsing (sem banco):
  python ingest_senado.py --start 2020-04-01 --end 2020-04-30 --dry-run

  # Carga real:
  export DATABASE_URL="postgresql://user:pass@localhost:5432/evpv"
  python ingest_senado.py --start 2024-01-01 --end 2024-12-31

Dependências: requests (sempre); psycopg2 (só fora do --dry-run).
"""

import argparse
import os
import sys
import time
from datetime import date, datetime, timedelta

import requests

BASE = "https://legis.senado.leg.br/dadosabertos"

# Senado -> nossa enum de voto (schema.sql: vote.option CHECK)
VOTE_MAP = {
    "Sim": "sim",
    "Não": "nao",
    "Abstenção": "abstencao",
}
# Marcadores de ausência/não-voto observados no Senado. REVISAR/expandir conforme
# necessário (o Senado usa vários códigos: AP=atividade parlamentar, NCom=não
# compareceu, LA/LS=licença, MIS=missão, "Presidente (art. 51 RISF)" etc.).
ABSENCE_CODES = {
    "AP", "NCom", "LA", "LS", "MIS", "P-NRV",
    "Presidente (art. 51 RISF)", "Presidente",
}

session = requests.Session()
session.headers.update({"Accept": "application/json",
                        "User-Agent": "ElesVotamPorVoce/0.1 (ingest-senado)"})


# ---------------------------------------------------------------------------
#  HTTP com throttle + retry (limite do Senado: >10 req/s -> HTTP 429)
# ---------------------------------------------------------------------------
def get_json(url, params=None, throttle=0.3, retries=4):
    for attempt in range(retries):
        try:
            r = session.get(url, params=params, timeout=45)
            if r.status_code == 429:
                time.sleep(2 * (attempt + 1))
                continue
            if r.status_code == 404:
                return []
            r.raise_for_status()
            time.sleep(throttle)
            if not r.text.strip():
                return []
            return r.json()
        except (requests.RequestException, ValueError):
            if attempt == retries - 1:
                raise
            time.sleep(1.5 * (attempt + 1))
    return []


def month_chunks(start, end):
    """Divide [start, end] em janelas de ~1 mês para não pedir tudo de uma vez."""
    d0 = datetime.strptime(start, "%Y-%m-%d").date()
    d1 = datetime.strptime(end, "%Y-%m-%d").date()
    cur = d0
    while cur <= d1:
        nxt = min(cur + timedelta(days=30), d1)
        yield cur.isoformat(), nxt.isoformat()
        cur = nxt + timedelta(days=1)


def iter_votacoes(start, end):
    """Itera votações do período, pedindo por janelas mensais."""
    for a, b in month_chunks(start, end):
        payload = get_json(f"{BASE}/votacao", params={"dataInicio": a, "dataFim": b})
        # A resposta é uma lista; toleramos também dict de erro/envelope vazio.
        if isinstance(payload, dict):
            payload = payload.get("votacoes") or payload.get("dados") or []
        for v in payload:
            yield v


# ---------------------------------------------------------------------------
#  Normalização (API -> dicts do nosso modelo)
# ---------------------------------------------------------------------------
def _bool_result(txt):
    if not txt:
        return None
    t = txt.lower()
    if "aprovad" in t:
        return True
    if "rejeitad" in t or "prejudicad" in t:
        return False
    return None


def map_vote(sigla):
    if sigla in VOTE_MAP:
        return VOTE_MAP[sigla]
    if sigla in ABSENCE_CODES:
        return "ausente"
    return "outro"


def normalize_division(v):
    return {
        "house": "senado",
        "external_id": str(v.get("codigoSessaoVotacao") or v.get("codigoSessao")),
        "occurred_at": v.get("dataSessao"),
        "body": v.get("casaSessao") or "PLEN",
        "description": v.get("descricaoVotacao") or v.get("ementa"),
        "result_approved": _bool_result(v.get("resultadoVotacao")),
        "is_secret": bool(v.get("votacaoSecreta")),
        # proposição / matéria
        "prop_external_id": str(v.get("codigoMateria")) if v.get("codigoMateria") else None,
        "prop_sigla": v.get("sigla"),
        "prop_numero": str(v.get("numero")) if v.get("numero") is not None else None,
        "prop_ano": str(v.get("ano")) if v.get("ano") is not None else None,
        "prop_ementa": v.get("ementa"),
        "prop_label": v.get("identificacao"),
    }


def normalize_votos(v):
    out = []
    for item in v.get("votos", []) or []:
        out.append({
            "person_external_id": str(item.get("codigoParlamentar")),
            "name": item.get("nomeParlamentar"),
            "uf": item.get("siglaUFParlamentar"),
            "party_sigla": item.get("siglaPartidoParlamentar"),
            "option": map_vote(item.get("siglaVotoParlamentar")),
        })
    return out


def tally_by_party(votos):
    tallies = {}
    for v in votos:
        sig = v["party_sigla"]
        if not sig:
            continue
        t = tallies.setdefault(sig, {"sim": 0, "nao": 0, "abstencao": 0,
                                     "obstrucao": 0, "ausente": 0, "outro": 0})
        t[v["option"]] = t.get(v["option"], 0) + 1
    for sig, t in tallies.items():
        countable = {k: t[k] for k in ("sim", "nao", "abstencao", "obstrucao")}
        t["majority_option"] = max(countable, key=countable.get) if any(countable.values()) else None
    return tallies


# ---------------------------------------------------------------------------
#  Persistência (Postgres) — house = 'senado'
# ---------------------------------------------------------------------------
class DB:
    def __init__(self, dsn):
        import psycopg2
        self.conn = psycopg2.connect(dsn)
        self.conn.autocommit = False

    def close(self):
        self.conn.close()

    def upsert_party(self, cur, sigla):
        if not sigla:
            return None
        cur.execute(
            """INSERT INTO party (sigla) VALUES (%s)
               ON CONFLICT (sigla) DO UPDATE SET sigla = EXCLUDED.sigla
               RETURNING id""",
            (sigla,),
        )
        return cur.fetchone()[0]

    def upsert_person(self, cur, p):
        cur.execute(
            """INSERT INTO person (house, external_id, name, uf)
               VALUES ('senado', %s, %s, %s)
               ON CONFLICT (house, external_id) DO UPDATE
                 SET name = EXCLUDED.name, uf = EXCLUDED.uf
               RETURNING id""",
            (p["person_external_id"], p["name"], p["uf"]),
        )
        return cur.fetchone()[0]

    def upsert_proposition(self, cur, d):
        if not d["prop_external_id"] and not d["prop_label"]:
            return None
        cur.execute(
            """INSERT INTO proposition
                 (house, external_id, sigla, numero, ano, ementa, raw_label)
               VALUES ('senado', %s, %s, %s, %s, %s, %s)
               ON CONFLICT (house, external_id) DO UPDATE
                 SET sigla = EXCLUDED.sigla, numero = EXCLUDED.numero,
                     ano = EXCLUDED.ano, ementa = EXCLUDED.ementa,
                     raw_label = EXCLUDED.raw_label
               RETURNING id""",
            (d["prop_external_id"], d["prop_sigla"], d["prop_numero"],
             d["prop_ano"], d["prop_ementa"], d["prop_label"]),
        )
        return cur.fetchone()[0]

    def upsert_division(self, cur, d, prop_id):
        cur.execute(
            """INSERT INTO division
                 (house, external_id, occurred_at, body, proposition_id,
                  description, result_approved, is_nominal, is_secret)
               VALUES ('senado', %s, %s, %s, %s, %s, %s, TRUE, %s)
               ON CONFLICT (house, external_id) DO UPDATE
                 SET occurred_at = EXCLUDED.occurred_at, body = EXCLUDED.body,
                     proposition_id = COALESCE(EXCLUDED.proposition_id, division.proposition_id),
                     description = EXCLUDED.description,
                     result_approved = EXCLUDED.result_approved,
                     is_secret = EXCLUDED.is_secret
               RETURNING id""",
            (d["external_id"], d["occurred_at"], d["body"], prop_id,
             d["description"], d["result_approved"], d["is_secret"]),
        )
        return cur.fetchone()[0]

    def upsert_vote(self, cur, division_id, person_id, party_id, opt):
        cur.execute(
            """INSERT INTO vote (division_id, person_id, party_id, option)
               VALUES (%s, %s, %s, %s)
               ON CONFLICT (division_id, person_id) DO UPDATE
                 SET party_id = EXCLUDED.party_id, option = EXCLUDED.option""",
            (division_id, person_id, party_id, opt),
        )

    def upsert_tally(self, cur, division_id, party_id, t):
        cur.execute(
            """INSERT INTO party_vote_tally
                 (division_id, party_id, sim_count, nao_count, abstencao_count,
                  obstrucao_count, ausente_count, majority_option)
               VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
               ON CONFLICT (division_id, party_id) DO UPDATE
                 SET sim_count = EXCLUDED.sim_count, nao_count = EXCLUDED.nao_count,
                     abstencao_count = EXCLUDED.abstencao_count,
                     obstrucao_count = EXCLUDED.obstrucao_count,
                     ausente_count = EXCLUDED.ausente_count,
                     majority_option = EXCLUDED.majority_option""",
            (division_id, party_id, t["sim"], t["nao"], t["abstencao"],
             t["obstrucao"], t["ausente"], t["majority_option"]),
        )


# ---------------------------------------------------------------------------
#  Orquestração
# ---------------------------------------------------------------------------
def process_division(v, db, cur, dry_run):
    d = normalize_division(v)
    if not d["external_id"] or d["external_id"] == "None":
        return  # votação sem identificador utilizável
    votos = normalize_votos(v)
    tallies = tally_by_party(votos)

    if dry_run:
        print(f"— votação {d['external_id']} [{d['body']}] {d['occurred_at']}"
              f" | {d['prop_label']} | aprov={d['result_approved']}")
        print(f"    votos/pessoa: {len(votos)} | partidos no placar: {len(tallies)}")
        if votos:
            ex = votos[0]
            print(f"    ex. voto: {ex['name']} ({ex['party_sigla']}-{ex['uf']}) -> {ex['option']}")
        return

    prop_id = db.upsert_proposition(cur, d)
    division_id = db.upsert_division(cur, d, prop_id)
    for p in votos:
        person_id = db.upsert_person(cur, p)
        party_id = db.upsert_party(cur, p["party_sigla"])
        db.upsert_vote(cur, division_id, person_id, party_id, p["option"])
    for sigla, t in tallies.items():
        party_id = db.upsert_party(cur, sigla)
        db.upsert_tally(cur, division_id, party_id, t)


def main():
    ap = argparse.ArgumentParser(description="Ingestão de votações do Senado Federal")
    ap.add_argument("--start", required=True, help="data inicial AAAA-MM-DD")
    ap.add_argument("--end", default=None, help="data final AAAA-MM-DD (default = start)")
    ap.add_argument("--dry-run", action="store_true", help="não grava; só imprime")
    args = ap.parse_args()

    start = args.start
    end = args.end or args.start

    db = cur = None
    if not args.dry_run:
        dsn = os.environ.get("DATABASE_URL")
        if not dsn:
            sys.exit("ERRO: defina DATABASE_URL (ou use --dry-run).")
        db = DB(dsn)
        cur = db.conn.cursor()

    n = 0
    try:
        for v in iter_votacoes(start, end):
            process_division(v, db, cur, args.dry_run)
            n += 1
            if db and n % 25 == 0:
                db.conn.commit()
        if db:
            db.conn.commit()
    finally:
        if db:
            db.close()

    print(f"\nConcluído: {n} votação(ões) processada(s) "
          f"({'dry-run' if args.dry_run else 'gravadas no banco'}).")


if __name__ == "__main__":
    main()

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
def get_json(url, params=None, throttle=0.3, retries=6):
    for attempt in range(retries):
        try:
            r = session.get(url, params=params, timeout=60)
            if r.status_code == 429:
                time.sleep(3 * (attempt + 1))
                continue
            if r.status_code == 404:
                return []
            if r.status_code in (500, 502, 503, 504):   # servidor instável
                time.sleep(3 * (attempt + 1))
                continue
            r.raise_for_status()
            time.sleep(throttle)
            if not r.text.strip():
                return []
            return r.json()
        except (requests.RequestException, ValueError) as e:
            if attempt == retries - 1:
                # NÃO derruba o job: pula este pedaço e segue
                print(f"[senado: pulado {params or url}] {e}", file=sys.stderr)
                return []
            time.sleep(3 * (attempt + 1))
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
        self.party_cache = {}    # sigla -> id
        self.person_cache = {}   # external_id -> id

    def close(self):
        self.conn.close()

    def clear_cache(self):
        self.party_cache.clear()
        self.person_cache.clear()

    def upsert_party(self, cur, sigla):
        if not sigla:
            return None
        if sigla in self.party_cache:
            return self.party_cache[sigla]
        cur.execute(
            """INSERT INTO party (sigla) VALUES (%s)
               ON CONFLICT (sigla) DO UPDATE SET sigla = EXCLUDED.sigla
               RETURNING id""",
            (sigla,),
        )
        pid = cur.fetchone()[0]
        self.party_cache[sigla] = pid
        return pid

    def upsert_person(self, cur, p):
        ext = p["person_external_id"]
        if ext in self.person_cache:
            return self.person_cache[ext]
        # Foto oficial do Senado, derivada do código do parlamentar.
        # Padrão estável: .../fotos-oficiais/senador{codigo}.jpg
        photo = (
            "https://www.senado.leg.br/senadores/img/fotos-oficiais/"
            f"senador{ext}.jpg"
        )
        cur.execute(
            """INSERT INTO person (house, external_id, name, uf, photo_url)
               VALUES ('senado', %s, %s, %s, %s)
               ON CONFLICT (house, external_id) DO UPDATE
                 SET name = EXCLUDED.name,
                     uf = EXCLUDED.uf,
                     photo_url = COALESCE(person.photo_url, EXCLUDED.photo_url)
               RETURNING id""",
            (p["person_external_id"], p["name"], p["uf"], photo),
        )
        pid = cur.fetchone()[0]
        self.person_cache[ext] = pid
        return pid

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

    def votes_bulk(self, cur, rows):
        if not rows:
            return
        from psycopg2.extras import execute_values
        execute_values(cur,
            """INSERT INTO vote (division_id, person_id, party_id, option)
               VALUES %s
               ON CONFLICT (division_id, person_id) DO UPDATE
                 SET party_id = EXCLUDED.party_id, option = EXCLUDED.option""", rows)

    def tally_bulk(self, cur, rows):
        if not rows:
            return
        from psycopg2.extras import execute_values
        execute_values(cur,
            """INSERT INTO party_vote_tally
                 (division_id, party_id, sim_count, nao_count, abstencao_count,
                  obstrucao_count, ausente_count, majority_option)
               VALUES %s
               ON CONFLICT (division_id, party_id) DO UPDATE
                 SET sim_count = EXCLUDED.sim_count, nao_count = EXCLUDED.nao_count,
                     abstencao_count = EXCLUDED.abstencao_count,
                     obstrucao_count = EXCLUDED.obstrucao_count,
                     ausente_count = EXCLUDED.ausente_count,
                     majority_option = EXCLUDED.majority_option""", rows)


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

    vote_rows = []
    for p in votos:
        person_id = db.upsert_person(cur, p)          # cacheado
        party_id = db.upsert_party(cur, p["party_sigla"])
        vote_rows.append((division_id, person_id, party_id, p["option"]))
    db.votes_bulk(cur, vote_rows)                      # em lote

    tally_rows = [(division_id, db.upsert_party(cur, sig), t["sim"], t["nao"],
                   t["abstencao"], t["obstrucao"], t["ausente"], t["majority_option"])
                  for sig, t in tallies.items()]
    db.tally_bulk(cur, tally_rows)


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

    n = skipped = 0
    try:
        for v in iter_votacoes(start, end):
            try:
                process_division(v, db, cur, args.dry_run)
                if db:
                    db.conn.commit()          # commit por votação
                n += 1
                if n % 50 == 0:
                    print(f"{n} votações processadas...", flush=True)
            except Exception as e:            # noqa: BLE001 — uma ruim não derruba o resto
                if db:
                    db.conn.rollback()
                    db.clear_cache()          # evita cache "sujo" após rollback
                skipped += 1
                print(f"[pulada] {e}", file=sys.stderr)
    finally:
        if db:
            db.close()

    print(f"\nConcluído: {n} votação(ões) gravada(s), {skipped} pulada(s) "
          f"({'dry-run' if args.dry_run else 'banco'}).", flush=True)


if __name__ == "__main__":
    main()

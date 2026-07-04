#!/usr/bin/env python3
"""
Adaptador de ingestão — Câmara dos Deputados
Projeto: Eles Votam Por Você

Busca votações num intervalo de datas na API de Dados Abertos da Câmara,
puxa o voto de cada deputado (/votos) e a orientação de cada partido
(/orientacoes), normaliza tudo para o schema unificado e grava no Postgres.

Características:
  - Idempotente: usa UPSERT (ON CONFLICT) — pode rodar de novo sem duplicar.
  - Throttled + retry: respeita a API e tolera falhas transitórias.
  - Materializa o placar por partido (party_vote_tally) por votação.
  - Modo --dry-run: valida o parsing SEM banco (só imprime o que faria).

Uso:
  # Teste de parsing (sem banco), poucas votações:
  python ingest_camara.py --start 2025-12-17 --end 2025-12-17 --limit 5 --dry-run

  # Carga real no Postgres:
  export DATABASE_URL="postgresql://user:pass@localhost:5432/evpv"
  python ingest_camara.py --start 2025-12-01 --end 2025-12-18

  # Só Plenário (onde há orientação de bancada e votos nominais):
  python ingest_camara.py --start 2025-12-01 --end 2025-12-18 --plen-only

Dependências: requests (sempre); psycopg2 (só fora do --dry-run).
  pip install requests psycopg2-binary
"""

import argparse
import os
import sys
import time
from datetime import date

import requests

API = "https://dadosabertos.camara.leg.br/api/v2"

# Câmara -> nossa enum de voto (schema.sql: vote.option CHECK)
VOTE_MAP = {
    "Sim": "sim",
    "Não": "nao",
    "Abstenção": "abstencao",
    "Obstrução": "obstrucao",
    "Artigo 17": "artigo17",
}
# Câmara -> nossa enum de orientação (party_orientation.orientation CHECK)
ORIENT_MAP = {
    "Sim": "sim",
    "Não": "nao",
    "Liberado": "liberado",
    "Obstrução": "obstrucao",
}

BLOCS = {"Governo", "Oposição", "Minoria", "Maioria"}  # codTipoLideranca == 'B'

session = requests.Session()
session.headers.update({"Accept": "application/json",
                        "User-Agent": "ElesVotamPorVoce/0.1 (ingest)"})


# ---------------------------------------------------------------------------
#  HTTP com throttle + retry
# ---------------------------------------------------------------------------
def get_json(url, params=None, throttle=0.25, retries=4):
    """GET com backoff exponencial. Retorna o dict JSON."""
    for attempt in range(retries):
        try:
            r = session.get(url, params=params, timeout=30)
            if r.status_code == 429:            # rate limited
                time.sleep(2 * (attempt + 1))
                continue
            r.raise_for_status()
            time.sleep(throttle)                # gentileza com a API
            return r.json()
        except (requests.RequestException, ValueError) as e:
            if attempt == retries - 1:
                raise
            time.sleep(1.5 * (attempt + 1))
    return {}


def iter_votacoes(start, end, plen_only=False, limit=None):
    """Itera as votações do período, paginando via links 'next'."""
    params = {
        "dataInicio": start,
        "dataFim": end,
        "ordem": "ASC",
        "ordenarPor": "dataHoraRegistro",
        "itens": 100,
    }
    url = f"{API}/votacoes"
    seen = 0
    while url:
        payload = get_json(url, params=params)
        params = None                            # o link 'next' já traz a query
        for v in payload.get("dados", []):
            if plen_only and v.get("siglaOrgao") != "PLEN":
                continue
            yield v
            seen += 1
            if limit and seen >= limit:
                return
        url = next((l["href"] for l in payload.get("links", [])
                    if l.get("rel") == "next"), None)


def fetch_votos(vote_id):
    return get_json(f"{API}/votacoes/{vote_id}/votos").get("dados", [])


def fetch_orientacoes(vote_id):
    return get_json(f"{API}/votacoes/{vote_id}/orientacoes").get("dados", [])


# ---------------------------------------------------------------------------
#  Normalização (API -> dicts do nosso modelo)
# ---------------------------------------------------------------------------
def normalize_division(v):
    aprov = v.get("aprovacao")
    return {
        "house": "camara",
        "external_id": v["id"],
        "occurred_at": v.get("dataHoraRegistro") or v.get("data"),
        "body": v.get("siglaOrgao"),
        "description": v.get("descricao"),
        "result_approved": (bool(aprov) if aprov is not None else None),
        "prop_uri": v.get("uriProposicaoObjeto"),
        "prop_label": v.get("proposicaoObjeto"),
    }


def normalize_votos(votos):
    out = []
    for item in votos:
        dep = item.get("deputado_") or {}
        out.append({
            "person_external_id": str(dep.get("id")),
            "name": dep.get("nome"),
            "uf": dep.get("siglaUf"),
            "party_sigla": dep.get("siglaPartido"),
            "photo_url": dep.get("urlFoto"),
            "email": dep.get("email"),
            "option": VOTE_MAP.get(item.get("tipoVoto"), "outro"),
            "registered_at": item.get("dataRegistroVoto"),
        })
    return out


def normalize_orientacoes(orients):
    out = []
    for o in orients:
        sigla = o.get("siglaPartidoBloco")
        is_bloc = (o.get("codTipoLideranca") == "B") or (sigla in BLOCS)
        out.append({
            "party_sigla": None if is_bloc else sigla,
            "party_cod": o.get("codPartidoBloco"),
            "bloc_name": sigla if is_bloc else None,
            "leadership_type": o.get("codTipoLideranca"),
            "orientation": ORIENT_MAP.get(o.get("orientacaoVoto"), "outro"),
        })
    return out


def tally_by_party(votos):
    """Placar agregado por sigla de partido (usa o partido no momento do voto)."""
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
#  Persistência (Postgres)
# ---------------------------------------------------------------------------
class DB:
    def __init__(self, dsn):
        import psycopg2                          # import tardio: só quando grava
        self.conn = psycopg2.connect(dsn)
        self.conn.autocommit = False

    def close(self):
        self.conn.close()

    def upsert_party(self, cur, sigla, cod=None):
        if not sigla:
            return None
        cur.execute(
            """INSERT INTO party (sigla, camara_cod) VALUES (%s, %s)
               ON CONFLICT (sigla) DO UPDATE
                 SET camara_cod = COALESCE(EXCLUDED.camara_cod, party.camara_cod)
               RETURNING id""",
            (sigla, cod),
        )
        return cur.fetchone()[0]

    def upsert_person(self, cur, p):
        cur.execute(
            """INSERT INTO person (house, external_id, name, uf, photo_url, email)
               VALUES ('camara', %s, %s, %s, %s, %s)
               ON CONFLICT (house, external_id) DO UPDATE
                 SET name = EXCLUDED.name, uf = EXCLUDED.uf,
                     photo_url = EXCLUDED.photo_url,
                     email = COALESCE(EXCLUDED.email, person.email)
               RETURNING id""",
            (p["person_external_id"], p["name"], p["uf"], p["photo_url"], p["email"]),
        )
        return cur.fetchone()[0]

    def upsert_proposition(self, cur, uri, label):
        if not uri and not label:
            return None
        ext = uri.rstrip("/").split("/")[-1] if uri else None
        cur.execute(
            """INSERT INTO proposition (house, external_id, raw_label)
               VALUES ('camara', %s, %s)
               ON CONFLICT (house, external_id) DO UPDATE
                 SET raw_label = COALESCE(EXCLUDED.raw_label, proposition.raw_label)
               RETURNING id""",
            (ext, label),
        )
        return cur.fetchone()[0]

    def upsert_division(self, cur, d, prop_id, is_nominal):
        cur.execute(
            """INSERT INTO division
                 (house, external_id, occurred_at, body, proposition_id,
                  description, result_approved, is_nominal)
               VALUES ('camara', %s, %s, %s, %s, %s, %s, %s)
               ON CONFLICT (house, external_id) DO UPDATE
                 SET occurred_at = EXCLUDED.occurred_at,
                     body = EXCLUDED.body,
                     proposition_id = COALESCE(EXCLUDED.proposition_id, division.proposition_id),
                     description = EXCLUDED.description,
                     result_approved = EXCLUDED.result_approved,
                     is_nominal = EXCLUDED.is_nominal
               RETURNING id""",
            (d["external_id"], d["occurred_at"], d["body"], prop_id,
             d["description"], d["result_approved"], is_nominal),
        )
        return cur.fetchone()[0]

    def upsert_vote(self, cur, division_id, person_id, party_id, opt, reg_at):
        cur.execute(
            """INSERT INTO vote (division_id, person_id, party_id, option, registered_at)
               VALUES (%s, %s, %s, %s, %s)
               ON CONFLICT (division_id, person_id) DO UPDATE
                 SET party_id = EXCLUDED.party_id, option = EXCLUDED.option,
                     registered_at = EXCLUDED.registered_at""",
            (division_id, person_id, party_id, opt, reg_at),
        )

    def upsert_orientation(self, cur, division_id, party_id, o):
        cur.execute(
            """INSERT INTO party_orientation
                 (division_id, party_id, bloc_name, leadership_type, orientation)
               VALUES (%s, %s, %s, %s, %s)
               ON CONFLICT (division_id, party_id, bloc_name) DO UPDATE
                 SET leadership_type = EXCLUDED.leadership_type,
                     orientation = EXCLUDED.orientation""",
            (division_id, party_id, o["bloc_name"], o["leadership_type"], o["orientation"]),
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
    votos = normalize_votos(fetch_votos(v["id"]))
    orients = normalize_orientacoes(fetch_orientacoes(v["id"]))
    # Heurística: se há voto individual registrado, tratamos como nominal.
    # (A API não traz um flag nominal/simbólica direto na lista de votações.)
    is_nominal = len(votos) > 0
    tallies = tally_by_party(votos)

    if dry_run:
        print(f"— votação {d['external_id']} [{d['body']}] {d['occurred_at']}"
              f" | aprov={d['result_approved']} | nominal={is_nominal}")
        print(f"    {d['description'][:90] if d['description'] else ''}")
        print(f"    votos/pessoa: {len(votos)} | orientações/partido: {len(orients)}"
              f" | partidos no placar: {len(tallies)}")
        if votos:
            ex = votos[0]
            print(f"    ex. voto: {ex['name']} ({ex['party_sigla']}-{ex['uf']}) -> {ex['option']}")
        if orients:
            eo = orients[0]
            who = eo["bloc_name"] or eo["party_sigla"]
            print(f"    ex. orientação: {who} -> {eo['orientation']}")
        return

    prop_id = db.upsert_proposition(cur, d["prop_uri"], d["prop_label"])
    division_id = db.upsert_division(cur, d, prop_id, is_nominal)

    for p in votos:
        person_id = db.upsert_person(cur, p)
        party_id = db.upsert_party(cur, p["party_sigla"])
        db.upsert_vote(cur, division_id, person_id, party_id, p["option"], p["registered_at"])

    for o in orients:
        party_id = db.upsert_party(cur, o["party_sigla"], o["party_cod"]) if o["party_sigla"] else None
        db.upsert_orientation(cur, division_id, party_id, o)

    for sigla, t in tallies.items():
        party_id = db.upsert_party(cur, sigla)
        db.upsert_tally(cur, division_id, party_id, t)


def main():
    ap = argparse.ArgumentParser(description="Ingestão de votações da Câmara dos Deputados")
    ap.add_argument("--start", required=True, help="data inicial AAAA-MM-DD")
    ap.add_argument("--end", default=None, help="data final AAAA-MM-DD (default = start)")
    ap.add_argument("--plen-only", action="store_true", help="só votações do Plenário")
    ap.add_argument("--limit", type=int, default=None, help="máx. de votações (teste)")
    ap.add_argument("--dry-run", action="store_true", help="não grava; só imprime o parsing")
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
        for v in iter_votacoes(start, end, plen_only=args.plen_only, limit=args.limit):
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

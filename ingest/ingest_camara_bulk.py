#!/usr/bin/env python3
"""
Ingestão em MASSA — Câmara dos Deputados (arquivos anuais)
Projeto: Eles Votam Por Você

Baixa os arquivos anuais oficiais (~3 por ano) e ingere as votações NOMINAIS.
Muito mais rápido/confiável que a API por votação.

Performance: cacheia pessoas/partidos e insere votos/orientações/placares em
LOTE (execute_values), evitando dezenas de milhares de idas à rede.

Uso:
  export DATABASE_URL="postgresql://..."
  python ingest/ingest_camara_bulk.py --years 2023 2024 2025 2026
"""

import argparse
import os
import sys
import time
from collections import defaultdict

import requests

BASE = "https://dadosabertos.camara.leg.br/arquivos"

VOTE_MAP = {"Sim": "sim", "Não": "nao", "Abstenção": "abstencao",
            "Obstrução": "obstrucao", "Artigo 17": "artigo17"}
ORIENT_MAP = {"Sim": "sim", "Não": "nao", "Liberado": "liberado",
              "Obstrução": "obstrucao"}
BLOCS = {"Governo", "Oposição", "Minoria", "Maioria"}

session = requests.Session()
session.headers.update({"User-Agent": "ElesVotamPorVoce/0.1 (bulk)"})


# ---------------------------------------------------------------------------
#  Download dos arquivos anuais — com retry
# ---------------------------------------------------------------------------
def download_dados(nome, ano, retries=5):
    url = f"{BASE}/{nome}/json/{nome}-{ano}.json"
    for attempt in range(retries):
        try:
            r = session.get(url, timeout=(30, 180))
            if r.status_code == 404:
                print(f"  (sem arquivo {nome}-{ano})", file=sys.stderr)
                return []
            r.raise_for_status()
            return r.json().get("dados", [])
        except (requests.RequestException, ValueError) as e:
            if attempt == retries - 1:
                raise
            print(f"  retry {nome}-{ano} ({e})", file=sys.stderr)
            time.sleep(5 * (attempt + 1))
    return []


# ---------------------------------------------------------------------------
#  Leitura tolerante de campos (bulk achatado x API aninhado)
# ---------------------------------------------------------------------------
def voto_value(v):
    return v.get("voto") or v.get("tipoVoto")


def dep(v, sub):
    flat = v.get(f"deputado_{sub}")
    if flat is not None:
        return flat
    return (v.get("deputado_") or {}).get(sub)


def norm_person(v):
    return {
        "person_external_id": str(dep(v, "id")),
        "name": dep(v, "nome"),
        "uf": dep(v, "siglaUf"),
        "party_sigla": dep(v, "siglaPartido"),
        "photo_url": dep(v, "urlFoto"),
        "email": dep(v, "email"),
        "option": VOTE_MAP.get(voto_value(v), "outro"),
        "registered_at": v.get("dataRegistroVoto"),
    }


def tally_by_party(votos):
    t = defaultdict(lambda: defaultdict(int))
    for p in votos:
        if p["party_sigla"]:
            t[p["party_sigla"]][p["option"]] += 1
    out = {}
    for sig, c in t.items():
        countable = {k: c.get(k, 0) for k in ("sim", "nao", "abstencao", "obstrucao")}
        maj = max(countable, key=countable.get) if any(countable.values()) else None
        out[sig] = {"sim": c.get("sim", 0), "nao": c.get("nao", 0),
                    "abstencao": c.get("abstencao", 0),
                    "obstrucao": c.get("obstrucao", 0),
                    "ausente": c.get("ausente", 0), "majority_option": maj}
    return out


# ---------------------------------------------------------------------------
#  Persistência (Postgres) — com cache e inserção em lote
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

    # --- referência: carrega partidos e pessoas de uma vez, popula cache ---
    def load_parties(self, cur, siglas):
        from psycopg2.extras import execute_values
        if siglas:
            execute_values(cur,
                "INSERT INTO party (sigla) VALUES %s ON CONFLICT (sigla) DO NOTHING",
                [(s,) for s in siglas])
        cur.execute("SELECT sigla, id FROM party")
        self.party_cache = {s: i for s, i in cur.fetchall()}

    def load_persons(self, cur, persons):
        from psycopg2.extras import execute_values
        if persons:
            execute_values(cur,
                """INSERT INTO person (house, external_id, name, uf, photo_url, email)
                   VALUES %s
                   ON CONFLICT (house, external_id) DO UPDATE
                     SET name=EXCLUDED.name, uf=EXCLUDED.uf,
                         photo_url=EXCLUDED.photo_url,
                         email=COALESCE(EXCLUDED.email, person.email)""",
                [('camara', p["person_external_id"], p["name"], p["uf"],
                  p["photo_url"], p["email"]) for p in persons.values()])
        cur.execute("SELECT external_id, id FROM person WHERE house='camara'")
        self.person_cache = {e: i for e, i in cur.fetchall()}

    def division(self, cur, vot):
        cur.execute("""INSERT INTO division
                         (house, external_id, occurred_at, body, description,
                          result_approved, is_nominal)
                       VALUES ('camara', %s,%s,%s,%s,%s, TRUE)
                       ON CONFLICT (house, external_id) DO UPDATE
                         SET occurred_at=EXCLUDED.occurred_at, body=EXCLUDED.body,
                             description=EXCLUDED.description,
                             result_approved=EXCLUDED.result_approved, is_nominal=TRUE
                       RETURNING id""",
                    (vot["id"], vot.get("dataHoraRegistro") or vot.get("data"),
                     vot.get("siglaOrgao"), vot.get("descricao"),
                     (bool(vot["aprovacao"]) if vot.get("aprovacao") is not None else None)))
        return cur.fetchone()[0]

    def votes_bulk(self, cur, rows):
        if not rows:
            return
        from psycopg2.extras import execute_values
        execute_values(cur,
            """INSERT INTO vote (division_id, person_id, party_id, option, registered_at)
               VALUES %s
               ON CONFLICT (division_id, person_id) DO UPDATE
                 SET party_id=EXCLUDED.party_id, option=EXCLUDED.option,
                     registered_at=EXCLUDED.registered_at""", rows)

    def orientations_replace(self, cur, division_id, rows):
        from psycopg2.extras import execute_values
        cur.execute("DELETE FROM party_orientation WHERE division_id=%s", (division_id,))
        if rows:
            execute_values(cur,
                """INSERT INTO party_orientation
                     (division_id, party_id, bloc_name, leadership_type, orientation)
                   VALUES %s""", rows)

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
                 SET sim_count=EXCLUDED.sim_count, nao_count=EXCLUDED.nao_count,
                     abstencao_count=EXCLUDED.abstencao_count,
                     obstrucao_count=EXCLUDED.obstrucao_count,
                     ausente_count=EXCLUDED.ausente_count,
                     majority_option=EXCLUDED.majority_option""", rows)


# ---------------------------------------------------------------------------
#  Processamento de um ano
# ---------------------------------------------------------------------------
def process_year(ano, db):
    print(f"Ano {ano}: baixando arquivos...", flush=True)
    votos_raw = download_dados("votacoesVotos", ano)
    orient_raw = download_dados("votacoesOrientacoes", ano)
    votacoes = download_dados("votacoes", ano)

    votos_by = defaultdict(list)
    for v in votos_raw:
        vid = v.get("idVotacao") or v.get("id")
        votos_by[vid].append(norm_person(v))
    orient_by = defaultdict(list)
    for o in orient_raw:
        orient_by[o.get("idVotacao")].append(o)
    meta_by = {vt["id"]: vt for vt in votacoes}

    total = len(votos_by)
    print(f"Ano {ano}: {total} votações nominais (de {len(votacoes)} no arquivo).", flush=True)

    # referência: pessoas + partidos (de votos e de orientações) numa tacada
    persons, parties = {}, set()
    for votos in votos_by.values():
        for p in votos:
            if p["person_external_id"] and p["person_external_id"] != "None":
                persons[p["person_external_id"]] = p
            if p["party_sigla"]:
                parties.add(p["party_sigla"])
    for o in orient_raw:
        sig = o.get("siglaBancada")
        if sig and sig not in BLOCS:
            parties.add(sig)

    cur = db.conn.cursor()
    db.load_parties(cur, parties)
    db.load_persons(cur, persons)
    db.conn.commit()
    print(f"Ano {ano}: {len(persons)} pessoas, {len(parties)} partidos em cache.", flush=True)

    n = skipped = 0
    for vid, votos in votos_by.items():
        vot = meta_by.get(vid) or {"id": vid}
        try:
            div_id = db.division(cur, vot)

            vote_rows = []
            for p in votos:
                pid = db.person_cache.get(p["person_external_id"])
                if not pid:
                    continue
                vote_rows.append((div_id, pid, db.party_cache.get(p["party_sigla"]),
                                  p["option"], p["registered_at"]))
            db.votes_bulk(cur, vote_rows)

            orient_rows = []
            for o in orient_by.get(vid, []):
                sig = o.get("siglaBancada")
                is_bloc = sig in BLOCS
                orient_rows.append((div_id,
                                    None if is_bloc else db.party_cache.get(sig),
                                    sig if is_bloc else None,
                                    'B' if is_bloc else 'P',
                                    ORIENT_MAP.get(o.get("orientacao"), "outro")))
            db.orientations_replace(cur, div_id, orient_rows)

            tally_rows = [(div_id, db.party_cache.get(sig), c["sim"], c["nao"],
                           c["abstencao"], c["obstrucao"], c["ausente"], c["majority_option"])
                          for sig, c in tally_by_party(votos).items()
                          if db.party_cache.get(sig)]
            db.tally_bulk(cur, tally_rows)

            db.conn.commit()
            n += 1
            if n % 100 == 0:
                print(f"Ano {ano}: {n}/{total} processadas...", flush=True)
        except Exception as e:            # noqa: BLE001
            db.conn.rollback()
            skipped += 1
            print(f"[pulada {vid}] {e}", file=sys.stderr)
    cur.close()
    print(f"Ano {ano}: {n} votações gravadas, {skipped} puladas.", flush=True)
    return n


def main():
    ap = argparse.ArgumentParser(description="Ingestão em massa da Câmara (arquivos anuais)")
    ap.add_argument("--years", nargs="+", type=int, required=True)
    args = ap.parse_args()

    dsn = os.environ.get("DATABASE_URL")
    if not dsn:
        sys.exit("ERRO: defina DATABASE_URL.")
    db = DB(dsn)
    total = 0
    try:
        for ano in args.years:
            try:
                total += process_year(ano, db)
            except Exception as e:        # noqa: BLE001
                print(f"[ano {ano} falhou] {e}", file=sys.stderr)
    finally:
        db.close()
    print(f"\nConcluído: {total} votações nominais gravadas em {len(args.years)} ano(s).",
          flush=True)


if __name__ == "__main__":
    main()

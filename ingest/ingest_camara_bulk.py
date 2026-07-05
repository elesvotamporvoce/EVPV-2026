#!/usr/bin/env python3
"""
Ingestão em MASSA — Câmara dos Deputados (arquivos anuais)
Projeto: Eles Votam Por Você

Em vez de milhares de chamadas por votação (frágeis, dão timeout), baixa os
arquivos anuais oficiais — ~3 downloads por ano — e ingere as votações NOMINAIS
(as que têm voto individual registrado). Muito mais rápido e confiável.

Arquivos usados (por ano):
  votacoes-{ano}.json            -> metadados da votação
  votacoesVotos-{ano}.json       -> voto de cada deputado
  votacoesOrientacoes-{ano}.json -> orientação de cada partido/bloco

Uso:
  export DATABASE_URL="postgresql://..."
  python ingest/ingest_camara_bulk.py --years 2023 2024 2025 2026

Dependências: requests; psycopg2.
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
#  Download dos arquivos anuais (grandes) — com retry
# ---------------------------------------------------------------------------
def download_dados(nome, ano, retries=5):
    url = f"{BASE}/{nome}/json/{nome}-{ano}.json"
    for attempt in range(retries):
        try:
            r = session.get(url, timeout=600)      # arquivos podem ser grandes
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
    """Campo do deputado: aceita 'deputado_<sub>' (bulk) e 'deputado_'.<sub> (api)."""
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
    t = defaultdict(lambda: {"sim": 0, "nao": 0, "abstencao": 0,
                             "obstrucao": 0, "ausente": 0, "outro": 0})
    for p in votos:
        if p["party_sigla"]:
            t[p["party_sigla"]][p["option"]] += 1
    out = {}
    for sig, c in t.items():
        countable = {k: c[k] for k in ("sim", "nao", "abstencao", "obstrucao")}
        c["majority_option"] = max(countable, key=countable.get) if any(countable.values()) else None
        out[sig] = c
    return out


# ---------------------------------------------------------------------------
#  Persistência (Postgres)
# ---------------------------------------------------------------------------
class DB:
    def __init__(self, dsn):
        import psycopg2
        self.conn = psycopg2.connect(dsn)
        self.conn.autocommit = False

    def close(self):
        self.conn.close()

    def party(self, cur, sigla):
        if not sigla:
            return None
        cur.execute("""INSERT INTO party (sigla) VALUES (%s)
                       ON CONFLICT (sigla) DO UPDATE SET sigla=EXCLUDED.sigla
                       RETURNING id""", (sigla,))
        return cur.fetchone()[0]

    def person(self, cur, p):
        cur.execute("""INSERT INTO person (house, external_id, name, uf, photo_url, email)
                       VALUES ('camara', %s,%s,%s,%s,%s)
                       ON CONFLICT (house, external_id) DO UPDATE
                         SET name=EXCLUDED.name, uf=EXCLUDED.uf,
                             photo_url=EXCLUDED.photo_url,
                             email=COALESCE(EXCLUDED.email, person.email)
                       RETURNING id""",
                    (p["person_external_id"], p["name"], p["uf"],
                     p["photo_url"], p["email"]))
        return cur.fetchone()[0]

    def division(self, cur, vot):
        cur.execute("""INSERT INTO division
                         (house, external_id, occurred_at, body, description,
                          result_approved, is_nominal)
                       VALUES ('camara', %s,%s,%s,%s,%s, TRUE)
                       ON CONFLICT (house, external_id) DO UPDATE
                         SET occurred_at=EXCLUDED.occurred_at, body=EXCLUDED.body,
                             description=EXCLUDED.description,
                             result_approved=EXCLUDED.result_approved,
                             is_nominal=TRUE
                       RETURNING id""",
                    (vot["id"], vot.get("dataHoraRegistro") or vot.get("data"),
                     vot.get("siglaOrgao"), vot.get("descricao"),
                     (bool(vot["aprovacao"]) if vot.get("aprovacao") is not None else None)))
        return cur.fetchone()[0]

    def vote(self, cur, div_id, person_id, party_id, opt, reg):
        cur.execute("""INSERT INTO vote (division_id, person_id, party_id, option, registered_at)
                       VALUES (%s,%s,%s,%s,%s)
                       ON CONFLICT (division_id, person_id) DO UPDATE
                         SET party_id=EXCLUDED.party_id, option=EXCLUDED.option,
                             registered_at=EXCLUDED.registered_at""",
                    (div_id, person_id, party_id, opt, reg))

    def orientation(self, cur, div_id, party_id, bloc, orient):
        cur.execute("""INSERT INTO party_orientation
                         (division_id, party_id, bloc_name, leadership_type, orientation)
                       VALUES (%s,%s,%s,%s,%s)
                       ON CONFLICT (division_id, party_id, bloc_name) DO UPDATE
                         SET orientation=EXCLUDED.orientation,
                             leadership_type=EXCLUDED.leadership_type""",
                    (div_id, party_id, bloc, 'B' if bloc else 'P', orient))

    def tally(self, cur, div_id, party_id, c):
        cur.execute("""INSERT INTO party_vote_tally
                         (division_id, party_id, sim_count, nao_count, abstencao_count,
                          obstrucao_count, ausente_count, majority_option)
                       VALUES (%s,%s,%s,%s,%s,%s,%s,%s)
                       ON CONFLICT (division_id, party_id) DO UPDATE
                         SET sim_count=EXCLUDED.sim_count, nao_count=EXCLUDED.nao_count,
                             abstencao_count=EXCLUDED.abstencao_count,
                             obstrucao_count=EXCLUDED.obstrucao_count,
                             ausente_count=EXCLUDED.ausente_count,
                             majority_option=EXCLUDED.majority_option""",
                    (div_id, party_id, c["sim"], c["nao"], c["abstencao"],
                     c["obstrucao"], c["ausente"], c["majority_option"]))


# ---------------------------------------------------------------------------
#  Processamento de um ano
# ---------------------------------------------------------------------------
def process_year(ano, db):
    print(f"Ano {ano}: baixando arquivos...")
    votos_raw = download_dados("votacoesVotos", ano)
    orient_raw = download_dados("votacoesOrientacoes", ano)
    votacoes = download_dados("votacoes", ano)

    # agrupa por id de votação
    votos_by = defaultdict(list)
    for v in votos_raw:
        vid = v.get("idVotacao") or v.get("id")
        votos_by[vid].append(norm_person(v))
    orient_by = defaultdict(list)
    for o in orient_raw:
        orient_by[o.get("idVotacao")].append(o)
    meta_by = {vt["id"]: vt for vt in votacoes}

    print(f"Ano {ano}: {len(votos_by)} votações nominais (de {len(votacoes)} no arquivo).")

    cur = db.conn.cursor()
    n = skipped = 0
    for vid, votos in votos_by.items():
        vot = meta_by.get(vid)
        if not vot:
            vot = {"id": vid}          # sem metadados: grava o mínimo
        try:
            div_id = db.division(cur, vot)
            for p in votos:
                pid = db.person(cur, p)
                party_id = db.party(cur, p["party_sigla"])
                db.vote(cur, div_id, pid, party_id, p["option"], p["registered_at"])
            for o in orient_by.get(vid, []):
                sig = o.get("siglaBancada")
                is_bloc = sig in BLOCS
                party_id = None if is_bloc else db.party(cur, sig)
                bloc = sig if is_bloc else None
                db.orientation(cur, div_id, party_id, bloc,
                               ORIENT_MAP.get(o.get("orientacao"), "outro"))
            for sig, c in tally_by_party(votos).items():
                db.tally(cur, div_id, db.party(cur, sig), c)
            db.conn.commit()
            n += 1
        except Exception as e:            # noqa: BLE001
            db.conn.rollback()
            skipped += 1
            print(f"[pulada {vid}] {e}", file=sys.stderr)
    cur.close()
    print(f"Ano {ano}: {n} votações gravadas, {skipped} puladas.")
    return n


def main():
    ap = argparse.ArgumentParser(description="Ingestão em massa da Câmara (arquivos anuais)")
    ap.add_argument("--years", nargs="+", type=int, required=True,
                    help="anos, ex.: --years 2023 2024 2025 2026")
    args = ap.parse_args()

    dsn = os.environ.get("DATABASE_URL")
    if not dsn:
        sys.exit("ERRO: defina DATABASE_URL.")
    db = DB(dsn)
    total = 0
    try:
        for ano in args.years:
            total += process_year(ano, db)
    finally:
        db.close()
    print(f"\nConcluído: {total} votações nominais gravadas em {len(args.years)} ano(s).")


if __name__ == "__main__":
    main()

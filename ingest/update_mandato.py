#!/usr/bin/env python3
"""
Atualiza o status de mandato de cada parlamentar.

Fontes oficiais:
  Camara: /deputados (em exercicio) + /deputados/{id} (situacao dos demais)
  Senado: /senador/lista/atual (em exercicio) + /senador/lista/afastados

Status gravados em person.mandate_status:
  em_exercicio | licenciado | fora
person.mandate_detail: texto livre (ex. "Licenca", "Vacancia"). Nunca
sobrescreve um detail editorial ja existente (usa COALESCE).
person.active = status em (em_exercicio, licenciado).

Uso: export DATABASE_URL=... ; python ingest/update_mandato.py
"""
import json
import os
import sys
import time
import urllib.request

CAMARA = "https://dadosabertos.camara.leg.br/api/v2"
SENADO = "https://legis.senado.leg.br/dadosabertos"
HEADERS = {"Accept": "application/json", "User-Agent": "elesvotamporvoce.org (contato@elesvotamporvoce.org)"}


def get_json(url, retries=3):
    for i in range(retries):
        try:
            req = urllib.request.Request(url, headers=HEADERS)
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.load(r)
        except Exception as e:
            if i == retries - 1:
                raise
            print(f"  retry {i+1} {url}: {e}", flush=True)
            time.sleep(3 * (i + 1))


def camara_em_exercicio():
    ids = set()
    pagina = 1
    while True:
        data = get_json(f"{CAMARA}/deputados?itens=100&pagina={pagina}")
        rows = data.get("dados", [])
        if not rows:
            break
        ids.update(str(d["id"]) for d in rows)
        pagina += 1
    return ids


def camara_situacao(ext_id):
    try:
        data = get_json(f"{CAMARA}/deputados/{ext_id}")
        st = (data.get("dados") or {}).get("ultimoStatus") or {}
        return (st.get("situacao") or "").strip()
    except Exception as e:
        print(f"  aviso: sem situacao p/ deputado {ext_id}: {e}", flush=True)
        return ""


def collect_codigos(node, out):
    """Acha recursivamente todos os IdentificacaoParlamentar.CodigoParlamentar."""
    if isinstance(node, dict):
        ident = node.get("IdentificacaoParlamentar")
        if isinstance(ident, dict) and ident.get("CodigoParlamentar"):
            out.add(str(ident["CodigoParlamentar"]))
        for v in node.values():
            collect_codigos(v, out)
    elif isinstance(node, list):
        for v in node:
            collect_codigos(v, out)


def senado_lista(path):
    out = set()
    collect_codigos(get_json(f"{SENADO}/senador/lista/{path}"), out)
    return out


def main():
    dsn = os.environ.get("DATABASE_URL")
    if not dsn:
        sys.exit("ERRO: defina DATABASE_URL.")
    import psycopg2

    conn = psycopg2.connect(dsn)
    conn.autocommit = False
    cur = conn.cursor()

    cur.execute("SELECT house, external_id FROM person")
    pessoas = cur.fetchall()
    camara_db = [e for h, e in pessoas if h == "camara"]
    senado_db = [e for h, e in pessoas if h == "senado"]
    print(f"No banco: {len(camara_db)} camara, {len(senado_db)} senado", flush=True)

    # ---- Camara ------------------------------------------------------------
    atuais = camara_em_exercicio()
    print(f"Camara em exercicio (API): {len(atuais)}", flush=True)
    updates = []  # (status, detail, ativo, house, ext)
    fora_cam = [e for e in camara_db if e not in atuais]
    for e in camara_db:
        if e in atuais:
            updates.append(("em_exercicio", None, True, "camara", e))
    print(f"Consultando situacao de {len(fora_cam)} deputados fora da lista...", flush=True)
    for i, e in enumerate(fora_cam):
        sit = camara_situacao(e)
        low = sit.lower()
        if "exerc" in low:
            status, ativo = "em_exercicio", True
        elif "licen" in low or "afast" in low:
            status, ativo = "licenciado", True
        else:
            status, ativo = "fora", False
        updates.append((status, sit or None, ativo, "camara", e))
        if i % 50 == 0:
            print(f"  {i}/{len(fora_cam)}", flush=True)
        time.sleep(0.25)

    # ---- Senado ------------------------------------------------------------
    sen_atual = senado_lista("atual")
    sen_afast = senado_lista("afastados")
    print(f"Senado em exercicio: {len(sen_atual)}, afastados: {len(sen_afast)}", flush=True)
    for e in senado_db:
        if e in sen_atual:
            updates.append(("em_exercicio", None, True, "senado", e))
        elif e in sen_afast:
            updates.append(("licenciado", "Afastado (fonte: Senado)", True, "senado", e))
        else:
            updates.append(("fora", None, False, "senado", e))

    # ---- grava -------------------------------------------------------------
    cur.executemany(
        """UPDATE person
           SET mandate_status=%s,
               mandate_detail=COALESCE(%s, mandate_detail),
               active=%s
           WHERE house=%s AND external_id=%s""",
        updates,
    )
    conn.commit()

    cur.execute("SELECT mandate_status, count(*) FROM person GROUP BY 1 ORDER BY 1")
    for row in cur.fetchall():
        print(f"  {row[0]}: {row[1]}", flush=True)
    conn.close()
    print("OK: status de mandato atualizado.", flush=True)


if __name__ == "__main__":
    main()

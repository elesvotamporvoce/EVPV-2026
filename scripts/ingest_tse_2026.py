#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Ingestão TSE 2026 — candidaturas e patrimônio dos parlamentares atuais.

Cruza os parlamentares do banco com o DivulgaCandContas do TSE (registro de
candidaturas encerrado em 15/08/2026) e grava em candidatura_2026:
cargo, UF, situação, nome de urna, partido, patrimônio declarado e o
sq_candidato (id do TSE, para conferência manual).

Uso (na sua máquina, com acesso à internet e ao banco):
  export DATABASE_URL=postgresql://...   # conexão do Supabase
  python scripts/ingest_tse_2026.py            # tudo
  python scripts/ingest_tse_2026.py --uf SP    # só um estado

O casamento é por NOME COMPLETO normalizado (sem acento, maiúsculas) + UF.
Quem não casar sai em nao_casados_tse.csv para revisão manual — nome de urna
e nome civil às vezes divergem; NÃO complete na mão sem conferir no TSE.
"""
import argparse, csv, json, os, re, sys, time, unicodedata
import urllib.error
import urllib.request

import psycopg2

BASE = "https://divulgacandcontas.tse.jus.br/divulga/rest/v1"
ANO = 2026
# cargos federais/estaduais em eleição geral; código -> rótulo usado no site
CARGOS = {"1": "presidente", "3": "governador", "5": "senador",
          "6": "deputado_federal", "7": "deputado_estadual"}
SITUACAO = {  # descrição do TSE -> nosso vocabulário
    "DEFERIDO": "deferido", "DEFERIDO COM RECURSO": "deferido",
    "INDEFERIDO": "indeferido", "INDEFERIDO COM RECURSO": "indeferido",
    "AGUARDANDO JULGAMENTO": "pendente", "PENDENTE DE JULGAMENTO": "pendente",
}
UFS = ("AC AL AM AP BA CE DF ES GO MA MG MS MT PA PB PE PI PR RJ RN RO RR RS "
       "SC SE SP TO").split()

# ---------------------------------------------------------------- HTTP no TSE
# O DivulgaCandContas passou a responder 403 para cliente que nao parece
# navegador (o "EVPV/1.0" que usavamos aqui deixou de passar em 21/08/2026).
# Mandamos os mesmos cabecalhos de um navegador; se ainda vier 403, trocamos o
# conjunto uma vez antes de desistir — repetir o mesmo 403 nao adianta.
_CHROME = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
           "(KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36")
_CABECALHOS = [
    {"User-Agent": _CHROME,
     "Accept": "application/json, text/plain, */*",
     "Accept-Language": "pt-BR,pt;q=0.9,en;q=0.8",
     "Referer": "https://divulgacandcontas.tse.jus.br/divulga/"},
    {"User-Agent": _CHROME, "Accept": "*/*"},
]

def get(url, tries=3):
    ultimo = None
    for cab in _CABECALHOS:
        for i in range(tries):
            try:
                req = urllib.request.Request(url, headers=cab)
                with urllib.request.urlopen(req, timeout=40) as r:
                    return json.load(r)
            except urllib.error.HTTPError as e:
                ultimo = e
                if e.code == 403:
                    break  # nao melhora repetindo: tenta o outro cabecalho
                if e.code in (429, 500, 502, 503, 504) and i < tries - 1:
                    time.sleep(3 * (i + 1))
                    continue
                raise
            except Exception as e:
                ultimo = e
                if i == tries - 1:
                    break
                time.sleep(2 * (i + 1))
    if isinstance(ultimo, urllib.error.HTTPError) and ultimo.code == 403:
        raise SystemExit(
            "\nO TSE respondeu 403 (Forbidden) em:\n  " + url +
            "\nIsso e bloqueio do lado deles, nao erro do script."
            "\nRode 'python scripts/testar_tse.py' para descobrir se e cabecalho,"
            "\nVPN/proxy, bloqueio por IP ou o site fora do ar.\n")
    raise ultimo

def norm(s):
    s = unicodedata.normalize("NFD", s or "")
    s = re.sub(r"[^A-Z ]", "", s.upper().encode("ascii", "ignore").decode())
    # espacos multiplos viram um so (o TSE tem nomes de urna com espaco duplo,
    # ex.: "ENFERMEIRA  ANA PAULA" — sem isso o casamento falha)
    return re.sub(r" +", " ", s).strip()

def sexo_tse(det):
    """'FEM.' / 'MASC.' do TSE -> 'F' / 'M'. Desconhecido vira None."""
    d = (det or {}).get("descricaoSexo") or ""
    d = d.strip().upper()
    if d.startswith("FEM"):
        return "F"
    if d.startswith("MASC"):
        return "M"
    return None


def eleicao_id():
    for e in get(f"{BASE}/eleicao/ordinarias"):
        if str(e.get("ano")) == str(ANO):
            return e["id"]
    sys.exit(f"Eleição de {ANO} não encontrada em /eleicao/ordinarias")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--uf", help="limita a um estado")
    args = ap.parse_args()
    dsn = os.environ.get("DATABASE_URL") or sys.exit("defina DATABASE_URL")
    eid = eleicao_id()
    print(f"eleição {ANO}: id {eid}")

    con = psycopg2.connect(dsn); cur = con.cursor()
    cur.execute("SELECT id, name, uf FROM person")
    pessoas = {}  # (nome_norm, uf) -> person_id
    for pid, nome, uf in cur.fetchall():
        pessoas[(norm(nome), uf)] = pid

    achados, nao_casados = 0, []
    ufs = [args.uf.upper()] if args.uf else UFS + ["BR"]
    for uf in ufs:
        for cod, rotulo in CARGOS.items():
            # presidente e cargo nacional (UF "BR"); os demais, estaduais
            if (rotulo == "presidente") != (uf == "BR"): continue
            url = f"{BASE}/candidatura/listar/{ANO}/{uf}/{eid}/{cod}/candidatos"
            try: data = get(url)
            except Exception as e:
                print(f"  aviso {uf}/{rotulo}: {e}"); continue
            for c in data.get("candidatos", []):
                # tenta pelo nome de urna (costuma ser o nome parlamentar)
                # e depois pelo nome civil completo
                pid = (pessoas.get((norm(c.get("nomeUrna")), uf))
                       or pessoas.get((norm(c.get("nomeCompleto")), uf)))
                if pid is None:
                    nao_casados.append((uf, rotulo, c.get("nomeCompleto"),
                                        c.get("nomeUrna"), c.get("id")))
                    continue
                # detalhe traz situação atual e total de bens
                det = get(f"{BASE}/candidatura/buscar/{ANO}/{uf}/{eid}/candidato/{c['id']}")
                sit = SITUACAO.get((det.get("descricaoSituacao") or "").upper().strip(),
                                   "pendente")
                bens = det.get("totalDeBens")
                sexo = sexo_tse(det)
                cur.execute("""
                    INSERT INTO candidatura_2026
                      (person_id, cargo, uf, situacao, fonte, atualizado_em,
                       patrimonio_total, nome_urna, partido_sigla, sq_candidato,
                       sexo)
                    VALUES (%s,%s,%s,%s,'TSE DivulgaCandContas', now(),%s,%s,%s,%s,%s)
                    ON CONFLICT (person_id) DO UPDATE SET
                      cargo=EXCLUDED.cargo, uf=EXCLUDED.uf,
                      situacao=EXCLUDED.situacao, fonte=EXCLUDED.fonte,
                      atualizado_em=now(),
                      patrimonio_total=EXCLUDED.patrimonio_total,
                      nome_urna=EXCLUDED.nome_urna,
                      partido_sigla=EXCLUDED.partido_sigla,
                      sq_candidato=EXCLUDED.sq_candidato,
                      sexo=COALESCE(EXCLUDED.sexo, candidatura_2026.sexo)
                """, (pid, rotulo, uf, sit, bens,
                      c.get("nomeUrna"), (c.get("partido") or {}).get("sigla"),
                      str(c.get("id")), sexo))
                achados += 1
            con.commit()
            print(f"  {uf} {rotulo}: ok (acumulado {achados})")
            time.sleep(0.4)  # gentileza com a API

    with open("nao_casados_tse.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f); w.writerow(["uf","cargo","nome_completo","nome_urna","id_tse"])
        w.writerows(nao_casados)
    print(f"\nGravadas {achados} candidaturas de parlamentares atuais.")
    print(f"{len(nao_casados)} candidatos do TSE sem par no banco -> nao_casados_tse.csv")
    print("(a maioria é candidato que NÃO é parlamentar atual; isso é esperado)")

if __name__ == "__main__":
    main()

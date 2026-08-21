#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Ingestão TSE 2026 — candidatos SEM histórico no Congresso.

Complementa o scripts/ingest_tse_2026.py: aquele casa candidatos com os
parlamentares que já estão no nosso banco; este grava os que NÃO casam, ou
seja, quem não tem voto nominal registrado na Câmara/Senado desde 2019.

Escopo: presidente, senador e deputado federal — os cargos que o site cobre.
Governador e deputado estadual ficam de fora de propósito: não votam no
Congresso, então não há como dar nenhuma referência de votação.

Uso (na sua máquina, com acesso à internet e ao banco):
  export DATABASE_URL=postgresql://...      # string do POOLER (IPv4)
  python scripts/ingest_candidatos_novos.py
  python scripts/ingest_candidatos_novos.py --uf SP     # só um estado
  python scripts/ingest_candidatos_novos.py --sem-bens  # pula o detalhe (rápido)

O detalhe de cada candidato (situação + patrimônio) é uma chamada extra por
pessoa. São ~7.400 candidatos, então a execução completa leva um bom tempo;
--sem-bens grava só o básico (nome, cargo, UF, partido) em poucos minutos.
"""
import argparse, os, json, re, sys, time, unicodedata
import urllib.error
import urllib.request

import psycopg2
from psycopg2.extras import execute_values

BASE = "https://divulgacandcontas.tse.jus.br/divulga/rest/v1"
ANO = 2026
# só os cargos que o site cobre (o Congresso)
CARGOS = {"1": "presidente", "5": "senador", "6": "deputado_federal"}
SITUACAO = {
    "DEFERIDO": "deferido", "DEFERIDO COM RECURSO": "deferido",
    "INDEFERIDO": "indeferido", "INDEFERIDO COM RECURSO": "indeferido",
    "AGUARDANDO JULGAMENTO": "pendente", "PENDENTE DE JULGAMENTO": "pendente",
}
UFS = ("AC AL AM AP BA CE DF ES GO MA MG MS MT PA PB PE PI PR RJ RN RO RR RS "
       "SC SE SP TO").split()

# O TSE e o nosso banco escrevem algumas siglas de formas diferentes.
# Só mapeamos o que diverge; o resto casa direto pela sigla.
SIGLA_ALIAS = {
    "PODEMOS": "PODE",
    "UNIAO": "UNIÃO",
    "UNIAO BRASIL": "UNIÃO",
    "UNIÃO BRASIL": "UNIÃO",
    "SOLIDARIEDADE": "SOLIDARIEDADE",
    "PC DO B": "PCdoB",
    "PCDOB": "PCdoB",
    "PV": "PV",
    "REDE": "REDE",
}


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
    """Maiúsculas, sem acento, sem pontuação, espaços colapsados."""
    s = unicodedata.normalize("NFD", s or "")
    s = re.sub(r"[^A-Z ]", "", s.upper().encode("ascii", "ignore").decode())
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
    ap.add_argument("--sem-bens", action="store_true",
                    help="não busca o detalhe (situação/patrimônio) de cada candidato")
    args = ap.parse_args()
    dsn = os.environ.get("DATABASE_URL") or sys.exit("defina DATABASE_URL")
    eid = eleicao_id()
    print(f"eleição {ANO}: id {eid}")

    con = psycopg2.connect(dsn)
    cur = con.cursor()

    # Quem JÁ é nosso: casamos por (nome normalizado, UF) igual ao outro script,
    # para não duplicar na página de "sem histórico" quem já tem perfil no site.
    cur.execute("SELECT name, uf FROM person")
    pessoas = cur.fetchall()
    nossos = {(norm(n), uf) for n, uf in pessoas}
    # e por nome só, para pegar quem mudou de estado (ex.: Tiririca SP->CE)
    nossos_nome = {norm(n) for n, _ in pessoas}

    # Mapa sigla -> party_id, só dos partidos com média de votação utilizável.
    cur.execute("""SELECT p.id, p.sigla FROM party p
                    WHERE EXISTS (SELECT 1 FROM party_policy_agreement a
                                   WHERE a.party_id = p.id AND a.n_people >= 5)""")
    partidos = {norm(s): pid for pid, s in cur.fetchall()}

    def party_id(sigla):
        if not sigla:
            return None
        chave = norm(SIGLA_ALIAS.get(norm(sigla), sigla))
        return partidos.get(chave)

    linhas, vistos, pulados = [], set(), 0
    ufs = [args.uf.upper()] if args.uf else UFS + ["BR"]
    for uf in ufs:
        for cod, rotulo in CARGOS.items():
            if (rotulo == "presidente") != (uf == "BR"):
                continue
            url = f"{BASE}/candidatura/listar/{ANO}/{uf}/{eid}/{cod}/candidatos"
            try:
                data = get(url)
            except Exception as e:
                print(f"  aviso {uf}/{rotulo}: {e}")
                continue
            for c in data.get("candidatos", []):
                sq = str(c.get("id"))
                if sq in vistos:
                    continue
                urna = (c.get("nomeUrna") or "").strip()
                completo = (c.get("nomeCompleto") or "").strip()
                # já temos essa pessoa? então ela tem perfil e histórico no site
                if ((norm(urna), uf) in nossos or (norm(completo), uf) in nossos
                        or norm(urna) in nossos_nome or norm(completo) in nossos_nome):
                    pulados += 1
                    continue
                vistos.add(sq)
                sigla = (c.get("partido") or {}).get("sigla")
                sit, bens, sexo = None, None, None
                if not args.sem_bens:
                    try:
                        det = get(f"{BASE}/candidatura/buscar/{ANO}/{uf}/{eid}/candidato/{sq}")
                        sit = SITUACAO.get(
                            (det.get("descricaoSituacao") or "").upper().strip(), "pendente")
                        bens = det.get("totalDeBens")
                        # ATENCAO: o sexo so vem no DETALHE. Com --sem-bens ele
                        # fica nulo e o selo cai no masculino como neutro.
                        sexo = sexo_tse(det)
                    except Exception:
                        sit = "pendente"
                linhas.append((sq, urna, completo, rotulo, uf, sigla,
                               party_id(sigla), sit, bens, sexo))
            print(f"  {uf} {rotulo}: acumulado {len(linhas)} novos "
                  f"({pulados} já são nossos)")
            time.sleep(0.4)  # gentileza com a API

    execute_values(cur, """
        INSERT INTO candidato_novo_2026
          (sq_candidato, nome_urna, nome_completo, cargo, uf, partido_sigla,
           party_id, situacao, patrimonio_total, sexo)
        VALUES %s
        ON CONFLICT (sq_candidato) DO UPDATE SET
          nome_urna=EXCLUDED.nome_urna, nome_completo=EXCLUDED.nome_completo,
          cargo=EXCLUDED.cargo, uf=EXCLUDED.uf,
          partido_sigla=EXCLUDED.partido_sigla, party_id=EXCLUDED.party_id,
          situacao=EXCLUDED.situacao, patrimonio_total=EXCLUDED.patrimonio_total,
          sexo=COALESCE(EXCLUDED.sexo, candidato_novo_2026.sexo),
          atualizado_em=now()
    """, linhas, page_size=500)
    con.commit()

    # tira quem saiu da lista do TSE nesta rodada (candidatura cancelada)
    if linhas and not args.uf:
        cur.execute("DELETE FROM candidato_novo_2026 WHERE sq_candidato <> ALL(%s)",
                    ([l[0] for l in linhas],))
        if cur.rowcount:
            print(f"{cur.rowcount} candidatura(s) que sumiram do TSE foram removidas")
        con.commit()

    cur.close()
    con.close()
    print(f"\n{len(linhas)} candidatos sem histórico gravados em candidato_novo_2026.")
    print(f"{pulados} eram parlamentares que já estão no site (têm histórico).")


if __name__ == "__main__":
    main()

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


def get(url, tries=3):
    for i in range(tries):
        try:
            with urllib.request.urlopen(urllib.request.Request(
                    url, headers={"User-Agent": "EVPV/1.0"}), timeout=40) as r:
                return json.load(r)
        except Exception:
            if i == tries - 1:
                raise
            time.sleep(2 * (i + 1))


def norm(s):
    """Maiúsculas, sem acento, sem pontuação, espaços colapsados."""
    s = unicodedata.normalize("NFD", s or "")
    s = re.sub(r"[^A-Z ]", "", s.upper().encode("ascii", "ignore").decode())
    return re.sub(r" +", " ", s).strip()


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
                sit, bens = None, None
                if not args.sem_bens:
                    try:
                        det = get(f"{BASE}/candidatura/buscar/{ANO}/{uf}/{eid}/candidato/{sq}")
                        sit = SITUACAO.get(
                            (det.get("descricaoSituacao") or "").upper().strip(), "pendente")
                        bens = det.get("totalDeBens")
                    except Exception:
                        sit = "pendente"
                linhas.append((sq, urna, completo, rotulo, uf, sigla,
                               party_id(sigla), sit, bens))
            print(f"  {uf} {rotulo}: acumulado {len(linhas)} novos "
                  f"({pulados} já são nossos)")
            time.sleep(0.4)  # gentileza com a API

    execute_values(cur, """
        INSERT INTO candidato_novo_2026
          (sq_candidato, nome_urna, nome_completo, cargo, uf, partido_sigla,
           party_id, situacao, patrimonio_total)
        VALUES %s
        ON CONFLICT (sq_candidato) DO UPDATE SET
          nome_urna=EXCLUDED.nome_urna, nome_completo=EXCLUDED.nome_completo,
          cargo=EXCLUDED.cargo, uf=EXCLUDED.uf,
          partido_sigla=EXCLUDED.partido_sigla, party_id=EXCLUDED.party_id,
          situacao=EXCLUDED.situacao, patrimonio_total=EXCLUDED.patrimonio_total,
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

#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Períodos em que o parlamentar NÃO estava em exercício (licenças).

Por que isto existe
-------------------
A página do parlamentar mostra "faltou em X de Y votações". Sem este dado, um
deputado que se licenciou para ser ministro aparecia com 86% de ausência — o
que é falso: ele não faltou, estava legalmente afastado. Este script busca os
períodos de afastamento nas fontes oficiais e grava em `afastamento`; a view
`person_participation` desconta essas votações do denominador sozinha.

Fontes
------
Câmara: /deputados/{id}/historico  → histórico de situações com data
        (Exercício, Licença, Suplência, FIM_MANDATO...). Tudo que NÃO é
        "Exercício" vira um intervalo de afastamento.
Senado: /senador/{codigo}/licencas → licenças com DataInicio/DataFim.

ATENÇÃO (limite conhecido): a lista de licenças do Senado tem se mostrado
incompleta para afastamentos ministeriais. O script avisa quando encontra um
senador com um buraco longo de votações sem licença correspondente, para
conferência manual — não invente o dado, confira no portal do Senado.

Uso (na sua máquina, com internet e banco):
  export DATABASE_URL=postgresql://...      # string do POOLER (IPv4)
  python scripts/update_afastamentos.py
  python scripts/update_afastamentos.py --casa camara     # só uma casa
  python scripts/update_afastamentos.py --dry-run         # não grava, só lista
"""
import argparse, json, os, sys, time
from datetime import date, datetime, timedelta
import urllib.request

import psycopg2
from psycopg2.extras import execute_values

CAM = "https://dadosabertos.camara.leg.br/api/v2"
SEN = "https://legis.senado.leg.br/dadosabertos"
HOJE = date.today()


def get(url, tries=3, accept="application/json"):
    for i in range(tries):
        try:
            req = urllib.request.Request(
                url, headers={"User-Agent": "EVPV/1.0", "Accept": accept})
            with urllib.request.urlopen(req, timeout=40) as r:
                return json.load(r)
        except Exception:
            if i == tries - 1:
                raise
            time.sleep(2 * (i + 1))


def d(s):
    """'2023-09-13T00:00' ou '13/09/2023' -> date, tolerante a nulo."""
    if not s:
        return None
    s = str(s).strip()
    for fmt in ("%Y-%m-%dT%H:%M", "%Y-%m-%dT%H:%M:%S", "%Y-%m-%d", "%d/%m/%Y"):
        try:
            return datetime.strptime(s[:len(fmt) + 2] if "T" in fmt else s[:10], fmt).date()
        except ValueError:
            continue
    try:
        return datetime.fromisoformat(s.replace("Z", "")).date()
    except Exception:
        return None


def merge(intervalos):
    """Junta intervalos que se tocam. fim=None significa 'até hoje'."""
    if not intervalos:
        return []
    norm = sorted(((i, f or HOJE, m) for i, f, m in intervalos if i))
    out = [list(norm[0])]
    for ini, fim, mot in norm[1:]:
        if ini <= out[-1][1] + timedelta(days=1):
            if fim > out[-1][1]:
                out[-1][1] = fim
                out[-1][2] = out[-1][2] or mot
        else:
            out.append([ini, fim, mot])
    return [(i, (None if f >= HOJE else f), m) for i, f, m in out]


# ---------------------------------------------------------------- Câmara
def camara(external_id):
    """Intervalos em que o deputado NÃO estava em exercício."""
    try:
        hist = get(f"{CAM}/deputados/{external_id}/historico").get("dados", [])
    except Exception as e:
        print(f"    aviso: histórico indisponível ({e})")
        return []
    linhas = []
    for h in hist:
        dt = d(h.get("dataHora"))
        if dt:
            linhas.append((dt, (h.get("situacao") or "").strip(),
                           (h.get("descricaoStatus") or "").strip()))
    linhas.sort(key=lambda x: x[0])

    fora = []
    for idx, (dt, sit, desc) in enumerate(linhas):
        # "Exercício" (com ou sem acento) = estava lá. Qualquer outra coisa
        # (Licença, Suplência, FIM_MANDATO, Vacância) = não estava.
        em_exercicio = sit.lower().startswith("exerc")
        if em_exercicio:
            continue
        fim = linhas[idx + 1][0] - timedelta(days=1) if idx + 1 < len(linhas) else None
        # Linhas de metadado no início da legislatura ("Nome no início da
        # legislatura", situacao vazia) têm a mesma data da posse: o intervalo
        # sai invertido e não representa afastamento nenhum. Descarta.
        if fim is not None and fim < dt:
            continue
        fora.append((dt, fim, desc or sit or "fora de exercício"))
    return merge(fora)


# ---------------------------------------------------------------- Senado
def senado(external_id):
    try:
        js = get(f"{SEN}/senador/{external_id}/licencas")
    except Exception as e:
        print(f"    aviso: licenças indisponíveis ({e})")
        return []
    # a resposta vem aninhada e o nome do nó varia; procuramos as folhas
    achados = []

    def anda(no):
        if isinstance(no, dict):
            if "DataInicio" in no or "DataInicioPrevista" in no:
                ini = d(no.get("DataInicio") or no.get("DataInicioPrevista"))
                fim = d(no.get("DataFim") or no.get("DataFimPrevista"))
                mot = (no.get("DescricaoTipoAfastamento")
                       or no.get("SiglaTipoAfastamento") or "licença")
                if ini:
                    achados.append((ini, fim, mot))
            for v in no.values():
                anda(v)
        elif isinstance(no, list):
            for v in no:
                anda(v)

    anda(js)
    return merge(achados)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--casa", choices=["camara", "senado"])
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    dsn = os.environ.get("DATABASE_URL") or sys.exit("defina DATABASE_URL")

    con = psycopg2.connect(dsn)
    cur = con.cursor()
    cur.execute("""SELECT p.id, p.house, p.external_id, p.name
                     FROM person p
                    WHERE (%s IS NULL OR p.house = %s)
                    ORDER BY p.house, p.name""", (args.casa, args.casa))
    pessoas = cur.fetchall()
    print(f"{len(pessoas)} parlamentares a consultar\n")

    linhas, com_afast = [], 0
    for n, (pid, house, ext, nome) in enumerate(pessoas, 1):
        if not ext:
            continue
        fora = camara(ext) if house == "camara" else senado(ext)
        if fora:
            com_afast += 1
            for ini, fim, mot in fora:
                linhas.append((pid, ini, fim, mot[:300],
                               "Câmara /historico" if house == "camara"
                               else "Senado /licencas"))
            dias = sum(((f or HOJE) - i).days for i, f, _ in fora)
            print(f"  [{n}/{len(pessoas)}] {nome} ({house}): "
                  f"{len(fora)} afastamento(s), ~{dias} dias")
        if n % 25 == 0:
            print(f"  ... {n}/{len(pessoas)}")
        time.sleep(0.15)  # gentileza com as APIs

    print(f"\n{com_afast} parlamentares com afastamento; {len(linhas)} intervalos.")
    if args.dry_run:
        print("--dry-run: nada foi gravado.")
        return

    cur.execute("DELETE FROM afastamento")
    execute_values(cur, """
        INSERT INTO afastamento (person_id, inicio, fim, motivo, fonte)
        VALUES %s
        ON CONFLICT (person_id, inicio) DO UPDATE
          SET fim = EXCLUDED.fim, motivo = EXCLUDED.motivo,
              fonte = EXCLUDED.fonte, atualizado_em = now()
    """, linhas, page_size=500)
    con.commit()

    # A presenca vive numa tabela calculada: sem isto, o site continuaria
    # mostrando o numero antigo mesmo com as licencas ja gravadas.
    print("\nRecalculando a presenca...")
    cur.execute("SELECT recalcular_participacao()")
    print(f"  {cur.fetchone()[0]} parlamentares recalculados")
    cur.execute("SELECT marcar_confiabilidade()")
    cur.execute("SELECT count(*) FROM participacao_calc WHERE NOT confiavel")
    print(f"  {cur.fetchone()[0]} com dado NAO confiavel (o site esconde o %)")
    con.commit()

    # Conferência: quem continua com muita ausência DEPOIS do desconto?
    cur.execute("""
        SELECT pd.name, pd.house, pp.n_votes, pp.eligible, pp.votacoes_afastado
          FROM person_participation pp
          JOIN person_directory pd ON pd.id = pp.person_id
         WHERE pp.eligible >= 200
           AND pp.confiavel
           AND (pp.eligible - pp.n_votes)::numeric / pp.eligible > 0.5
         ORDER BY (pp.eligible - pp.n_votes)::numeric / pp.eligible DESC
         LIMIT 20""")
    print("\nAinda com mais de 50% de ausência DEPOIS de descontar licença:")
    for nome, casa, nv, el, af in cur.fetchall():
        print(f"  {nome} ({casa}): votou {nv} de {el} "
              f"({round(100*(el-nv)/el)}% ausência; {af} votações descontadas)")
    print("\nConfira esta lista antes de publicar: se alguém aqui teve licença "
          "que a API não registrou, o número segue injusto.")

    cur.close()
    con.close()


if __name__ == "__main__":
    main()

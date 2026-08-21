#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Diagnostico: descobrir por que o TSE respondeu 403.

Nao grava nada e nao precisa de banco. Faz uma unica chamada leve
(/eleicao/ordinarias) com varios conjuntos de cabecalho e diz qual passa.

  python scripts/testar_tse.py
"""
import json
import sys
import time
import urllib.error
import urllib.request

BASE = "https://divulgacandcontas.tse.jus.br/divulga/rest/v1"
URL = f"{BASE}/eleicao/ordinarias"

CHROME = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
          "(KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36")

VARIANTES = [
    ("1. como o script fazia (User-Agent EVPV/1.0)",
     {"User-Agent": "EVPV/1.0"}),
    ("2. sem nenhum cabecalho (padrao do Python)",
     {}),
    ("3. so User-Agent de navegador",
     {"User-Agent": CHROME}),
    ("4. navegador completo (UA + Accept + Referer)",
     {"User-Agent": CHROME,
      "Accept": "application/json, text/plain, */*",
      "Accept-Language": "pt-BR,pt;q=0.9,en;q=0.8",
      "Referer": "https://divulgacandcontas.tse.jus.br/divulga/"}),
]


def tentar(cabecalhos):
    req = urllib.request.Request(URL, headers=cabecalhos)
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            corpo = r.read()
            try:
                dados = json.loads(corpo)
                n = len(dados) if isinstance(dados, list) else 1
                return True, f"HTTP {r.status} — JSON com {n} eleicoes"
            except Exception:
                return False, f"HTTP {r.status} mas a resposta nao e JSON ({len(corpo)} bytes)"
    except urllib.error.HTTPError as e:
        return False, f"HTTP {e.code} {e.reason}"
    except urllib.error.URLError as e:
        return False, f"nao conectou: {e.reason}"
    except Exception as e:
        return False, f"{type(e).__name__}: {e}"


def main():
    print(f"Testando {URL}\n")
    passou = []
    for nome, cab in VARIANTES:
        ok, msg = tentar(cab)
        print(f"  [{'OK ' if ok else 'X  '}] {nome}")
        print(f"         {msg}")
        if ok:
            passou.append(nome)
        time.sleep(1.5)

    print()
    if passou:
        print("Pelo menos um conjunto passou:")
        for p in passou:
            print("   " + p)
        print("\nO ingest_tse_2026.py atualizado ja usa o conjunto 4. Rode:")
        print("   python scripts/ingest_tse_2026.py")
        return 0

    print("TODOS deram erro. Isso aponta para bloqueio de rede ou do lado do TSE,")
    print("nao para o cabecalho. Na ordem:")
    print("  1. desligue VPN / proxy corporativo e rode de novo;")
    print("  2. abra https://divulgacandcontas.tse.jus.br/divulga/ no navegador:")
    print("     se o site tambem nao abrir, o problema e do TSE ou da sua rede;")
    print("  3. se o site abre no navegador mas aqui nao, pode ser bloqueio por IP")
    print("     depois de muitas chamadas — espere 15-30 min e tente de novo;")
    print("  4. teste de outra rede (celular como roteador, por exemplo).")
    return 1


if __name__ == "__main__":
    sys.exit(main())

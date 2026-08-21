#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Diagnostico: descobrir por que o TSE responde 403.

Nao grava nada e nao precisa de banco. Faz uma chamada leve
(/eleicao/ordinarias) de varios jeitos diferentes e diz qual passa.

  python scripts/testar_tse.py
"""
import json
import sys
import time
import urllib.error
import urllib.request

try:
    import requests
except ImportError:
    requests = None

BASE = "https://divulgacandcontas.tse.jus.br/divulga/rest/v1"
URL = f"{BASE}/eleicao/ordinarias"
SITE = "https://divulgacandcontas.tse.jus.br/divulga/"

CHROME = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
          "(KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36")

NAVEGADOR = {
    "User-Agent": CHROME,
    "Accept": "application/json, text/plain, */*",
    "Accept-Language": "pt-BR,pt;q=0.9,en-US;q=0.8,en;q=0.7",
    "Referer": SITE,
    "Origin": "https://divulgacandcontas.tse.jus.br",
    "Connection": "keep-alive",
}


def resumo(dados):
    if isinstance(dados, list):
        return f"JSON com {len(dados)} eleicoes"
    return "JSON recebido"


def por_urllib(cabecalhos):
    try:
        req = urllib.request.Request(URL, headers=cabecalhos)
        with urllib.request.urlopen(req, timeout=30) as r:
            return True, f"HTTP {r.status} — {resumo(json.load(r))}"
    except urllib.error.HTTPError as e:
        return False, f"HTTP {e.code} {e.reason}"
    except urllib.error.URLError as e:
        return False, f"nao conectou: {e.reason}"
    except Exception as e:
        return False, f"{type(e).__name__}: {e}"


def por_requests(cabecalhos, aquecer):
    if requests is None:
        return False, "biblioteca 'requests' nao instalada (pip install requests)"
    try:
        s = requests.Session()
        s.headers.update(cabecalhos)
        aviso = ""
        if aquecer:
            try:
                h = s.get(SITE, timeout=30)
                aviso = f" [home {h.status_code}, {len(s.cookies)} cookie(s)]"
            except Exception as e:
                aviso = f" [home falhou: {type(e).__name__}]"
        r = s.get(URL, timeout=30)
        if r.status_code == 200:
            try:
                return True, f"HTTP 200 — {resumo(r.json())}{aviso}"
            except Exception:
                return False, f"HTTP 200 mas nao veio JSON ({len(r.content)} bytes){aviso}"
        return False, f"HTTP {r.status_code}{aviso}"
    except Exception as e:
        return False, f"{type(e).__name__}: {e}"


VARIANTES = [
    ("1. urllib, User-Agent EVPV/1.0 (como era antes)",
     lambda: por_urllib({"User-Agent": "EVPV/1.0"})),
    ("2. urllib, sem cabecalho nenhum",
     lambda: por_urllib({})),
    ("3. urllib, cabecalho de navegador",
     lambda: por_urllib(NAVEGADOR)),
    ("4. requests, cabecalho de navegador",
     lambda: por_requests(NAVEGADOR, aquecer=False)),
    ("5. requests, sessao aquecida na home (e o que o ingest usa)",
     lambda: por_requests(NAVEGADOR, aquecer=True)),
]


def main():
    print(f"Testando {URL}\n")
    passou = []
    for nome, fn in VARIANTES:
        ok, msg = fn()
        print(f"  [{'OK ' if ok else 'X  '}] {nome}")
        print(f"         {msg}")
        if ok:
            passou.append(nome)
        time.sleep(1.5)

    print()
    if passou:
        print("Passaram:")
        for p in passou:
            print("   " + p)
        if any(p.startswith(("4.", "5.")) for p in passou):
            print("\nO ingest ja usa esse caminho. Pode rodar:")
            print("   python scripts/ingest_tse_2026.py")
        else:
            print("\nSo o urllib passou — me avise qual numero, porque o ingest")
            print("tenta requests primeiro e cai no urllib depois; deve funcionar.")
        return 0

    print("TODAS falharam. Na ordem, o que verificar:")
    print("  1. Abra no navegador:")
    print("     " + URL)
    print("     Se ABRIR e mostrar JSON, o TSE esta bloqueando cliente automatizado")
    print("     (fingerprint de TLS). Nesse caso nao ha ajuste de cabecalho que")
    print("     resolva; costuma passar sozinho depois de algumas horas.")
    print("  2. Se NAO abrir nem no navegador, o problema e a sua rede ou o TSE.")
    print("     Desligue VPN/proxy e teste de outra conexao.")
    print("  3. Rode este mesmo teste pelo GitHub Actions para comparar de outro IP.")
    return 1


if __name__ == "__main__":
    sys.exit(main())

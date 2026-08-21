#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Cliente HTTP compartilhado para a API DivulgaCandContas do TSE.

Por que este arquivo existe: em 21/08/2026 o TSE passou a responder 403 tanto
da maquina de casa quanto do runner do GitHub, enquanto a mesma URL aberta por
um navegador devolvia JSON normal. Ou seja, o bloqueio nao e por IP nem por
endpoint — e pelo formato do pedido.

Em 21/08 o diagnostico mostrou que ate a HOME em HTML (/divulga/) volta 403
para o runner — 0 cookies. Nao e filtro de cabecalho nem de cookie: o host
recusa o cliente inteiro. Cabecalho de navegador com biblioteca Python nao
resolve porque o aperto de mao TLS do OpenSSL tem uma assinatura (JA3)
diferente da de um Chrome de verdade, e da para bloquear so por isso.

Por isso a primeira estrategia usa curl_cffi, que reproduz o handshake do
Chrome. As outras ficam como reserva, para o caso de o bloqueio mudar.

Ordem das tentativas:

  0. curl_cffi com impersonate="chrome" (assinatura TLS de Chrome real).
  1. requests com SESSAO AQUECIDA: abre a home antes, para carregar o cookie
     que um WAF costuma exigir.
  2. requests sem aquecer, so com cabecalho de navegador.
  3. urllib com cabecalho de navegador (ultimo recurso, sem cookie).

Se nada passar, levanta SystemExit com uma explicacao em portugues em vez de
despejar traceback.
"""
import json
import time
import urllib.error
import urllib.request

try:
    import requests
except ImportError:  # o requirements ja pede requests, mas nao custa
    requests = None

try:
    from curl_cffi import requests as curl_requests
except ImportError:
    curl_requests = None

SITE = "https://divulgacandcontas.tse.jus.br/divulga/"

CHROME = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
          "(KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36")

CABECALHOS = {
    "User-Agent": CHROME,
    "Accept": "application/json, text/plain, */*",
    "Accept-Language": "pt-BR,pt;q=0.9,en-US;q=0.8,en;q=0.7",
    "Referer": SITE,
    "Origin": "https://divulgacandcontas.tse.jus.br",
    "Connection": "keep-alive",
}

_sessao = None
_aquecida = False


def sessao(aquecer=True):
    """Sessao unica do processo, para os cookies durarem entre as chamadas."""
    global _sessao, _aquecida
    if requests is None:
        return None
    if _sessao is None:
        _sessao = requests.Session()
        _sessao.headers.update(CABECALHOS)
    if aquecer and not _aquecida:
        _aquecida = True
        try:
            _sessao.get(SITE, timeout=30)
        except Exception:
            pass  # se a home falhar, ainda tentamos a API
    return _sessao


_sessao_curl = None


def _via_curl_cffi(url, tries):
    """Chrome de verdade no aperto de mao TLS. E o unico caminho que resolve
    bloqueio por assinatura de cliente."""
    global _sessao_curl
    if curl_requests is None:
        return None, "curl_cffi nao instalado (pip install curl_cffi)"
    if _sessao_curl is None:
        try:
            _sessao_curl = curl_requests.Session(impersonate="chrome")
            _sessao_curl.headers.update(CABECALHOS)
            try:
                _sessao_curl.get(SITE, timeout=30)  # aquece: pega cookie do WAF
            except Exception:
                pass
        except Exception as e:
            return None, f"nao abriu sessao: {type(e).__name__}: {e}"
    for i in range(tries):
        try:
            r = _sessao_curl.get(url, timeout=40)
            if r.status_code == 200:
                return r.json(), None
            if r.status_code == 403:
                return None, "HTTP 403"
            if r.status_code in (429, 500, 502, 503, 504) and i < tries - 1:
                time.sleep(3 * (i + 1))
                continue
            return None, f"HTTP {r.status_code}"
        except Exception as e:
            if i == tries - 1:
                return None, f"{type(e).__name__}: {e}"
            time.sleep(2 * (i + 1))
    return None, "sem resposta"


def _via_requests(url, tries, aquecer):
    s = sessao(aquecer=aquecer)
    if s is None:
        return None, "requests nao instalado"
    for i in range(tries):
        try:
            r = s.get(url, timeout=40)
            if r.status_code == 200:
                return r.json(), None
            if r.status_code == 403:
                return None, "HTTP 403"
            if r.status_code in (429, 500, 502, 503, 504) and i < tries - 1:
                time.sleep(3 * (i + 1))
                continue
            return None, f"HTTP {r.status_code}"
        except Exception as e:
            if i == tries - 1:
                return None, f"{type(e).__name__}: {e}"
            time.sleep(2 * (i + 1))
    return None, "sem resposta"


def _via_urllib(url, tries):
    for i in range(tries):
        try:
            req = urllib.request.Request(url, headers=CABECALHOS)
            with urllib.request.urlopen(req, timeout=40) as r:
                return json.load(r), None
        except urllib.error.HTTPError as e:
            if e.code == 403:
                return None, "HTTP 403"
            if e.code in (429, 500, 502, 503, 504) and i < tries - 1:
                time.sleep(3 * (i + 1))
                continue
            return None, f"HTTP {e.code}"
        except Exception as e:
            if i == tries - 1:
                return None, f"{type(e).__name__}: {e}"
            time.sleep(2 * (i + 1))
    return None, "sem resposta"


def get(url, tries=3):
    motivos = []
    for rotulo, fn in (
        ("curl_cffi (TLS de Chrome)", lambda: _via_curl_cffi(url, tries)),
        ("requests com sessao aquecida", lambda: _via_requests(url, tries, True)),
        ("requests sem aquecer", lambda: _via_requests(url, tries, False)),
        ("urllib", lambda: _via_urllib(url, tries)),
    ):
        dados, erro = fn()
        if erro is None:
            return dados
        motivos.append(f"{rotulo}: {erro}")

    raise SystemExit(
        "\nNao consegui falar com o TSE. O que cada tentativa devolveu:\n  " +
        "\n  ".join(motivos) +
        "\n\nURL: " + url +
        "\n\nSe todas deram 403, inclusive a do curl_cffi, o bloqueio nao e de"
        "\ncabecalho nem de TLS — e do endereco de onde o pedido sai."
        "\nRode 'python scripts/testar_tse.py' para o quadro completo.\n")

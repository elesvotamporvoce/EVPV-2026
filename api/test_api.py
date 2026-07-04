"""
Testes da API sem banco: substituímos as funções de api.db por fixtures e
exercitamos roteamento + serialização (modelos Pydantic) via TestClient.

Rodar:
  pip install fastapi httpx
  python api/test_api.py        # (ou: pytest api/test_api.py)
"""

from fastapi.testclient import TestClient

import api.db as db
from api.main import app

client = TestClient(app)


# ---- Fixtures (substituem o acesso ao banco) ----------------------------
def _install_fakes():
    db.list_people = lambda house=None, uf=None, party=None, limit=100, offset=0: [
        {"id": 1, "house": "camara", "external_id": "66179", "name": "Norma Ayub",
         "uf": "ES", "party": "PL", "photo_url": "http://x/66179.jpg"},
        {"id": 2, "house": "camara", "external_id": "204521", "name": "Fulano",
         "uf": "SP", "party": "PT", "photo_url": None},
    ]
    db.get_person = lambda pid: (
        {"id": 1, "house": "camara", "external_id": "66179", "name": "Norma Ayub",
         "uf": "ES", "party": "PL", "photo_url": None, "email": None}
        if pid == 1 else None)
    db.person_stats = lambda pid: {"votes_cast": 120, "votes_attended": 110, "rebellions": 4}
    db.person_scores = lambda pid: [
        {"policy_id": 1, "policy_name": "Pauta ambiental", "score": 91.5,
         "category": "for2", "n_divisions": 8}]

    db.list_divisions = lambda house=None, start=None, end=None, limit=100, offset=0: [
        {"id": 10, "house": "camara", "external_id": "2265603-43",
         "occurred_at": "2020-12-22T23:35:42", "body": "PLEN",
         "description": "Aprovada a Redação Final.", "result_approved": True,
         "is_nominal": True}]
    db.get_division = lambda did: (
        {"id": 10, "house": "camara", "external_id": "2265603-43",
         "occurred_at": "2020-12-22T23:35:42", "body": "PLEN",
         "description": "Aprovada a Redação Final.", "result_approved": True,
         "is_nominal": True, "is_secret": False, "prop_sigla": "PL",
         "prop_numero": "4162", "prop_ano": "2019", "prop_ementa": "..."}
        if did == 10 else None)
    db.division_votes = lambda did: [
        {"person_id": 1, "name": "Norma Ayub", "party": "PL", "uf": "ES", "option": "nao"}]
    db.division_orientations = lambda did: [
        {"name": "PT", "leadership_type": "P", "orientation": "nao"},
        {"name": "Governo", "leadership_type": "B", "orientation": "nao"}]
    db.division_tally = lambda did: [
        {"party": "PT", "sim_count": 2, "nao_count": 1, "abstencao_count": 0,
         "obstrucao_count": 0, "ausente_count": 0, "majority_option": "sim"}]

    db.list_policies = lambda: [
        {"id": 1, "name": "Pauta ambiental", "description": "...", "provisional": True}]
    db.get_policy = lambda pid: (
        {"id": 1, "name": "Pauta ambiental", "description": "...", "provisional": True}
        if pid == 1 else None)
    db.policy_people = lambda pid: [
        {"person_id": 1, "name": "Norma Ayub", "uf": "ES", "party": "PL",
         "score": 91.5, "category": "for2", "n_divisions": 8}]

    db.list_parties = lambda: [{"id": 1, "sigla": "PT", "name": "Partido dos Trabalhadores"}]
    db.get_party = lambda pid: (
        {"id": 1, "sigla": "PT", "name": "Partido dos Trabalhadores"} if pid == 1 else None)
    db.party_scores = lambda pid: [
        {"policy_id": 1, "policy_name": "Pauta ambiental", "avg_score": 88.0, "n_people": 60}]


_install_fakes()


# ---- Testes --------------------------------------------------------------
def test_health():
    assert client.get("/health").json() == {"status": "ok"}


def test_people_list():
    r = client.get("/api/v1/people?house=camara&uf=ES")
    assert r.status_code == 200
    data = r.json()
    assert data[0]["name"] == "Norma Ayub" and data[0]["party"] == "PL"


def test_person_detail_merges_stats_and_scores():
    r = client.get("/api/v1/people/1")
    assert r.status_code == 200
    d = r.json()
    assert d["rebellions"] == 4 and d["votes_attended"] == 110
    assert d["policy_comparisons"][0]["category"] == "for2"


def test_person_404():
    assert client.get("/api/v1/people/999").status_code == 404


def test_division_detail_has_votes_orientations_tally():
    r = client.get("/api/v1/divisions/10")
    assert r.status_code == 200
    d = r.json()
    assert d["votes"][0]["option"] == "nao"
    assert any(o["name"] == "Governo" for o in d["orientations"])
    assert d["party_tally"][0]["majority_option"] == "sim"


def test_policy_detail():
    d = client.get("/api/v1/policies/1").json()
    assert d["people_comparisons"][0]["score"] == 91.5


def test_party_detail():
    d = client.get("/api/v1/parties/1").json()
    assert d["sigla"] == "PT"
    assert d["policy_comparisons"][0]["avg_score"] == 88.0


def test_representatives_by_uf():
    r = client.get("/api/v1/representatives?uf=es")
    assert r.status_code == 200
    d = r.json()
    assert d["uf"] == "ES" and len(d["deputados"]) >= 1


def test_openapi_lists_expected_paths():
    paths = client.get("/openapi.json").json()["paths"]
    for p in ["/api/v1/people", "/api/v1/people/{person_id}",
              "/api/v1/divisions", "/api/v1/divisions/{division_id}",
              "/api/v1/policies", "/api/v1/parties",
              "/api/v1/representatives"]:
        assert p in paths, f"faltou {p}"


def test_api_key_enforced_when_configured(monkeypatch=None):
    import os
    os.environ["API_KEYS"] = "segredo123"
    try:
        assert client.get("/api/v1/people").status_code == 401
        ok = client.get("/api/v1/people", headers={"X-API-Key": "segredo123"})
        assert ok.status_code == 200
    finally:
        del os.environ["API_KEYS"]


if __name__ == "__main__":
    fns = [v for k, v in sorted(globals().items()) if k.startswith("test_")]
    passed = 0
    for fn in fns:
        fn()
        print(f"  ✓ {fn.__name__}")
        passed += 1
    print(f"\n✅ {passed}/{len(fns)} testes da API passaram.")

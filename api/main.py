"""
API REST — Eles Votam Por Você (FastAPI)

Espelha a lógica do TheyVoteForYou: pessoas, votações, políticas, partidos e
"encontre seu representante". Documentação automática em /docs (Swagger) e
/openapi.json.

Rodar:
  export DATABASE_URL="postgresql://user:pass@localhost:5432/evpv"
  uvicorn api.main:app --reload
"""

from typing import Optional, List

from fastapi import FastAPI, HTTPException, Query, Header, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from . import db

import os

app = FastAPI(
    title="Eles Votam Por Você — API",
    version="0.1.0",
    description="Como cada parlamentar (e cada partido) vota no Congresso Nacional.",
)

# CORS liberado (dados públicos). Restrinja em produção se quiser.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], allow_methods=["GET"], allow_headers=["*"],
)


# ---- Chave de API (opcional) --------------------------------------------
def require_key(x_api_key: Optional[str] = Header(default=None)):
    """
    Se a env API_KEYS estiver definida (lista separada por vírgula), exige
    o header X-API-Key. Se não estiver definida, a API é aberta (dev).
    """
    allowed = os.environ.get("API_KEYS")
    if not allowed:
        return
    if x_api_key not in {k.strip() for k in allowed.split(",") if k.strip()}:
        raise HTTPException(status_code=401, detail="Chave de API inválida ou ausente")


# ---- Modelos de resposta -------------------------------------------------
class Person(BaseModel):
    id: int
    house: str
    name: str
    uf: Optional[str] = None
    party: Optional[str] = None
    photo_url: Optional[str] = None


class PolicyComparison(BaseModel):
    policy_id: int
    policy_name: Optional[str] = None
    score: Optional[float] = None
    category: Optional[str] = None
    n_divisions: Optional[int] = None


class PersonDetail(Person):
    email: Optional[str] = None
    votes_cast: int = 0
    votes_attended: int = 0
    rebellions: int = 0
    policy_comparisons: List[PolicyComparison] = []


class DivisionSummary(BaseModel):
    id: int
    house: str
    external_id: str
    occurred_at: Optional[str] = None
    body: Optional[str] = None
    description: Optional[str] = None
    result_approved: Optional[bool] = None
    is_nominal: bool = False


class VoteItem(BaseModel):
    person_id: int
    name: Optional[str] = None
    party: Optional[str] = None
    uf: Optional[str] = None
    option: str


class OrientationItem(BaseModel):
    name: Optional[str] = None
    leadership_type: Optional[str] = None
    orientation: Optional[str] = None


class TallyItem(BaseModel):
    party: Optional[str] = None
    sim_count: int = 0
    nao_count: int = 0
    abstencao_count: int = 0
    obstrucao_count: int = 0
    ausente_count: int = 0
    majority_option: Optional[str] = None


class DivisionDetail(DivisionSummary):
    is_secret: bool = False
    prop_sigla: Optional[str] = None
    prop_numero: Optional[str] = None
    prop_ano: Optional[str] = None
    prop_ementa: Optional[str] = None
    votes: List[VoteItem] = []
    orientations: List[OrientationItem] = []
    party_tally: List[TallyItem] = []


class Policy(BaseModel):
    id: int
    name: str
    description: Optional[str] = None
    provisional: bool = True


class PolicyPerson(BaseModel):
    person_id: int
    name: Optional[str] = None
    uf: Optional[str] = None
    party: Optional[str] = None
    score: Optional[float] = None
    category: Optional[str] = None
    n_divisions: Optional[int] = None


class PolicyDetail(Policy):
    people_comparisons: List[PolicyPerson] = []


class Party(BaseModel):
    id: int
    sigla: str
    name: Optional[str] = None


class PartyPolicyScore(BaseModel):
    policy_id: int
    policy_name: Optional[str] = None
    avg_score: Optional[float] = None
    n_people: Optional[int] = None


class PartyDetail(Party):
    policy_comparisons: List[PartyPolicyScore] = []


class Representatives(BaseModel):
    uf: str
    deputados: List[Person] = []
    senadores: List[Person] = []


# ---- Rotas ---------------------------------------------------------------
API = "/api/v1"


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get(f"{API}/people", response_model=List[Person], dependencies=[Depends(require_key)])
def people(house: Optional[str] = Query(None, pattern="^(camara|senado)$"),
           uf: Optional[str] = None, party: Optional[str] = None,
           limit: int = Query(100, le=500), offset: int = 0):
    return db.list_people(house, uf, party, limit, offset)


@app.get(f"{API}/people/{{person_id}}", response_model=PersonDetail,
         dependencies=[Depends(require_key)])
def person(person_id: int):
    p = db.get_person(person_id)
    if not p:
        raise HTTPException(404, "Pessoa não encontrada")
    stats = db.person_stats(person_id) or {}
    return {**p,
            "votes_cast": stats.get("votes_cast", 0),
            "votes_attended": stats.get("votes_attended", 0),
            "rebellions": stats.get("rebellions", 0),
            "policy_comparisons": db.person_scores(person_id)}


@app.get(f"{API}/divisions", response_model=List[DivisionSummary],
         dependencies=[Depends(require_key)])
def divisions(house: Optional[str] = Query(None, pattern="^(camara|senado)$"),
              start_date: Optional[str] = None, end_date: Optional[str] = None,
              limit: int = Query(100, le=500), offset: int = 0):
    return db.list_divisions(house, start_date, end_date, limit, offset)


@app.get(f"{API}/divisions/{{division_id}}", response_model=DivisionDetail,
         dependencies=[Depends(require_key)])
def division(division_id: int):
    d = db.get_division(division_id)
    if not d:
        raise HTTPException(404, "Votação não encontrada")
    return {**d,
            "votes": db.division_votes(division_id),
            "orientations": db.division_orientations(division_id),
            "party_tally": db.division_tally(division_id)}


@app.get(f"{API}/policies", response_model=List[Policy],
         dependencies=[Depends(require_key)])
def policies():
    return db.list_policies()


@app.get(f"{API}/policies/{{policy_id}}", response_model=PolicyDetail,
         dependencies=[Depends(require_key)])
def policy(policy_id: int):
    p = db.get_policy(policy_id)
    if not p:
        raise HTTPException(404, "Política não encontrada")
    return {**p, "people_comparisons": db.policy_people(policy_id)}


@app.get(f"{API}/parties", response_model=List[Party],
         dependencies=[Depends(require_key)])
def parties():
    return db.list_parties()


@app.get(f"{API}/parties/{{party_id}}", response_model=PartyDetail,
         dependencies=[Depends(require_key)])
def party(party_id: int):
    p = db.get_party(party_id)
    if not p:
        raise HTTPException(404, "Partido não encontrado")
    return {**p, "policy_comparisons": db.party_scores(party_id)}


@app.get(f"{API}/representatives", response_model=Representatives,
         dependencies=[Depends(require_key)])
def representatives(uf: str = Query(..., min_length=2, max_length=2)):
    """Encontre seus representantes por estado (UF): deputados + senadores."""
    uf = uf.upper()
    return {"uf": uf,
            "deputados": db.list_people(house="camara", uf=uf, limit=500),
            "senadores": db.list_people(house="senado", uf=uf, limit=500)}

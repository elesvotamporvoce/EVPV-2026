"""
Camada de acesso a dados da API (Postgres).
As funções retornam dicts (RealDictCursor) e são o único ponto que fala com o
banco — o que torna fácil testar as rotas com estas funções "mockadas".
psycopg2 é importado de forma tardia para o app poder ser importado sem o driver
(útil em testes que substituem estas funções).
"""

import os
from contextlib import contextmanager

_pool = None


def init_pool(dsn=None):
    global _pool
    if _pool is not None:
        return
    from psycopg2.pool import ThreadedConnectionPool
    dsn = dsn or os.environ.get("DATABASE_URL")
    if not dsn:
        raise RuntimeError("DATABASE_URL não definido")
    _pool = ThreadedConnectionPool(1, 10, dsn)


@contextmanager
def _cursor():
    from psycopg2.extras import RealDictCursor
    init_pool()
    conn = _pool.getconn()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            yield cur
        conn.commit()
    finally:
        _pool.putconn(conn)


def _all(sql, params=None):
    with _cursor() as cur:
        cur.execute(sql, params or {})
        return cur.fetchall()


def _one(sql, params=None):
    with _cursor() as cur:
        cur.execute(sql, params or {})
        return cur.fetchone()


# CTE reutilizável: partido ATUAL = partido do voto mais recente da pessoa.
# (Enquanto party_membership não é curado, derivamos do último voto.)
_CURRENT_PARTY_JOIN = """
LEFT JOIN LATERAL (
    SELECT v.party_id
    FROM vote v JOIN division d ON d.id = v.division_id
    WHERE v.person_id = p.id AND v.party_id IS NOT NULL
    ORDER BY d.occurred_at DESC NULLS LAST
    LIMIT 1
) cp ON TRUE
LEFT JOIN party cpt ON cpt.id = cp.party_id
"""


# ---- Pessoas -------------------------------------------------------------
def list_people(house=None, uf=None, party=None, limit=100, offset=0):
    sql = f"""
        SELECT p.id, p.house, p.external_id, p.name, p.uf, p.photo_url,
               cpt.sigla AS party
        FROM person p
        {_CURRENT_PARTY_JOIN}
        WHERE (%(house)s IS NULL OR p.house = %(house)s)
          AND (%(uf)s   IS NULL OR p.uf = %(uf)s)
          AND (%(party)s IS NULL OR cpt.sigla = %(party)s)
        ORDER BY p.name
        LIMIT %(limit)s OFFSET %(offset)s
    """
    return _all(sql, {"house": house, "uf": uf, "party": party,
                      "limit": limit, "offset": offset})


def get_person(person_id):
    sql = f"""
        SELECT p.id, p.house, p.external_id, p.name, p.uf, p.photo_url, p.email,
               cpt.sigla AS party
        FROM person p
        {_CURRENT_PARTY_JOIN}
        WHERE p.id = %(id)s
    """
    return _one(sql, {"id": person_id})


def person_stats(person_id):
    """votos dados/decisivos e nº de rebeliões (voto contra a orientação do partido)."""
    return _one(
        """
        SELECT
          (SELECT count(*) FROM vote WHERE person_id = %(id)s) AS votes_cast,
          (SELECT count(*) FROM vote WHERE person_id = %(id)s
             AND option IN ('sim','nao')) AS votes_attended,
          (SELECT count(*) FROM vote v
             JOIN party_orientation o
               ON o.division_id = v.division_id AND o.party_id = v.party_id
            WHERE v.person_id = %(id)s
              AND v.option IN ('sim','nao')
              AND o.orientation IN ('sim','nao')
              AND o.orientation <> v.option) AS rebellions
        """,
        {"id": person_id},
    )


def person_scores(person_id):
    return _all(
        """
        SELECT a.policy_id, pol.name AS policy_name,
               a.score, a.category, a.n_divisions
        FROM agreement_score a JOIN policy pol ON pol.id = a.policy_id
        WHERE a.person_id = %(id)s
        ORDER BY a.score DESC NULLS LAST
        """,
        {"id": person_id},
    )


# ---- Votações ------------------------------------------------------------
def list_divisions(house=None, start=None, end=None, limit=100, offset=0):
    return _all(
        """
        SELECT id, house, external_id, occurred_at, body,
               description, result_approved, is_nominal
        FROM division
        WHERE (%(house)s IS NULL OR house = %(house)s)
          AND (%(start)s IS NULL OR occurred_at >= %(start)s)
          AND (%(end)s   IS NULL OR occurred_at <= %(end)s)
        ORDER BY occurred_at DESC NULLS LAST
        LIMIT %(limit)s OFFSET %(offset)s
        """,
        {"house": house, "start": start, "end": end,
         "limit": limit, "offset": offset},
    )


def get_division(division_id):
    return _one(
        """
        SELECT d.id, d.house, d.external_id, d.occurred_at, d.body,
               d.description, d.result_approved, d.is_nominal, d.is_secret,
               pr.sigla AS prop_sigla, pr.numero AS prop_numero,
               pr.ano AS prop_ano, pr.ementa AS prop_ementa
        FROM division d
        LEFT JOIN proposition pr ON pr.id = d.proposition_id
        WHERE d.id = %(id)s
        """,
        {"id": division_id},
    )


def division_votes(division_id):
    return _all(
        """
        SELECT v.person_id, pe.name, pt.sigla AS party, pe.uf, v.option
        FROM vote v
        JOIN person pe ON pe.id = v.person_id
        LEFT JOIN party pt ON pt.id = v.party_id
        WHERE v.division_id = %(id)s
        ORDER BY pe.name
        """,
        {"id": division_id},
    )


def division_orientations(division_id):
    return _all(
        """
        SELECT COALESCE(pt.sigla, o.bloc_name) AS name,
               o.leadership_type, o.orientation
        FROM party_orientation o
        LEFT JOIN party pt ON pt.id = o.party_id
        WHERE o.division_id = %(id)s
        ORDER BY name
        """,
        {"id": division_id},
    )


def division_tally(division_id):
    return _all(
        """
        SELECT pt.sigla AS party, t.sim_count, t.nao_count,
               t.abstencao_count, t.obstrucao_count, t.ausente_count,
               t.majority_option
        FROM party_vote_tally t
        JOIN party pt ON pt.id = t.party_id
        WHERE t.division_id = %(id)s
        ORDER BY pt.sigla
        """,
        {"id": division_id},
    )


# ---- Políticas -----------------------------------------------------------
def list_policies():
    return _all("SELECT id, name, description, provisional FROM policy ORDER BY name")


def get_policy(policy_id):
    return _one(
        "SELECT id, name, description, provisional FROM policy WHERE id = %(id)s",
        {"id": policy_id},
    )


def policy_people(policy_id):
    return _all(
        """
        SELECT a.person_id, pe.name, pe.uf, pt.sigla AS party,
               a.score, a.category, a.n_divisions
        FROM agreement_score a
        JOIN person pe ON pe.id = a.person_id
        LEFT JOIN party_membership pm ON pm.person_id = pe.id AND pm.end_date IS NULL
        LEFT JOIN party pt ON pt.id = pm.party_id
        WHERE a.policy_id = %(id)s
        ORDER BY a.score DESC NULLS LAST
        """,
        {"id": policy_id},
    )


# ---- Partidos ------------------------------------------------------------
def list_parties():
    return _all("SELECT id, sigla, name FROM party ORDER BY sigla")


def get_party(party_id):
    return _one("SELECT id, sigla, name FROM party WHERE id = %(id)s", {"id": party_id})


def party_scores(party_id):
    """Concordância média do partido por política (view party_agreement)."""
    return _all(
        """
        SELECT pa.policy_id, pol.name AS policy_name, pa.avg_score, pa.n_people
        FROM party_agreement pa
        JOIN policy pol ON pol.id = pa.policy_id
        WHERE pa.party_id = %(id)s
        ORDER BY pa.avg_score DESC NULLS LAST
        """,
        {"id": party_id},
    )

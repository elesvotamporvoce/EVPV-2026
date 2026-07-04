#!/usr/bin/env python3
"""
Motor de "agreement score" — Eles Votam Por Você

Calcula, para cada (pessoa, política/tema), o quanto a pessoa votou de acordo
com a política, e traduz num rótulo em linguagem simples ("votou consistentemente
a favor"). Grava em `agreement_score`. Uma VIEW (db/views_agreement.sql) agrega
isso por partido.

METODOLOGIA (transparente e AJUSTÁVEL — veja as constantes abaixo)
-----------------------------------------------------------------
Inspirada no método do Public Whip / TheyVoteForYou, mas com pesos e limiares
NOSSOS, explícitos e configuráveis. NÃO é uma cópia bit-a-bit do algoritmo do
TVFY — para paridade exata, porte a implementação open-source deles e confira.

Para cada votação (division) ligada à política:
  - a política define uma POSTURA (`stance`): 'for' = votar SIM apoia a política;
    'against' = votar NÃO apoia a política.
  - a política marca a votação como 'normal' ou 'strong' (voto forte pesa mais).
  - o voto da pessoa é decisivo (sim/não) ou não-decisivo (abstenção, obstrução,
    ausência) — não-decisivo entra com peso reduzido e valor "neutro".

Acumulamos numerador/denominador ponderados e score = 100 * num/den.

Uso:
  python score.py --self-test          # testa a lógica pura (sem banco)
  export DATABASE_URL=postgresql://...
  python score.py                      # recalcula todas as políticas
  python score.py --policy 3           # recalcula só a política 3
"""

import argparse
import os
import sys

# ---- Constantes AJUSTÁVEIS da metodologia -------------------------------
WEIGHT = {"normal": 10, "strong": 25}   # voto forte pesa mais
ABSENCE_FACTOR = 0.20                    # ausência/abstenção entra com 20% do peso
ABSENCE_CREDIT = 0.50                    # e vale como "neutro" (meio-termo)
MIN_ATTENDED = 2                         # menos que isso -> 'sem dados suficientes'

# votos decisivos; o resto (abstenção, obstrução, ausente, outro, artigo17)
# é tratado como não-decisivo ("absent")
DECISIVE = {"sim", "nao"}

# limiares score->categoria (0..100). Ajustáveis; espelham os 8 rótulos do TVFY.
CATEGORY_LABELS = {
    "for3":      "votou consistentemente a favor",
    "for2":      "votou quase sempre a favor",
    "for1":      "votou geralmente a favor",
    "mixture":   "votou uma mistura de a favor e contra",
    "against1":  "votou geralmente contra",
    "against2":  "votou quase sempre contra",
    "against3":  "votou consistentemente contra",
    "not_enough": "sem votos suficientes para uma conclusão",
}


# ---- Lógica pura (testável sem banco) -----------------------------------
def alignment(option, stance):
    """Retorna 'agree', 'disagree' ou 'absent' para um voto ante uma postura."""
    if option not in DECISIVE:
        return "absent"
    is_yes = option == "sim"
    if stance == "for":
        return "agree" if is_yes else "disagree"
    else:  # 'against'
        return "agree" if (not is_yes) else "disagree"


def agreement_from_comparisons(comparisons):
    """
    comparisons: iterável de (stance, strength, option).
    Retorna (score_0_100 | None, attended) onde attended = nº de votos decisivos.
    """
    num = den = 0.0
    attended = 0
    for stance, strength, option in comparisons:
        w = WEIGHT.get(strength, WEIGHT["normal"])
        a = alignment(option, stance)
        if a == "agree":
            num += w
            den += w
            attended += 1
        elif a == "disagree":
            den += w
            attended += 1
        else:  # absent / não-decisivo
            aw = w * ABSENCE_FACTOR
            num += aw * ABSENCE_CREDIT
            den += aw
    if den == 0:
        return None, 0
    return 100.0 * num / den, attended


def categorize(score, attended):
    """Traduz (score, attended) para um código de categoria."""
    if score is None or attended < MIN_ATTENDED:
        return "not_enough"
    if score >= 95:
        return "for3"
    if score >= 85:
        return "for2"
    if score >= 60:
        return "for1"
    if score > 40:
        return "mixture"
    if score > 15:
        return "against1"
    if score > 5:
        return "against2"
    return "against3"


# ---- Glue de banco -------------------------------------------------------
def load_policies(cur):
    """policy_id -> lista de (division_id, stance, strength)."""
    cur.execute("SELECT policy_id, division_id, stance, strength FROM policy_division")
    policies = {}
    for pid, did, stance, strength in cur.fetchall():
        policies.setdefault(pid, []).append((did, stance, strength))
    return policies


def votes_for_divisions(cur, division_ids):
    """(person_id, division_id) -> option, para as votações dadas."""
    if not division_ids:
        return {}
    cur.execute(
        "SELECT person_id, division_id, option FROM vote WHERE division_id = ANY(%s)",
        (list(division_ids),),
    )
    out = {}
    for person_id, division_id, option in cur.fetchall():
        out.setdefault(person_id, {})[division_id] = option
    return out


def compute_policy(cur, policy_id, divisions):
    """Calcula e grava agreement_score para uma política. Retorna nº de pessoas."""
    div_ids = [d[0] for d in divisions]
    stance_by_div = {d[0]: (d[1], d[2]) for d in divisions}
    per_person = votes_for_divisions(cur, div_ids)

    rows = 0
    for person_id, voted in per_person.items():
        comparisons = []
        for did in div_ids:
            stance, strength = stance_by_div[did]
            option = voted.get(did, "ausente")   # sem registro -> ausente
            comparisons.append((stance, strength, option))
        score, attended = agreement_from_comparisons(comparisons)
        category = categorize(score, attended)
        cur.execute(
            """INSERT INTO agreement_score
                 (person_id, policy_id, score, category, n_divisions, computed_at)
               VALUES (%s, %s, %s, %s, %s, now())
               ON CONFLICT (person_id, policy_id) DO UPDATE
                 SET score = EXCLUDED.score, category = EXCLUDED.category,
                     n_divisions = EXCLUDED.n_divisions, computed_at = now()""",
            (person_id, policy_id,
             round(score, 2) if score is not None else None,
             category, attended),
        )
        rows += 1
    return rows


def run(dsn, only_policy=None):
    import psycopg2
    conn = psycopg2.connect(dsn)
    conn.autocommit = False
    cur = conn.cursor()
    policies = load_policies(cur)
    if only_policy is not None:
        policies = {only_policy: policies.get(only_policy, [])}
    total_people = 0
    for pid, divisions in policies.items():
        if not divisions:
            print(f"política {pid}: sem votações vinculadas — pulada")
            continue
        n = compute_policy(cur, pid, divisions)
        conn.commit()
        print(f"política {pid}: {len(divisions)} votações, {n} pessoas pontuadas")
        total_people += n
    cur.close()
    conn.close()
    print(f"\nConcluído: {len(policies)} política(s), {total_people} score(s) gravado(s).")


# ---- Self-test da lógica pura -------------------------------------------
def self_test():
    def cat(comps):
        s, a = agreement_from_comparisons(comps)
        return round(s, 1) if s is not None else None, categorize(s, a)

    # 3 votações 'for'/normal, sempre SIM -> 100 -> for3
    s, c = cat([("for", "normal", "sim")] * 3)
    assert (s, c) == (100.0, "for3"), (s, c)

    # sempre NÃO numa política 'for' -> 0 -> against3
    s, c = cat([("for", "normal", "nao")] * 3)
    assert (s, c) == (0.0, "against3"), (s, c)

    # metade a favor, metade contra -> 50 -> mixture
    s, c = cat([("for", "normal", "sim"), ("for", "normal", "nao"),
                ("for", "normal", "sim"), ("for", "normal", "nao")])
    assert c == "mixture" and abs(s - 50.0) < 1e-6, (s, c)

    # postura 'against': votar NÃO concorda -> 100 -> for3
    s, c = cat([("against", "normal", "nao")] * 2)
    assert (s, c) == (100.0, "for3"), (s, c)

    # poucos votos decisivos -> not_enough (só 1 decisivo)
    s, c = cat([("for", "normal", "sim"), ("for", "normal", "ausente")])
    assert c == "not_enough", (s, c)

    # voto FORTE domina: concorda no forte (25), discorda no normal (10)
    s, a = agreement_from_comparisons([("for", "strong", "sim"),
                                       ("for", "normal", "nao")])
    assert abs(s - 100 * 25 / 35) < 1e-6, s      # ~71.4 -> for1
    assert categorize(s, a) == "for1", categorize(s, a)

    # ausência dilui mas não conta como discordância total:
    # 1 SIM (for/normal) + 1 ausência -> score fica alto (>85) mas 1 decisivo
    s, a = agreement_from_comparisons([("for", "normal", "sim"),
                                       ("for", "normal", "ausente")])
    assert s > 85 and a == 1, (s, a)

    print("✅ self-test: todas as asserções da lógica de score passaram.")
    print("   exemplos:")
    for comps, desc in [
        ([("for", "strong", "sim")] * 4, "4x SIM forte (for)"),
        ([("for", "normal", "sim"), ("for", "normal", "sim"), ("for", "normal", "nao")], "2 SIM / 1 NÃO"),
        ([("for", "strong", "nao"), ("for", "normal", "nao"), ("for", "normal", "sim")], "2 NÃO / 1 SIM"),
    ]:
        s, a = agreement_from_comparisons(comps)
        print(f"     {desc:26s} -> score={s:5.1f} | {categorize(s, a)} ({CATEGORY_LABELS[categorize(s,a)]})")


def main():
    ap = argparse.ArgumentParser(description="Calcula agreement scores")
    ap.add_argument("--self-test", action="store_true", help="testa a lógica pura e sai")
    ap.add_argument("--policy", type=int, default=None, help="recalcula só esta política")
    args = ap.parse_args()

    if args.self_test:
        self_test()
        return

    dsn = os.environ.get("DATABASE_URL")
    if not dsn:
        sys.exit("ERRO: defina DATABASE_URL (ou use --self-test).")
    run(dsn, only_policy=args.policy)


if __name__ == "__main__":
    main()

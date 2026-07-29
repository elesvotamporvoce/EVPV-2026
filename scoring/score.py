#!/usr/bin/env python3
"""
Motor de "agreement score" — Eles Votam Por Você

Calcula, para cada (pessoa, política/tema), o quanto a pessoa votou de acordo
com a política, e traduz num rótulo em linguagem simples ("votou consistentemente
a favor"). Grava em `agreement_score`. Uma VIEW (db/views_agreement.sql) agrega
isso por partido.

METODOLOGIA (transparente e AJUSTÁVEL — veja as constantes abaixo)
-----------------------------------------------------------------
Os pesos e limiares são NOSSOS, explícitos e configuráveis — calibrados para o
Congresso brasileiro. Não são portados de nenhuma implementação externa: se
mudar as constantes abaixo, a metodologia muda junto (e deve ser documentada).

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
WEIGHT = {"weak": 4, "normal": 10, "strong": 25}   # voto forte pesa mais
ABSENCE_FACTOR = 0.20                    # ausência/abstenção entra com 20% do peso
ABSENCE_CREDIT = 0.50                    # e vale como "neutro" (meio-termo)
MIN_ATTENDED = 2                         # menos que isso -> 'sem dados suficientes'

# Votação quase unânime quase não distingue parlamentares: se 95% ou mais votaram
# do mesmo lado, saber que alguém acompanhou a maioria informa pouco. Ainda assim
# NÃO descartamos a votação, porque ela informa muito sobre a minoria que votou
# contra a corrente. Solução: rebaixamos para o peso 'weak', automaticamente, pela
# margem apurada — a curadoria não precisa lembrar da regra.
LOPSIDED_THRESHOLD = 0.95

# votos decisivos; o resto (abstenção, obstrução, ausente, outro, artigo17)
# é tratado como não-decisivo ("absent")
DECISIVE = {"sim", "nao"}

# limiares score->categoria (0..100). Ajustáveis; definem os 8 rótulos exibidos.
CATEGORY_LABELS = {
    "for3":      "Sempre a favor",
    "for2":      "Quase sempre a favor",
    "for1":      "Geralmente a favor",
    "mixture":   "Às vezes",
    "against1":  "Geralmente contra",
    "against2":  "Quase sempre contra",
    "against3":  "Sempre contra",
    "not_enough": "Sem votos suficientes",
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


def lopsided_divisions(cur, division_ids, threshold=LOPSIDED_THRESHOLD):
    """
    Devolve o set de division_ids em que >= threshold dos votos decisivos ficou
    do mesmo lado. Essas votações entram com peso 'weak'.
    """
    if not division_ids:
        return set()
    cur.execute(
        """SELECT division_id,
                  COUNT(*) FILTER (WHERE option = 'sim') AS sim,
                  COUNT(*) FILTER (WHERE option = 'nao') AS nao
             FROM vote
            WHERE division_id = ANY(%s)
            GROUP BY division_id""",
        (list(division_ids),),
    )
    out = set()
    for division_id, sim, nao in cur.fetchall():
        total = (sim or 0) + (nao or 0)
        if total and max(sim or 0, nao or 0) / total >= threshold:
            out.add(division_id)
    return out


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
    lopsided = lopsided_divisions(cur, div_ids)
    # margem >= LOPSIDED_THRESHOLD rebaixa o peso, mesmo que a curadoria tenha
    # marcado a votação como 'strong'.
    stance_by_div = {
        d[0]: (d[1], "weak" if d[0] in lopsided else d[2])
        for d in divisions
    }
    if lopsided:
        print(f"  {len(lopsided)} votação(ões) quase unânime(s) rebaixada(s) a peso 'weak'")

    # Grava o peso efetivo de volta no banco: o site le essa coluna (via a view
    # policy_division_detail) para mostrar ao usuario o MESMO peso que usamos no
    # calculo. Sem isso a UI desenharia ★ de "voto forte" numa votacao rebaixada.
    for did, (_stance, eff) in stance_by_div.items():
        cur.execute(
            "UPDATE policy_division SET effective_strength = %s "
            " WHERE policy_id = %s AND division_id = %s",
            (eff, policy_id, did),
        )

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

    # Remove scores órfãos: quem tem linha gravada mas não votou em NENHUMA das
    # votações atuais da política (acontece quando uma votação sai da política).
    cur.execute(
        """DELETE FROM agreement_score a
            WHERE a.policy_id = %s
              AND NOT EXISTS (SELECT 1 FROM vote v
                               WHERE v.person_id = a.person_id
                                 AND v.division_id = ANY(%s))""",
        (policy_id, div_ids),
    )
    if cur.rowcount:
        print(f"  {cur.rowcount} score(s) órfão(s) removido(s)")
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

    # peso 'weak': votacao quase unanime quase nao move o score.
    # concorda no weak (4), discorda no normal (10) -> 4/14 = ~28.6
    s, a = agreement_from_comparisons([("for", "weak", "sim"),
                                       ("for", "normal", "nao")])
    assert abs(s - 100 * 4 / 14) < 1e-6, s
    # o inverso pesa muito mais: concorda no normal, discorda no weak -> 10/14
    s2, _ = agreement_from_comparisons([("for", "normal", "sim"),
                                        ("for", "weak", "nao")])
    assert s2 > s, (s, s2)
    # strength desconhecido cai no default 'normal' (proteção contra dado sujo)
    s3, _ = agreement_from_comparisons([("for", "xpto", "sim")])
    assert s3 == 100.0, s3

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

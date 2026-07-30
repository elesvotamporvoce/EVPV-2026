"use client";

import { useState } from "react";
import Link from "next/link";
import { supabase } from "@/lib/supabase";
import { UFS, CARGO_LABEL } from "@/lib/format";

export type QuizPolicy = {
  id: number;
  name: string;
  impact: string | null;
  description: string | null;
};

type Answer = { value: number | null; priority: boolean };

type PersonResult = {
  id: number;
  name: string;
  party: string | null;
  uf: string | null;
  house: string;
  photo: string | null;
  match: number;
  n: number;
};

type PartyResult = { sigla: string; match: number; n: number };

const OPTIONS = [
  { label: "Sempre contra", value: 0, color: "#dc2626" },
  { label: "Geralmente contra", value: 25, color: "#f87171" },
  { label: "Depende", value: 50, color: "#f59e0b" },
  { label: "Geralmente a favor", value: 75, color: "#4ade80" },
  { label: "Sempre a favor", value: 100, color: "#16a34a" },
];

export default function QuizPerfil({ policies }: { policies: QuizPolicy[] }) {
  const [started, setStarted] = useState(false);
  const [list, setList] = useState<QuizPolicy[]>(policies);
  const [step, setStep] = useState(0);
  const [answers, setAnswers] = useState<Record<number, Answer>>({});
  const [uf, setUf] = useState("");
  const [loading, setLoading] = useState(false);
  const [people, setPeople] = useState<PersonResult[] | null>(null);
  const [parties, setParties] = useState<PartyResult[] | null>(null);

  const current = list[step];
  const done = step >= list.length;
  const answered = Object.values(answers).filter((a) => a.value !== null).length;

  function answer(value: number | null) {
    setAnswers((a) => ({
      ...a,
      [current.id]: { value, priority: a[current.id]?.priority ?? false },
    }));
    setStep((s) => s + 1);
  }

  function togglePriority() {
    setAnswers((a) => ({
      ...a,
      [current.id]: {
        value: a[current.id]?.value ?? null,
        priority: !a[current.id]?.priority,
      },
    }));
  }

  async function calcular(estado: string) {
    setLoading(true);
    setUf(estado);
    const ids = Object.entries(answers)
      .filter(([, a]) => a.value !== null)
      .map(([id]) => Number(id));

    const [{ data: sc }, { data: pa }] = await Promise.all([
      supabase
        .from("score_named")
        .select("person_id, person_name, party_sigla, uf, house, photo_url, policy_id, score, category")
        .in("policy_id", ids)
        .eq("uf", estado)
        .neq("category", "not_enough")
        .limit(5000),
      supabase
        .from("party_policy_agreement")
        .select("party_sigla, policy_id, avg_score, n_people")
        .in("policy_id", ids)
        .gte("n_people", 5)
        .limit(2000),
    ]);

    const w = (pid: number) => (answers[pid]?.priority ? 2 : 1);

    // --- parlamentares
    const byPerson = new Map<number, { info: PersonResult; num: number; den: number }>();
    const scoreRows = (sc ?? []) as unknown as {
      person_id: number; person_name: string; party_sigla: string | null; uf: string | null;
      house: string; photo_url: string | null; policy_id: number; score: number;
    }[];
    for (const r of scoreRows) {
      const mine = answers[r.policy_id]?.value;
      if (mine === null || mine === undefined) continue;
      const peso = w(r.policy_id);
      const prox = 100 - Math.abs(mine - r.score);
      const cur = byPerson.get(r.person_id) ?? {
        info: {
          id: r.person_id, name: r.person_name, party: r.party_sigla, uf: r.uf,
          house: r.house, photo: r.photo_url, match: 0, n: 0,
        },
        num: 0, den: 0,
      };
      cur.num += prox * peso;
      cur.den += peso;
      cur.info.n += 1;
      byPerson.set(r.person_id, cur);
    }
    const minPolicies = Math.max(3, Math.ceil(ids.length / 2));
    const ranked = [...byPerson.values()]
      .filter((p) => p.info.n >= Math.min(minPolicies, ids.length))
      .map((p) => ({ ...p.info, match: Math.round(p.num / p.den) }))
      .sort((a, b) => b.match - a.match)
      .slice(0, 5);

    // --- partidos
    const byParty = new Map<string, { num: number; den: number; n: number }>();
    for (const r of (pa ?? []) as unknown as {
      party_sigla: string; policy_id: number; avg_score: number;
    }[]) {
      const mine = answers[r.policy_id]?.value;
      if (mine === null || mine === undefined) continue;
      const peso = w(r.policy_id);
      const prox = 100 - Math.abs(mine - r.avg_score);
      const cur = byParty.get(r.party_sigla) ?? { num: 0, den: 0, n: 0 };
      cur.num += prox * peso;
      cur.den += peso;
      cur.n += 1;
      byParty.set(r.party_sigla, cur);
    }
    const rankedParties = [...byParty.entries()]
      .filter(([, v]) => v.n >= Math.min(minPolicies, ids.length))
      .map(([sigla, v]) => ({ sigla, match: Math.round(v.num / v.den), n: v.n }))
      .sort((a, b) => b.match - a.match)
      .slice(0, 5);

    setPeople(ranked);
    setParties(rankedParties);
    setLoading(false);
  }

  function recomecar() {
    setStarted(false);
    setList(policies);
    setStep(0);
    setAnswers({});
    setUf("");
    setPeople(null);
    setParties(null);
  }

  // ---------- tela inicial ----------
  if (!started) {
    return (
      <div className="rounded-xl border border-brand-light bg-violet-50 p-6 text-center">
        <h1 className="mb-4 text-2xl font-bold text-brand">
          Quem vota como você?
        </h1>
        <p className="text-lg font-semibold text-slate-800">
          Responda como você votaria
        </p>
        <p className="mx-auto mt-2 max-w-xl leading-relaxed text-slate-600">
          Diga como você votaria em cada tema. No final, comparamos suas
          respostas com os votos reais do Congresso e mostramos quais partidos e
          parlamentares mais votam como você. Leva cerca de 3 minutos.
        </p>
        <button
          type="button"
          onClick={() => setStarted(true)}
          className="mt-5 rounded-lg bg-brand px-6 py-3 font-semibold text-white hover:bg-brand-dark"
        >
          Começar
        </button>
        <p className="mt-3 text-xs text-slate-500">
          Suas respostas ficam no seu navegador. Não pedimos cadastro nem
          guardamos nada.
        </p>
      </div>
    );
  }

  // ---------- resultado ----------
  if (done) {
    if (people && parties) {
      return (
        <div className="space-y-6">
          <div className="rounded-xl border border-brand-light bg-violet-50 p-5 text-center">
            <p className="font-semibold text-slate-800">
              Seu resultado, com base em {answered}{" "}
              {answered === 1 ? "resposta" : "respostas"}
            </p>
            <p className="mt-1 text-sm text-slate-600">
              Quanto maior o percentual, mais os votos reais no Congresso se
              parecem com as suas respostas.
            </p>
          </div>

          <section>
            <h2 className="mb-3 text-lg font-semibold text-slate-800">
              Parlamentares de {uf} que mais votam como você
            </h2>
            <div className="divide-y divide-slate-100 rounded-lg border border-slate-200 bg-white">
              {people.map((p) => (
                <Link
                  key={p.id}
                  href={`/pessoas/${p.id}`}
                  className="flex items-center gap-3 p-3 hover:bg-slate-50"
                >
                  <span className="h-11 w-11 shrink-0 overflow-hidden rounded-full bg-slate-100">
                    {p.photo ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img src={p.photo} alt="" className="h-full w-full object-cover" loading="lazy" />
                    ) : null}
                  </span>
                  <span className="min-w-0 flex-1">
                    <span className="block truncate font-medium text-slate-800">{p.name}</span>
                    <span className="text-xs text-slate-500">
                      {p.party ?? "sem partido"} · {CARGO_LABEL[p.house as "camara" | "senado"]}
                    </span>
                  </span>
                  <span className="shrink-0 text-right">
                    <span className="block text-lg font-bold text-brand">{p.match}%</span>
                    <span className="text-[11px] text-slate-400">{p.n} temas</span>
                  </span>
                </Link>
              ))}
              {people.length === 0 && (
                <p className="p-4 text-sm text-slate-500">
                  Não há parlamentares de {uf} com votos suficientes nos temas que
                  você respondeu.
                </p>
              )}
            </div>
          </section>

          <section>
            <h2 className="mb-3 text-lg font-semibold text-slate-800">
              Partidos que mais votam como você
            </h2>
            <div className="divide-y divide-slate-100 rounded-lg border border-slate-200 bg-white">
              {parties.map((p) => (
                <div key={p.sigla} className="flex items-center gap-3 p-3">
                  <span className="w-24 shrink-0 font-semibold text-slate-700">{p.sigla}</span>
                  <span className="h-2.5 flex-1 overflow-hidden rounded-full bg-slate-100">
                    <span
                      className="block h-full rounded-full bg-brand"
                      style={{ width: `${Math.max(3, p.match)}%` }}
                    />
                  </span>
                  <span className="w-12 shrink-0 text-right font-bold text-brand">{p.match}%</span>
                </div>
              ))}
            </div>
          </section>

          <div className="rounded-lg border border-slate-200 bg-white p-4 text-sm leading-relaxed text-slate-600">
            Isto compara as suas respostas com o histórico de votos de cada
            parlamentar nos temas que você respondeu. Não é recomendação de voto:
            um mesmo parlamentar pode concordar com você em um tema e discordar
            em outro. Veja a{" "}
            <Link href="/sobre" className="text-brand hover:underline">
              metodologia
            </Link>
            .
          </div>

          <div className="flex flex-wrap justify-center gap-3">
            <button
              type="button"
              onClick={recomecar}
              className="rounded-lg border border-slate-300 px-5 py-2.5 font-semibold text-slate-700 hover:bg-slate-50"
            >
              Começar de novo
            </button>
          </div>
        </div>
      );
    }

    // escolher estado
    return (
      <div className="rounded-xl border border-brand-light bg-violet-50 p-6 text-center">
        <p className="text-lg font-semibold text-slate-800">
          Quase lá: escolha o seu estado
        </p>
        <p className="mx-auto mt-2 max-w-lg text-slate-600">
          Assim mostramos os deputados e senadores que representam você.
        </p>
        <div className="mt-4 flex flex-wrap justify-center gap-2">
          {UFS.map((u) => (
            <button
              key={u}
              type="button"
              disabled={loading}
              onClick={() => calcular(u)}
              className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm font-semibold text-slate-700 hover:border-brand hover:text-brand disabled:opacity-50"
            >
              {u}
            </button>
          ))}
        </div>
        {loading && (
          <p className="mt-4 text-sm text-slate-500">Comparando com os votos reais...</p>
        )}
        {answered === 0 && (
          <p className="mt-4 text-sm text-amber-700">
            Você não respondeu nenhum tema. Volte e responda ao menos três para
            ter um resultado.
          </p>
        )}
      </div>
    );
  }

  // ---------- pergunta ----------
  const a = answers[current.id];
  return (
    <div className="space-y-4">
      <div className="flex items-center gap-3">
        <span className="h-1.5 flex-1 overflow-hidden rounded-full bg-slate-200">
          <span
            className="block h-full rounded-full bg-brand transition-all"
            style={{ width: `${(step / list.length) * 100}%` }}
          />
        </span>
        <span className="shrink-0 text-sm text-slate-500">
          {step + 1} de {list.length}
        </span>
      </div>

      {/* Nome da politica fixo no topo: a pessoa precisa ver sobre o que esta
          respondendo enquanto rola. top-14 fica logo abaixo da navbar, que e
          sticky top-0. */}
      <div className="sticky top-14 z-30 -mx-4 bg-slate-50 px-4 pb-2 pt-1 sm:mx-0 sm:px-0">
        <div className="rounded-md bg-violet-100 px-4 py-3 shadow-sm">
          <h2 className="text-center text-lg font-bold leading-snug text-slate-800 sm:text-xl">
            {current.name}
          </h2>
        </div>
      </div>

      <div className="rounded-xl border border-slate-200 bg-white p-6">
        {current.impact && (
          <details className="group rounded-none border-l-4 border-amber-500 bg-amber-100">
            <summary className="flex cursor-pointer list-none items-center justify-between gap-2 p-4 text-sm font-semibold text-amber-900 marker:hidden">
              Por que isso importa para você?
              <svg
                aria-hidden="true"
                viewBox="0 0 20 20"
                className="h-4 w-4 shrink-0 transition-transform group-open:rotate-180"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
              >
                <path d="M5 8l5 5 5-5" strokeLinecap="round" strokeLinejoin="round" />
              </svg>
            </summary>
            <p className="px-4 pb-4 text-[15px] leading-relaxed text-amber-900/90">
              {current.impact}
            </p>
          </details>
        )}

        <p className="mt-5 text-center font-semibold text-slate-700">
          Como você votaria?
        </p>
        <div className="mt-3 space-y-2">
          {OPTIONS.map((o) => (
            <button
              key={o.value}
              type="button"
              onClick={() => answer(o.value)}
              className="flex w-full items-center gap-3 rounded-lg border border-slate-300 px-4 py-3 text-left font-medium text-slate-700 hover:border-brand hover:bg-violet-50"
            >
              <span
                className="h-3.5 w-3.5 shrink-0 rounded-full"
                style={{ background: o.color }}
              />
              {o.label}
            </button>
          ))}
        </div>

        <div className="mt-4 flex flex-wrap items-center justify-between gap-3">
          <button
            type="button"
            onClick={togglePriority}
            className={`rounded-lg border px-3 py-2 text-sm font-medium ${
              a?.priority
                ? "border-brand bg-brand text-white"
                : "border-slate-300 text-slate-600 hover:border-brand hover:text-brand"
            }`}
          >
            {a?.priority ? "★ Tema prioritário para mim" : "☆ Esse tema é muito importante para mim"}
          </button>
          <button
            type="button"
            onClick={() => answer(null)}
            className="text-sm text-slate-500 underline hover:text-brand"
          >
            Não tenho opinião, pular
          </button>
        </div>
      </div>

      {step > 0 && (
        <button
          type="button"
          onClick={() => setStep((s) => s - 1)}
          className="text-sm text-brand hover:underline"
        >
          ← Voltar ao tema anterior
        </button>
      )}
    </div>
  );
}

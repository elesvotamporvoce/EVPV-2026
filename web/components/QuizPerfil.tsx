"use client";

import { useState } from "react";
import Link from "next/link";
import { supabase } from "@/lib/supabase";
import { UFS, CARGO_LABEL } from "@/lib/format";

export type QuizPolicy = {
  id: number;
  name: string;
  /** texto curto do quiz; a pagina da politica usa outro texto, mais longo */
  quiz_hook: string | null;
  description: string | null;
  /** lado A e sempre o que da score ALTO na politica */
  side_a_title: string | null;
  side_a_note: string | null;
  side_b_title: string | null;
  side_b_note: string | null;
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

  // Escolher NAO avanca: quem avanca e o botao Confirmar. Assim um toque
  // acidental nao pula o tema, que era a queixa principal sobre o quiz.
  function escolher(value: number | null) {
    setAnswers((a) => ({
      ...a,
      // pular zera o peso dobrado: nao faz sentido priorizar um tema sem opiniao
      [current.id]: {
        value,
        priority: value === null ? false : a[current.id]?.priority ?? false,
      },
    }));
  }

  function togglePriority() {
    setAnswers((a) => {
      const atual = a[current.id];
      if (!atual || atual.value === null) return a;
      return { ...a, [current.id]: { ...atual, priority: !atual.priority } };
    });
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
          Responda como você votaria em cada tema político
        </p>
        <p className="mx-auto mt-2 max-w-xl leading-relaxed text-slate-600">
          No final, comparamos suas respostas com os votos do Congresso e
          mostramos quais partidos e políticos mais se alinham com você. Leva
          cerca de 3 minutos.
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
        <button
          type="button"
          onClick={() => setStep(list.length - 1)}
          className="mt-5 text-sm text-brand hover:underline"
        >
          ← Voltar aos temas
        </button>
      </div>
    );
  }

  // ---------- pergunta ----------
  const a = answers[current.id];
  return (
    <div className="space-y-4">
      {/* Pergunta fixa no topo: a pessoa precisa ver sobre o que esta
          respondendo enquanto rola. top-14 fica logo abaixo da navbar, que e
          sticky top-0. */}
      <div className="sticky top-14 z-30 -mx-4 bg-slate-50 px-4 pb-2 pt-1 sm:mx-0 sm:px-0">
        <div className="rounded-md bg-brand px-4 pb-3 pt-2 shadow-md">
          <p className="py-1 text-center text-[13px] uppercase tracking-widest text-white/60">
            política {step + 1}/{list.length}
          </p>
          <h2 className="mt-2 text-center text-lg font-normal leading-snug text-white sm:text-xl">
            Como você votaria para
            <br />
            <strong className="font-bold underline underline-offset-4">
              {current.name}
            </strong>
            ?
          </h2>
        </div>
      </div>

      {current.quiz_hook && (
        <div className="rounded-none border-l-4 border-amber-500 bg-amber-100 p-4 text-center">
          <p className="text-sm font-semibold text-amber-900">
            Por que isso importa
          </p>
          <p className="mt-1.5 text-[15px] leading-relaxed text-amber-900/90">
            {current.quiz_hook}
          </p>
        </div>
      )}

      <div className="rounded-xl border border-slate-200 bg-white p-6">
        <p className="text-center text-[19px] font-semibold leading-snug text-slate-900">
          Marque seu voto
        </p>

        {/* As duas caixas tem a mesma altura (auto-rows-fr): nenhuma posicao
            parece mais importante que a outra por ocupar mais espaco. */}
        <div className="mt-4 grid auto-rows-fr gap-2.5">
          {[
            { v: 100, titulo: current.side_a_title, nota: current.side_a_note },
            { v: 0, titulo: current.side_b_title, nota: current.side_b_note },
          ].map((lado) =>
            lado.titulo ? (
              <button
                key={lado.v}
                type="button"
                aria-pressed={a?.value === lado.v}
                onClick={() => escolher(lado.v)}
                className={`rounded-lg border-2 bg-violet-100 px-4 py-3 text-center transition ${
                  a?.value === lado.v
                    ? "border-brand ring-2 ring-brand/30"
                    : "border-violet-200 hover:border-brand-light"
                }`}
              >
                <span className="block font-semibold text-slate-800">
                  {lado.titulo}
                </span>
                {lado.nota && (
                  <span className="mt-0.5 block text-sm leading-snug text-slate-600">
                    ({lado.nota})
                  </span>
                )}
              </button>
            ) : null
          )}
        </div>

        {/* Dobrar peso: separado por uma linha, e indisponivel para quem pulou */}
        <div className="mt-5 border-t border-slate-200 pt-4 text-center">
          <button
            type="button"
            onClick={togglePriority}
            disabled={a === undefined || a.value === null}
            className={`rounded-lg border px-3 py-2 text-sm font-medium transition disabled:cursor-not-allowed disabled:opacity-40 ${
              a?.priority
                ? "border-green-500 bg-green-200 text-green-900"
                : "border-green-300 bg-green-100 text-green-800 hover:border-green-500"
            }`}
          >
            {a?.priority
              ? "★ Peso dobrado neste tema"
              : "★ Dobrar peso: esse tema é essencial para mim"}
          </button>
        </div>

        <div className="mt-5 flex items-center justify-between gap-3">
          <button
            type="button"
            onClick={() => {
              escolher(null);
              setStep((v) => v + 1);
            }}
            className="rounded-lg border border-slate-300 px-5 py-3 font-medium text-slate-600 transition hover:border-brand hover:text-brand"
          >
            Pular esse tema
          </button>
          <button
            type="button"
            disabled={a === undefined || a.value === null}
            onClick={() => setStep((v) => v + 1)}
            className="rounded-lg bg-brand px-7 py-3 font-semibold text-white transition hover:bg-brand-dark disabled:cursor-not-allowed disabled:bg-slate-300"
          >
            {step === list.length - 1 ? "Ver meu resultado" : "Confirmar voto"}
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

import Link from "next/link";
import { supabase } from "@/lib/supabase";
import Voltar from "@/components/Voltar";
import ScoreBadge from "@/components/ScoreBadge";
import { UFS } from "@/lib/format";

export const revalidate = 3600;
export const metadata = {
  title: "Candidatos sem histórico no Congresso",
  description:
    "Candidatos de 2026 a presidente, senador e deputado federal que nunca votaram na Câmara ou no Senado. Como não há voto para mostrar, exibimos como o partido deles votou.",
};

const PAGE_SIZE = 48;

const CARGO_LABEL: Record<string, string> = {
  presidente: "Presidente",
  senador: "Senador(a)",
  deputado_federal: "Deputado(a) Federal",
};

const SITUACAO_LABEL: Record<string, string> = {
  deferido: "Candidatura deferida",
  pendente: "Registro em análise",
  indeferido: "Registro indeferido",
};

const brl = (v: number) =>
  v.toLocaleString("pt-BR", {
    style: "currency",
    currency: "BRL",
    maximumFractionDigits: 0,
  });

// Parametros repetidos (?q=a&q=b) chegam como array; usamos so o primeiro.
const one = (v: string | string[] | undefined): string | undefined =>
  Array.isArray(v) ? v[0] : v;

// Escapa curingas do ilike (% e _) para a busca ser literal.
const likeSafe = (s: string) => s.replace(/[\\%_]/g, "\\$&");

type Cand = {
  sq_candidato: string;
  nome_urna: string;
  nome_completo: string | null;
  cargo: string;
  uf: string;
  partido_sigla: string | null;
  party_id: number | null;
  situacao: string | null;
  patrimonio_total: number | null;
};

type Agr = {
  party_id: number;
  policy_id: number;
  policy_name: string;
  avg_score: number;
  n_people: number;
};

export default async function CandidatosNovosPage({
  searchParams,
}: {
  searchParams: Promise<{
    q?: string | string[];
    uf?: string | string[];
    cargo?: string | string[];
    partido?: string | string[];
    page?: string | string[];
  }>;
}) {
  const spRaw = await searchParams;
  const sp = {
    q: one(spRaw.q),
    uf: one(spRaw.uf),
    cargo: one(spRaw.cargo),
    partido: one(spRaw.partido),
    page: one(spRaw.page),
  };
  const page = Math.max(1, parseInt(sp.page ?? "1", 10) || 1);
  const from = (page - 1) * PAGE_SIZE;

  let query = supabase
    .from("candidato_novo_2026")
    .select("*", { count: "exact" })
    .order("nome_urna")
    .range(from, from + PAGE_SIZE - 1);

  if (sp.q) query = query.ilike("nome_urna", `%${likeSafe(sp.q)}%`);
  if (sp.uf) query = query.eq("uf", sp.uf);
  if (sp.cargo) query = query.eq("cargo", sp.cargo);
  if (sp.partido) query = query.eq("partido_sigla", sp.partido);

  const [{ data: rows, count }, { data: siglasRows }, { data: agrRows }] =
    await Promise.all([
      query,
      supabase
        .from("candidato_novo_2026")
        .select("partido_sigla")
        .not("partido_sigla", "is", null)
        .limit(20000),
      supabase
        .from("party_policy_agreement")
        .select("party_id, policy_id, policy_name, avg_score, n_people")
        .gte("n_people", 5)
        .order("policy_name"),
    ]);

  const cands = (rows ?? []) as Cand[];
  const total = count ?? 0;
  const pages = Math.max(1, Math.ceil(total / PAGE_SIZE));
  const siglas = [
    ...new Set(
      ((siglasRows ?? []) as { partido_sigla: string }[]).map((r) => r.partido_sigla)
    ),
  ].sort();

  // Posicao media do partido por politica (a referencia que mostramos no lugar
  // do voto individual, que nao existe).
  const porPartido = new Map<number, Agr[]>();
  for (const a of (agrRows ?? []) as Agr[]) {
    const arr = porPartido.get(a.party_id) ?? [];
    arr.push(a);
    porPartido.set(a.party_id, arr);
  }

  const qs = (extra: Record<string, string | number | undefined>) => {
    const u = new URLSearchParams();
    for (const [k, v] of Object.entries({ ...sp, ...extra })) {
      if (v !== undefined && v !== "" && v !== null) u.set(k, String(v));
    }
    const s = u.toString();
    return s ? `?${s}` : "";
  };

  return (
    <div className="space-y-6">
<Voltar fallback="/eleicoes-2026" />

      <div className="space-y-3">
        <h1 className="text-2xl font-bold text-brand">
          Candidatos sem histórico no Congresso
        </h1>
        <div className="rounded-lg border border-brand-light bg-violet-50 p-4">
          <p className="font-semibold text-slate-800">
            Por que estes não têm votos para mostrar
          </p>
          <p className="mt-1.5 text-[15px] leading-relaxed text-slate-700">
            O site mostra como cada parlamentar votou. Só que boa parte dos
            candidatos de 2026 <strong>nunca votou na Câmara nem no Senado</strong>:
            é gente estreando na política, vindo de outro cargo (prefeito,
            vereador, deputado estadual) ou que saiu do Congresso antes de
            fevereiro de 2019, quando começa a nossa base. Não são os que estão
            tentando a reeleição — esses estão em{" "}
            <Link href="/eleicoes-2026" className="text-brand hover:underline">
              Eleições 2026
            </Link>
            , cada um com o próprio histórico.
          </p>
          <p className="mt-2 text-[15px] leading-relaxed text-slate-700">
            Sem voto individual, a melhor referência disponível é{" "}
            <strong>como o partido deles vota</strong>. É uma pista, não uma
            promessa: parlamentar nenhum é obrigado a seguir o partido, e quem
            for eleito pode votar diferente.
          </p>
        </div>
        <p className="text-sm text-slate-500">
          Presidente, senador e deputado federal — os cargos que votam no
          Congresso. Fonte: DivulgaCandContas, do TSE.
        </p>
      </div>

      {total === 0 && !sp.q && !sp.uf && !sp.cargo && !sp.partido ? (
        <div className="rounded-lg border border-slate-200 bg-white p-8 text-center">
          <p className="font-semibold text-slate-700">
            A lista ainda está sendo importada.
          </p>
          <p className="mx-auto mt-2 max-w-xl text-slate-500">
            Estamos carregando os candidatos registrados no TSE. Enquanto isso,
            veja{" "}
            <Link href="/eleicoes-2026" className="text-brand hover:underline">
              os parlamentares que estão concorrendo
            </Link>{" "}
            e como cada um votou.
          </p>
        </div>
      ) : (
        <>
          <form
            method="GET"
            className="flex flex-wrap items-end gap-2 rounded-lg border border-slate-200 bg-white p-3 text-sm"
          >
            <input
              name="q"
              defaultValue={sp.q ?? ""}
              placeholder="Nome"
              className="w-40 rounded-md border border-slate-300 px-3 py-2"
            />
            <select
              name="uf"
              defaultValue={sp.uf ?? ""}
              className="rounded-md border border-slate-300 px-2 py-2"
            >
              <option value="">Estado</option>
              {UFS.map((u) => (
                <option key={u} value={u}>
                  {u}
                </option>
              ))}
            </select>
            <select
              name="cargo"
              defaultValue={sp.cargo ?? ""}
              className="rounded-md border border-slate-300 px-2 py-2"
            >
              <option value="">Todos os cargos</option>
              <option value="presidente">Presidente</option>
              <option value="senador">Senador</option>
              <option value="deputado_federal">Deputado federal</option>
            </select>
            <select
              name="partido"
              defaultValue={sp.partido ?? ""}
              className="rounded-md border border-slate-300 px-2 py-2"
            >
              <option value="">Partido</option>
              {siglas.map((s) => (
                <option key={s} value={s}>
                  {s}
                </option>
              ))}
            </select>
            <button
              type="submit"
              className="rounded-md bg-brand px-4 py-2 font-semibold text-white"
            >
              Filtrar
            </button>
            <Link
              href="/eleicoes-2026/novos"
              className="px-2 py-2 text-brand hover:underline"
            >
              Limpar
            </Link>
          </form>

          <p className="text-sm text-slate-500">
            {total.toLocaleString("pt-BR")}{" "}
            {total === 1 ? "candidato" : "candidatos"}
            {pages > 1 ? ` · página ${page} de ${pages}` : ""}
          </p>

          {cands.length === 0 ? (
            <div className="rounded-lg border border-slate-200 bg-white p-8 text-center">
              <p className="font-semibold text-slate-700">
                Nenhum candidato com esses filtros.
              </p>
            </div>
          ) : (
            <div className="grid gap-3 sm:grid-cols-2">
              {cands.map((c) => {
                const agr = c.party_id ? porPartido.get(c.party_id) : undefined;
                return (
                  <div
                    key={c.sq_candidato}
                    className="rounded-lg border border-slate-200 bg-white p-4 text-center"
                  >
                    <p className="font-semibold text-slate-800">{c.nome_urna}</p>
                    {c.nome_completo &&
                      c.nome_completo.toUpperCase() !==
                        c.nome_urna.toUpperCase() && (
                        <p className="text-xs text-slate-400">{c.nome_completo}</p>
                      )}
                    <p className="mt-1 text-sm text-slate-500">
                      {CARGO_LABEL[c.cargo] ?? c.cargo} · {c.uf}
                      {c.partido_sigla ? ` · ${c.partido_sigla}` : ""}
                    </p>
                    <p className="mt-0.5 text-xs text-slate-500">
                      {SITUACAO_LABEL[c.situacao ?? ""] ?? "Situação não informada"}
                      {c.patrimonio_total != null && (
                        <> · patrimônio declarado: {brl(c.patrimonio_total)}</>
                      )}
                    </p>

                    {agr && agr.length > 0 ? (
                      <details className="group mt-3 border-t border-slate-100 pt-2.5 text-left">
                        <summary className="flex cursor-pointer list-none items-center justify-center gap-1.5 text-sm font-medium text-brand [&::-webkit-details-marker]:hidden">
                          Como o {c.partido_sigla} votou
                          <svg
                            viewBox="0 0 20 20"
                            fill="currentColor"
                            aria-hidden="true"
                            className="h-4 w-4 shrink-0 transition-transform group-open:rotate-180"
                          >
                            <path
                              fillRule="evenodd"
                              d="M5.23 7.21a.75.75 0 0 1 1.06.02L10 11.17l3.71-3.94a.75.75 0 1 1 1.08 1.04l-4.25 4.5a.75.75 0 0 1-1.08 0l-4.25-4.5a.75.75 0 0 1 .02-1.06Z"
                              clipRule="evenodd"
                            />
                          </svg>
                        </summary>
                        <p className="mt-2 text-xs leading-relaxed text-slate-500">
                          Posição média do {c.partido_sigla} no Congresso. É o
                          partido, <strong>não esta pessoa</strong>.
                        </p>
                        <ul className="mt-2 space-y-1.5">
                          {agr.map((a) => (
                            <li
                              key={a.policy_id}
                              className="flex items-center justify-between gap-3"
                            >
                              <Link
                                href={`/politicas/${a.policy_id}`}
                                className="min-w-0 flex-1 truncate text-sm text-slate-600 hover:text-brand hover:underline"
                              >
                                {a.policy_name}
                              </Link>
                              <ScoreBadge score={a.avg_score} category="" small />
                            </li>
                          ))}
                        </ul>
                        {c.party_id && (
                          <Link
                            href={`/partidos/${c.party_id}`}
                            className="mt-2.5 inline-block text-sm text-brand hover:underline"
                          >
                            Ver a página do {c.partido_sigla} →
                          </Link>
                        )}
                      </details>
                    ) : (
                      <p className="mt-3 border-t border-slate-100 pt-2.5 text-sm text-slate-500">
                        Não temos votos suficientes do{" "}
                        {c.partido_sigla ?? "partido"} no Congresso para servir
                        de referência.
                      </p>
                    )}
                  </div>
                );
              })}
            </div>
          )}

          {pages > 1 && (
            <div className="flex items-center justify-between gap-3 pt-2">
              {page > 1 ? (
                <Link
                  href={`/eleicoes-2026/novos${qs({ page: page - 1 })}`}
                  className="rounded-lg border border-slate-300 px-4 py-2 text-sm text-slate-600 hover:border-brand hover:text-brand"
                >
                  ← Anterior
                </Link>
              ) : (
                <span />
              )}
              {page < pages ? (
                <Link
                  href={`/eleicoes-2026/novos${qs({ page: page + 1 })}`}
                  className="rounded-lg border border-slate-300 px-4 py-2 text-sm text-slate-600 hover:border-brand hover:text-brand"
                >
                  Próxima →
                </Link>
              ) : (
                <span />
              )}
            </div>
          )}
        </>
      )}
    </div>
  );
}

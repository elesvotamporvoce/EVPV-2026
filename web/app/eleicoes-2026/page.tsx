import { supabase } from "@/lib/supabase";
import PersonCard from "@/components/PersonCard";
import FeaturedRotator from "@/components/FeaturedRotator";
import Link from "next/link";
import { UFS } from "@/lib/format";
import type { PersonDir } from "@/lib/types";

export const revalidate = 3600;
// Esta pagina e dinamica (le params/searchParams), entao nao fica no
// cache de pagina. Sem a linha abaixo, as consultas ao Supabase caem no
// Data Cache do Next, que sobrevive a deploy e nao e limpo pelo
// revalidatePath de rota dinamica — foi assim que o placar da P15 ficou
// horas mostrando o numero antigo. Com no-store, sempre le o banco.
export const fetchCache = "default-no-store";
export const metadata = {
  title: "Eleições 2026",
  description:
    "Deputados e senadores atuais com pré-candidatura anunciada ou candidatura registrada para 2026, e como cada um votou no mandato.",
};

const CARGO_2026: Record<string, string> = {
  presidente: "Presidente",
  governador: "Governador(a)",
  senador: "Senador(a)",
  deputado_federal: "Deputado(a) Federal",
  deputado_estadual: "Deputado(a) Estadual",
};

const brl = (v: number) =>
  v.toLocaleString("pt-BR", { style: "currency", currency: "BRL", maximumFractionDigits: 0 });

const SITUACAO_LABEL: Record<string, string> = {
  anunciado: "Pré-candidatura anunciada",
  pendente: "Registro em análise",
  deferido: "Candidatura deferida",
  indeferido: "Registro indeferido",
};

const norm = (x: string) =>
  x.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();

// Parametros repetidos (?q=a&q=b) chegam como array; usamos so o primeiro.
const one = (v: string | string[] | undefined): string | undefined =>
  Array.isArray(v) ? v[0] : v;

export default async function Eleicoes2026Page({
  searchParams,
}: {
  searchParams: Promise<{
    q?: string | string[];
    uf?: string | string[];
    cargo?: string | string[];
    partido?: string | string[];
  }>;
}) {
  const sp = await searchParams;
  const q = one(sp.q), uf = one(sp.uf), cargo = one(sp.cargo), partido = one(sp.partido);
  const { data: cand } = await supabase
    .from("candidatura_2026")
    .select(
      "person_id, cargo, uf, situacao, fonte, atualizado_em, patrimonio_total, nome_urna, partido_sigla, sexo"
    )
    .order("situacao")
    .limit(2000);
  const candRows = (cand ?? []) as {
    person_id: number;
    cargo: string | null;
    uf: string | null;
    situacao: string | null;
    fonte: string | null;
    patrimonio_total: number | null;
    nome_urna: string | null;
    partido_sigla: string | null;
    sexo: string | null;
  }[];

  let people: PersonDir[] = [];
  if (candRows.length) {
    const { data } = await supabase
      .from("person_directory")
      .select("*")
      .in(
        "id",
        candRows.map((c) => c.person_id)
      )
      .order("name");
    people = (data ?? []) as PersonDir[];
  }
  const candBy = new Map(candRows.map((c) => [c.person_id, c]));

  // Candidatos sem historico no Congresso: o botao so aparece quando a
  // ingestao do TSE ja tiver populado a tabela.
  const { count: nNovos } = await supabase
    .from("candidato_novo_2026")
    .select("sq_candidato", { count: "exact", head: true });

  // Opcoes dos filtros vem da lista COMPLETA (antes de filtrar), para o
  // usuario poder trocar de partido sem precisar limpar o filtro atual.
  const ufsDisponiveis = new Set(candRows.map((c) => c.uf).filter(Boolean) as string[]);
  const partidos = [...new Set(people.map((p) => p.party_sigla).filter(Boolean))].sort();
  const cargosDisponiveis = [
    ...new Set(candRows.map((c) => c.cargo).filter(Boolean) as string[]),
  ].sort((a, b) => (CARGO_2026[a] ?? a).localeCompare(CARGO_2026[b] ?? b));

  // Filtros (aplicados em memoria: a lista e pequena)
  people = people.filter((p) => {
    const c = candBy.get(p.id);
    if (q && !norm(p.name).includes(norm(q))) return false;
    if (uf && c?.uf !== uf) return false;
    if (cargo && c?.cargo !== cargo) return false;
    if (partido && p.party_sigla !== partido) return false;
    return true;
  });
  // Com filtro ativo: mostramos os resultados e escondemos a lista completa.
  const temFiltro = Boolean(q || uf || cargo || partido);

  // Mais procurados que concorrem
  const { data: hf } = await supabase
    .from("home_featured").select("person_id, rank").order("rank");
  const procuradosIds = ((hf ?? []) as { person_id: number }[])
    .map((h) => h.person_id).filter((id) => candBy.has(id));
  const { data: procData } = procuradosIds.length
    ? await supabase.from("person_directory").select("*").in("id", procuradosIds)
    : { data: [] };
  const procurados = procuradosIds
    .map((id) => ((procData ?? []) as PersonDir[]).find((p) => p.id === id))
    .filter(Boolean) as PersonDir[];

  // Monta a URL preservando os outros filtros (usado nos botoes de estado).
  const href = (troca: Record<string, string | undefined>) => {
    const u = new URLSearchParams();
    for (const [k, v] of Object.entries({ q, uf, cargo, partido, ...troca })) {
      if (v) u.set(k, v);
    }
    const s = u.toString();
    return s ? `/eleicoes-2026?${s}` : "/eleicoes-2026";
  };

  const listaCards = (
    <div className="grid grid-cols-2 gap-3 pt-3 sm:grid-cols-3 lg:grid-cols-4">
      {people.map((p) => {
        const c = candBy.get(p.id);
        return (
          <div key={p.id} className="space-y-1">
            <PersonCard p={p} candidato feminino={candBy.get(p.id)?.sexo === "F"} />
            {c && (
              <p className="px-1 text-center text-xs text-slate-500">
                {c.cargo ? `${CARGO_2026[c.cargo] ?? c.cargo}${c.uf ? ` · ${c.uf}` : ""} · ` : ""}
                {SITUACAO_LABEL[c.situacao ?? ""] ?? "Situação não informada"}
                {c.patrimonio_total != null && (
                  <>
                    {" · patrimônio declarado: "}
                    {brl(c.patrimonio_total)}
                  </>
                )}
              </p>
            )}
          </div>
        );
      })}
    </div>
  );

  return (
    <div className="space-y-6">
      <div className="space-y-3">
        <h1 className="text-2xl font-bold text-brand">Eleições 2026</h1>
        <div className="rounded-lg border border-amber-500 bg-amber-100 p-4">
          <p className="font-semibold text-amber-900">Lista parcial</p>
          <p className="mt-1 text-[15px] leading-relaxed text-amber-900/90">
            O prazo de registro no TSE terminou em 15 de agosto de 2026, e esta
            lista é atualizada a partir dos registros oficiais. Registrar não é
            o mesmo que ter a candidatura confirmada: a Justiça Eleitoral ainda
            julga cada pedido, e indicamos a situação de cada um. O patrimônio
            exibido é o declarado pelo próprio candidato ao TSE.
          </p>
        </div>
      </div>

      {/* BUSCA — em cima de tudo e centralizada. O estado sai numa caixa de
          botoes (igual a do fim do quiz); nome, cargo e partido vem abaixo. */}
      <div className="rounded-xl border border-brand-light bg-violet-50 p-4 text-center sm:p-6">
        <p className="text-lg font-semibold text-slate-800">
          Procure um candidato
        </p>

        <p className="mt-3 text-sm font-medium text-slate-600">Estado</p>
        <div className="mt-2 flex flex-wrap justify-center gap-1.5">
          <Link
            href={href({ uf: undefined })}
            className={`rounded-lg border px-3 py-2 text-sm font-semibold ${
              !uf
                ? "border-brand bg-brand text-white"
                : "border-slate-300 bg-white text-slate-700 hover:border-brand hover:text-brand"
            }`}
          >
            Todos
          </Link>
          {UFS.filter((u) => ufsDisponiveis.has(u)).map((u) => (
            <Link
              key={u}
              href={href({ uf: u })}
              className={`rounded-lg border px-3 py-2 text-sm font-semibold ${
                uf === u
                  ? "border-brand bg-brand text-white"
                  : "border-slate-300 bg-white text-slate-700 hover:border-brand hover:text-brand"
              }`}
            >
              {u}
            </Link>
          ))}
        </div>

        <form
          method="GET"
          className="mt-5 flex flex-col items-center gap-2 sm:flex-row sm:flex-wrap sm:justify-center"
        >
          {uf && <input type="hidden" name="uf" value={uf} />}
          <input
            name="q"
            defaultValue={q ?? ""}
            placeholder="Nome"
            aria-label="Nome do candidato"
            className="w-full rounded-md border border-slate-300 px-3 py-2 text-center text-sm sm:w-44 sm:text-left"
          />
          <select
            name="cargo"
            defaultValue={cargo ?? ""}
            aria-label="Cargo em 2026"
            className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm sm:w-auto"
          >
            <option value="">Todos os cargos</option>
            {cargosDisponiveis.map((cg) => (
              <option key={cg} value={cg}>
                {CARGO_2026[cg] ?? cg}
              </option>
            ))}
          </select>
          <select
            name="partido"
            defaultValue={partido ?? ""}
            aria-label="Partido"
            className="w-full rounded-md border border-slate-300 px-3 py-2 text-sm sm:w-auto"
          >
            <option value="">Todos os partidos</option>
            {partidos.map((pt) => (
              <option key={pt} value={pt!}>
                {pt}
              </option>
            ))}
          </select>
          <div className="mt-1 flex items-center gap-3 sm:mt-0">
            <button
              type="submit"
              className="rounded-md bg-brand px-5 py-2 font-semibold text-white hover:bg-brand-dark"
            >
              Procurar
            </button>
            {temFiltro && (
              <Link href="/eleicoes-2026" className="text-sm text-brand hover:underline">
                Limpar
              </Link>
            )}
          </div>
        </form>
      </div>

      {/* RESULTADOS — so aparecem depois de procurar, logo abaixo da busca. */}
      {temFiltro && (
        <section>
          <p className="text-center text-sm text-slate-500">
            {people.length === 0
              ? "Nenhum candidato com esses filtros."
              : `${people.length} ${people.length === 1 ? "resultado" : "resultados"}`}
          </p>
          {people.length > 0 && listaCards}
        </section>
      )}

      {procurados.length > 0 && (
        <div className="rounded-xl border border-brand-light bg-violet-50/60 p-4">
          <p className="mb-1 text-center font-semibold text-slate-800">
            Mais procurados
          </p>
          <FeaturedRotator>
            {procurados.map((p) => (
              <PersonCard
                key={p.id}
                p={p}
                candidato
                feminino={candBy.get(p.id)?.sexo === "F"}
              />
            ))}
          </FeaturedRotator>
        </div>
      )}

      {/* LISTA COMPLETA — em ordem alfabetica; some quando ha filtro. */}
      {!temFiltro &&
        (people.length === 0 ? (
          <div className="rounded-lg border border-slate-200 bg-white p-8 text-center">
            <p className="font-semibold text-slate-700">
              Ainda não há pré-candidaturas ou candidaturas na nossa base.
            </p>
            <p className="mx-auto mt-2 max-w-xl text-slate-500">
              O registro no TSE encerrou em 15 de agosto e estamos importando os
              dados oficiais. Assim que a importação terminar, os nomes aparecem
              aqui. Enquanto isso, veja{" "}
              <Link href="/pessoas" className="text-brand hover:underline">
                todos os parlamentares
              </Link>{" "}
              e como cada um vota.
            </p>
          </div>
        ) : (
          <section>
            <p className="text-center text-sm text-slate-500">
              {people.length.toLocaleString("pt-BR")} candidatos, em ordem
              alfabética
            </p>
            {listaCards}
          </section>
        ))}

      {(nNovos ?? 0) > 0 && (
        <Link
          href="/eleicoes-2026/novos"
          className="flex flex-wrap items-center justify-between gap-3 rounded-xl border border-brand-light bg-violet-50 p-4 hover:border-brand hover:shadow-sm"
        >
          <span>
            <span className="block font-semibold text-slate-800">
              E quem nunca votou no Congresso?
            </span>
            <span className="mt-0.5 block text-sm leading-relaxed text-slate-600">
              {(nNovos ?? 0).toLocaleString("pt-BR")} candidatos a presidente,
              senador e deputado federal sem histórico de votação. Sem voto para
              mostrar, mostramos como o partido deles vota.
            </span>
          </span>
          <span className="shrink-0 rounded-lg bg-brand px-4 py-2.5 font-semibold text-white">
            Ver a lista
          </span>
        </Link>
      )}

      <section className="rounded-lg border border-slate-200 bg-white p-5">
        <h2 className="font-semibold text-slate-800">De onde vêm estes dados</h2>
        <ul className="mt-2 list-disc space-y-1.5 pl-6 text-sm leading-relaxed text-slate-600">
          <li>
            Candidaturas registradas:{" "}
            <a
              href="https://divulgacandcontas.tse.jus.br"
              target="_blank"
              rel="noreferrer"
              className="text-brand hover:underline"
            >
              DivulgaCandContas, do TSE
            </a>
            , sistema oficial que publica os pedidos de registro e a situação de
            cada um.
          </li>
          <li>
            Dados consolidados e histórico de eleições:{" "}
            <a
              href="https://dadosabertos.tse.jus.br"
              target="_blank"
              rel="noreferrer"
              className="text-brand hover:underline"
            >
              Portal de Dados Abertos do TSE
            </a>
            .
          </li>
          <li>
            Calendário eleitoral e prazos:{" "}
            <a
              href="https://www.tse.jus.br"
              target="_blank"
              rel="noreferrer"
              className="text-brand hover:underline"
            >
              Tribunal Superior Eleitoral
            </a>
            .
          </li>
          <li>
            Pré-candidaturas anunciadas: declarações públicas do próprio
            parlamentar ou do partido, antes do registro oficial. São marcadas
            como &quot;pré-candidatura anunciada&quot; justamente por ainda não
            constarem no TSE.
          </li>
        </ul>
        <p className="mt-3 text-xs text-slate-400">
          Encontrou um nome errado ou faltando? Escreva para{" "}
          <a
            href="mailto:contato@elesvotamporvoce.org"
            className="text-brand hover:underline"
          >
            contato@elesvotamporvoce.org
          </a>
          .
        </p>
      </section>
    </div>
  );
}

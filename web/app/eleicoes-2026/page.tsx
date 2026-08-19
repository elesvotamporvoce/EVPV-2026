import { supabase } from "@/lib/supabase";
import PersonCard from "@/components/PersonCard";
import Link from "next/link";
import type { PersonDir } from "@/lib/types";

export const revalidate = 3600;
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
    casa?: string | string[];
    partido?: string | string[];
  }>;
}) {
  const sp = await searchParams;
  const q = one(sp.q), uf = one(sp.uf), casa = one(sp.casa), partido = one(sp.partido);
  const { data: cand } = await supabase
    .from("candidatura_2026")
    .select(
      "person_id, cargo, uf, situacao, fonte, atualizado_em, patrimonio_total, nome_urna, partido_sigla"
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

  // Opcoes dos filtros vem da lista COMPLETA (antes de filtrar), para o
  // usuario poder trocar de partido sem precisar limpar o filtro atual.
  const ufsDisponiveis = [...new Set(candRows.map((c) => c.uf).filter(Boolean))].sort();
  const partidos = [...new Set(people.map((p) => p.party_sigla).filter(Boolean))].sort();

  // Filtros (aplicados em memoria: a lista e pequena)
  people = people.filter((p) => {
    const c = candBy.get(p.id);
    if (q && !norm(p.name).includes(norm(q))) return false;
    if (uf && c?.uf !== uf) return false;
    if (casa && p.house !== casa) return false;
    if (partido && p.party_sigla !== partido) return false;
    return true;
  });

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
        <p className="text-slate-600">
          Deputados e senadores em exercício que já se movimentaram para 2026.
          Clique em qualquer um para ver como votou durante o mandato.
        </p>
      </div>

      {procurados.length > 0 && (
        <div className="rounded-xl border border-brand-light bg-violet-50/60 p-4">
          <p className="mb-3 font-semibold text-slate-800">Mais procurados que vão concorrer</p>
          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            {procurados.slice(0, 6).map((p) => (
              <PersonCard key={p.id} p={p} candidato />
            ))}
          </div>
        </div>
      )}

      <form method="GET" className="flex flex-wrap items-end gap-2 rounded-lg border border-slate-200 bg-white p-3 text-sm">
        <input name="q" defaultValue={q ?? ""} placeholder="Nome"
          className="w-40 rounded-md border border-slate-300 px-3 py-2" />
        <select name="uf" defaultValue={uf ?? ""} className="rounded-md border border-slate-300 px-2 py-2">
          <option value="">Estado</option>
          {ufsDisponiveis.map((u) => (<option key={u} value={u!}>{u}</option>))}
        </select>
        <select name="casa" defaultValue={casa ?? ""} className="rounded-md border border-slate-300 px-2 py-2">
          <option value="">Deputado e senador</option>
          <option value="camara">Deputado federal</option>
          <option value="senado">Senador</option>
        </select>
        <select name="partido" defaultValue={partido ?? ""} className="rounded-md border border-slate-300 px-2 py-2">
          <option value="">Partido</option>
          {partidos.map((pt) => (<option key={pt} value={pt!}>{pt}</option>))}
        </select>
        <button type="submit" className="rounded-md bg-brand px-4 py-2 font-semibold text-white">Filtrar</button>
        <Link href="/eleicoes-2026" className="px-2 py-2 text-brand hover:underline">Limpar</Link>
      </form>

      {people.length === 0 ? (
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
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          {people.map((p) => {
            const c = candBy.get(p.id);
            return (
              <div key={p.id} className="space-y-1">
                <PersonCard p={p} candidato />
                {c && (
                  <p className="px-1 text-xs text-slate-500">
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

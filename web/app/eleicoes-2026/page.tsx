import { supabase } from "@/lib/supabase";
import PersonCard from "@/components/PersonCard";
import SearchFilters from "@/components/SearchFilters";
import Link from "next/link";
import type { PersonDir } from "@/lib/types";

export const revalidate = 3600;
export const metadata = {
  title: "Eleições 2026",
  description:
    "Quais deputados e senadores atuais são candidatos nas eleições de 2026, e como cada um votou no mandato.",
};

const PAGE_SIZE = 48;

async function getParties(): Promise<string[]> {
  const { data } = await supabase
    .from("person_directory")
    .select("party_sigla")
    .not("party_sigla", "is", null)
    .limit(2000);
  const siglas = (data ?? []).map((r) => r.party_sigla as string).filter(Boolean);
  return [...new Set(siglas)].sort();
}

export default async function Eleicoes2026Page({
  searchParams,
}: {
  searchParams: Promise<{
    q?: string;
    house?: string;
    uf?: string;
    party?: string;
    page?: string;
    so?: string;
  }>;
}) {
  const sp = await searchParams;
  const page = Math.max(1, parseInt(sp.page ?? "1", 10) || 1);
  const from = (page - 1) * PAGE_SIZE;

  const { data: cand } = await supabase
    .from("candidatura_2026")
    .select("person_id, cargo, uf, situacao")
    .limit(2000);
  const candRows = (cand ?? []) as {
    person_id: number;
    cargo: string | null;
    uf: string | null;
    situacao: string | null;
  }[];
  const candBy = new Map(candRows.map((c) => [c.person_id, c]));
  const soCandidatos = sp.so === "1";

  let query = supabase
    .from("person_directory")
    .select("*", { count: "exact" })
    .in("mandate_status", ["em_exercicio", "licenciado"])
    .order("name");

  if (sp.q) query = query.ilike("name", `%${sp.q}%`);
  if (sp.house) query = query.eq("house", sp.house);
  if (sp.uf) query = query.eq("uf", sp.uf);
  if (sp.party) query = query.eq("party_sigla", sp.party);
  if (soCandidatos) {
    const ids = candRows.map((c) => c.person_id);
    query = query.in("id", ids.length ? ids : [-1]);
  }

  const [{ data, count }, parties] = await Promise.all([
    query.range(from, from + PAGE_SIZE - 1),
    getParties(),
  ]);
  const people = (data ?? []) as PersonDir[];
  const total = count ?? 0;
  const pages = Math.ceil(total / PAGE_SIZE);

  const qs = (p: number) => {
    const params = new URLSearchParams();
    if (sp.q) params.set("q", sp.q);
    if (sp.house) params.set("house", sp.house);
    if (sp.uf) params.set("uf", sp.uf);
    if (sp.party) params.set("party", sp.party);
    if (soCandidatos) params.set("so", "1");
    params.set("page", String(p));
    return `/eleicoes-2026?${params.toString()}`;
  };

  return (
    <div className="space-y-6">
      <div className="space-y-3">
        <h1 className="text-2xl font-bold text-brand">Eleições 2026</h1>
        <div className="rounded-lg border border-amber-500 bg-amber-100 p-4">
          <p className="font-semibold text-amber-900">Lista parcial</p>
          <p className="mt-1 text-[15px] leading-relaxed text-amber-900/90">
            As convenções partidárias vão até 5 de agosto e o prazo para
            registrar candidatura termina em 15 de agosto de 2026. Até lá, esta
            lista está incompleta: quem ainda não aparece como candidato pode vir
            a se candidatar. Registrar candidatura também não é o mesmo que ter
            candidatura confirmada, porque a Justiça Eleitoral ainda julga cada
            pedido.
          </p>
        </div>
        <p className="text-slate-600">
          Aqui estão os {total.toLocaleString("pt-BR")} deputados e senadores em
          exercício. Quem já tem candidatura registrada para 2026 aparece com o
          selo <span className="font-semibold text-brand">Candidato 2026</span>.
          Clique em qualquer um para ver como votou durante o mandato.
        </p>
      </div>

      <SearchFilters parties={parties} basePath="/eleicoes-2026" />

      <div className="flex flex-wrap items-center gap-3">
        <Link
          href={soCandidatos ? "/eleicoes-2026" : "/eleicoes-2026?so=1"}
          className={`rounded-lg border px-4 py-2 text-sm font-semibold ${
            soCandidatos
              ? "border-brand bg-brand text-white"
              : "border-slate-300 text-slate-700 hover:border-brand hover:text-brand"
          }`}
        >
          {soCandidatos ? "✓ Só candidatos confirmados" : "Ver só candidatos confirmados"}
        </Link>
        <span className="text-sm text-slate-500">
          {candRows.length} candidatura{candRows.length === 1 ? "" : "s"}{" "}
          registrada{candRows.length === 1 ? "" : "s"} até agora
        </span>
      </div>

      {people.length === 0 ? (
        <p className="py-12 text-center text-slate-500">
          {soCandidatos
            ? "Ainda não há candidaturas registradas na nossa base. Volte depois das convenções partidárias."
            : "Nenhum parlamentar encontrado com esses filtros."}
        </p>
      ) : (
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          {people.map((p) => (
            <PersonCard
              key={p.id}
              p={p}
              candidato={candBy.get(p.id)?.situacao ? true : candBy.has(p.id)}
            />
          ))}
        </div>
      )}

      {pages > 1 && (
        <div className="flex items-center justify-center gap-4 pt-4 text-sm">
          {page > 1 && (
            <Link href={qs(page - 1)} className="text-brand hover:underline">
              ← Anterior
            </Link>
          )}
          <span className="text-slate-500">
            Página {page} de {pages}
          </span>
          {page < pages && (
            <Link href={qs(page + 1)} className="text-brand hover:underline">
              Próxima →
            </Link>
          )}
        </div>
      )}
    </div>
  );
}

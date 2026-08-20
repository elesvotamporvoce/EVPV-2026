import Link from "next/link";
import { supabase } from "@/lib/supabase";
import SearchFilters from "@/components/SearchFilters";
import PersonCard from "@/components/PersonCard";
import FeaturedRotator from "@/components/FeaturedRotator";
import type { PersonDir } from "@/lib/types";

export const revalidate = 3600;
export const metadata = { title: "Parlamentares" };

const PAGE_SIZE = 48;

async function getParties(): Promise<string[]> {
  // Apenas partidos que têm parlamentar no diretório (evita siglas vazias)
  const { data } = await supabase
    .from("person_directory")
    .select("party_sigla")
    .not("party_sigla", "is", null)
    .limit(2000);
  const siglas = (data ?? []).map((r) => r.party_sigla as string).filter(Boolean);
  return [...new Set(siglas)].sort();
}

// Parametros repetidos (?q=a&q=b) chegam como array; usamos so o primeiro.
const one = (v: string | string[] | undefined): string | undefined =>
  Array.isArray(v) ? v[0] : v;

// Escapa curingas do ilike (% e _) para a busca ser literal.
const likeSafe = (s: string) => s.replace(/[\\%_]/g, "\\$&");

export default async function PessoasPage({
  searchParams,
}: {
  searchParams: Promise<{
    q?: string | string[];
    house?: string | string[];
    uf?: string | string[];
    party?: string | string[];
    mandato?: string | string[];
    page?: string | string[];
  }>;
}) {
  const spRaw = await searchParams;
  const sp = {
    q: one(spRaw.q),
    house: one(spRaw.house),
    uf: one(spRaw.uf),
    party: one(spRaw.party),
    mandato: one(spRaw.mandato),
    page: one(spRaw.page),
  };
  const page = Math.max(1, parseInt(sp.page ?? "1", 10) || 1);
  const from = (page - 1) * PAGE_SIZE;

  let query = supabase
    .from("person_directory")
    .select("*", { count: "exact" })
    .order("name")
    .range(from, from + PAGE_SIZE - 1);

  if (sp.q) query = query.ilike("name", `%${likeSafe(sp.q)}%`);
  if (sp.house) query = query.eq("house", sp.house);
  if (sp.uf) query = query.eq("uf", sp.uf);
  if (sp.party) query = query.eq("party_sigla", sp.party);
  if (sp.mandato) query = query.eq("mandate_status", sp.mandato);

  const emExQuery = supabase
    .from("person_directory")
    .select("id", { count: "exact", head: true })
    .eq("mandate_status", "em_exercicio");
  // Destaques curados (tabela search_featured), so na visao padrao sem filtros
  const showFeatured =
    !sp.q && !sp.house && !sp.uf && !sp.party && !sp.mandato && page === 1;

  const { data: candIds } = await supabase.from("candidatura_2026").select("person_id");
  const candSet = new Set(
    ((candIds ?? []) as { person_id: number }[]).map((c) => c.person_id)
  );
  const [{ data, count }, parties, { count: emEx }] = await Promise.all([
    query,
    getParties(),
    emExQuery,
  ]);
  const people = (data ?? []) as PersonDir[];
  const total = count ?? 0;

  let destaque: PersonDir[] = [];
  if (showFeatured) {
    const { data: sf } = await supabase
      .from("search_featured")
      .select("person_id, rank")
      .order("rank");
    const ids = ((sf ?? []) as { person_id: number }[]).map((r) => r.person_id);
    if (ids.length) {
      const { data: dp } = await supabase
        .from("person_directory")
        .select("*")
        .in("id", ids);
      const by = new Map(((dp ?? []) as PersonDir[]).map((p) => [p.id, p]));
      destaque = ids.map((i) => by.get(i)).filter(Boolean) as PersonDir[];
    }
  }
  const pages = Math.ceil(total / PAGE_SIZE);

  const qs = (p: number) => {
    const params = new URLSearchParams();
    if (sp.q) params.set("q", sp.q);
    if (sp.house) params.set("house", sp.house);
    if (sp.uf) params.set("uf", sp.uf);
    if (sp.party) params.set("party", sp.party);
    if (sp.mandato) params.set("mandato", sp.mandato);
    params.set("page", String(p));
    return `/pessoas?${params.toString()}`;
  };

  return (
    <div className="space-y-6">
      <div className="space-y-2 pb-1">
        <h1 className="text-2xl font-bold text-brand">Parlamentares</h1>
        <p className="text-sm text-slate-500">
          {total.toLocaleString("pt-BR")} deputados e senadores
          {(emEx ?? 0) >= 400
            ? `, ${(emEx ?? 0).toLocaleString("pt-BR")} no cargo`
            : ""}
        </p>
      </div>

      <SearchFilters parties={parties} />

      {destaque.length > 0 && (
        <div className="rounded-xl border border-brand-light bg-violet-50/60 p-4">
          <p className="mb-3 font-semibold text-slate-800">Mais procurados</p>
          <FeaturedRotator className="grid grid-cols-2 gap-3 pt-3 sm:grid-cols-3 lg:grid-cols-4">
            {destaque.map((p) => (
              <PersonCard key={p.id} p={p} candidato={candSet.has(p.id)} />
            ))}
          </FeaturedRotator>
        </div>
      )}

      {people.length === 0 ? (
        <p className="py-12 text-center text-slate-500">
          Nenhum parlamentar encontrado com esses filtros.
        </p>
      ) : (
        <div className="grid grid-cols-2 gap-3 pt-3 sm:grid-cols-3 lg:grid-cols-4">
          {people.map((p) => (
            <PersonCard key={p.id} p={p} candidato={candSet.has(p.id)} />
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

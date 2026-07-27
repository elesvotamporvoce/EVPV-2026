import Link from "next/link";
import { supabase } from "@/lib/supabase";
import SearchFilters from "@/components/SearchFilters";
import PersonCard from "@/components/PersonCard";
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

export default async function PessoasPage({
  searchParams,
}: {
  searchParams: Promise<{
    q?: string;
    house?: string;
    uf?: string;
    party?: string;
    page?: string;
  }>;
}) {
  const sp = await searchParams;
  const page = Math.max(1, parseInt(sp.page ?? "1", 10) || 1);
  const from = (page - 1) * PAGE_SIZE;

  let query = supabase
    .from("person_directory")
    .select("*", { count: "exact" })
    .order("name")
    .range(from, from + PAGE_SIZE - 1);

  if (sp.q) query = query.ilike("name", `%${sp.q}%`);
  if (sp.house) query = query.eq("house", sp.house);
  if (sp.uf) query = query.eq("uf", sp.uf);
  if (sp.party) query = query.eq("party_sigla", sp.party);

  const [{ data, count }, parties] = await Promise.all([query, getParties()]);
  const people = (data ?? []) as PersonDir[];
  const total = count ?? 0;
  const pages = Math.ceil(total / PAGE_SIZE);

  const qs = (p: number) => {
    const params = new URLSearchParams();
    if (sp.q) params.set("q", sp.q);
    if (sp.house) params.set("house", sp.house);
    if (sp.uf) params.set("uf", sp.uf);
    if (sp.party) params.set("party", sp.party);
    params.set("page", String(p));
    return `/pessoas?${params.toString()}`;
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-slate-800">Parlamentares</h1>
        <p className="text-sm text-slate-500">
          {total.toLocaleString("pt-BR")} deputados e senadores
        </p>
      </div>

      <SearchFilters parties={parties} />

      {people.length === 0 ? (
        <p className="py-12 text-center text-slate-500">
          Nenhum parlamentar encontrado com esses filtros.
        </p>
      ) : (
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          {people.map((p) => (
            <PersonCard key={p.id} p={p} />
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

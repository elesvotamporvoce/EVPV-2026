import Link from "next/link";
import { supabase } from "@/lib/supabase";
import { featuredRank } from "@/lib/format";
import type { Policy } from "@/lib/types";

export const revalidate = 3600;
export const metadata = { title: "Políticas" };

async function getPolicies(): Promise<Policy[]> {
  try {
    const { data } = await supabase
      .from("policy")
      .select("id, name, description, provisional")
      .order("name");
    const pols = (data ?? []) as Policy[];
    return pols.sort(
      (a, b) => featuredRank(a.name) - featuredRank(b.name) || a.name.localeCompare(b.name)
    );
  } catch {
    return [];
  }
}

export default async function PoliticasPage() {
  const policies = await getPolicies();

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-slate-800">Políticas</h1>
        <p className="text-sm text-slate-500">
          Uma política é um conjunto de votações que, juntas, indicam uma posição
          sobre um assunto. A posição de cada parlamentar é a média de como
          votou nessas votações.
        </p>
      </div>

      <div className="grid gap-4 sm:grid-cols-2">
        {policies.map((pol) => (
          <Link
            key={pol.id}
            href={`/politicas/${pol.id}`}
            className="rounded-lg border border-slate-200 bg-white p-5 hover:border-brand-light hover:shadow-sm"
          >
            <div className="flex items-center gap-2">
              <p className="font-semibold text-slate-800">{pol.name}</p>
              {featuredRank(pol.name) < 99 && (
                <span className="rounded bg-amber-100 px-2 py-0.5 text-xs font-medium text-amber-700">
                  Destaque
                </span>
              )}
              {pol.provisional && (
                <span className="rounded bg-amber-100 px-2 py-0.5 text-xs text-amber-700">
                  provisório
                </span>
              )}
            </div>
            {pol.description && (
              <p className="mt-2 text-base leading-relaxed text-slate-600">{pol.description}</p>
            )}
          </Link>
        ))}
      </div>

      {policies.length === 0 && (
        <p className="text-slate-500">Nenhuma política publicada ainda.</p>
      )}
    </div>
  );
}

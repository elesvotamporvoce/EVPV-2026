import Link from "next/link";
import { supabase } from "@/lib/supabase";
import { featuredRank } from "@/lib/format";
import type { Policy } from "@/lib/types";

export const revalidate = 900;
export const metadata = { title: "Políticas" };

async function getPolicies(): Promise<Policy[]> {
  try {
    const { data } = await supabase
      .from("policy")
      .select("id, name, description, quiz_hook, provisional")
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
        <h1 className="text-2xl font-bold text-brand">Políticas</h1>
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
            className="rounded-lg border border-brand-light bg-white p-5 hover:border-brand hover:shadow-sm"
          >
            <div className="rounded-md bg-violet-100 px-3 py-2 text-center">
              <p className="font-semibold text-slate-800">
                {pol.name}
                {pol.provisional && (
                  <span className="ml-2 rounded bg-amber-100 px-2 py-0.5 align-middle text-xs font-normal text-amber-700">
                    provisório
                  </span>
                )}
              </p>
            </div>
            {(pol.quiz_hook ?? pol.description) && (
              <p className="mt-3 text-center text-base leading-relaxed text-slate-600">
                {pol.quiz_hook ?? pol.description}
              </p>
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

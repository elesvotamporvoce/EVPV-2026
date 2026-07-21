import Link from "next/link";
import { notFound } from "next/navigation";
import { supabase } from "@/lib/supabase";
import { HOUSE_LABEL, VOTE_LABEL, fmtDate } from "@/lib/format";
import type { DivisionVote } from "@/lib/types";

export const revalidate = 3600;

type Prop = { sigla: string; numero: string; ano: string; ementa: string | null };

async function getDivision(id: number) {
  const [{ data: div }, { data: votes }] = await Promise.all([
    supabase
      .from("division")
      .select(
        "id, house, external_id, occurred_at, description, result_approved, proposition:proposition_id(sigla,numero,ano,ementa)"
      )
      .eq("id", id)
      .maybeSingle(),
    supabase.from("division_vote").select("*").eq("division_id", id),
  ]);
  return { div, votes: (votes ?? []) as DivisionVote[] };
}

export default async function DivisionPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id: idParam } = await params;
  const id = Number(idParam);
  if (!Number.isFinite(id)) notFound();
  const { div, votes } = await getDivision(id);
  if (!div) notFound();

  const prop =
    (Array.isArray(div.proposition)
      ? (div.proposition[0] as Prop | undefined)
      : (div.proposition as unknown as Prop | null)) ?? null;

  const counts: Record<string, number> = {};
  const byParty: Record<string, Record<string, number>> = {};
  for (const v of votes) {
    counts[v.option] = (counts[v.option] ?? 0) + 1;
    const p = v.party_sigla ?? "—";
    byParty[p] = byParty[p] ?? {};
    byParty[p][v.option] = (byParty[p][v.option] ?? 0) + 1;
  }
  const orderedVotes = [...votes].sort((a, b) => {
    const pa = a.party_sigla ?? "";
    const pb = b.party_sigla ?? "";
    return pa === pb ? a.name.localeCompare(b.name) : pa.localeCompare(pb);
  });
  const parties = Object.keys(byParty).sort();

  return (
    <div className="space-y-8">
      <Link href="/politicas" className="text-sm text-brand hover:underline">
        &larr; Políticas
      </Link>

      <div>
        {prop && (
          <p className="text-sm font-medium text-brand">
            {prop.sigla} {prop.numero}/{prop.ano}
          </p>
        )}
        <h1 className="mt-1 text-2xl font-bold text-slate-800">
          {div.description ?? `Votacao #${div.id}`}
        </h1>
        <p className="mt-1 text-sm text-slate-500">
          {fmtDate(div.occurred_at)} ·{" "}
          {HOUSE_LABEL[div.house as "camara" | "senado"]}
          {div.result_approved !== null && (
            <>
              {" · "}
              <span className={div.result_approved ? "text-green-700" : "text-red-700"}>
                {div.result_approved ? "Aprovada" : "Rejeitada"}
              </span>
            </>
          )}
        </p>
        {prop?.ementa && (
          <p className="mt-3 max-w-3xl rounded-lg bg-white p-4 text-sm text-slate-600 ring-1 ring-slate-200">
            {prop.ementa}
          </p>
        )}
      </div>

      <section className="flex flex-wrap gap-3">
        {["sim", "nao", "abstencao", "obstrucao", "ausente"].map((opt) =>
          counts[opt] ? (
            <div
              key={opt}
              className="rounded-lg border border-slate-200 bg-white px-4 py-2 text-center"
            >
              <p className="text-xl font-bold text-slate-800">{counts[opt]}</p>
              <p className="text-xs text-slate-500">{VOTE_LABEL[opt] ?? opt}</p>
            </div>
          ) : null
        )}
      </section>

      <section>
        <h2 className="mb-3 text-lg font-semibold text-slate-800">Por partido</h2>
        <div className="overflow-hidden rounded-lg border border-slate-200 bg-white">
          <table className="w-full text-sm">
            <thead className="bg-slate-50 text-left text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-2">Partido</th>
                <th className="px-3 py-2 text-right">Sim</th>
                <th className="px-3 py-2 text-right">Nao</th>
                <th className="px-3 py-2 text-right">Outros</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {parties.map((p) => {
                const c = byParty[p];
                const outros =
                  Object.values(c).reduce((a, b) => a + b, 0) -
                  (c.sim ?? 0) -
                  (c.nao ?? 0);
                return (
                  <tr key={p} className="hover:bg-slate-50">
                    <td className="px-4 py-2 font-medium text-slate-700">{p}</td>
                    <td className="px-3 py-2 text-right text-green-700">{c.sim ?? 0}</td>
                    <td className="px-3 py-2 text-right text-red-700">{c.nao ?? 0}</td>
                    <td className="px-3 py-2 text-right text-slate-400">{outros}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </section>

      <section>
        <h2 className="mb-3 text-lg font-semibold text-slate-800">
          Como cada um votou ({votes.length})
        </h2>
        <div className="grid gap-2 sm:grid-cols-2">
          {orderedVotes.map((v) => (
            <Link
              key={v.person_id}
              href={`/pessoas/${v.person_id}`}
              className="flex items-center justify-between gap-2 rounded border border-slate-200 bg-white px-3 py-2 text-sm hover:bg-slate-50"
            >
              <span className="min-w-0 truncate">
                <span className="text-slate-700">{v.name}</span>{" "}
                <span className="text-xs text-slate-400">
                  {v.party_sigla ?? "—"}
                  {v.uf ? `/${v.uf}` : ""}
                </span>
              </span>
              <VoteChip option={v.option} />
            </Link>
          ))}
        </div>
      </section>
    </div>
  );
}

function VoteChip({ option }: { option: string }) {
  const map: Record<string, string> = {
    sim: "bg-green-100 text-green-800",
    nao: "bg-red-100 text-red-800",
  };
  const cls = map[option] ?? "bg-slate-100 text-slate-600";
  return (
    <span className={`shrink-0 rounded px-2 py-0.5 text-xs font-medium ${cls}`}>
      {VOTE_LABEL[option] ?? option}
    </span>
  );
}

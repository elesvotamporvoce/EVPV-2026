import Link from "next/link";
import { notFound } from "next/navigation";
import { supabase } from "@/lib/supabase";
import ScoreBadge from "@/components/ScoreBadge";
import { HOUSE_LABEL, fmtDate } from "@/lib/format";
import type { Policy, PartyPolicyAgreement, ScoreNamed } from "@/lib/types";

export const revalidate = 3600;

type Div = {
  policy_id: number;
  stance: string;
  strength: string;
  division_id: number;
  description: string | null;
  occurred_at: string | null;
  house: "camara" | "senado";
  result_approved: boolean | null;
};

async function getPolicy(id: number) {
  const [{ data: pol }, { data: parties }, { data: top }, { data: bottom }, { data: divs }] =
    await Promise.all([
      supabase.from("policy").select("*").eq("id", id).maybeSingle(),
      supabase
        .from("party_policy_agreement")
        .select("*")
        .eq("policy_id", id)
        .order("avg_score", { ascending: false }),
      supabase
        .from("score_named")
        .select("*")
        .eq("policy_id", id)
        .neq("category", "not_enough")
        .order("score", { ascending: false })
        .limit(10),
      supabase
        .from("score_named")
        .select("*")
        .eq("policy_id", id)
        .neq("category", "not_enough")
        .order("score", { ascending: true })
        .limit(10),
      supabase
        .from("policy_division_detail")
        .select("*")
        .eq("policy_id", id)
        .order("occurred_at", { ascending: false }),
    ]);
  return {
    pol: pol as Policy | null,
    parties: (parties ?? []) as PartyPolicyAgreement[],
    top: (top ?? []) as ScoreNamed[],
    bottom: (bottom ?? []) as ScoreNamed[],
    divs: (divs ?? []) as Div[],
  };
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const { data } = await supabase
    .from("policy")
    .select("name")
    .eq("id", Number(id))
    .maybeSingle();
  return { title: data?.name ?? "Política" };
}

export default async function PolicyPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id: idParam } = await params;
  const id = Number(idParam);
  if (!Number.isFinite(id)) notFound();
  const { pol, parties, top, bottom, divs } = await getPolicy(id);
  if (!pol) notFound();

  return (
    <div className="space-y-8">
      <Link href="/politicas" className="text-sm text-brand hover:underline">
        ← Todas as políticas
      </Link>

      <div>
        <h1 className="text-2xl font-bold text-slate-800">{pol.name}</h1>
        {pol.description && (
          <p className="mt-2 max-w-3xl text-slate-600">{pol.description}</p>
        )}
      </div>

      {/* Ranking por partido */}
      <section>
        <h2 className="mb-3 text-lg font-semibold text-slate-800">
          Posição por partido
        </h2>
        <div className="overflow-hidden rounded-lg border border-slate-200 bg-white">
          <table className="w-full text-sm">
            <thead className="bg-slate-50 text-left text-xs uppercase text-slate-500">
              <tr>
                <th className="px-4 py-2">Partido</th>
                <th className="px-4 py-2">Parlamentares</th>
                <th className="px-4 py-2 text-right">Posição média</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {parties.map((p) => (
                <tr key={p.party_id} className="hover:bg-slate-50">
                  <td className="px-4 py-2">
                    <Link
                      href={`/partidos/${p.party_id}`}
                      className="font-medium text-brand hover:underline"
                    >
                      {p.party_sigla}
                    </Link>
                  </td>
                  <td className="px-4 py-2 text-slate-500">{p.n_people}</td>
                  <td className="px-4 py-2 text-right">
                    <ScoreBadge score={p.avg_score} category="" small />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      {/* Mais a favor / mais contra */}
      <section className="grid gap-6 lg:grid-cols-2">
        <RankList title="Mais a favor" rows={top} />
        <RankList title="Mais contra" rows={bottom} />
      </section>

      {/* Votações que compõem a política */}
      <section>
        <h2 className="mb-3 text-lg font-semibold text-slate-800">
          Votações consideradas ({divs.length})
        </h2>
        <div className="divide-y divide-slate-100 rounded-lg border border-slate-200 bg-white">
          {divs.map((d) => (
            <Link
              key={d.division_id}
              href={`/votacoes/${d.division_id}`}
              className="flex items-start justify-between gap-4 p-4 hover:bg-slate-50"
            >
              <div className="min-w-0">
                <p className="truncate text-sm text-slate-700">
                  {d.description ?? `Votação #${d.division_id}`}
                </p>
                <p className="text-xs text-slate-400">
                  {fmtDate(d.occurred_at)} · {HOUSE_LABEL[d.house]}
                </p>
              </div>
              <StanceChip stance={d.stance} strength={d.strength} />
            </Link>
          ))}
        </div>
      </section>
    </div>
  );
}

function RankList({ title, rows }: { title: string; rows: ScoreNamed[] }) {
  return (
    <div>
      <h3 className="mb-2 font-semibold text-slate-700">{title}</h3>
      <div className="divide-y divide-slate-100 rounded-lg border border-slate-200 bg-white">
        {rows.map((r) => (
          <Link
            key={r.person_id}
            href={`/pessoas/${r.person_id}`}
            className="flex items-center justify-between gap-3 p-3 hover:bg-slate-50"
          >
            <span className="min-w-0">
              <span className="block truncate text-sm font-medium text-slate-700">
                {r.person_name}
              </span>
              <span className="text-xs text-slate-400">
                {r.party_sigla ?? "—"}
                {r.uf ? ` · ${r.uf}` : ""}
              </span>
            </span>
            <ScoreBadge score={r.score} category={r.category} small />
          </Link>
        ))}
        {rows.length === 0 && (
          <p className="p-3 text-sm text-slate-500">Sem dados.</p>
        )}
      </div>
    </div>
  );
}

function StanceChip({ stance, strength }: { stance: string; strength: string }) {
  const forStance = stance === "for";
  return (
    <span
      className={`shrink-0 rounded px-2 py-0.5 text-xs font-medium ${
        forStance ? "bg-green-100 text-green-800" : "bg-red-100 text-red-800"
      }`}
      title={strength === "strong" ? "Peso maior" : "Peso normal"}
    >
      {forStance ? "Sim = a favor" : "Sim = contra"}
      {strength === "strong" ? " ★" : ""}
    </span>
  );
}

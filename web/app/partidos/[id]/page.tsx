import Link from "next/link";
import { notFound } from "next/navigation";
import { supabase } from "@/lib/supabase";
import ScoreBadge from "@/components/ScoreBadge";
import PersonCard from "@/components/PersonCard";
import type { PartyPolicyAgreement, PersonDir } from "@/lib/types";

export const revalidate = 3600;

async function getParty(id: number) {
  const [{ data: party }, { data: agr }, { data: members }] = await Promise.all([
    supabase.from("party").select("id, sigla, name").eq("id", id).maybeSingle(),
    supabase
      .from("party_policy_agreement")
      .select("*")
      .eq("party_id", id)
      .order("policy_name"),
    supabase
      .from("person_directory")
      .select("*")
      .eq("party_id", id)
      .order("name"),
  ]);
  return {
    party,
    agr: (agr ?? []) as PartyPolicyAgreement[],
    members: (members ?? []) as PersonDir[],
  };
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const { data } = await supabase
    .from("party")
    .select("sigla")
    .eq("id", Number(id))
    .maybeSingle();
  return { title: data?.sigla ? `Partido ${data.sigla}` : "Partido" };
}

export default async function PartyPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id: idParam } = await params;
  const id = Number(idParam);
  if (!Number.isFinite(id)) notFound();
  const { party, agr, members } = await getParty(id);
  if (!party) notFound();

  return (
    <div className="space-y-8">
      <Link href="/pessoas" className="text-sm text-brand hover:underline">
        ← Parlamentares
      </Link>

      <div>
        <h1 className="text-2xl font-bold text-slate-800">{party.sigla}</h1>
        {party.name && <p className="text-slate-500">{party.name}</p>}
        <p className="mt-1 text-sm text-slate-500">
          {members.length} parlamentares
        </p>
      </div>

      {agr.length > 0 && (
        <section>
          <h2 className="mb-3 text-lg font-semibold text-slate-800">
            Posição do partido por política
          </h2>
          <div className="divide-y divide-slate-100 rounded-lg border border-slate-200 bg-white">
            {agr.map((a) => (
              <Link
                key={a.policy_id}
                href={`/politicas/${a.policy_id}`}
                className="flex items-center justify-between gap-4 p-4 hover:bg-slate-50"
              >
                <span className="font-medium text-slate-700">
                  {a.policy_name}
                </span>
                <ScoreBadge score={a.avg_score} category="" small />
              </Link>
            ))}
          </div>
        </section>
      )}

      <section>
        <h2 className="mb-3 text-lg font-semibold text-slate-800">Membros</h2>
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          {members.map((p) => (
            <PersonCard key={p.id} p={p} />
          ))}
        </div>
      </section>
    </div>
  );
}

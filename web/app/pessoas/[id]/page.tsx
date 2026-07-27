import Link from "next/link";
import { notFound } from "next/navigation";
import { supabase } from "@/lib/supabase";
import PositionBar from "@/components/PositionBar";
import VoteChip from "@/components/VoteChip";
import { CARGO_LABEL, HOUSE_LABEL, MANDATE_CLASS, MANDATE_LABEL, categoryLabel, featuredRank, fmtDate, scoreColor, supportTip } from "@/lib/format";
import type { PersonDir, ScoreNamed, PersonVote, Participation } from "@/lib/types";

export const revalidate = 3600;

async function getPerson(id: number) {
  const [{ data: dir }, { data: part }, { data: scores }, { data: votes }] =
    await Promise.all([
      supabase.from("person_directory").select("*").eq("id", id).maybeSingle(),
      supabase
        .from("person_participation")
        .select("*")
        .eq("person_id", id)
        .maybeSingle(),
      supabase
        .from("score_named")
        .select("*")
        .eq("person_id", id)
        .order("score", { ascending: false }),
      supabase
        .from("person_vote")
        .select("*")
        .eq("person_id", id)
        .order("occurred_at", { ascending: false })
        .limit(10),
    ]);
  return {
    dir: dir as PersonDir | null,
    part: part as Participation | null,
    scores: (scores ?? []) as ScoreNamed[],
    votes: (votes ?? []) as PersonVote[],
  };
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const { data } = await supabase
    .from("person_directory")
    .select("name, party_sigla")
    .eq("id", Number(id))
    .maybeSingle();
  return { title: data?.name ?? "Parlamentar" };
}

export default async function PersonPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id: idParam } = await params;
  const id = Number(idParam);
  if (!Number.isFinite(id)) notFound();
  const { dir, part, scores, votes } = await getPerson(id);
  if (!dir) notFound();

  // Senadores: como ha poucos temas com voto aberto no Senado, mostramos
  // TODAS as politicas; as sem dados ganham aviso + referencia do partido
  let allScores = scores;
  if (dir.house === "senado") {
    const { data: allPols } = await supabase
      .from("policy")
      .select("id, name")
      .order("name");
    const have = new Set(scores.map((s) => s.policy_id));
    const extras = ((allPols ?? []) as { id: number; name: string }[])
      .filter((p) => !have.has(p.id))
      .map(
        (p) =>
          ({
            policy_id: p.id,
            policy_name: p.name,
            category: "not_enough",
            score: 0,
          }) as unknown as ScoreNamed
      );
    allScores = [...scores, ...extras];
  }

  const sortedScores = [...allScores].sort(
    (a, b) =>
      featuredRank(a.policy_name) - featuredRank(b.policy_name) ||
      b.score - a.score
  );
  const presPct =
    part && part.eligible > 0
      ? Math.round((100 * part.n_votes) / part.eligible)
      : null;

  const anoInicio = part?.first_vote
    ? new Date(part.first_vote).getFullYear()
    : null;
  const anos = anoInicio ? new Date().getFullYear() - anoInicio : null;
  const anoFim = part?.last_vote ? new Date(part.last_vote).getFullYear() : null;

  // Média do partido por política (contexto quando faltam votos individuais)
  let partyAvg = new Map<number, number>();
  if (dir.party_id) {
    const { data: ppa } = await supabase
      .from("party_policy_agreement")
      .select("policy_id, avg_score")
      .eq("party_id", dir.party_id);
    partyAvg = new Map(
      ((ppa ?? []) as { policy_id: number; avg_score: number }[]).map((r) => [
        r.policy_id,
        r.avg_score,
      ])
    );
  }

  // Resumo por política quando não há votos suficientes (evita "punir" sem contexto)
  const notEnoughIds = allScores
    .filter((s) => s.category === "not_enough")
    .map((s) => s.policy_id);
  const breakdown = new Map<number, string>();
  if (notEnoughIds.length) {
    const { data: pdd } = await supabase
      .from("policy_division_detail")
      .select("policy_id, division_id, stance, house")
      .in("policy_id", notEnoughIds);
    const pddRows = (
      (pdd ?? []) as { policy_id: number; division_id: number; stance: string; house: string }[]
    ).filter((r) => r.house === dir.house);
    const divIds = [...new Set(pddRows.map((r) => r.division_id))];
    let pvRows: { division_id: number; option: string }[] = [];
    if (divIds.length) {
      const { data: pv } = await supabase
        .from("person_vote")
        .select("division_id, option")
        .eq("person_id", id)
        .in("division_id", divIds);
      pvRows = (pv ?? []) as { division_id: number; option: string }[];
    }
    const voteBy = new Map(pvRows.map((v) => [v.division_id, v.option]));
    for (const polId of notEnoughIds) {
      let aFavor = 0;
      let contra = 0;
      let ausente = 0;
      let outros = 0;
      for (const r of pddRows.filter((x) => x.policy_id === polId)) {
        const opt = voteBy.get(r.division_id);
        if (!opt || opt === "ausente") ausente += 1;
        else if (opt === "sim") {
          if (r.stance === "for") aFavor += 1;
          else contra += 1;
        } else if (opt === "nao") {
          if (r.stance === "for") contra += 1;
          else aFavor += 1;
        } else outros += 1;
      }
      const vt = (n: number) => (n === 1 ? "1 votação" : `${n} votações`);
      const parts: string[] = [];
      if (aFavor) parts.push(`votou a favor da política em ${vt(aFavor)}`);
      if (contra) parts.push(`votou contra em ${vt(contra)}`);
      if (outros) parts.push(`registrou abstenção ou outro voto em ${vt(outros)}`);
      if (ausente) parts.push(`esteve ausente em ${vt(ausente)}`);
      if (parts.length) {
        const txt =
          parts.length > 1
            ? parts.slice(0, -1).join(", ") + " e " + parts[parts.length - 1]
            : parts[0];
        breakdown.set(polId, txt.charAt(0).toUpperCase() + txt.slice(1) + ".");
      }
    }
  }

  return (
    <div className="space-y-8">
      <Link href="/pessoas" className="text-sm text-brand hover:underline">
        ← Todos os parlamentares
      </Link>

      {/* Cabeçalho (o wrapper cria um fundo cheio para o conteúdo não aparecer
          nas bordas da caixa durante o scroll) */}
      <div className="sticky top-0 z-20 -mx-4 bg-slate-50 px-4 pb-2 pt-3">
      <div className="flex flex-col gap-4 rounded-lg border border-slate-200 bg-white p-6 shadow-sm sm:flex-row sm:items-center">
        <div className="h-24 w-24 shrink-0 overflow-hidden rounded-full bg-slate-100">
          {dir.photo_url ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={dir.photo_url} alt={dir.name} className="h-full w-full object-cover" />
          ) : (
            <div className="flex h-full w-full items-center justify-center text-2xl text-slate-400">
              {dir.name?.[0]}
            </div>
          )}
        </div>
        <div className="flex-1">
          <h1 className="text-2xl font-bold text-slate-800">{dir.name}</h1>
          <div className="mt-1.5 space-y-1.5">
          <p className="text-slate-500">
            {dir.party_sigla ?? "sem partido"}
            {dir.uf ? ` · ${dir.uf}` : ""} · {CARGO_LABEL[dir.house]}
          </p>
          {anoInicio && (
            <p className="text-sm text-slate-500">
              {dir.mandate_status === "fora" && anoFim
                ? `No cargo de ${anoInicio} até ${anoFim}`
                : `No cargo desde ${anoInicio} (${anos} ${anos === 1 ? "ano" : "anos"})`}
            </p>
          )}
          {dir.mandate_status && (
            <p className="text-sm">
              <span className={`font-semibold ${MANDATE_CLASS[dir.mandate_status] ?? "text-slate-500"}`}>
                Mandato: {MANDATE_LABEL[dir.mandate_status] ?? dir.mandate_status}
              </span>
              {dir.mandate_detail && (
                <span className="text-slate-500"> · {dir.mandate_detail}</span>
              )}
            </p>
          )}
          </div>
        </div>
      </div>
      </div>

      {/* Políticas */}
      <section>
        <h2 className="mb-3 text-lg font-semibold text-slate-800">Políticas</h2>
        {dir.house === "senado" && (
          <div className="mb-4 rounded-lg border border-brand-light bg-violet-50 p-4 text-sm leading-relaxed text-slate-700">
            Quase metade das votações do Senado é secreta (sabatinas de
            autoridades, por exemplo): o painel registra que o senador votou,
            mas <strong>não revela o voto</strong>. Sem o voto de cada senador,
            não há como saber a posição individual e incluir essas sessões nas
            políticas. Por isso, senadores costumam ter menos políticas com
            posição do que deputados.
          </div>
        )}
        {sortedScores.length === 0 ? (
          <p className="text-sm text-slate-500">
            Ainda não há políticas com votos suficientes para este parlamentar.
          </p>
        ) : (
          <div className="space-y-3">
            {sortedScores.map((s) => (
              <Link
                key={s.policy_id}
                href={`/politicas/${s.policy_id}?pessoa=${id}`}
                className="block rounded-xl border border-slate-200 bg-white p-5 hover:border-brand-light hover:shadow-sm"
              >
                <p className="mb-3.5 text-center text-[22px] font-semibold leading-snug text-slate-800">
                  {s.policy_name}
                  {s.category !== "not_enough" && (
                    <>
                      {" "}-{" "}
                      <span style={{ color: scoreColor(s.score) }}>
                        {categoryLabel(s.category)}
                      </span>
                    </>
                  )}
                  {s.category === "not_enough" && (
                    <>
                      {" "}-{" "}
                      <span className="text-slate-400">Sem votos suficientes</span>
                    </>
                  )}
                </p>
                {s.category === "not_enough" && breakdown.get(s.policy_id) && (
                  <p className="-mt-2 mb-1.5 text-center text-sm leading-relaxed text-slate-500">
                    {breakdown.get(s.policy_id)} Poucas votações para atribuir
                    uma posição.
                  </p>
                )}
                {s.category === "not_enough" &&
                  dir.party_sigla &&
                  partyAvg.has(s.policy_id) && (
                    <p className="mb-3 text-center text-sm text-slate-500">
                      Como referência, a média do {dir.party_sigla} é{" "}
                      {supportTip(partyAvg.get(s.policy_id)!)}.
                    </p>
                  )}
                <PositionBar
                  score={s.category === "not_enough" ? null : s.score}
                  category={s.category}
                  showLabel={false}
                />
              </Link>
            ))}
          </div>
        )}
      </section>

      {/* Presença nas votações */}
      {part &&
        part.eligible >= 10 &&
        part.n_votes > 0 &&
        (() => {
          const faltas = Math.max(0, part.eligible - part.n_votes);
          const ausPct = Math.round((100 * faltas) / part.eligible);
          const muito = ausPct > 50;
          const saiu = dir.mandate_status === "fora";
          return (
            <section>
              <div
                className={`rounded-lg border p-5 ${
                  muito
                    ? "border-amber-300 bg-amber-50"
                    : "border-slate-200 bg-white"
                }`}
              >
                <h2 className="text-lg font-semibold text-slate-800">
                  Presença nas votações
                </h2>
                <p className="mt-1.5 text-slate-700">
                  Faltou em{" "}
                  <span className={muito ? "font-bold text-amber-700" : "font-semibold"}>
                    {faltas.toLocaleString("pt-BR")} de{" "}
                    {part.eligible.toLocaleString("pt-BR")} sessões
                  </span>{" "}
                  ({ausPct}% de ausência
                  {saiu ? ", no período em que exerceu o mandato" : ""}).
                </p>
                {muito && (
                  <p className="mt-1.5 text-sm text-amber-800">
                    Faltou à maioria das votações. O papel de quem foi eleito é
                    votar.
                  </p>
                )}
                <p className="mt-2 text-xs text-slate-400">
                  Considera as votações nominais da casa durante o mandato; votos
                  secretos contam como participação. Critério completo em{" "}
                  <Link href="/como-funciona" className="text-brand hover:underline">
                    Como funciona
                  </Link>
                  .
                </p>
              </div>
            </section>
          );
        })()}

      {/* Votos recentes */}
      <section>
        <h2 className="mb-3 text-lg font-semibold text-slate-800">
          Votos mais recentes
        </h2>
        <div className="divide-y divide-slate-100 rounded-lg border border-slate-200 bg-white">
          {votes.map((v) => (
            <Link
              key={v.division_id}
              href={`/votacoes/${v.division_id}`}
              className="flex items-start justify-between gap-4 p-4 hover:bg-slate-50"
            >
              <div className="min-w-0">
                <p className="truncate text-sm text-slate-700">
                  {v.description ?? `Votação #${v.division_id}`}
                </p>
                <p className="text-xs text-slate-400">
                  {fmtDate(v.occurred_at)} · {HOUSE_LABEL[v.house]}
                </p>
              </div>
              <VoteChip option={v.option} />
            </Link>
          ))}
          {votes.length === 0 && (
            <p className="p-4 text-sm text-slate-500">Sem votos registrados.</p>
          )}
        </div>
      </section>

    </div>
  );
}

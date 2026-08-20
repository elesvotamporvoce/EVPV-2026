import Link from "next/link";
import { notFound } from "next/navigation";
import { supabase } from "@/lib/supabase";
import Voltar from "@/components/Voltar";
import PositionBar from "@/components/PositionBar";
import VoteChip from "@/components/VoteChip";
import SeloCandidato from "@/components/SeloCandidato";
import { CARGO_LABEL, HOUSE_LABEL, MANDATE_CLASS, MANDATE_LABEL, categoryLabel, featuredRank, fmtDate, scoreColor, supportTip } from "@/lib/format";
import type { PersonDir, ScoreNamed, PersonVote, Participation } from "@/lib/types";

export const revalidate = 3600;
// Esta pagina e dinamica (le params/searchParams), entao nao fica no
// cache de pagina. Sem a linha abaixo, as consultas ao Supabase caem no
// Data Cache do Next, que sobrevive a deploy e nao e limpo pelo
// revalidatePath de rota dinamica — foi assim que o placar da P15 ficou
// horas mostrando o numero antigo. Com no-store, sempre le o banco.
export const fetchCache = "default-no-store";

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

  const { data: candRow } = await supabase
    .from("candidatura_2026")
    .select("cargo, uf, situacao, patrimonio_total")
    .eq("person_id", id)
    .maybeSingle();
  const cand = candRow as {
    cargo: string | null;
    uf: string | null;
    situacao: string | null;
    patrimonio_total: number | null;
  } | null;
  const brl = (v: number) =>
    v.toLocaleString("pt-BR", { style: "currency", currency: "BRL", maximumFractionDigits: 0 });

  // Senadores: mostramos APENAS as politicas que tiveram votacao no Senado.
  // As demais so foram votadas na Camara — o senador nunca teve a chance de se
  // posicionar, e exibi-las como "sem votos suficientes" sugeriria falta onde
  // houve ausencia de oportunidade.
  // Dentro das que o Senado votou, ainda completamos com as que este senador
  // nao votou o bastante: ai "sem votos suficientes" e a leitura correta.
  let allScores = scores;
  let soNaCamara: { id: number; name: string }[] = [];
  if (dir.house === "senado") {
    const { data: senDivs } = await supabase
      .from("policy_division_detail")
      .select("policy_id, house")
      .eq("house", "senado");
    const idsSenado = [
      ...new Set(((senDivs ?? []) as { policy_id: number }[]).map((r) => r.policy_id)),
    ];
    const { data: todasPols } = await supabase
      .from("policy")
      .select("id, name")
      .order("name");
    const allPols = ((todasPols ?? []) as { id: number; name: string }[]).filter(
      (p) => idsSenado.includes(p.id)
    );
    // Temas que o Senado nao votou: viram uma nota no fim, nao blocos vazios.
    soNaCamara = ((todasPols ?? []) as { id: number; name: string }[]).filter(
      (p) => !idsSenado.includes(p.id)
    );
    const have = new Set(scores.map((s) => s.policy_id));
    const extras = allPols
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
      (a.category === "not_enough" ? 1 : 0) - (b.category === "not_enough" ? 1 : 0) ||
      featuredRank(a.policy_name) - featuredRank(b.policy_name) ||
      b.score - a.score
  );
  const presPct =
    part && part.eligible > 0
      ? Math.round((100 * part.n_votes) / part.eligible)
      : null;

  // Presenca nas votacoes: calculada aqui porque agora mora dentro do
  // "Mais informacoes" do cabecalho, e nao mais numa secao no fim da pagina.
  const presenca =
    part && part.eligible >= 10 && part.n_votes > 0
      ? (() => {
          const faltas = Math.max(0, part.eligible - part.n_votes);
          const ausPct = Math.round((100 * faltas) / part.eligible);
          // Votações que caíram dentro de uma licença (ministério, saúde,
          // maternidade, missão oficial) já saíram do denominador na view.
          const afastado = part.votacoes_afastado ?? 0;
          return {
            faltas,
            ausPct,
            afastado,
            // O aviso duro só aparece quando a ausência é do parlamentar em
            // exercício. Enquanto a tabela de licenças não estiver carregada
            // (afastado === 0 para todo mundo), preferimos NÃO acusar: já
            // erramos ao chamar de faltoso quem estava licenciado.
            muito: ausPct > 50 && afastado > 0,
            sufixo:
              dir.mandate_status === "fora"
                ? ", no período em que exerceu o mandato"
                : dir.mandate_status === "licenciado"
                  ? ", contando até sair de licença"
                  : "",
          };
        })()
      : null;

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
  const breakdown = new Map<number, { kind: "for" | "against" | "plain"; text: string }[]>();
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
      // Segmentos tipados para o render colorir "a favor" e "contra".
      const parts: { kind: "for" | "against" | "plain"; text: string }[] = [];
      if (aFavor) parts.push({ kind: "for", text: `votou a favor da política em ${vt(aFavor)}` });
      if (contra) parts.push({ kind: "against", text: `votou contra em ${vt(contra)}` });
      if (outros) parts.push({ kind: "plain", text: `registrou abstenção ou outro voto em ${vt(outros)}` });
      if (ausente) parts.push({ kind: "plain", text: `esteve ausente em ${vt(ausente)}` });
      if (parts.length) {
        parts[0] = {
          ...parts[0],
          text: parts[0].text.charAt(0).toUpperCase() + parts[0].text.slice(1),
        };
        breakdown.set(polId, parts);
      }
    }
  }

  return (
    <div className="space-y-8">
<Voltar fallback="/pessoas" />

      {/* Cabeçalho (o wrapper cria um fundo cheio para o conteúdo não aparecer
          nas bordas da caixa durante o scroll) */}
      <div className="sticky top-[58px] z-20 -mx-4 bg-slate-50 px-4 pb-2 pt-3">
      <div className="relative flex flex-col items-center gap-4 rounded-lg border border-slate-200 bg-white p-6 text-center shadow-sm">
        {cand && (
          <Link
            href="/eleicoes-2026"
            className="absolute -right-3 -top-3"
            title={
              cand.cargo
                ? `Candidatura registrada: ${cand.cargo}`
                : "Candidatura registrada para 2026"
            }
          >
            <SeloCandidato />
          </Link>
        )}
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
        <div className="w-full flex-1">
          <h1 className="text-2xl font-bold text-slate-800">{dir.name}</h1>
          {/* Visivel sempre: quem e, de onde e, e se esta no exercicio do
              mandato. Tudo o mais fica atras de "Mais informacoes" — o
              cabecalho e sticky, entao quanto menor, mais politica cabe na
              tela. */}
          <div className="mt-1.5 space-y-1.5">
            <p className="text-slate-500">
              {dir.party_sigla ?? "sem partido"}
              {dir.uf ? ` · ${dir.uf}` : ""} · {CARGO_LABEL[dir.house]}
            </p>
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

          {((cand && cand.patrimonio_total != null) || presenca) && (
            <details className="group mt-3 border-t border-slate-100 pt-2.5 text-left">
              <summary className="flex cursor-pointer list-none items-center justify-center gap-1.5 text-sm font-medium text-brand [&::-webkit-details-marker]:hidden">
                Mais informações
                <svg
                  viewBox="0 0 20 20"
                  fill="currentColor"
                  aria-hidden="true"
                  className="h-4 w-4 shrink-0 transition-transform duration-200 group-open:rotate-180"
                >
                  <path
                    fillRule="evenodd"
                    d="M5.23 7.21a.75.75 0 0 1 1.06.02L10 11.17l3.71-3.94a.75.75 0 1 1 1.08 1.04l-4.25 4.5a.75.75 0 0 1-1.08 0l-4.25-4.5a.75.75 0 0 1 .02-1.06Z"
                    clipRule="evenodd"
                  />
                </svg>
              </summary>
              <div className="mt-2.5 space-y-1.5 text-center">
                {cand && cand.patrimonio_total != null && (
                  <p className="text-sm text-slate-500">
                    Patrimônio declarado (candidatura 2026):{" "}
                    <span className="font-semibold text-slate-700">
                      {brl(cand.patrimonio_total)}
                    </span>
                  </p>
                )}
                {presenca && (
                  <div
                    className={`mt-2 rounded-lg border p-3 text-left ${
                      presenca.muito
                        ? "border-amber-300 bg-amber-50"
                        : "border-slate-200 bg-slate-50"
                    }`}
                  >
                    <p className="text-sm font-semibold text-slate-800">
                      Presença nas votações
                    </p>
                    <p className="mt-1 text-sm text-slate-700">
                      Faltou em{" "}
                      <span
                        className={
                          presenca.muito ? "font-bold text-amber-700" : "font-semibold"
                        }
                      >
                        {presenca.faltas.toLocaleString("pt-BR")} de{" "}
                        {part!.eligible.toLocaleString("pt-BR")} votações
                      </span>{" "}
                      ({presenca.ausPct}% de ausência
                      {presenca.sufixo}).
                    </p>
                    {presenca.muito && (
                      <p className="mt-1 text-sm text-amber-800">
                        Faltou à maioria das votações. O papel de quem foi
                        eleito é votar.
                      </p>
                    )}
                    {presenca.afastado > 0 && (
                      <p className="mt-1.5 text-sm text-slate-600">
                        Outras{" "}
                        <span className="font-semibold">
                          {presenca.afastado.toLocaleString("pt-BR")} votações
                        </span>{" "}
                        aconteceram enquanto estava licenciado do mandato e{" "}
                        <span className="font-semibold">não entram na conta</span>.
                      </p>
                    )}
                    <p className="mt-1.5 text-xs text-slate-400">
                      Conta as votações nominais da casa no período em que a
                      pessoa estava em exercício; votos secretos contam como
                      participação. Uma sessão costuma ter várias votações, então
                      este número é bem maior que o de dias de trabalho. Critério
                      completo em{" "}
                      <Link href="/sobre" className="text-brand hover:underline">
                        Sobre o site
                      </Link>
                      .
                    </p>
                  </div>
                )}
              </div>
            </details>
          )}
        </div>
      </div>
      </div>

      {/* Políticas */}
      <section>
        <h2 className="mb-3 text-lg font-semibold text-slate-800">Políticas</h2>
        {dir.house === "senado" && (
          <div className="mb-4 rounded-lg border border-brand-light bg-violet-50 p-4 text-sm leading-relaxed text-slate-700">
            Quase metade das votações do Senado é secreta. O painel registra
            que o senador votou, mas <strong>não revela o voto</strong>. Sem o
            voto de cada senador, não há como saber a posição individual e
            incluir essas votações nas políticas. Por isso, senadores costumam
            ter menos políticas com posição do que deputados.
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
                    {breakdown.get(s.policy_id)!.map((seg, i, arr) => (
                      <span key={i}>
                        <span
                          className={
                            seg.kind === "for"
                              ? "font-medium text-green-700"
                              : seg.kind === "against"
                                ? "font-medium text-red-700"
                                : undefined
                          }
                        >
                          {seg.text}
                        </span>
                        {i < arr.length - 2 ? ", " : i === arr.length - 2 ? " e " : "."}
                      </span>
                    ))}{" "}
                    Poucas votações para atribuir uma posição.
                  </p>
                )}
                {s.category === "not_enough" &&
                  dir.party_sigla &&
                  partyAvg.has(s.policy_id) && (
                    <p className="mb-3 text-center text-sm text-slate-500">
                      Como referência, a média do{" "}
                      <span className="font-semibold text-slate-600">
                        {dir.party_sigla}
                      </span>{" "}
                      nesta política é{" "}
                      <span className="font-semibold text-slate-600">
                        {supportTip(partyAvg.get(s.policy_id)!)}
                      </span>
                      .
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

        {soNaCamara.length > 0 && (
          <div className="mt-4 rounded-lg border border-slate-200 bg-slate-50 p-4 text-sm leading-relaxed text-slate-600">
            <p>
              Os outros {soNaCamara.length} temas do site foram votados{" "}
              <strong>apenas na Câmara</strong>. O Senado ainda não votou nenhum
              deles, então não há como registrar a posição de um senador:
            </p>
            <p className="mt-2">
              {soNaCamara.map((p, i) => (
                <span key={p.id}>
                  {i > 0 && ", "}
                  <Link
                    href={`/politicas/${p.id}`}
                    className="text-brand hover:underline"
                  >
                    {p.name}
                  </Link>
                </span>
              ))}
              .
            </p>
          </div>
        )}
      </section>

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

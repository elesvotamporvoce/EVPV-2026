import Link from "next/link";
import { supabase } from "@/lib/supabase";
import HomeSearch from "@/components/HomeSearch";
import BigNumbers from "@/components/BigNumbers";
import FeaturedRotator from "@/components/FeaturedRotator";
import SeloCandidato from "@/components/SeloCandidato";
import { CARGO_LABEL, FEATURED_POLICIES, featuredRank, scoreColor } from "@/lib/format";
import type { PartyPolicyAgreement, PersonDir, Policy } from "@/lib/types";

export const revalidate = 900;

type Trend = { policy: Policy; rows: PartyPolicyAgreement[] };

async function getData() {
  try {
    const [{ data: policies }, { count: people }, { count: divisions }] =
      await Promise.all([
        supabase
          .from("policy")
          .select("id, name, description, quiz_hook, provisional")
          .order("name"),
        supabase.from("person").select("id", { count: "exact", head: true }),
        supabase
          .from("division")
          .select("id", { count: "exact", head: true })
          .eq("is_nominal", true),
      ]);
    const pols = ((policies ?? []) as Policy[]).sort(
      (a, b) => featuredRank(a.name) - featuredRank(b.name) || a.name.localeCompare(b.name)
    );

    // Assuntos em alta: as 3 primeiras em destaque, com o retrato por partido
    const hot = pols.filter((p) => FEATURED_POLICIES.includes(p.name)).slice(0, 3);
    let trends: Trend[] = [];
    if (hot.length) {
      const { data: agr } = await supabase
        .from("party_policy_agreement")
        .select("*")
        .in("policy_id", hot.map((p) => p.id))
        .gte("n_people", 8)
        .order("avg_score", { ascending: false });
      const all = (agr ?? []) as PartyPolicyAgreement[];
      trends = hot.map((policy) => {
        const rows = all.filter((a) => a.policy_id === policy.id);
        const picks =
          rows.length <= 3
            ? rows
            : [rows[0], rows[Math.floor(rows.length / 2)], rows[rows.length - 1]];
        return { policy, rows: picks };
      });
    }
    // Recordistas do plenário
    type Rec = { label: string; value: string; person: PersonDir };
    let recordistas: Rec[] = [];
    const { data: partRows } = await supabase
      .from("person_participation")
      .select("person_id, n_votes, eligible");
    const rows = (partRows ?? []) as { person_id: number; n_votes: number; eligible: number }[];
    const qual = rows.filter((r) => r.eligible >= 200);
    if (qual.length) {
      const maisVotos = [...rows].sort((a, b) => b.n_votes - a.n_votes)[0];
      const maisPresente = [...qual].sort(
        (a, b) => b.n_votes / b.eligible - a.n_votes / a.eligible
      )[0];
      const maisAusente = [...qual].sort(
        (a, b) => a.n_votes / a.eligible - b.n_votes / b.eligible
      )[0];
      const ids = [maisVotos.person_id, maisPresente.person_id, maisAusente.person_id];
      const { data: ppl } = await supabase
        .from("person_directory")
        .select("*")
        .in("id", ids);
      const by = new Map(((ppl ?? []) as PersonDir[]).map((p) => [p.id, p]));
      const pct = (r: { n_votes: number; eligible: number }) =>
        Math.round((100 * r.n_votes) / r.eligible);
      recordistas = [
        {
          label: "Quem mais votou",
          value: maisVotos.n_votes.toLocaleString("pt-BR") + " votos",
          person: by.get(maisVotos.person_id) as PersonDir,
        },
        {
          label: "Maior presença nas votações",
          value: pct(maisPresente) + "%",
          person: by.get(maisPresente.person_id) as PersonDir,
        },
        {
          label: "Maior ausência nas votações",
          value: 100 - pct(maisAusente) + "%",
          person: by.get(maisAusente.person_id) as PersonDir,
        },
      ].filter((r) => r.person);
    }
    // Quem e candidato em 2026 (para o selo nos cards)
    const { data: candIds } = await supabase
      .from("candidatura_2026")
      .select("person_id");
    const candSet = new Set(
      ((candIds ?? []) as { person_id: number }[]).map((c) => c.person_id)
    );

    // Mais procurados (curadoria na tabela home_featured; futuramente analytics)
    type FeaturedCard = { person: PersonDir; nVotes: number | null; eligible: number | null };
    let procurados: FeaturedCard[] = [];
    const { data: hfRows } = await supabase
      .from("home_featured")
      .select("person_id, rank")
      .order("rank");
    const hf = (hfRows ?? []) as { person_id: number; rank: number }[];
    if (hf.length) {
      const fIds = hf.map((h) => h.person_id);
      const { data: fPpl } = await supabase
        .from("person_directory")
        .select("*")
        .in("id", fIds);
      const fById = new Map(((fPpl ?? []) as PersonDir[]).map((x) => [x.id, x]));
      const fPart = new Map(
        rows.filter((r) => fIds.includes(r.person_id)).map((r) => [r.person_id, r])
      );
      procurados = hf.flatMap((h) => {
        const person = fById.get(h.person_id);
        if (!person) return [];
        const pr = fPart.get(h.person_id);
        return [{
          person,
          nVotes: pr ? pr.n_votes : null,
          eligible: pr ? pr.eligible : null,
        }];
      });
    }

    return { policies: pols, trends, recordistas, procurados, candSet, people: people ?? 0, divisions: divisions ?? 0 };
  } catch {
    return {
      policies: [] as Policy[],
      trends: [] as Trend[],
      recordistas: [] as { label: string; value: string; person: PersonDir }[],
      procurados: [] as { person: PersonDir; nVotes: number | null; eligible: number | null }[],
      candSet: new Set<number>(),
      people: 0,
      divisions: 0,
    };
  }
}

export default async function Home() {
  const { policies, trends, recordistas, procurados, candSet, people, divisions } = await getData();

  return (
    <div className="space-y-12">
      <section className="home-hero relative left-1/2 -mt-8 w-screen -translate-x-1/2 bg-brand-ink text-white">
        <div className="mx-auto max-w-6xl px-4 py-16 text-center">
          <h1 className="text-4xl font-bold text-brand-light sm:text-5xl">
            Você sabia que seu político vota por você?
          </h1>
          <ol className="mx-auto mt-6 flex w-fit flex-col gap-2.5 text-left">
            {[
              "Você elege um deputado e um senador",
              "Eles votam sim ou não em projetos de lei",
              "O que passa vira regra para todo mundo",
            ].map((txt, i) => (
              <li key={txt} className="flex items-center gap-3">
                <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-brand-light/20 text-[13px] font-semibold text-brand-light">
                  {i + 1}
                </span>
                <span className="text-white/75">{txt}</span>
              </li>
            ))}
          </ol>
          <div className="mt-8">
            <HomeSearch />
          </div>
          <div className="mt-9">
            <p className="mb-2.5 text-sm text-white/60">
              Faça o teste e descubra quem pensa igual a você
            </p>
            <Link
              href="/seu-perfil"
              className="inline-block rounded-lg bg-brand px-7 py-3.5 text-lg font-semibold text-white shadow-lg shadow-brand/25 hover:bg-brand-dark"
            >
              Começar teste
            </Link>
          </div>
        </div>
      </section>

      {/* Destaque: Eleições 2026 */}
      <div className="flex justify-center">
        <Link
          href="/eleicoes-2026"
          className="rounded-xl bg-brand px-8 py-4 text-center text-lg font-semibold text-white shadow-lg shadow-brand/25 hover:bg-brand-dark"
        >
          Eleições 2026: Veja quem são os candidatos!
        </Link>
      </div>

      {procurados.length > 0 && (
        <section>
          <h2 className="mb-4 text-xl font-semibold text-slate-800">
            Mais procurados
          </h2>
          <FeaturedRotator>
            {procurados.map(({ person, nVotes, eligible }) => (
              <Link
                key={person.id}
                href={`/pessoas/${person.id}`}
                className="relative rounded-xl border border-slate-200 bg-white p-4 text-center hover:border-brand-light hover:shadow-sm"
              >
                {candSet.has(person.id) && (
                  <SeloCandidato size="sm" className="absolute -right-2.5 -top-2.5" />
                )}
                <span className="mx-auto block h-16 w-16 overflow-hidden rounded-full bg-slate-100">
                  {person.photo_url ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img
                      src={person.photo_url}
                      alt={person.name}
                      className="h-full w-full object-cover"
                      loading="lazy"
                    />
                  ) : null}
                </span>
                <p className="mt-2.5 text-[15px] font-semibold leading-snug text-slate-800">
                  {person.name}
                </p>
                <p className="mt-0.5 text-xs text-slate-500">
                  {person.party_sigla ?? "sem partido"}
                  {person.uf ? ` · ${person.uf}` : ""} · {CARGO_LABEL[person.house]}
                </p>
                {nVotes !== null && eligible !== null && eligible > 0 && (
                  <p className="mt-2 text-[11px] leading-snug text-slate-400">
                    Votou em {nVotes.toLocaleString("pt-BR")} de{" "}
                    {eligible.toLocaleString("pt-BR")} votações
                  </p>
                )}
              </Link>
            ))}
          </FeaturedRotator>
        </section>
      )}

      {trends.length > 0 && (
        <section>
          <h2 className="text-xl font-semibold text-slate-800">Assuntos em alta</h2>
          <p className="mb-4 text-sm text-slate-500">
            as posições que mais dividem o Congresso
          </p>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {trends.map(({ policy, rows }) => (
              <Link
                key={policy.id}
                href={`/politicas/${policy.id}`}
                className="rounded-xl border border-slate-200 bg-white p-5 hover:border-brand-light hover:shadow-sm"
              >
                <p className="mb-4 text-center font-semibold leading-snug text-slate-800">
                  {policy.name}
                </p>
                {rows.map((r) => (
                  <div key={r.party_id} className="mb-2.5 flex items-center gap-2.5">
                    <span className="w-14 shrink-0 truncate text-xs font-bold text-slate-600">
                      {r.party_sigla}
                    </span>
                    <span className="h-2 flex-1 overflow-hidden rounded-full bg-slate-100">
                      <span
                        className="animate-grow block h-full rounded-full"
                        style={
                          {
                            "--w": `${Math.max(3, Math.round(r.avg_score))}%`,
                            background: scoreColor(r.avg_score),
                          } as React.CSSProperties
                        }
                      />
                    </span>
                    <span
                      className="w-10 shrink-0 text-right text-xs font-bold"
                      style={{ color: scoreColor(r.avg_score) }}
                    >
                      {Math.round(r.avg_score)}%
                    </span>
                  </div>
                ))}
                <p className="mt-3 text-center text-xs text-slate-400">
                  % de apoio à política, por partido
                </p>
              </Link>
            ))}
          </div>
          <div className="mt-6 text-center">
            <Link
              href="/politicas"
              className="inline-block rounded-lg bg-brand px-6 py-3 font-medium text-white hover:bg-brand-dark"
            >
              Ver todas as {policies.length} políticas
            </Link>
          </div>
        </section>
      )}

      {recordistas.length > 0 && (
        <section>
          <h2 className="mb-4 text-xl font-semibold text-slate-800">
            Recordistas do plenário
          </h2>
          <div className="grid gap-4 pt-3 sm:grid-cols-3">
            {recordistas.map((r) => (
              <Link
                key={r.label}
                href={`/pessoas/${r.person.id}`}
                className="relative rounded-xl border border-slate-200 bg-white p-5 text-center hover:border-brand-light hover:shadow-sm"
              >
                {candSet.has(r.person.id) && (
                  <SeloCandidato size="sm" className="absolute -right-2.5 -top-2.5" />
                )}
                <p className="text-4xl font-bold leading-none text-slate-900">
                  {r.value}
                </p>
                <p className="mt-2 text-xs uppercase tracking-wider text-slate-400">
                  {r.label}
                </p>
                <span className="mt-4 flex items-center justify-center gap-2.5">
                  <span className="h-9 w-9 shrink-0 overflow-hidden rounded-full bg-slate-100">
                    {r.person.photo_url ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img
                        src={r.person.photo_url}
                        alt={r.person.name}
                        className="h-full w-full object-cover"
                        loading="lazy"
                      />
                    ) : null}
                  </span>
                  <span className="text-left">
                    <span className="block text-sm font-medium text-slate-700">
                      {r.person.name}
                    </span>
                    <span className="text-xs text-slate-400">
                      {r.person.party_sigla ?? ""}
                      {r.person.uf ? ` · ${r.person.uf}` : ""}
                    </span>
                  </span>
                </span>
              </Link>
            ))}
          </div>
        </section>
      )}

      {/* Números do projeto, em destaque antes das principais políticas */}
      <section className="rounded-xl bg-brand-ink px-4 py-9 text-white">
        <BigNumbers
          items={[
            { value: people, label: "parlamentares analisados" },
            { value: divisions, label: "votações nominais" },
            { value: policies.length, label: "temas políticos" },
          ]}
        />
      </section>

      {trends.length === 0 && policies.length > 0 && (
        <section className="text-center">
          <Link
            href="/politicas"
            className="inline-block rounded-lg bg-brand px-6 py-3 font-medium text-white hover:bg-brand-dark"
          >
            Ver todas as {policies.length} políticas
          </Link>
        </section>
      )}

      <section className="rounded-lg border border-slate-200 bg-white p-6">
        <h2 className="text-lg font-semibold text-slate-800">Como funciona</h2>
        <div className="mt-3 grid gap-4 text-sm text-slate-600 sm:grid-cols-3">
          <div>
            <p className="font-medium text-slate-800">1. Coletamos os votos</p>
            <p className="mt-1">
              Todas as votações nominais da Câmara e do Senado, direto das fontes
              oficiais.
            </p>
          </div>
          <div>
            <p className="font-medium text-slate-800">2. Agrupamos em políticas</p>
            <p className="mt-1">
              Votações relacionadas viram uma política (ex.: ação climática), com uma
              direção clara.
            </p>
          </div>
          <div>
            <p className="font-medium text-slate-800">3. Calculamos a média</p>
            <p className="mt-1">
              Para cada parlamentar, o quanto ele apoia ou rejeita cada política.
              O cálculo está em{" "}
              <Link href="/sobre" className="text-brand hover:underline">
                Sobre o site
              </Link>
              .
            </p>
          </div>
        </div>
      </section>
    </div>
  );
}

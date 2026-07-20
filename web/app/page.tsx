import Link from "next/link";
import { supabase } from "@/lib/supabase";
import HomeSearch from "@/components/HomeSearch";
import type { Policy } from "@/lib/types";

export const revalidate = 3600;

async function getData() {
  try {
    const [{ data: policies }, { count: people }, { count: divisions }] =
      await Promise.all([
        supabase
          .from("policy")
          .select("id, name, description, provisional")
          .order("name"),
        supabase.from("person").select("id", { count: "exact", head: true }),
        supabase
          .from("division")
          .select("id", { count: "exact", head: true })
          .eq("is_nominal", true),
      ]);
    return {
      policies: (policies ?? []) as Policy[],
      people: people ?? 0,
      divisions: divisions ?? 0,
    };
  } catch {
    return { policies: [] as Policy[], people: 0, divisions: 0 };
  }
}

export default async function Home() {
  const { policies, people, divisions } = await getData();

  return (
    <div className="space-y-12">
      <section className="relative left-1/2 -mt-8 w-screen -translate-x-1/2 bg-brand text-white">
        <div className="mx-auto max-w-6xl px-4 py-16 text-center">
          <h1 className="mx-auto max-w-3xl text-4xl font-bold sm:text-5xl">
            Como seu deputado e senador votam de verdade?
          </h1>
          <p className="mx-auto mt-4 max-w-2xl text-white/85">
            Esqueça o que dizem na campanha. O que importa é o voto, que vira lei
            e afeta todos nós. Aqui você acompanha, tema a tema, como cada
            parlamentar vota no Congresso.
          </p>
          <div className="mt-6">
            <HomeSearch />
          </div>
          <p className="mt-4 text-sm text-white/70">
            {people.toLocaleString("pt-BR")} parlamentares ·{" "}
            {divisions.toLocaleString("pt-BR")} votações analisadas
          </p>
        </div>
      </section>

      <section>
        <div className="mb-4 flex items-end justify-between">
          <h2 className="text-xl font-semibold text-slate-800">
            Temas acompanhados
          </h2>
          <Link href="/politicas" className="text-sm text-brand hover:underline">
            Ver todos
          </Link>
        </div>
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {policies.map((pol) => (
            <Link
              key={pol.id}
              href={`/politicas/${pol.id}`}
              className="rounded-lg border border-slate-200 bg-white p-4 hover:border-brand-light hover:shadow-sm"
            >
              <p className="font-medium text-slate-800">{pol.name}</p>
              {pol.description && (
                <p className="mt-1 line-clamp-3 text-sm text-slate-500">
                  {pol.description}
                </p>
              )}
            </Link>
          ))}
        </div>
        {policies.length === 0 && (
          <p className="text-sm text-slate-500">Nenhum tema publicado ainda.</p>
        )}
      </section>

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
            <p className="font-medium text-slate-800">2. Agrupamos por tema</p>
            <p className="mt-1">
              Votações relacionadas viram um tema (ex.: meio ambiente), com uma
              direção clara.
            </p>
          </div>
          <div>
            <p className="font-medium text-slate-800">3. Calculamos a média</p>
            <p className="mt-1">
              Para cada parlamentar, o quanto ele apoia ou rejeita cada tema.{" "}
              <Link href="/metodologia" className="text-brand hover:underline">
                Ver metodologia
              </Link>
              .
            </p>
          </div>
        </div>
      </section>
    </div>
  );
}

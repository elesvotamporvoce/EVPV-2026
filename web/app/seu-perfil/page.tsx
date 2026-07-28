import { supabase } from "@/lib/supabase";
import QuizPerfil, { type QuizPolicy } from "@/components/QuizPerfil";

export const revalidate = 3600;
export const metadata = {
  title: "Quem vota como você?",
  description:
    "Responda como você votaria nos temas que o Congresso decidiu e descubra quais partidos e parlamentares mais votam como você.",
};

// Ordem: as políticas com mais parlamentares com posição vêm primeiro,
// porque separam melhor quem vota de um jeito e quem vota de outro.
async function getPolicies() {
  const [{ data: pols }, { data: part }] = await Promise.all([
    supabase.from("policy").select("id, name, impact, description"),
    supabase.from("policy_participation").select("policy_id, n_scored"),
  ]);
  const n = new Map(
    ((part ?? []) as { policy_id: number; n_scored: number }[]).map((r) => [
      r.policy_id,
      r.n_scored,
    ])
  );
  const ordered = ((pols ?? []) as QuizPolicy[]).sort(
    (a, b) => (n.get(b.id) ?? 0) - (n.get(a.id) ?? 0)
  );
  return { principais: ordered.slice(0, 8), extras: ordered.slice(8) };
}

export default async function SeuPerfilPage() {
  const { principais, extras } = await getPolicies();

  return (
    <div className="mx-auto max-w-3xl space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-brand">Quem vota como você?</h1>
        <p className="mt-2 text-slate-600">
          Diga como você votaria em cada tema. No final, comparamos suas
          respostas com os votos reais no Congresso.
        </p>
      </div>

      <QuizPerfil principais={principais} extras={extras} />
    </div>
  );
}

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
  return ((pols ?? []) as QuizPolicy[]).sort(
    (a, b) => (n.get(b.id) ?? 0) - (n.get(a.id) ?? 0)
  );
}

export default async function SeuPerfilPage() {
  const policies = await getPolicies();

  return (
    <div className="mx-auto max-w-3xl space-y-6">
      {/* O titulo vive dentro do QuizPerfil: ele some depois que a pessoa
          comeca a responder, para dar lugar ao nome da politica fixo no topo. */}
      <QuizPerfil policies={policies} />
    </div>
  );
}

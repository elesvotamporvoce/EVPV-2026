import Link from "next/link";
import { nomeCurto } from "@/lib/format";
import ScoreBadge from "@/components/ScoreBadge";
import SeloCandidato from "@/components/SeloCandidato";
import type { ScoreNamed } from "@/lib/types";

/**
 * Top 10 de uma politica ("mais votaram a favor" / "mais votaram contra").
 *
 * Mora em componente proprio (e nao dentro da pagina) para poder ser renderizado
 * numa pagina de teste com dados fixos: e assim que conferimos, com screenshot,
 * se a linha cabe no celular sem quebrar.
 *
 * A caixa segue o mesmo desenho das outras secoes da pagina da politica:
 * quadrada, faixa colorida a esquerda e p-5, iguais a caixa amarela do
 * "Por que isso importa para voce?".
 */
export default function RankList({
  title,
  rows,
  candSet,
  femSet,
  accent = "border-slate-300",
}: {
  title: string;
  rows: ScoreNamed[];
  candSet: Set<number>;
  femSet: Set<number>;
  /** cor da faixa lateral: verde no "a favor", vermelho no "contra" */
  accent?: string;
}) {
  return (
    /* min-w-0: sem isso o item do grid usa min-width:auto, o conteudo de
       largura fixa da fileira (foto + selo + caixinha de posicao) vira o
       piso da coluna e a caixa estoura a largura da tela no celular. */
    <div className={`min-w-0 border-l-4 bg-white p-5 shadow-sm ${accent}`}>
      <h3 className="mb-3 font-semibold text-slate-700">{title}</h3>
      <div className="divide-y divide-slate-100">
        {rows.map((r) => (
          <Link
            key={r.person_id}
            href={`/pessoas/${r.person_id}`}
            className="flex h-14 items-center justify-between gap-1.5 hover:bg-slate-50 sm:gap-3"
          >
            <span className="flex min-w-0 flex-1 items-center gap-2 sm:gap-3">
              <span className="h-9 w-9 shrink-0 overflow-hidden rounded-full bg-slate-100">
                {r.photo_url ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img
                    src={r.photo_url}
                    alt={r.person_name}
                    className="h-full w-full object-cover"
                    loading="lazy"
                  />
                ) : (
                  <span className="flex h-full w-full items-center justify-center text-sm text-slate-400">
                    {r.person_name?.[0]}
                  </span>
                )}
              </span>
              <span className="min-w-0 flex-1">
                {/* nomeCurto mantem todas as linhas com a mesma cara: nome
                    grande vira "Primeiro Segundo.." em vez de espremer a
                    caixinha de posicao ao lado. */}
                <span className="block truncate text-sm font-medium text-slate-700">
                  {nomeCurto(r.person_name)}
                </span>
                <span className="block truncate text-xs text-slate-400">
                  {r.party_sigla ?? "-"}
                  {r.uf ? ` · ${r.uf}` : ""}
                </span>
              </span>
            </span>
            {/* O selo fica FORA do bloco do nome de proposito: dentro dele,
                os 34px do selo esticavam so aquela linha e a fileira de quem
                e candidato ficava 15px mais alta que as outras. Aqui ele e
                irmao do bloco, centralizado pela propria linha de altura
                fixa (h-14), e todas as fileiras ficam iguais. */}
            {candSet.has(r.person_id) && (
              <SeloCandidato size="xs" feminino={femSet.has(r.person_id)} />
            )}
            <ScoreBadge score={r.score} category={r.category} small />
          </Link>
        ))}
        {rows.length === 0 && (
          <p className="py-2.5 text-sm text-slate-500">Sem dados.</p>
        )}
      </div>
    </div>
  );
}

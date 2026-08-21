import { categoryFromScore, categoryLabel, scoreColor, supportTip } from "@/lib/format";

export default function ScoreBadge({
  score,
  category,
  small,
}: {
  score: number | null;
  category: string;
  small?: boolean;
}) {
  const cat = category && category.length > 0 ? category : categoryFromScore(score);
  const color = cat === "not_enough" ? "#94a3b8" : scoreColor(score);
  const tip = cat === "not_enough" ? null : supportTip(score);
  return (
    <span
      // Largura FIXA no modo small: "Sempre a favor" e "Quase sempre a favor"
      // tinham tamanhos diferentes e as listas ficavam desalinhadas. Agora
      // toda caixinha ocupa o mesmo espaco.
      // Os numeros sao medidos, nao chutados: no celular (10,5px) o rotulo
      // mais largo, "Quase sempre a favor", mede 116,2px; com os 8px de
      // padding da 124,2px, entao 128px cabe com ~4px de folga. Cada pixel
      // que sobra aqui vira espaco para o nome ao lado, que e quem estava
      // sendo cortado. No sm (13px) o mesmo rotulo da 143,9px — dai os 158px.
      className={`group/sb relative inline-flex shrink-0 items-center justify-center rounded-full text-center font-medium text-white ${
        small
          ? "w-[128px] whitespace-nowrap px-1 py-0.5 text-[10.5px] sm:w-[158px] sm:text-[13px]"
          : "px-3 py-1 text-[15px]"
      }`}
      style={{ backgroundColor: color }}
    >
      {categoryLabel(cat)}
      {tip && (
        <span className="pointer-events-none absolute -top-8 left-1/2 z-10 -translate-x-1/2 whitespace-nowrap rounded bg-slate-800 px-2 py-1 text-xs font-normal text-white opacity-0 transition-opacity group-hover/sb:opacity-100">
          {tip}
        </span>
      )}
    </span>
  );
}

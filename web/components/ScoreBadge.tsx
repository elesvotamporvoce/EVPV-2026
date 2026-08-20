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
      // Largura FIXA no modo small: "Sempre a favor" (100px) e "Quase sempre
      // a favor" (144px) tinham tamanhos diferentes e as listas ficavam
      // desalinhadas. Agora toda caixinha ocupa o mesmo espaco.
      className={`group/sb relative inline-flex shrink-0 items-center justify-center rounded-full text-center font-medium text-white ${
        small
          ? "w-[136px] whitespace-nowrap px-1 py-0.5 text-[10.5px] sm:w-[158px] sm:text-[13px]"
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

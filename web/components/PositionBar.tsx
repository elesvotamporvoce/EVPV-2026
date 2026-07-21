import { categoryLabel, scoreColor } from "@/lib/format";

export default function PositionBar({
  score,
  category,
}: {
  score: number | null;
  category: string;
}) {
  const enough = category !== "not_enough" && score !== null;
  const pos = enough ? Math.max(0, Math.min(100, score as number)) : 50;
  const color = enough ? scoreColor(score) : "#94a3b8";
  return (
    <div className="group relative w-full">
      <p
        className="mb-2 text-center text-base font-medium leading-tight"
        style={{ color }}
      >
        {categoryLabel(category)}
      </p>
      {enough ? (
        <>
          <div
            className="relative h-2.5 rounded-full"
            style={{
              background:
                "linear-gradient(to right,#fecaca 0%,#fde68a 50%,#bbf7d0 100%)",
            }}
          >
            <span className="absolute left-1/2 top-1/2 h-3 w-px -translate-y-1/2 bg-slate-300" />
            <span
              className="absolute top-1/2 h-[18px] w-[18px] -translate-x-1/2 -translate-y-1/2 rounded-full border-2 border-white shadow"
              style={{ left: `${pos}%`, background: color }}
            />
            <span
              className="pointer-events-none absolute -top-8 z-10 -translate-x-1/2 whitespace-nowrap rounded bg-slate-800 px-2 py-1 text-xs text-white opacity-0 transition-opacity group-hover:opacity-100"
              style={{ left: `${pos}%` }}
            >
              {Math.round(score as number)}% de apoio à política
            </span>
          </div>
          <div className="mt-1.5 flex justify-between text-[11px] font-medium">
            <span className="text-red-700">Contra</span>
            <span className="text-green-700">A favor</span>
          </div>
        </>
      ) : (
        <div className="h-2.5 rounded-full bg-slate-100" />
      )}
    </div>
  );
}

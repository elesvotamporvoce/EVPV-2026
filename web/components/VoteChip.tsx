"use client";

import { useEffect, useRef, useState } from "react";
import { VOTE_LABEL } from "@/lib/format";

const OUTRO_TIP =
  "Votação secreta: o painel registra que o parlamentar votou, sem revelar o voto";

export default function VoteChip({
  option,
  prefix,
}: {
  option: string;
  prefix?: string;
}) {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLSpanElement>(null);

  // Fecha ao clicar/tocar fora
  useEffect(() => {
    if (!open) return;
    const h = (e: MouseEvent | TouchEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) {
        setOpen(false);
      }
    };
    document.addEventListener("mousedown", h);
    document.addEventListener("touchstart", h);
    return () => {
      document.removeEventListener("mousedown", h);
      document.removeEventListener("touchstart", h);
    };
  }, [open]);

  const map: Record<string, string> = {
    sim: "bg-green-100 text-green-800",
    nao: "bg-red-100 text-red-800",
  };
  const cls = map[option] ?? "bg-slate-100 text-slate-600";
  const label = `${prefix ? `${prefix}: ` : ""}${VOTE_LABEL[option] ?? option}`;

  if (option !== "outro") {
    return (
      <span className={`shrink-0 rounded px-2 py-0.5 text-xs font-medium ${cls}`}>
        {label}
      </span>
    );
  }

  return (
    <span
      ref={ref}
      className={`group/vc relative inline-flex shrink-0 cursor-pointer items-center gap-1 rounded px-2 py-0.5 text-xs font-medium ${cls}`}
      role="button"
      tabIndex={0}
      onClick={(e) => {
        // Chips ficam dentro de links; o clique no "i" não deve navegar
        e.preventDefault();
        e.stopPropagation();
        setOpen((o) => !o);
      }}
      onKeyDown={(e) => {
        if (e.key === "Enter" || e.key === " ") {
          e.preventDefault();
          setOpen((o) => !o);
        }
      }}
    >
      {label}
      <span
        aria-label="O que é outro registro?"
        className="inline-flex h-3.5 w-3.5 items-center justify-center rounded-full bg-slate-400 text-[9px] font-bold leading-none text-white"
      >
        i
      </span>
      <span
        className={`pointer-events-none absolute bottom-full left-1/2 z-10 mb-1 w-56 -translate-x-1/2 whitespace-normal rounded bg-slate-800 px-2 py-1 text-center text-xs font-normal text-white transition-opacity ${
          open ? "opacity-100" : "opacity-0 group-hover/vc:opacity-100"
        }`}
      >
        {OUTRO_TIP}
      </span>
    </span>
  );
}

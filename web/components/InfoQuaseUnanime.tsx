"use client";

import { useEffect, useRef, useState } from "react";

/**
 * Botãozinho "i" ao lado do selo de postura, para as votações quase unânimes.
 * Clicar abre a explicação de por que aquela votação pesa menos no score.
 * O texto fica escondido por padrão para não poluir a lista de votações, mas
 * precisa estar ao alcance de um clique: é uma escolha de metodologia que afeta
 * o número que o leitor está vendo.
 */
export default function InfoQuaseUnanime({
  pctMaioria,
  votosSim,
  votosNao,
}: {
  pctMaioria: number | null;
  votosSim: number | null;
  votosNao: number | null;
}) {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLSpanElement>(null);

  useEffect(() => {
    if (!open) return;
    const onClick = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
    };
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") setOpen(false);
    };
    document.addEventListener("mousedown", onClick);
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("mousedown", onClick);
      document.removeEventListener("keydown", onKey);
    };
  }, [open]);

  const placar =
    votosSim !== null && votosNao !== null
      ? `${Math.max(votosSim, votosNao)} a ${Math.min(votosSim, votosNao)}`
      : null;

  return (
    <span ref={ref} className="relative inline-flex">
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        aria-expanded={open}
        aria-label="Por que esta votação pesa menos"
        className="flex h-4 w-4 items-center justify-center rounded-full border border-slate-300 text-[10px] font-semibold leading-none text-slate-500 transition hover:border-slate-400 hover:bg-slate-50 hover:text-slate-700"
      >
        i
      </button>

      {open && (
        <span
          role="tooltip"
          className="absolute right-0 top-6 z-20 w-64 rounded-lg border border-slate-200 bg-white p-3 text-left text-xs leading-relaxed font-normal text-slate-600 shadow-lg"
        >
          <span className="mb-1 block font-semibold text-slate-800">
            Esta votação pesa menos
          </span>
          {placar && (
            <span className="mb-1 block text-slate-500">
              Placar: {placar}
              {pctMaioria ? ` — ${pctMaioria}% de um lado.` : "."}
            </span>
          )}
          Quando quase todo mundo vota igual, o voto de cada um diz pouco: seguir
          uma maioria esmagadora não revela muito sobre as convicções de um
          parlamentar. Então esta votação entra no cálculo com peso reduzido.
          <span className="mt-2 block">
            Não a descartamos, porque ela diz bastante sobre quem votou{" "}
            <em>contra</em> a corrente. O corte é automático: vale para toda
            votação com 95% ou mais dos votos de um lado.
          </span>
        </span>
      )}
    </span>
  );
}

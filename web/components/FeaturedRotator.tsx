"use client";

import { Children, useEffect, useState } from "react";
import type { ReactNode } from "react";

/**
 * Mostra os itens em grupos, com setas nas laterais e bolinhas embaixo.
 * Sem movimento automático.
 *
 * Quantos cards aparecem por vez depende do TAMANHO DA TELA: 2 no celular,
 * 3 no tablet, 4 no computador (ajustável em `sizes`). A primeira renderização
 * usa o valor de desktop nos dois lados — servidor e cliente — para não dar
 * hydration mismatch; o efeito logo corrige para a largura real.
 */
export default function FeaturedRotator({
  children,
  sizes = { base: 2, sm: 3, lg: 4 },
  className = "grid grid-cols-2 gap-3 pt-3 sm:grid-cols-3 lg:grid-cols-4",
}: {
  children: ReactNode;
  /** quantos cards por vez em cada faixa de largura */
  sizes?: { base: number; sm: number; lg: number };
  className?: string;
}) {
  const items = Children.toArray(children);
  const [size, setSize] = useState(sizes.lg);
  const [page, setPage] = useState(0);

  const { base: sBase, sm: sSm, lg: sLg } = sizes;
  useEffect(() => {
    const calc = () => {
      const w = window.innerWidth;
      setSize(w >= 1024 ? sLg : w >= 640 ? sSm : sBase);
    };
    calc();
    window.addEventListener("resize", calc);
    return () => window.removeEventListener("resize", calc);
  }, [sBase, sSm, sLg]);

  const pages = Math.max(1, Math.ceil(items.length / size));

  useEffect(() => {
    if (page >= pages) setPage(0);
  }, [page, pages]);

  // Wrap-around: se a última página ficaria incompleta, completa com os
  // primeiros itens, para o grid nunca aparecer quebrado.
  const visible =
    items.length >= size
      ? Array.from({ length: size }, (_, i) => items[(page * size + i) % items.length])
      : items;
  const go = (dir: number) => setPage((p) => (p + dir + pages) % pages);

  if (pages <= 1) return <div className={className}>{visible}</div>;

  return (
    <div>
      <div className="flex items-center gap-2 sm:gap-3">
        <button
          type="button"
          aria-label="Anteriores"
          onClick={() => go(-1)}
          className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full border border-slate-300 bg-white text-xl leading-none text-slate-600 shadow-sm hover:border-brand hover:text-brand"
        >
          &#8249;
        </button>
        <div className={`flex-1 ${className}`}>{visible}</div>
        <button
          type="button"
          aria-label="Próximos"
          onClick={() => go(1)}
          className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full border border-slate-300 bg-white text-xl leading-none text-slate-600 shadow-sm hover:border-brand hover:text-brand"
        >
          &#8250;
        </button>
      </div>
      <div className="mt-4 flex justify-center gap-2">
        {Array.from({ length: pages }).map((_, i) => (
          <button
            key={i}
            type="button"
            aria-label={`Mostrar grupo ${i + 1} de ${pages}`}
            onClick={() => setPage(i)}
            className={`h-2 rounded-full transition-all ${
              i === page ? "w-6 bg-brand" : "w-2 bg-slate-300 hover:bg-slate-400"
            }`}
          />
        ))}
      </div>
    </div>
  );
}

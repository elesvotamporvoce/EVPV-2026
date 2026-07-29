"use client";

import { Children, useEffect, useState } from "react";
import type { ReactNode } from "react";

/**
 * Mostra os itens em grupos de `size`. A navegação é manual: setas nas laterais
 * e bolinhas embaixo. Sem movimento automático.
 */
export default function FeaturedRotator({
  children,
  size = 3,
  className = "grid gap-4 sm:grid-cols-2 lg:grid-cols-3",
}: {
  children: ReactNode;
  size?: number;
  className?: string;
}) {
  const items = Children.toArray(children);
  const pages = Math.max(1, Math.ceil(items.length / size));
  const [page, setPage] = useState(0);

  useEffect(() => {
    if (page >= pages) setPage(0);
  }, [page, pages]);

  const visible = items.slice(page * size, page * size + size);
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

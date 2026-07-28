"use client";

import { useEffect, useState } from "react";
import type { ReactNode } from "react";

/**
 * Mostra os itens em grupos de `size`, trocando de grupo a cada `intervalMs`.
 * Pausa quando o mouse está sobre o bloco e respeita quem prefere menos
 * animação (prefers-reduced-motion).
 */
export default function FeaturedRotator({
  children,
  size = 3,
  intervalMs = 6000,
  className = "grid gap-4 sm:grid-cols-2 lg:grid-cols-3",
}: {
  children: ReactNode[];
  size?: number;
  intervalMs?: number;
  className?: string;
}) {
  const items = Array.isArray(children) ? children : [children];
  const pages = Math.max(1, Math.ceil(items.length / size));
  const [page, setPage] = useState(0);
  const [paused, setPaused] = useState(false);

  useEffect(() => {
    if (pages <= 1 || paused) return;
    if (
      typeof window !== "undefined" &&
      window.matchMedia?.("(prefers-reduced-motion: reduce)").matches
    ) {
      return;
    }
    const t = setInterval(() => setPage((p) => (p + 1) % pages), intervalMs);
    return () => clearInterval(t);
  }, [pages, paused, intervalMs]);

  const visible = items.slice(page * size, page * size + size);

  return (
    <div
      onMouseEnter={() => setPaused(true)}
      onMouseLeave={() => setPaused(false)}
    >
      <div key={page} className={`animate-fade ${className}`}>
        {visible}
      </div>
      {pages > 1 && (
        <div className="mt-4 flex justify-center gap-2">
          {Array.from({ length: pages }).map((_, i) => (
            <button
              key={i}
              type="button"
              aria-label={`Mostrar grupo ${i + 1}`}
              onClick={() => setPage(i)}
              className={`h-2 rounded-full transition-all ${
                i === page ? "w-6 bg-brand" : "w-2 bg-slate-300 hover:bg-slate-400"
              }`}
            />
          ))}
        </div>
      )}
    </div>
  );
}

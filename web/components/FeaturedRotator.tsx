"use client";

import { Children, useEffect, useState } from "react";
import type { ReactNode } from "react";

/**
 * Mostra os itens em grupos de `size`, trocando de grupo a cada `intervalMs`.
 * Pausa com o mouse em cima e permite navegar pelas bolinhas.
 *
 * Children.toArray é usado de propósito: quando os filhos vêm de um Server
 * Component, props.children nem sempre chega como array simples.
 */
export default function FeaturedRotator({
  children,
  size = 3,
  intervalMs = 6000,
  className = "grid gap-4 sm:grid-cols-2 lg:grid-cols-3",
}: {
  children: ReactNode;
  size?: number;
  intervalMs?: number;
  className?: string;
}) {
  const items = Children.toArray(children);
  const pages = Math.max(1, Math.ceil(items.length / size));
  const [page, setPage] = useState(0);
  const [paused, setPaused] = useState(false);
  const [reduced, setReduced] = useState(false);

  useEffect(() => {
    const mq = window.matchMedia?.("(prefers-reduced-motion: reduce)");
    if (mq) setReduced(mq.matches);
  }, []);

  useEffect(() => {
    if (pages <= 1 || paused) return;
    const t = window.setInterval(
      () => setPage((p) => (p + 1) % pages),
      intervalMs
    );
    return () => window.clearInterval(t);
  }, [pages, paused, intervalMs]);

  // Se a lista encolher, não deixa a página passar do fim
  useEffect(() => {
    if (page >= pages) setPage(0);
  }, [page, pages]);

  const start = page * size;
  const visible = items.slice(start, start + size);

  return (
    <div
      onMouseEnter={() => setPaused(true)}
      onMouseLeave={() => setPaused(false)}
    >
      <div key={page} className={`${reduced ? "" : "animate-fade "}${className}`}>
        {visible}
      </div>
      {pages > 1 && (
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
      )}
    </div>
  );
}

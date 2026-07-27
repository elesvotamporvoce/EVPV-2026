"use client";

import { useEffect, useRef, useState } from "react";

function Counter({ to }: { to: number }) {
  const [n, setN] = useState(0);
  const done = useRef(false);
  useEffect(() => {
    if (done.current) return;
    done.current = true;
    const step = Math.max(1, Math.round(to / 45));
    const t = setInterval(() => {
      setN((v) => {
        const next = v + step;
        if (next >= to) {
          clearInterval(t);
          return to;
        }
        return next;
      });
    }, 22);
    return () => clearInterval(t);
  }, [to]);
  return <>{n.toLocaleString("pt-BR")}</>;
}

export default function BigNumbers({
  items,
}: {
  items: { value: number; label: string }[];
}) {
  return (
    <div className="mt-10 flex flex-wrap items-start justify-center gap-x-12 gap-y-6">
      {items.map((it) => (
        <div key={it.label} className="text-center">
          <p className="text-4xl font-bold leading-none text-brand-light sm:text-5xl">
            <Counter to={it.value} />
          </p>
          <p className="mt-2 text-xs uppercase tracking-widest text-white/50">
            {it.label}
          </p>
        </div>
      ))}
    </div>
  );
}

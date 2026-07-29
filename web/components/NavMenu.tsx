"use client";

import Link from "next/link";
import { useEffect, useRef, useState } from "react";

export default function NavMenu({
  links,
}: {
  links: { href: string; label: string }[];
}) {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

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

  return (
    <div ref={ref} className="relative">
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        aria-label="Abrir menu"
        aria-expanded={open}
        className="nav-link flex h-10 w-10 items-center justify-center rounded-lg text-white/80 hover:bg-white/10 hover:text-white"
      >
        <span className="flex flex-col gap-[5px]">
          <span className="block h-[2px] w-6 rounded bg-current" />
          <span className="block h-[2px] w-6 rounded bg-current" />
          <span className="block h-[2px] w-6 rounded bg-current" />
        </span>
      </button>

      {open && (
        <nav className="absolute right-0 top-full z-40 mt-2 w-60 overflow-hidden rounded-xl border border-slate-200 bg-white py-1.5 shadow-xl">
          {links.map((l) => (
            <Link
              key={l.href}
              href={l.href}
              onClick={() => setOpen(false)}
              className="block px-4 py-3 text-[15px] font-semibold text-slate-700 hover:bg-violet-50 hover:text-brand"
            >
              {l.label}
            </Link>
          ))}
        </nav>
      )}
    </div>
  );
}

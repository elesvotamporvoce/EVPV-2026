"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

const links = [
  { href: "/pessoas", label: "Parlamentares" },
  { href: "/politicas", label: "Temas" },
  { href: "/metodologia", label: "Metodologia" },
  { href: "/sobre", label: "Sobre" },
];

export default function Navbar() {
  const pathname = usePathname();
  const home = pathname === "/";
  return (
    <header className={home ? "border-b border-slate-200 bg-slate-50" : "bg-brand"}>
      <div className="mx-auto flex max-w-6xl items-center justify-between gap-4 px-4 py-3">
        <Link
          href="/"
          className={`flex items-center gap-2 font-semibold leading-tight ${
            home ? "text-brand" : "text-white"
          }`}
        >
          <span className="text-lg">Eles Votam por Você</span>
        </Link>
        <nav className="flex flex-wrap items-center gap-4 text-sm font-semibold">
          {links.map((l) => (
            <Link
              key={l.href}
              href={l.href}
              className={home ? "text-slate-600 hover:text-brand" : "text-white/80 hover:text-white"}
            >
              {l.label}
            </Link>
          ))}
        </nav>
      </div>
    </header>
  );
}

"use client";

import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { supabase } from "@/lib/supabase";

type Sug = {
  id: number;
  name: string;
  party_sigla: string | null;
  uf: string | null;
  photo_url: string | null;
};

// Diretório carregado uma única vez por sessão (lista pequena).
let cache: Sug[] | null = null;
async function loadDir(): Promise<Sug[]> {
  if (cache) return cache;
  const { data } = await supabase
    .from("person_directory")
    .select("id,name,party_sigla,uf,photo_url")
    .order("name");
  cache = (data ?? []) as Sug[];
  return cache;
}

const norm = (s: string) =>
  s.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();

export default function NameSuggest({
  initial = "",
  placeholder,
  inputClass,
  withButton = false,
  onSearch,
}: {
  initial?: string;
  placeholder: string;
  inputClass: string;
  withButton?: boolean;
  onSearch: (q: string) => void;
}) {
  const router = useRouter();
  const [q, setQ] = useState(initial);
  const [open, setOpen] = useState(false);
  const [sugs, setSugs] = useState<Sug[]>([]);
  const [hi, setHi] = useState(-1);
  const boxRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const h = (e: MouseEvent) => {
      if (boxRef.current && !boxRef.current.contains(e.target as Node)) {
        setOpen(false);
      }
    };
    document.addEventListener("mousedown", h);
    return () => document.removeEventListener("mousedown", h);
  }, []);

  async function update(text: string) {
    setQ(text);
    if (text.trim().length < 2) {
      setSugs([]);
      setOpen(false);
      return;
    }
    const dir = await loadDir();
    const n = norm(text.trim());
    const starts = dir.filter((p) => norm(p.name).startsWith(n));
    const inc = dir.filter(
      (p) => !norm(p.name).startsWith(n) && norm(p.name).includes(n)
    );
    const top = [...starts, ...inc].slice(0, 8);
    setSugs(top);
    setHi(-1);
    setOpen(top.length > 0);
  }

  function pick(s: Sug) {
    setOpen(false);
    router.push(`/pessoas/${s.id}`);
  }

  return (
    <div ref={boxRef} className="relative w-full">
      <form
        className="flex w-full gap-2"
        onSubmit={(e) => {
          e.preventDefault();
          if (open && hi >= 0 && sugs[hi]) pick(sugs[hi]);
          else {
            setOpen(false);
            onSearch(q);
          }
        }}
      >
        <input
          value={q}
          onChange={(e) => update(e.target.value)}
          onFocus={() => {
            loadDir();
            if (sugs.length) setOpen(true);
          }}
          onKeyDown={(e) => {
            if (!open) return;
            if (e.key === "ArrowDown") {
              e.preventDefault();
              setHi((h) => Math.min(h + 1, sugs.length - 1));
            } else if (e.key === "ArrowUp") {
              e.preventDefault();
              setHi((h) => Math.max(h - 1, -1));
            } else if (e.key === "Escape") {
              setOpen(false);
            }
          }}
          placeholder={placeholder}
          className={inputClass}
          autoComplete="off"
        />
        {withButton && (
          <button
            type="submit"
            className="rounded-lg bg-white px-5 py-3 font-semibold text-brand hover:bg-white/90"
          >
            Buscar
          </button>
        )}
      </form>
      {open && (
        <ul className="absolute left-0 right-0 top-full z-30 mt-1 overflow-hidden rounded-lg border border-slate-200 bg-white text-left shadow-lg">
          {sugs.map((s, i) => (
            <li key={s.id}>
              <button
                type="button"
                onMouseDown={(e) => e.preventDefault()}
                onClick={() => pick(s)}
                className={`flex w-full items-center gap-3 px-3 py-2 text-sm ${
                  i === hi ? "bg-brand/10" : "hover:bg-slate-50"
                }`}
              >
                <span className="h-8 w-8 shrink-0 overflow-hidden rounded-full bg-slate-100">
                  {s.photo_url ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img
                      src={s.photo_url}
                      alt=""
                      className="h-full w-full object-cover"
                      loading="lazy"
                    />
                  ) : null}
                </span>
                <span className="min-w-0 flex-1 truncate text-slate-700">
                  {s.name}
                </span>
                <span className="shrink-0 text-xs text-slate-400">
                  {s.party_sigla ?? ""}
                  {s.uf ? ` · ${s.uf}` : ""}
                </span>
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

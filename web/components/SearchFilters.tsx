"use client";

import { useRouter, useSearchParams } from "next/navigation";
import { useTransition } from "react";
import NameSuggest from "./NameSuggest";
import { UFS } from "@/lib/format";

// Filtro client-side que atualiza a URL (?q=&house=&uf=). A página é server-side.
export default function SearchFilters({ parties }: { parties: string[] }) {
  const router = useRouter();
  const sp = useSearchParams();
  const [, startTransition] = useTransition();

  function apply(next: Record<string, string>) {
    const params = new URLSearchParams(sp.toString());
    for (const [k, v] of Object.entries(next)) {
      if (v) params.set(k, v);
      else params.delete(k);
    }
    params.delete("page");
    startTransition(() => router.push(`/pessoas?${params.toString()}`));
  }

  return (
    <div className="grid gap-3 sm:grid-cols-4">
      <div className="sm:col-span-2">
        <NameSuggest
          initial={sp.get("q") ?? ""}
          placeholder="Buscar por nome…"
          inputClass="w-full rounded-lg border border-slate-300 px-3 py-2 text-sm outline-none focus:border-brand"
          onSearch={(q) => apply({ q })}
        />
      </div>

      <select
        defaultValue={sp.get("house") ?? ""}
        onChange={(e) => apply({ house: e.target.value })}
        className="rounded-lg border border-slate-300 px-3 py-2 text-sm outline-none focus:border-brand"
      >
        <option value="">Todas as casas</option>
        <option value="camara">Câmara</option>
        <option value="senado">Senado</option>
      </select>

      <select
        defaultValue={sp.get("uf") ?? ""}
        onChange={(e) => apply({ uf: e.target.value })}
        className="rounded-lg border border-slate-300 px-3 py-2 text-sm outline-none focus:border-brand"
      >
        <option value="">Todas as UFs</option>
        {UFS.map((uf) => (
          <option key={uf} value={uf}>
            {uf}
          </option>
        ))}
      </select>

      <select
        defaultValue={sp.get("party") ?? ""}
        onChange={(e) => apply({ party: e.target.value })}
        className="rounded-lg border border-slate-300 px-3 py-2 text-sm outline-none focus:border-brand sm:col-span-4"
      >
        <option value="">Todos os partidos</option>
        {parties.map((s) => (
          <option key={s} value={s}>
            {s}
          </option>
        ))}
      </select>
    </div>
  );
}

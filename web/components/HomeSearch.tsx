"use client";

import { useRouter } from "next/navigation";
import NameSuggest from "./NameSuggest";

export default function HomeSearch() {
  const router = useRouter();
  return (
    <div className="mx-auto w-full max-w-xl">
      <NameSuggest
        withButton
        placeholder="Digite o nome do seu deputado ou senador…"
        inputClass="w-full rounded-lg border border-white/30 bg-white/95 px-4 py-3 text-slate-800 outline-none placeholder:text-slate-400"
        onSearch={(q) => router.push(`/pessoas?q=${encodeURIComponent(q)}`)}
      />
    </div>
  );
}

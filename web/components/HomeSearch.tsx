"use client";

import { useRouter } from "next/navigation";
import NameSuggest from "./NameSuggest";

export default function HomeSearch() {
  const router = useRouter();
  return (
    <div className="mx-auto w-full max-w-xl rounded-xl border border-brand-light/30 bg-brand-light/[0.09] p-4 pb-5">
      <p className="mb-2.5 text-[17px] font-semibold text-white">
        Veja aqui os votos e valores do seu político
      </p>
      <NameSuggest
        withButton
        placeholder="Digite um nome"
        inputClass="w-full rounded-lg border border-white/30 bg-white/95 px-4 py-3 text-slate-800 outline-none placeholder:text-slate-400"
        onSearch={(q) => router.push(`/pessoas?q=${encodeURIComponent(q)}`)}
      />
    </div>
  );
}

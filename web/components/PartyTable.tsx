"use client";

import Link from "next/link";
import { useState } from "react";
import ScoreBadge from "./ScoreBadge";
import type { PartyPolicyAgreement } from "@/lib/types";

export default function PartyTable({ parties }: { parties: PartyPolicyAgreement[] }) {
  const [all, setAll] = useState(false);
  const rows = all ? parties : parties.slice(0, 10);
  return (
    // sem max-w: a tabela acompanha a largura da caixa que a envolve, igual as
    // outras secoes da pagina da politica
    <div>
      <div className="overflow-x-auto">
        <table className="w-full text-sm">
          <thead className="bg-slate-50 text-xs uppercase text-slate-500">
            <tr>
              <th className="px-4 py-2 text-left">Partido</th>
              <th className="px-3 py-2 text-center">Parlamentares</th>
              <th className="px-3 py-2 text-center">Posição média</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100">
            {rows.map((p) => (
              <tr key={p.party_id} className="hover:bg-slate-50">
                <td className="px-4 py-2">
                  <Link
                    href={`/partidos/${p.party_id}`}
                    className="font-medium text-brand hover:underline"
                  >
                    {p.party_sigla}
                  </Link>
                </td>
                <td className="px-3 py-2 text-center text-slate-500">{p.n_people}</td>
                <td className="px-3 py-2 text-center">
                  <ScoreBadge score={p.avg_score} category="" small />
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      {parties.length > 10 && (
        <button
          onClick={() => setAll(!all)}
          className="mt-2 text-sm font-medium text-brand hover:underline"
        >
          {all ? "Mostrar menos" : `Mostrar todos os ${parties.length} partidos`}
        </button>
      )}
    </div>
  );
}

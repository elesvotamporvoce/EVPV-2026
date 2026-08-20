import Link from "next/link";
import { HOUSE_LABEL } from "@/lib/format";
import SeloCandidato from "@/components/SeloCandidato";
import type { PersonDir } from "@/lib/types";

export default function PersonCard({
  p,
  candidato = false,
  feminino = false,
}: {
  p: PersonDir;
  candidato?: boolean;
  /** vem do sexo registrado no TSE: muda o selo para "Candidata" */
  feminino?: boolean;
}) {
  return (
    <Link
      href={`/pessoas/${p.id}`}
      className="relative flex flex-col items-center rounded-lg border border-slate-200 bg-white p-4 text-center hover:border-brand-light hover:shadow-sm"
    >
      {candidato && (
        <SeloCandidato feminino={feminino} className="absolute -right-2.5 -top-2.5" />
      )}
      <span className="h-14 w-14 shrink-0 overflow-hidden rounded-full bg-slate-100">
        {p.photo_url ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={p.photo_url}
            alt={p.name}
            className="h-full w-full object-cover"
            loading="lazy"
          />
        ) : (
          <span className="flex h-full w-full items-center justify-center text-slate-400">
            {p.name?.[0] ?? "?"}
          </span>
        )}
      </span>
      <span className="mt-2.5 w-full truncate font-medium text-slate-800">
        {p.name}
      </span>
      <span className="mt-0.5 w-full truncate text-xs text-slate-500">
        {p.party_sigla ?? "sem partido"}
        {p.uf ? ` · ${p.uf}` : ""} · {HOUSE_LABEL[p.house]}
      </span>
    </Link>
  );
}

import Link from "next/link";
import { HOUSE_LABEL, MANDATE_CLASS, MANDATE_LABEL } from "@/lib/format";
import type { PersonDir } from "@/lib/types";

export default function PersonCard({ p }: { p: PersonDir }) {
  return (
    <Link
      href={`/pessoas/${p.id}`}
      className="flex items-center gap-3 rounded-lg border border-slate-200 bg-white p-3 hover:border-brand-light hover:shadow-sm"
    >
      <div className="h-12 w-12 shrink-0 overflow-hidden rounded-full bg-slate-100">
        {p.photo_url ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={p.photo_url}
            alt={p.name}
            className="h-full w-full object-cover"
            loading="lazy"
          />
        ) : (
          <div className="flex h-full w-full items-center justify-center text-slate-400">
            {p.name?.[0] ?? "?"}
          </div>
        )}
      </div>
      <div className="min-w-0">
        <p className="truncate font-medium text-slate-800">{p.name}</p>
        <p className="truncate text-xs text-slate-500">
          {p.party_sigla ?? "sem partido"}
          {p.uf ? ` · ${p.uf}` : ""} · {HOUSE_LABEL[p.house]}
        </p>
        {p.mandate_status && (
          <p
            className={`truncate text-xs font-semibold ${
              MANDATE_CLASS[p.mandate_status] ?? "text-slate-500"
            }`}
          >
            Mandato: {MANDATE_LABEL[p.mandate_status] ?? p.mandate_status}
          </p>
        )}
      </div>
    </Link>
  );
}

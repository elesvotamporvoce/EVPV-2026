"use client";

import { useRouter } from "next/navigation";

/**
 * Botao "Voltar" que leva para a PAGINA ANTERIOR de verdade (historico do
 * navegador), e nao para um destino fixo.
 *
 * Quando nao ha para onde voltar — a pessoa abriu o link direto do Google, do
 * WhatsApp ou digitou a URL — cai no `fallback`, para nunca deixar o usuario
 * preso. A checagem usa o referrer do proprio site e, na falta dele, o tamanho
 * do historico.
 */
export default function Voltar({
  fallback,
  children = "Voltar",
  className = "",
}: {
  /** para onde ir quando nao existe pagina anterior (ex.: "/pessoas") */
  fallback: string;
  children?: React.ReactNode;
  className?: string;
}) {
  const router = useRouter();

  const voltar = () => {
    const veioDoSite =
      typeof document !== "undefined" &&
      document.referrer &&
      document.referrer.startsWith(window.location.origin);
    if (veioDoSite || window.history.length > 1) router.back();
    else router.push(fallback);
  };

  return (
    <button
      type="button"
      onClick={voltar}
      className={`text-sm text-brand hover:underline ${className}`}
    >
      ← {children}
    </button>
  );
}

import Link from "next/link";

export default function Footer() {
  return (
    <footer className="mt-16 border-t border-slate-200 bg-white">
      <div className="mx-auto max-w-6xl px-4 py-8 text-sm text-slate-500">
        <p className="font-semibold text-slate-700">Eles Votam por Você</p>
        <p className="mt-1 max-w-2xl">
          Como cada deputado e senador vota no Congresso Nacional. Dados públicos
          da Câmara dos Deputados e do Senado Federal, organizados para você.
        </p>
        <p className="mt-3">
          <Link href="/como-funciona" className="text-brand hover:underline">
            Como funciona
          </Link>{" "}
          ·{" "}
          <Link href="/sobre" className="text-brand hover:underline">
            Sobre e fontes
          </Link>{" "}
          ·{" "}
          <Link href="/termos" className="text-brand hover:underline">
            Termos e privacidade
          </Link>
        </p>
        <p className="mt-3 text-xs text-slate-400">
          Projeto independente e sem fins lucrativos. Não é um site oficial do
          Congresso.
        </p>
      </div>
    </footer>
  );
}

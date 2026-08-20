/**
 * Selo redondo "Candidato 2026" — gradiente roxo, aro branco, estourando a
 * borda do card (opcao 21i). Marca quem esta concorrendo em 2026.
 *
 * Nos cards e usado com `absolute -right-2.5 -top-2.5`: um pedaco dele fica
 * para fora do cartao. O container precisa ser `relative` e NAO pode ter
 * `overflow-hidden`, senao o selo e cortado.
 *
 * Os tamanhos abaixo nao sao chute: "CANDIDATO" em 6,5px com tracking -0.02em
 * mede 41,8px, e a corda util de um circulo de 52px (menos o aro de 3px), na
 * altura onde a palavra fica, e 44,9px. Mexer na fonte sem mexer no diametro
 * corta a palavra.
 */
export default function SeloCandidato({
  size = "md",
  className = "",
}: {
  /** md = cards e cabecalho | sm = espacos apertados */
  size?: "sm" | "md";
  className?: string;
}) {
  const box = size === "sm" ? "h-[46px] w-[46px]" : "h-[52px] w-[52px]";
  const cima = size === "sm" ? "text-[5.5px]" : "text-[6.5px]";
  const ano = size === "sm" ? "text-[10px]" : "text-[12px]";
  return (
    <span
      title="Candidato nas eleições de 2026"
      aria-label="Candidato nas eleições de 2026"
      className={`z-10 flex ${box} shrink-0 flex-col items-center justify-center rounded-full border-[3px] border-white text-white shadow-md ${className}`}
      style={{
        // gradiente roxo (brand-light -> brand-dark)
        backgroundImage: "linear-gradient(135deg, #a78bfa 0%, #4c1d95 100%)",
      }}
    >
      <span
        className={`${cima} font-bold uppercase leading-none tracking-[-0.02em]`}
      >
        Candidato
      </span>
      <span className={`${ano} mt-[1px] font-extrabold leading-none`}>2026</span>
    </span>
  );
}

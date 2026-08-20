/**
 * Selo redondo "Candidato/Candidata 2026" — gradiente roxo, aro branco,
 * estourando a borda do card (opcao 21i). Marca quem esta concorrendo em 2026.
 *
 * Nos cards e usado com `absolute -right-2.5 -top-2.5`: um pedaco dele fica
 * para fora do cartao. O container precisa ser `relative` e NAO pode ter
 * `overflow-hidden`, senao o selo e cortado.
 *
 * Os tamanhos abaixo nao sao chute: "CANDIDATO" em 6,5px com tracking -0.02em
 * mede 41,8px, e a corda util de um circulo de 52px (menos o aro de 3px), na
 * altura onde a palavra fica, e 44,9px. Mexer na fonte sem mexer no diametro
 * corta a palavra. Por isso o tamanho `xs`, usado em listas densas, mostra so
 * o ano — a palavra nao caberia legivel — e o significado fica no title.
 */
export default function SeloCandidato({
  size = "md",
  feminino = false,
  className = "",
}: {
  /** md = cards e cabecalho | sm = espacos apertados | xs = linhas de lista */
  size?: "xs" | "sm" | "md";
  /** true = "Candidata" (vem do registro de sexo do TSE) */
  feminino?: boolean;
  className?: string;
}) {
  const palavra = feminino ? "Candidata" : "Candidato";
  const rotulo = `${palavra} nas eleições de 2026`;

  const box =
    size === "xs"
      ? "h-[34px] w-[34px] border-2"
      : size === "sm"
        ? "h-[46px] w-[46px] border-[3px]"
        : "h-[52px] w-[52px] border-[3px]";
  const cima = size === "sm" ? "text-[5.5px]" : "text-[6.5px]";
  const ano =
    size === "xs" ? "text-[11px]" : size === "sm" ? "text-[10px]" : "text-[12px]";

  return (
    <span
      title={rotulo}
      aria-label={rotulo}
      className={`z-10 flex ${box} shrink-0 flex-col items-center justify-center rounded-full border-white text-white shadow-md ${className}`}
      style={{
        // gradiente roxo (brand-light -> brand-dark)
        backgroundImage: "linear-gradient(135deg, #a78bfa 0%, #4c1d95 100%)",
      }}
    >
      {size !== "xs" && (
        <span
          className={`${cima} font-bold uppercase leading-none tracking-[-0.02em]`}
        >
          {palavra}
        </span>
      )}
      <span
        className={`${ano} font-extrabold leading-none ${size === "xs" ? "" : "mt-[1px]"}`}
      >
        2026
      </span>
    </span>
  );
}

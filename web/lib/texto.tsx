import type { ReactNode } from "react";

/**
 * Negrito nos textos que vem do banco: `**assim**` vira <strong>assim</strong>.
 *
 * Feito na unha de proposito. Nao usamos dangerouslySetInnerHTML nem biblioteca
 * de markdown, entao nada que venha da tabela policy pode virar HTML executavel
 * na pagina. Qualquer outra marcacao (*, _, link) fica como texto puro.
 *
 * Use em TODO lugar que mostra quiz_hook: se um lugar esquecer, o leitor ve os
 * asteriscos crus na tela. Hoje sao dois: o quiz e a lista /politicas.
 */
export function comNegrito(texto: string): ReactNode[] {
  return texto
    .split("**")
    .map((parte, i) =>
      i % 2 === 1 ? (
        <strong key={i}>{parte}</strong>
      ) : (
        <span key={i}>{parte}</span>
      )
    );
}

export const metadata = { title: "Sobre" };

export default function SobrePage() {
  return (
    <article className="max-w-3xl space-y-6">
      <h1 className="text-2xl font-bold text-slate-800">Sobre e fontes</h1>

      <p className="text-slate-600">
        <strong>Eles Votam por Você</strong> é um projeto independente de
        transparência política. Reunimos as votações nominais do Congresso
        Nacional em um só lugar, organizadas por política, para que qualquer pessoa
        possa acompanhar como seus representantes votam.
      </p>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-800">Fontes dos dados</h2>
        <ul className="list-disc space-y-1 pl-6 text-slate-600">
          <li>
            Dados Abertos da Câmara dos Deputados —{" "}
            <a
              href="https://dadosabertos.camara.leg.br"
              className="text-brand hover:underline"
              target="_blank"
              rel="noreferrer"
            >
              dadosabertos.camara.leg.br
            </a>
          </li>
          <li>
            Dados Abertos do Senado Federal —{" "}
            <a
              href="https://legis.senado.leg.br/dadosabertos"
              className="text-brand hover:underline"
              target="_blank"
              rel="noreferrer"
            >
              legis.senado.leg.br/dadosabertos
            </a>
          </li>
        </ul>
        <p className="text-slate-600">
          Os dados são públicos e oficiais. Este site não é filiado ao Congresso
          Nacional nem a nenhum partido.
        </p>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-800">Correções</h2>
        <p className="text-slate-600">
          Encontrou algo errado? A transparência também vale para nós — retornos
          são bem-vindos para corrigir e melhorar os dados.
        </p>
      </section>
    </article>
  );
}

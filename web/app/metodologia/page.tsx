export const metadata = { title: "Metodologia" };

export default function MetodologiaPage() {
  return (
    <article className="prose-slate max-w-3xl space-y-6">
      <h1 className="text-2xl font-bold text-slate-800">Metodologia</h1>

      <p className="text-slate-600">
        O objetivo é mostrar, com transparência, como cada parlamentar vota. Todo
        o cálculo parte de votações nominais reais da Câmara dos Deputados e do
        Senado Federal. Abaixo, como transformamos votos em uma posição por política.
      </p>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-800">
          1. O que é uma &quot;política&quot;
        </h2>
        <p className="text-slate-600">
          Uma política reúne votações relacionadas a um assunto (por exemplo, proteção
          ao meio ambiente). Para cada votação incluída, definimos qual voto
          representa apoio à política — em umas, votar <strong>Sim</strong> é a favor;
          em outras (como flexibilizar uma regra), votar <strong>Não</strong> é
          que representa apoio. Essa direção é definida no momento da curadoria e
          fica registrada.
        </p>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-800">
          2. Peso de cada votação
        </h2>
        <p className="text-slate-600">
          Nem toda votação tem a mesma importância. Cada uma entra com peso{" "}
          <strong>normal</strong> ou <strong>maior</strong> (para votações
          decisivas). A posição final é uma média ponderada por esses pesos.
        </p>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-800">3. Faltas</h2>
        <p className="text-slate-600">
          Ausências contam pouco, para não punir quem faltou pontualmente: uma
          falta pesa bem menos que um voto e recebe crédito parcial. Parlamentares
          com pouquíssimas votações registradas em uma política aparecem como{" "}
          <em>&quot;sem votos suficientes&quot;</em>, sem uma posição atribuída.
        </p>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-800">4. A posição final</h2>
        <p className="text-slate-600">
          O resultado é um número de 0% a 100% que mede o{" "}
          <strong>apoio à política</strong>: 0 significa votar sempre contra a
          direção da política; 100, sempre a favor. Atenção: não é a fração de vezes
          em que a pessoa votou &quot;sim&quot;, e sim o quanto ela apoia a posição
          descrita na política. Traduzimos esse número em faixas para facilitar a
          leitura:
        </p>
        <ul className="list-disc space-y-1 pl-6 text-slate-600">
          <li>Sempre / quase sempre a favor</li>
          <li>Geralmente a favor</li>
          <li>Às vezes a favor</li>
          <li>Geralmente contra</li>
          <li>Quase sempre / sempre contra</li>
        </ul>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-800">Limites e cuidados</h2>
        <p className="text-slate-600">
          Uma votação nem sempre reflete a posição completa de alguém — há acordos,
          textos combinados e votos táticos. Por isso, mostramos sempre as votações
          que compõem cada política, para você conferir o contexto. Esta é uma
          ferramenta de transparência, não um julgamento.
        </p>
      </section>
    </article>
  );
}

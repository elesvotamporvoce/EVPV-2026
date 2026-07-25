import Link from "next/link";

export const metadata = { title: "Como funciona" };

export default function ComoFuncionaPage() {
  return (
    <article className="max-w-3xl space-y-8">
      <div>
        <h1 className="text-2xl font-bold text-slate-800">Como funciona</h1>
        <p className="mt-2 text-lg text-slate-600">
          O método do site e o jargão do Congresso explicados em linguagem simples.
        </p>
      </div>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-800">
          De onde vêm os dados?
        </h2>
        <p className="text-slate-600">
          A Câmara dos Deputados e o Senado Federal publicam os dados de cada
          votação em seus portais de Dados Abertos. Nós coletamos esses registros
          todos os dias, organizamos as votações e as agrupamos em{" "}
          <Link href="/politicas" className="text-brand hover:underline">políticas</Link>:
          conjuntos de votações que, juntas, indicam uma posição sobre um
          assunto. As votações do Senado começam em 2019 e as da Câmara em 2020.
        </p>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-800">
          O que é uma votação nominal?
        </h2>
        <p className="text-slate-600">
          É a votação em que o voto de cada parlamentar fica registrado com nome:
          Sim, Não, Abstenção ou Obstrução. É diferente da votação{" "}
          <em>simbólica</em>, em que o resultado é decidido no conjunto e ninguém
          tem o voto individual registrado. Como a maioria das decisões do
          Congresso é simbólica, nem toda pauta importante aparece aqui: só
          podemos mostrar como cada um votou quando a votação foi nominal.
        </p>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-800">
          Como uma política é montada?
        </h2>
        <p className="text-slate-600">
          Uma política reúne votações sobre o mesmo assunto, com uma direção
          clara (ex.: &quot;Mais investimento na educação&quot;). Para cada
          votação incluída, definimos qual voto representa apoio: em algumas,
          votar SIM apoia a política; em outras (como flexibilizar uma
          proteção), votar NÃO é que apoia. Votações decisivas têm peso maior
          (marcadas com ★). Cada página de política lista todas as votações
          consideradas, com link para o projeto na íntegra no site oficial.
        </p>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-800">
          Quem decide se um parlamentar apoia uma política?
        </h2>
        <p className="text-slate-600">
          Ninguém: os votos decidem. Não importa o que o parlamentar diz em
          discurso ou campanha, o score é calculado apenas a partir de como ele
          votou nas votações da política. Nosso trabalho editorial se limita a
          escolher quais votações entram e qual voto conta como apoio. Essas
          escolhas ficam sempre publicadas na página da política, abertas para
          qualquer pessoa conferir.
        </p>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-800">
          O que significa a posição (score)?
        </h2>
        <p className="text-slate-600">
          É o apoio do parlamentar à política, de 0 a 100: 0 significa votar
          sempre contra a direção da política; 100, sempre a favor. Não é a
          fração de vezes em que votou &quot;sim&quot;. Traduzimos o número em
          faixas, de &quot;Sempre contra&quot; a &quot;Sempre a favor&quot;, e o
          percentual aparece ao passar o mouse sobre a posição.
        </p>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-800">
          E as faltas? Como pesam?
        </h2>
        <p className="text-slate-600">
          Faltas pesam pouco no score, para não punir ausências pontuais. Quem
          tem pouquíssimos votos numa política aparece como &quot;sem votos
          suficientes&quot;, sem posição atribuída. No fim do perfil mostramos a
          presença: quantas das votações nominais da casa, desde o primeiro voto
          registrado do parlamentar, ele efetivamente participou. Quando a
          ausência passa de 50%, o dado ganha destaque, porque o papel de quem
          foi eleito é votar. Não contabilizamos ausência de quem já deixou o
          cargo, para não misturar sessões posteriores à saída. O registro
          oficial não distingue falta por doença, missão oficial ou escolha,
          então tratamos todas da mesma forma.
        </p>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-800">
          Por que não existe política sobre certos temas?
        </h2>
        <p className="text-slate-600">
          Porque o plenário não votou esses temas nominalmente no período que
          cobrimos. Vários marcos recentes, como o casamento igualitário e a
          criminalização da homofobia, vieram de decisões do STF, não de
          votações no Congresso. Quando houver votação nominal, a política é
          criada.
        </p>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-800">
          Limites e cuidados
        </h2>
        <p className="text-slate-600">
          Uma votação nem sempre reflete a posição completa de alguém. Há
          acordos, textos combinados e votos táticos. Por isso mostramos sempre
          as votações que compõem cada política, para você conferir o contexto.
          Esta é uma ferramenta de transparência, não um julgamento.
        </p>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-800">
          Como conferir se os dados estão certos?
        </h2>
        <p className="text-slate-600">
          Cada votação traz data, casa, placar e o link &quot;Ler o projeto na
          íntegra&quot; para a página oficial da Câmara ou do Senado, onde você
          confere o registro original, voto a voto. Encontrou divergência? Fale
          conosco em{" "}
          <a href="mailto:contato@elesvotamporvoce.org" className="text-brand hover:underline">
            contato@elesvotamporvoce.org
          </a>{" "}
          e corrigiremos.
        </p>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-800">
          Quem faz este site? Tem partido?
        </h2>
        <p className="text-slate-600">
          O Eles Votam por Você é um projeto independente e sem fins lucrativos,
          sem vínculo com partidos, campanhas ou com o próprio Congresso. As
          políticas cobrem o espectro inteiro: em algumas quem pontua alto é a
          esquerda, em outras é a direita, porque o objetivo é mostrar o voto,
          não julgá-lo.
        </p>
      </section>
    </article>
  );
}

import Link from "next/link";

export const metadata = { title: "Como funciona" };

function Grupo({ titulo }: { titulo: string }) {
  return (
    <p className="border-t border-slate-200 pt-8 text-xs font-bold uppercase tracking-widest text-brand">
      {titulo}
    </p>
  );
}

export default function ComoFuncionaPage() {
  return (
    <article className="max-w-3xl space-y-8">
      <div>
        <h1 className="text-2xl font-bold text-brand">Como funciona</h1>
        <p className="mt-2 text-lg text-slate-600">
          O método do site explicado em linguagem simples.
        </p>
      </div>

      {/* Resumo para quem bate o olho */}
      <div className="rounded-lg border border-brand-light bg-violet-50 p-5">
        <p className="font-semibold text-slate-800">Em resumo</p>
        <p className="mt-1.5 leading-relaxed text-slate-700">
          Coletamos todo dia as votações oficiais da Câmara e do Senado,
          agrupamos as votações de um mesmo assunto em{" "}
          <Link href="/politicas" className="font-semibold text-brand hover:underline">
            políticas
          </Link>{" "}
          e calculamos a posição de cada parlamentar usando só uma coisa: o
          voto dele. Discurso e promessa não entram na conta.
        </p>
      </div>

      <Grupo titulo="Os dados" />

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-800">
          De onde vêm os dados?
        </h2>
        <p className="text-slate-600">
          Dos portais oficiais de Dados Abertos da Câmara dos Deputados e do
          Senado Federal, que publicam o registro de cada votação. Coletamos
          esses registros todos os dias. As votações do Senado começam em 2019 e
          as da Câmara em 2020.
        </p>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-800">
          Só votações nominais entram. O que é isso?
        </h2>
        <p className="text-slate-600">
          Votação nominal é a que registra o voto de cada parlamentar pelo nome:
          Sim, Não, Abstenção ou Obstrução. Na votação <em>simbólica</em>, o
          resultado sai no conjunto e ninguém tem voto individual registrado.
          Como boa parte das decisões do Congresso é simbólica, nem toda pauta
          importante aparece aqui: só mostramos o que tem registro individual.
        </p>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-800">
          E as votações secretas do Senado?
        </h2>
        <p className="text-slate-600">
          Quase metade das votações do Senado é secreta. O caso mais comum são
          as sabatinas: antes de um indicado assumir cargos como ministro do
          STF, chefe da PGR, diretor do Banco Central ou embaixador, o Senado o
          entrevista e aprova (ou rejeita) o nome em voto secreto. Nesses casos
          o painel informa que o senador votou, mas não revela o voto. Essas
          votações aparecem como &quot;outro registro&quot; e contam como
          presença, mas não podem entrar nas políticas, porque não há como
          saber a posição individual.
        </p>
      </section>

      <Grupo titulo="As políticas" />

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-800">
          Como uma política é montada?
        </h2>
        <p className="text-slate-600">
          Uma política reúne votações sobre o mesmo assunto, com uma direção
          clara (ex.: &quot;Mais investimento na educação&quot;). Para cada
          votação, definimos qual voto representa apoio: em algumas, votar SIM
          apoia a política; em outras (como flexibilizar uma proteção), votar
          NÃO é que apoia. Votações decisivas têm peso maior (marcadas com ★).
          Cada página de política lista todas as votações consideradas, com link
          para o projeto na íntegra no site oficial.
        </p>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-800">
          Quem decide se um parlamentar apoia uma política?
        </h2>
        <p className="text-slate-600">
          Ninguém: os votos decidem. Nosso trabalho editorial se limita a
          escolher quais votações entram e qual voto conta como apoio, e essas
          escolhas ficam publicadas na página de cada política, abertas para
          qualquer pessoa conferir.
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

      <Grupo titulo="A posição de cada parlamentar" />

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-800">
          O que significa a posição (score)?
        </h2>
        <p className="text-slate-600">
          É o apoio do parlamentar à política, de 0 a 100: 0 significa votar
          sempre contra a direção da política; 100, sempre a favor. Traduzimos o
          número em faixas, de &quot;Sempre contra&quot; a &quot;Sempre a
          favor&quot;, e o percentual exato aparece ao passar o mouse.
        </p>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-800">
          E as faltas? Como pesam?
        </h2>
        <p className="text-slate-600">
          Faltas pesam pouco no score, para não punir ausências pontuais. Quem
          tem pouquíssimos votos numa política aparece como &quot;sem votos
          suficientes&quot;, com um resumo do que aconteceu em cada votação e,
          como referência, a média do partido. O registro oficial não distingue
          falta por doença, missão oficial ou escolha, então tratamos todas da
          mesma forma.
        </p>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-800">
          Como calculamos a presença?
        </h2>
        <p className="text-slate-600">
          A presença mostra de quantas votações nominais da casa o parlamentar
          participou durante o mandato. Para quem estreou junto com a
          legislatura, contamos desde o primeiro dia dela; para quem chegou
          depois (suplentes, por exemplo), desde o primeiro registro; para quem
          já deixou o cargo, a contagem para no último registro. Acima de 50% de
          ausência, o dado ganha destaque no perfil: o papel de quem foi eleito
          é votar.
        </p>
      </section>

      <Grupo titulo="Confiança e limites" />

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-800">
          Como conferir se os dados estão certos?
        </h2>
        <p className="text-slate-600">
          Cada votação traz data, casa, placar e o link &quot;Ler o projeto na
          íntegra&quot; para a página oficial da Câmara ou do Senado, onde você
          confere o registro original, voto a voto. Encontrou divergência? Fale
          conosco em{" "}
          <a
            href="mailto:contato@elesvotamporvoce.org"
            className="text-brand hover:underline"
          >
            contato@elesvotamporvoce.org
          </a>{" "}
          e corrigiremos.
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

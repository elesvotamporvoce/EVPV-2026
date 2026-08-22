import Link from "next/link";

export const metadata = { title: "Sobre o site" };

function Grupo({ titulo }: { titulo: string }) {
  return (
    <p className="border-t border-slate-200 pt-8 text-xs font-bold uppercase tracking-widest text-brand">
      {titulo}
    </p>
  );
}

export default function SobrePage() {
  return (
    <article className="max-w-3xl space-y-8">
      <div>
        <h1 className="text-2xl font-bold text-brand">Sobre o site</h1>
        <p className="mt-2 text-lg text-slate-600">
          O que é o Eles Votam por Você e como o método funciona, em linguagem
          simples.
        </p>
      </div>

      <div className="rounded-lg border border-brand-light bg-violet-50 p-5">
        <p className="font-semibold text-slate-800">Em resumo</p>
        <p className="mt-1.5 leading-relaxed text-slate-700">
          Coletamos todo dia as votações oficiais da Câmara e do Senado,
          agrupamos as votações de um mesmo assunto em{" "}
          <Link href="/politicas" className="font-semibold text-brand hover:underline">
            políticas
          </Link>{" "}
          e calculamos a posição de cada parlamentar usando só uma coisa: o voto
          dele. Discurso e promessa não entram na conta.
        </p>
      </div>

      <Grupo titulo="Quem faz" />

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-800">
          Quem faz este site? Tem partido?
        </h2>
        <p className="text-slate-600">
          O Eles Votam por Você é um projeto independente e sem fins lucrativos
          de transparência política, sem vínculo com partidos, campanhas ou com o
          próprio Congresso. Reunimos as votações nominais em um só lugar,
          organizadas por tema, para que qualquer pessoa acompanhe como seus
          representantes votam. As políticas cobrem o espectro inteiro: em
          algumas quem pontua alto é a esquerda, em outras é a direita, porque o
          objetivo é mostrar o voto, não julgá-lo.
        </p>
      </section>

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
        <ul className="list-disc space-y-1 pl-6 text-slate-600">
          <li>
            Câmara dos Deputados:{" "}
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
            Senado Federal:{" "}
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
          Quase metade das votações do Senado é secreta. O caso mais comum são as
          sabatinas: antes de um indicado assumir cargos como ministro do STF,
          chefe da PGR, diretor do Banco Central ou embaixador, o Senado o
          entrevista e aprova (ou rejeita) o nome em voto secreto. Nesses casos o
          painel informa que o senador votou, mas não revela o voto. Essas
          votações aparecem como &quot;outro registro&quot; e contam como
          presença, mas não podem entrar nas políticas, porque não há como saber
          a posição individual.
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
          apoia a política; em outras (como flexibilizar uma proteção), votar NÃO
          é que apoia. Votações decisivas têm peso maior (marcadas com ★). Cada
          página de política lista todas as votações consideradas, com link para
          o projeto na íntegra no site oficial.
        </p>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-800">
          E quando quase todos votam igual?
        </h2>
        <p className="text-slate-600">
          Uma votação aprovada por 470 a 1 quase não distingue parlamentares:
          saber que alguém acompanhou a maioria esmagadora informa pouco sobre
          suas convicções. Por isso, quando 95% ou mais dos votos vão para o
          mesmo lado, a votação entra com peso reduzido. Não a descartamos,
          porque ela diz muito sobre a minoria que votou contra a corrente. O
          corte é automático, calculado a partir do resultado apurado, não é
          escolha editorial nossa caso a caso. Na página de cada política, essas
          votações trazem um <strong>i</strong> ao lado do selo: clique para ver o
          placar e a explicação.
        </p>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-800">
          Só entram votações de plenário
        </h2>
        <p className="text-slate-600">
          Numa votação de comissão, apenas os poucos parlamentares que são membros
          dela podem votar. Contar isso seria injusto: os demais apareceriam como
          ausentes sem nunca ter tido a chance de se posicionar. Por isso
          consideramos só as votações de plenário (da Câmara e do Senado) onde
          todos podiam votar.
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
          Por que o número do projeto às vezes não bate?
        </h2>
        <p className="text-slate-600">
          O Congresso costuma votar vários projetos parecidos de uma vez: eles
          são &quot;apensados&quot; ao mais antigo e o plenário aprova um texto
          único, o substitutivo. Por isso a descrição oficial da votação pode
          citar um número diferente do projeto que lhe deu origem. Nas nossas
          páginas mostramos o projeto principal, e o link oficial de cada
          votação leva ao registro completo, onde os apensados aparecem.
        </p>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-800">
          Por que não existe política sobre certos temas?
        </h2>
        <p className="text-slate-600">
          Porque o plenário não votou esses temas nominalmente no período que
          cobrimos. Vários marcos recentes, como o casamento igualitário e a
          criminalização da homofobia, vieram de decisões do STF, não de votações
          no Congresso. Quando houver votação nominal, a política é criada.
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
          A presença mostra de quantas votações nominais do <strong>plenário</strong>{" "}
          o parlamentar participou durante o mandato. Votação de comissão não
          entra na conta: quem não é membro daquela comissão não podia votar
          ali, e cobrar isso como falta seria injusto. Para quem estreou junto
          com a legislatura, contamos desde o primeiro dia dela; para quem
          chegou depois (suplentes, por exemplo), desde o primeiro registro;
          para quem já deixou o cargo ou está de licença, a contagem para no
          último registro. Votações que caíram dentro de uma licença registrada
          saem do denominador. Quando há um período longo sem votos que nenhuma
          licença explica, e esse período concentra muitas votações, preferimos
          não publicar percentual nenhum a publicar um número injusto. Acima de
          50% de ausência, o dado ganha destaque no perfil: o papel de quem foi
          eleito é votar.
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
          confere o registro original, voto a voto. Os dados são públicos e
          oficiais, e este site não é filiado ao Congresso Nacional nem a nenhum
          partido.
        </p>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-800">
          Escolhas que fizemos, e seus limites
        </h2>
        <p className="text-slate-600">
          Todo método tem escolhas, e preferimos declará-las. Os pesos são
          nossos: votação normal vale 10, votação decisiva (★) vale 25 e votação
          quase unânime vale 4. Ausência entra com 20% do peso e conta como
          meio-termo: nem apoio, nem rejeição. Isso evita punir a falta
          pontual, mas tem um efeito colateral: quem falta muito tende ao meio
          da escala, o que pode parecer indecisão em vez de ausência. O perfil
          mostra a presença separadamente por isso.
        </p>
        <p className="text-slate-600">
          Algumas votações do conjunto são requerimentos de urgência, que
          decidem se a matéria vai direto ao plenário: medem disposição de
          pautar, não posição sobre o conteúdo. Mantemos porque, na prática, a
          urgência costuma ser disputada nos mesmos termos do mérito, mas é uma
          escolha discutível, e cada página de política mostra quais votações
          são de que tipo. Por fim, bastam 2 votos para pontuar: em políticas
          com poucas votações, o resultado individual se apoia em pouca
          informação, e a página avisa quando é o caso.
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
        <h2 className="text-lg font-semibold text-slate-800">Correções</h2>
        <p className="text-slate-600">
          Encontrou algo errado? A transparência também vale para nós. Escreva
          para{" "}
          <a
            href="mailto:contato@elesvotamporvoce.org"
            className="text-brand hover:underline"
          >
            contato@elesvotamporvoce.org
          </a>{" "}
          e faremos o possível para analisar e corrigi-lo o mais rápido possível.
        </p>
      </section>
    </article>
  );
}

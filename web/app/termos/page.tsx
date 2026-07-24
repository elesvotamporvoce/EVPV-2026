export const metadata = { title: "Termos e privacidade" };

export default function TermosPage() {
  return (
    <article className="max-w-3xl space-y-6">
      <h1 className="text-2xl font-bold text-slate-800">
        Termos de uso e privacidade
      </h1>
      <p className="text-sm text-slate-400">Última atualização: julho de 2026</p>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-800">O que este site é</h2>
        <p className="text-slate-600">
          O Eles Votam por Você é um projeto independente, apartidário e sem fins
          lucrativos de transparência política. Mostramos como deputados e
          senadores votam no Congresso Nacional, a partir de registros oficiais e
          públicos. Não é um site oficial da Câmara, do Senado ou de qualquer
          órgão público, e não tem vínculo com partidos ou candidaturas.
        </p>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-800">
          Dados dos parlamentares
        </h2>
        <p className="text-slate-600">
          Todo o conteúdo sobre parlamentares (votos nominais, partido, estado,
          foto oficial e situação de mandato) vem dos portais de Dados Abertos da
          Câmara dos Deputados e do Senado Federal. São dados públicos de agentes
          públicos no exercício da função, cuja divulgação é amparada pelo
          princípio constitucional da publicidade, pela Lei de Acesso à
          Informação e pela LGPD. Nosso tratamento se limita a organizar e
          apresentar esses registros com finalidade informativa e de interesse
          público.
        </p>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-800">
          Dados de quem visita o site
        </h2>
        <p className="text-slate-600">
          Não pedimos cadastro, não temos formulários e não usamos cookies de
          rastreamento nem publicidade. A infraestrutura que hospeda o site
          registra logs técnicos básicos (como endereço IP e tipo de navegador)
          para segurança e funcionamento, prática padrão prevista no Marco Civil
          da Internet. Não vendemos nem compartilhamos dados de visitantes.
        </p>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-800">
          Onde o site é hospedado
        </h2>
        <p className="text-slate-600">
          Parte da infraestrutura do site fica fora do Brasil, em provedores
          internacionais de nuvem. Isso não muda nossas obrigações: a LGPD se
          aplica a serviços oferecidos a pessoas no Brasil independentemente de
          onde os servidores estão, e este projeto a segue.
        </p>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-800">
          Limites e responsabilidade
        </h2>
        <p className="text-slate-600">
          Fazemos o possível para manter os dados corretos e atualizados, mas
          erros de processamento podem acontecer. Em caso de divergência, valem
          sempre os registros oficiais da Câmara e do Senado, que linkamos em
          cada votação. O conteúdo tem caráter informativo e não substitui as
          fontes oficiais. A metodologia completa está na página{" "}
          <a href="/como-funciona" className="text-brand hover:underline">
            Como funciona
          </a>
          .
        </p>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-800">Uso do conteúdo</h2>
        <p className="text-slate-600">
          Você pode citar, compartilhar e reutilizar o conteúdo do site
          livremente, desde que com atribuição e link para
          elesvotamporvoce.org. Os dados brutos são públicos e podem ser obtidos
          diretamente nos portais oficiais.
        </p>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-800">
          Correções e contato
        </h2>
        <p className="text-slate-600">
          Encontrou um erro ou quer falar com a gente? Escreva para{" "}
          <a
            href="mailto:contato@elesvotamporvoce.org"
            className="text-brand hover:underline"
          >
            contato@elesvotamporvoce.org
          </a>
          . Correções procedentes são aplicadas o mais rápido possível.
        </p>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-slate-800">Alterações</h2>
        <p className="text-slate-600">
          Esta página pode ser atualizada quando o site evoluir. A data da última
          atualização aparece no topo.
        </p>
      </section>
    </article>
  );
}

import type { Metadata } from "next";
import { Analytics } from "@vercel/analytics/next";
import "./globals.css";
import Navbar from "@/components/Navbar";
import Footer from "@/components/Footer";

// O `title` abaixo e o do NAVEGADOR e do Google: comeca pelo nome do site,
// que e o que ajuda na busca. Ja o bloco openGraph e o que aparece quando
// alguem cola o link no WhatsApp — e ali usamos a MESMA frase da capa, senao
// quem clica chega numa pagina que fala outra coisa. Foi o que aconteceu:
// o card dizia "Como seu deputado e senador votam de verdade?" e a home
// dizia "Voce sabia que seu politico vota por voce?".
// Se mudar a chamada da home (app/page.tsx), mude CHAMADA aqui tambem.
const CHAMADA = "Você sabia que seu político vota por você?";
const RESUMO =
  "Você elege um deputado e um senador, eles votam sim ou não em projetos de " +
  "lei, e o que passa vira regra para todo mundo. Veja como cada um votou, " +
  "política por política, com dados oficiais da Câmara e do Senado.";

export const metadata: Metadata = {
  metadataBase: new URL("https://www.elesvotamporvoce.org"),
  title: {
    default: "Eles Votam por Você: como seu deputado e senador votam",
    template: "%s · Eles Votam por Você",
  },
  description: RESUMO,
  openGraph: {
    type: "website",
    locale: "pt_BR",
    siteName: "Eles Votam por Você",
    url: "https://www.elesvotamporvoce.org",
    title: CHAMADA,
    description: RESUMO,
  },
  twitter: {
    card: "summary_large_image",
    title: CHAMADA,
    description: RESUMO,
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="pt-BR">
      <body className="flex min-h-screen flex-col overflow-x-clip">
        <Navbar />
        <main className="mx-auto w-full max-w-6xl flex-1 px-4 py-8">
          {children}
        </main>
        <Footer />
        {/* Medicao de audiencia da Vercel: sem cookies e sem identificar
            ninguem — so conta quantas visitas cada pagina recebeu. Usamos isso
            para saber quais parlamentares o povo mais procura. Descrito na
            pagina de Termos e privacidade. */}
        <Analytics />
      </body>
    </html>
  );
}

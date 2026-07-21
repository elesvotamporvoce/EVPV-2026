import type { Metadata } from "next";
import "./globals.css";
import Navbar from "@/components/Navbar";
import Footer from "@/components/Footer";

export const metadata: Metadata = {
  title: {
    default: "Eles Votam por Você — como seu deputado e senador votam",
    template: "%s · Eles Votam por Você",
  },
  description:
    "Descubra como cada deputado e senador vota no Congresso Nacional, política por política. Dados públicos da Câmara e do Senado.",
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
      </body>
    </html>
  );
}

const CSP = [
  "default-src 'self'",
  // fotos dos parlamentares vem dos sites oficiais
  "img-src 'self' data: https://*.camara.leg.br https://*.senado.leg.br https://*.senado.gov.br",
  "script-src 'self' 'unsafe-inline'",
  "style-src 'self' 'unsafe-inline'",
  "font-src 'self' data:",
  // leitura do banco (Supabase) e a medicao de audiencia da Vercel
  "connect-src 'self' https://rvcfbklnwglmhoxfexvj.supabase.co https://vitals.vercel-insights.com",
  "frame-ancestors 'none'",
  "frame-src 'none'",
  "object-src 'none'",
  "base-uri 'self'",
  "form-action 'self'",
  "upgrade-insecure-requests",
].join("; ");

/** @type {import('next').NextConfig} */
const nextConfig = {
  images: {
    remotePatterns: [
      { protocol: "https", hostname: "**.camara.leg.br" },
      { protocol: "https", hostname: "**.senado.leg.br" },
      { protocol: "https", hostname: "**.senado.gov.br" },
    ],
  },
  async redirects() {
    return [
      { source: "/metodologia", destination: "/sobre", permanent: true },
      { source: "/faq", destination: "/sobre", permanent: true },
      { source: "/como-funciona", destination: "/sobre", permanent: true },
    ];
  },
  async headers() {
    return [
      {
        source: "/(.*)",
        headers: [
          // Ninguem pode embutir o site em iframe (clickjacking).
          { key: "X-Frame-Options", value: "DENY" },
          // Navegador nao tenta "adivinhar" tipo de conteudo.
          { key: "X-Content-Type-Options", value: "nosniff" },
          // Nao vazar a URL completa para sites externos.
          { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
          // Nao usamos camera/microfone/geolocalizacao.
          {
            key: "Permissions-Policy",
            value: "camera=(), microphone=(), geolocation=()",
          },
          // Content-Security-Policy: diz ao navegador de onde ele PODE
          // carregar coisa. Se alguem conseguisse injetar um <script src>
          // apontando para fora, o navegador recusaria — e, mais importante
          // aqui, script nenhum consegue mandar dado para um servidor que
          // nao esteja em connect-src.
          //
          // 'unsafe-inline' em script-src e chato mas necessario: o Next
          // injeta scripts inline de hidratacao sem nonce. Para tirar seria
          // preciso middleware gerando nonce por requisicao, o que deixa toda
          // pagina dinamica e derruba o cache estatico. Como o site nao tem
          // login, nao tem cookie e nunca renderiza texto do usuario como
          // HTML (ver lib/texto.tsx), a superficie de XSS e minima.
          //
          // Se um dia entrar fonte, script ou imagem de outro dominio, tem
          // que adicionar aqui, senao o navegador bloqueia em silencio.
          { key: "Content-Security-Policy", value: CSP },
        ],
      },
    ];
  },
};

export default nextConfig;

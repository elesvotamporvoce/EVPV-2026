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
        ],
      },
    ];
  },
};

export default nextConfig;

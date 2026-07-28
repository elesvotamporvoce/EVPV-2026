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
};

export default nextConfig;

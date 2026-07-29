import Link from "next/link";
import LogoMark from "./Logo";
import NavMenu from "./NavMenu";

const links = [
  { href: "/pessoas", label: "Parlamentares" },
  { href: "/politicas", label: "Políticas" },
  { href: "/seu-perfil", label: "Seu perfil" },
  { href: "/sobre", label: "Sobre o site" },
];

export default function Navbar() {
  return (
    <header className="site-nav sticky top-0 z-50 bg-brand-ink shadow-sm">
      <div className="mx-auto flex max-w-6xl items-center justify-between gap-4 px-4 py-3">
        <Link
          href="/"
          className="nav-brand flex items-center gap-2.5 font-semibold leading-tight text-white"
        >
          <LogoMark className="h-4 w-auto" />
          <span className="text-lg">Eles Votam por Você</span>
        </Link>
        <NavMenu links={links} />
      </div>
    </header>
  );
}

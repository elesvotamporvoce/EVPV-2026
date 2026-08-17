import { revalidatePath } from "next/cache";
import { NextRequest, NextResponse } from "next/server";

/**
 * Revalidacao sob demanda: derruba o cache das paginas na hora, sem esperar
 * a janela do ISR. Use depois de mudar textos no banco:
 *
 *   GET /api/revalidate?secret=SEU_SEGREDO            -> home, /politicas e /seu-perfil
 *   GET /api/revalidate?secret=SEU_SEGREDO&path=/politicas/16
 *
 * Defina REVALIDATE_SECRET nas variaveis de ambiente da Vercel.
 */
export async function GET(req: NextRequest) {
  const secret = req.nextUrl.searchParams.get("secret");
  if (!process.env.REVALIDATE_SECRET || secret !== process.env.REVALIDATE_SECRET) {
    return NextResponse.json({ ok: false, error: "segredo invalido" }, { status: 401 });
  }
  const path = req.nextUrl.searchParams.get("path");
  const paths = path ? [path] : ["/", "/politicas", "/seu-perfil"];
  for (const p of paths) revalidatePath(p);
  if (!path) revalidatePath("/politicas/[id]", "page");
  return NextResponse.json({ ok: true, revalidated: paths, em: new Date().toISOString() });
}

import type { MetadataRoute } from "next";
import { supabase } from "@/lib/supabase";

export const revalidate = 86400; // 1 dia

const BASE = "https://www.elesvotamporvoce.org";

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const fixas: MetadataRoute.Sitemap = [
    { url: `${BASE}/`, changeFrequency: "daily", priority: 1 },
    { url: `${BASE}/politicas`, changeFrequency: "daily", priority: 0.9 },
    { url: `${BASE}/pessoas`, changeFrequency: "daily", priority: 0.9 },
    { url: `${BASE}/eleicoes-2026`, changeFrequency: "daily", priority: 0.9 },
    { url: `${BASE}/seu-perfil`, changeFrequency: "weekly", priority: 0.8 },
    { url: `${BASE}/sobre`, changeFrequency: "monthly", priority: 0.5 },
    { url: `${BASE}/termos`, changeFrequency: "monthly", priority: 0.2 },
  ];

  try {
    const [{ data: pols }, { data: pes }, { data: parts }] = await Promise.all([
      supabase.from("policy").select("id"),
      supabase.from("person_directory").select("id"),
      supabase.from("party").select("id"),
    ]);
    const politicas = (pols ?? []).map((p) => ({
      url: `${BASE}/politicas/${p.id}`,
      changeFrequency: "weekly" as const,
      priority: 0.8,
    }));
    const pessoas = (pes ?? []).map((p) => ({
      url: `${BASE}/pessoas/${p.id}`,
      changeFrequency: "weekly" as const,
      priority: 0.6,
    }));
    const partidos = (parts ?? []).map((p) => ({
      url: `${BASE}/partidos/${p.id}`,
      changeFrequency: "weekly" as const,
      priority: 0.5,
    }));
    return [...fixas, ...politicas, ...pessoas, ...partidos];
  } catch {
    return fixas;
  }
}

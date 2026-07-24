// Rótulos e cores das categorias de concordância (iguais aos do motor de score).
export const CATEGORY_LABELS: Record<string, string> = {
  for3: "Sempre a favor",
  for2: "Quase sempre a favor",
  for1: "Geralmente a favor",
  mixture: "Às vezes a favor",
  against1: "Geralmente contra",
  against2: "Quase sempre contra",
  against3: "Sempre contra",
  not_enough: "Sem votos suficientes",
};

export const HOUSE_LABEL: Record<string, string> = {
  camara: "Câmara",
  senado: "Senado",
};

export const CARGO_LABEL: Record<string, string> = {
  camara: "Deputado Federal",
  senado: "Senador",
};

export const VOTE_LABEL: Record<string, string> = {
  sim: "Sim",
  nao: "Não",
  abstencao: "Abstenção",
  obstrucao: "Obstrução",
  artigo17: "Art. 17",
  ausente: "Ausente",
  outro: "Outro",
};

// Cor conforme a concordância (verde = a favor, vermelho = contra).
export function scoreColor(score: number | null | undefined): string {
  if (score === null || score === undefined) return "#94a3b8";
  if (score >= 85) return "#15803d";
  if (score >= 60) return "#4d7c0f";
  if (score > 40) return "#a16207";
  if (score > 15) return "#c2410c";
  return "#b91c1c";
}

export function categoryLabel(cat: string): string {
  return CATEGORY_LABELS[cat] ?? cat;
}

export function fmtDate(iso: string | null | undefined): string {
  if (!iso) return "—";
  const d = new Date(iso);
  if (isNaN(d.getTime())) return "—";
  return d.toLocaleDateString("pt-BR", {
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
  });
}

export function pct(n: number, total: number): string {
  if (!total) return "0%";
  return `${Math.round((100 * n) / total)}%`;
}

export const UFS = [
  "AC","AL","AP","AM","BA","CE","DF","ES","GO","MA","MT","MS","MG","PA","PB",
  "PR","PE","PI","RJ","RN","RS","RO","RR","SC","SP","SE","TO",
];

// Políticas em destaque no site (aparecem primeiro, com selo)
export const FEATURED_POLICIES = [
  "Proteção das mulheres contra a violência",
  "Direitos dos trabalhadores",
  "Ação climática e conservação",
  "Mais investimento na educação",
];

export function featuredRank(name: string): number {
  const i = FEATURED_POLICIES.indexOf(name);
  return i === -1 ? 99 : i;
}

export function categoryFromScore(score: number | null): string {
  if (score === null) return "not_enough";
  if (score >= 95) return "for3";
  if (score >= 85) return "for2";
  if (score >= 60) return "for1";
  if (score > 40) return "mixture";
  if (score > 15) return "against1";
  if (score > 5) return "against2";
  return "against3";
}

// Percentual direcional: mostra o lado que faz sentido para o leitor
export function supportTip(score: number | null): string | null {
  if (score === null) return null;
  const p = Math.round(score);
  return p >= 50 ? `${p}% a favor da política` : `${100 - p}% contra a política`;
}

export const MANDATE_LABEL: Record<string, string> = {
  em_exercicio: "Em exercício",
  licenciado: "Licenciado",
  fora: "Fora do Congresso",
};

export const MANDATE_CLASS: Record<string, string> = {
  em_exercicio: "text-green-700",
  licenciado: "text-amber-700",
  fora: "text-slate-500",
};

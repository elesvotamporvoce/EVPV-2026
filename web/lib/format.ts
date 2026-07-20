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

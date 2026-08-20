export type House = "camara" | "senado";

export type PersonDir = {
  id: number;
  house: House;
  name: string;
  uf: string | null;
  photo_url: string | null;
  active: boolean | null;
  mandate_status: string | null;
  mandate_detail: string | null;
  party_id: number | null;
  party_sigla: string | null;
};

export type PersonStats = {
  person_id: number;
  n_votes: number;
  n_attended: number;
  n_sim: number;
  n_nao: number;
  n_absent: number;
};

export type ScoreNamed = {
  person_id: number;
  policy_id: number;
  score: number;
  category: string;
  n_divisions: number;
  policy_name: string;
  person_name: string;
  uf: string | null;
  house: House;
  photo_url: string | null;
  party_sigla: string | null;
};

export type Policy = {
  id: number;
  name: string;
  description: string | null;
  provisional: boolean;
  /** texto longo da PAGINA da politica ("Por que isso importa para voce") */
  impact: string | null;
  /** texto curto do QUIZ; independente do impact */
  quiz_hook: string | null;
  side_a_title: string | null;
  side_a_note: string | null;
  side_b_title: string | null;
  side_b_note: string | null;
};

export type PartyPolicyAgreement = {
  party_id: number;
  party_sigla: string;
  policy_id: number;
  policy_name: string;
  avg_score: number;
  n_people: number;
};

export type DivisionRow = {
  id: number;
  house: House;
  external_id: string;
  occurred_at: string | null;
  description: string | null;
  result_approved: boolean | null;
  proposition_id: number | null;
};

export type PersonVote = {
  person_id: number;
  option: string;
  division_id: number;
  description: string | null;
  occurred_at: string | null;
  house: House;
  result_approved: boolean | null;
};

export type DivisionVote = {
  division_id: number;
  option: string;
  person_id: number;
  name: string;
  uf: string | null;
  photo_url: string | null;
  house: House;
  party_sigla: string | null;
};

export type Participation = {
  person_id: number;
  house: House;
  first_vote: string | null;
  n_votes: number;
  /** votações que a pessoa PODIA ter votado, já sem os períodos de licença */
  eligible: number;
  last_vote: string | null;
  /** o mesmo número antes de descontar licença (explica a diferença) */
  eligible_bruto?: number;
  /** quantas votações saíram da conta por licença/afastamento */
  votacoes_afastado?: number;
  /** false quando ha um buraco longo sem votar que nenhuma licenca explica:
   *  nesses casos o denominador nao e confiavel e NAO exibimos a ausencia */
  confiavel?: boolean;
  maior_buraco_dias?: number;
};

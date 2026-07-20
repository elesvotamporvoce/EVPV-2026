export type House = "camara" | "senado";

export type PersonDir = {
  id: number;
  house: House;
  name: string;
  uf: string | null;
  photo_url: string | null;
  active: boolean | null;
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
  eligible: number;
};

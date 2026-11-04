-- Detalhes da vaga externa cadastrada pela comunidade: descricao das atividades e faixa salarial.
-- (As importadas continuam com esses campos nulos; nada e inventado.)
alter table external_jobs add column if not exists description varchar(5000) null;
alter table external_jobs add column if not exists salary_min varchar(50) null;
alter table external_jobs add column if not exists salary_max varchar(50) null;
alter table external_jobs add column if not exists salary_period varchar(20) null;

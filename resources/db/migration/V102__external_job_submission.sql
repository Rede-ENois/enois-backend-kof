-- Vagas externas cadastradas por PESSOAS da comunidade (diferente das importadas de agregador).
--
-- `submitted_by` e o dono do registro: distingue a vaga da comunidade (cadastrada a mao, com o
-- botao indo para o link de origem, e excluivel por quem cadastrou) das importadas (somente
-- leitura, atualizadas pelo worker da meia-noite). Nulo = importada.
alter table external_jobs add column if not exists submitted_by varchar(255);

create index if not exists idx_external_jobs_submitted_by on external_jobs (submitted_by);

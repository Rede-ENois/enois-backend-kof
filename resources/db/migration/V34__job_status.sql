-- Ciclo de vida da vaga: hoje ela fica aberta para sempre, mesmo com o processo seletivo
-- encerrado. O default OPEN preserva o comportamento das vagas existentes (nenhuma nasce
-- encerrada, e nao existe data de encerramento a inventar).
alter table jobs add column status varchar(16) not null default 'OPEN';
alter table jobs add column closed_at timestamp;

-- "minhas vagas" filtra por estado junto da ordenacao por data.
create index idx_jobs_status_posted on jobs (status, posted_at);

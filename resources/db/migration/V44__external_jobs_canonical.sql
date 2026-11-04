-- Deduplicacao GLOBAL entre fontes: a mesma vaga publicada em plataformas diferentes aponta para a
-- mesma URL canonica. Guardamos a URL normalizada (sem fragmento nem parametros de rastreio) para
-- reconhecer a mesma oportunidade mesmo com id externo diferente. Backfill com a URL atual.
alter table external_jobs add column canonical_url varchar(1000);

update external_jobs set canonical_url = url where canonical_url is null;

create index idx_external_jobs_canonical on external_jobs (canonical_url);

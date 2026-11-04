-- Vagas de plataformas externas (ex.: JobRadar) em tabela PROPRIA — nao se misturam com a tabela
-- 'jobs' (vaga criada na plataforma). Sao LISTADAS junto das internas, mas a candidatura acontece na
-- origem. Unique (platform, external_id) evita duplicar na reimportacao.
create table external_jobs (
  id varchar(255) not null,
  platform varchar(64) not null,
  external_id varchar(255) not null,
  title varchar(500) not null,
  company varchar(255),
  location varchar(255),
  salary varchar(255),
  currency varchar(8),
  url varchar(1000) not null,
  imported_at timestamp not null,
  last_checked_at timestamp not null,
  external_status varchar(32) not null default 'FOUND',
  primary key (id)
);

alter table external_jobs add constraint uk_external_jobs_source unique (platform, external_id);
create index idx_external_jobs_checked on external_jobs (last_checked_at);

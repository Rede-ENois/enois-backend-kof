-- ECA Digital: supervisao parental e trilha de auditoria da classificacao etaria.
--
-- A data de nascimento declarada NAO e verificacao oficial: `age_source`/`age_verified_at` ficam
-- reservados para quando existir um mecanismo confiavel integrado (ex.: Gov.br) e hoje permanecem
-- nulos. O estado efetivo e derivado no backend (declarado / menor / supervisionado).
--
-- parental_links: convite de vinculo entre o menor e o responsavel. O token cru so existe no
-- e-mail; aqui fica o SHA-256. Uma linha por tentativa, com status e historico.
-- age_audit_events: quem mudou o que (declaracao, convite, aceite, recusa, revogacao).
alter table users add column if not exists age_source varchar(32) null;
alter table users add column if not exists age_verified_at timestamp null;

create table if not exists parental_links (
  id varchar(64) not null,
  minor_user_id varchar(64) not null,
  guardian_user_id varchar(64) null,
  guardian_email varchar(255) not null,
  status varchar(20) not null,
  token_hash varchar(64) null,
  terms_version varchar(20) not null,
  created_at timestamp not null,
  expires_at timestamp not null,
  decided_at timestamp null,
  revoked_at timestamp null,
  primary key (id),
  unique key ux_parental_token (token_hash),
  key idx_parental_minor (minor_user_id),
  key idx_parental_guardian (guardian_user_id)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;

create table if not exists age_audit_events (
  id varchar(64) not null,
  user_id varchar(64) not null,
  event varchar(40) not null,
  actor_id varchar(64) null,
  detail varchar(500) null,
  created_at timestamp not null,
  primary key (id),
  key idx_age_audit_user (user_id, created_at)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;

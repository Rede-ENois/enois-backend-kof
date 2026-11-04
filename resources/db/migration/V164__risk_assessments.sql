-- Historico do motor de risco (plano mestre de seguranca humana, item 7): cada avaliacao de
-- risco fica registrada com o nivel, os sinais que a compoem, a versao da regra e a resposta
-- aplicada. E o que permite reconstruir uma decisao ("por que esta pessoa foi bloqueada?") e
-- medir a linha de base antes de endurecer qualquer regra.
--
-- Idempotente de proposito (create table/index if not exists): a migracao precisa passar 2x na
-- bancada, porque o pod pode subir com a migration ja aplicada.
create table if not exists risk_assessments (
  id varchar(64) not null,
  user_id varchar(64) not null,
  action_type varchar(40) not null,
  level varchar(16) not null,
  score int not null default 0,
  signals varchar(500) not null,
  rule_version varchar(20) not null,
  decision varchar(20) not null,
  created_at timestamp not null,
  primary key (id),
  key idx_risk_assessments_user (user_id, created_at),
  key idx_risk_assessments_level (level, created_at)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;

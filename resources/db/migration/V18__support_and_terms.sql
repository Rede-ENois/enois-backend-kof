-- Consentimento de termos/idade no cadastro (guarda o instante do aceite) + pedidos de suporte.
--
-- ATENCAO: esta migracao substitui a V17, que nunca aplicou em producao.
-- A primeira tentativa falhou com "Can't create table support_requests (errno: 150
-- Foreign key constraint is incorrectly formed)": o banco esta em utf8mb4_unicode_ci como
-- collation padrao e a tabela users em utf8mb4_uca1400_ai_ci, e a FK entre collations
-- diferentes nao e aceita. Isso derrubou o boot e deixou o rollout do backend travado.
--
-- Motivos do renome + IF NOT EXISTS:
-- 1) a V17 pode ter ficado registrada como FAILED no flyway_schema_history, e nesse caso o
--    Flyway bloqueia novas tentativas da mesma versao;
-- 2) IF NOT EXISTS torna a migracao segura mesmo onde a V17 (ou parte dela) ja tenha aplicado.
--
-- Sem FK para users de proposito: a integridade fica na aplicacao (a exclusao de conta
-- anonimiza o usuario, nao apaga), evitando depender de collations.

alter table users add column if not exists terms_accepted_at timestamp null;

create table if not exists support_requests (
  id varchar(255) not null,
  user_id varchar(255) not null,
  subject varchar(160) not null,
  message varchar(4000) not null,
  contact_email varchar(255) not null,
  status varchar(32) not null,
  created_at timestamp not null,
  primary key (id),
  key idx_support_requests_created (created_at),
  key idx_support_requests_status (status),
  key idx_support_requests_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

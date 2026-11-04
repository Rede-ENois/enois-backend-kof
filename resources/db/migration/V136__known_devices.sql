-- Resgate da tabela known_devices: a migracao original nasceu como V110, foi aplicada em producao
-- e depois substituida na arvore pela V110 de vagas. Em producao a tabela existe; em banco novo ela
-- nao existia mais e o Hibernate recusava o boot ("missing table [known_devices]"). Idempotente:
-- onde a tabela ja existe, nada acontece.
create table if not exists known_devices (
  id varchar(64) not null,
  user_id varchar(64) not null,
  fingerprint varchar(128) not null,
  first_seen_at timestamp not null,
  primary key (id),
  key idx_known_devices_user (user_id),
  key idx_known_devices_fingerprint (fingerprint)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;

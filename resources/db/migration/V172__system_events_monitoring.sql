-- Monitorabilidade do painel admin: eventos, erros, falhas e logs operacionais.
-- A retenção é curta (7 dias por padrão) e o volume é limitado pelo serviço; não é tabela de
-- auditoria jurídica — para isso existem as tabelas de moderação/sanções.
create table if not exists system_events (
  id varchar(64) not null,
  created_at timestamp not null,
  level varchar(10) not null,
  type varchar(32) not null,
  message varchar(1000) not null,
  request_id varchar(64) null,
  method varchar(10) null,
  path varchar(300) null,
  route varchar(300) null,
  status int null,
  duration_ms bigint null,
  user_id varchar(64) null,
  client_ip varchar(64) null,
  device_id varchar(64) null,
  metadata text null,
  primary key (id),
  key idx_system_events_created (created_at),
  key idx_system_events_level (level, created_at),
  key idx_system_events_type (type, created_at)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;

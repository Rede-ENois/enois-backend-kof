-- Pré-triagem determinística antes da IA + ledger de feedback humano para pesos aprendidos.
alter table reports add column if not exists pre_triage text null;
alter table reports add column if not exists pre_triage_score int null;
alter table reports add column if not exists pre_triaged_at timestamp null;

create index if not exists idx_reports_pre_triage
  on reports (status, pre_triage_score, ai_triaged_at);

create table if not exists moderation_feedback (
  id varchar(64) not null,
  report_id varchar(64) not null,
  decision varchar(32) not null,
  source varchar(16) not null,
  decided_by varchar(255) null,
  signals varchar(500) null,
  score int null,
  created_at timestamp not null,
  primary key (id),
  key idx_moderation_feedback_report (report_id),
  key idx_moderation_feedback_created (decision, created_at)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;

-- A coluna chama signal_key e nao signal: `signal` e PALAVRA RESERVADA no MariaDB (1064 na
-- hora de criar a tabela e tambem no select) — a migracao falhava no banco de producao e o pod
-- nao subia. Nao existia coluna aplicada com esse nome (a migracao nunca rodou no MariaDB), entao
-- renomear nao quebra checksum de ninguem.
create table if not exists moderation_signal_weights (
  signal_key varchar(64) not null,
  weight int not null,
  samples int not null default 0,
  updated_at timestamp not null,
  primary key (signal_key)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;

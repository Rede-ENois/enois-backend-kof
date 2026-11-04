-- Flags de sistema compartilhados entre pods. O primeiro uso é o modo pânico: quando ligado,
-- toda escrita da aplicação responde 429 imediatamente, sem depender de reinício ou deploy.
create table if not exists system_flags (
  name varchar(64) not null,
  flag_value varchar(255) not null,
  updated_at timestamp not null,
  primary key (name)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;

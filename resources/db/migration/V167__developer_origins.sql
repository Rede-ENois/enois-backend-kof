-- Origem declarada para consumir a API pública (/v1) a partir do navegador. O CORS só libera
-- uma origem cadastrada aqui (ou as origens do próprio app); sem isso o navegador bloqueia.
create table if not exists developer_origins (
  id varchar(64) not null,
  user_id varchar(64) not null,
  origin varchar(200) not null,
  created_at timestamp not null,
  primary key (id),
  unique key uk_developer_origin_user (user_id, origin),
  key idx_developer_origins_user (user_id, created_at)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;

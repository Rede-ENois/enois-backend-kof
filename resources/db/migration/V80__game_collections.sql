-- G3 do plano: coleções temáticas de jogos curadas pela comunidade (a curadoria
-- v1 é da administração). A lista de jogos viaja como CSV (a convenção das tags).
create table if not exists game_collections (
  id varchar(255) not null,
  curator_id varchar(255) not null,
  title varchar(160) not null,
  description varchar(500),
  game_ids longtext,
  status varchar(16) not null,
  created_at timestamp not null,
  updated_at timestamp not null,
  primary key (id)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;

create index if not exists idx_game_collections_status on game_collections (status, created_at);

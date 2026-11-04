-- Avaliações (nota + texto) e comentários dos jogos da comunidade.
-- Sem FK para users/games pelo mesmo motivo de sempre (collation de users difere do default).
create table if not exists game_reviews (
  id varchar(64) not null,
  game_id varchar(64) not null,
  user_id varchar(64) not null,
  rating int not null,
  body varchar(2000) null,
  created_at timestamp not null,
  updated_at timestamp not null,
  primary key (id),
  unique key uk_game_review_user (game_id, user_id),
  key idx_game_reviews_game (game_id, created_at)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;

create table if not exists game_comments (
  id varchar(64) not null,
  game_id varchar(64) not null,
  user_id varchar(64) not null,
  body varchar(2000) not null,
  created_at timestamp not null,
  primary key (id),
  key idx_game_comments_game (game_id, created_at)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;

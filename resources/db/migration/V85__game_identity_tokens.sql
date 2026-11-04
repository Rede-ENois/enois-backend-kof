-- Identidade do jogador DENTRO do jogo: o jogo NUNCA recebe a sessão do Énóis. A plataforma
-- emite um TOKEN opaco e efêmero (15 min, uso único) e um PSEUDÔNIMO estável (playerRef) —
-- só isso atravessa a borda do iframe. O token é guardado com HASH (nunca em claro).
create table if not exists game_tokens (
  id varchar(255) not null,
  game_id varchar(255) not null,
  user_id varchar(255) not null,
  token_hash varchar(64) not null,
  player_ref varchar(64) not null,
  expires_at timestamp not null,
  used_at timestamp,
  created_at timestamp not null,
  primary key (id),
  constraint uk_game_token_hash unique (token_hash)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;

create index idx_game_tokens_game on game_tokens (game_id, expires_at);

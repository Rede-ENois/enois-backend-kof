-- Énóis Games: o módulo vira plataforma (catálogo com descoberta, página do criador, página do
-- jogo e biblioteca do jogador). Tudo ADITIVO: nada do que a V70 criou é renomeado ou removido, e
-- as linhas que já existem continuam válidas (as colunas novas entram nulas ou com default).
alter table games add column if not exists short_description varchar(300);
alter table games add column if not exists genres varchar(300);
alter table games add column if not exists languages varchar(200);
alter table games add column if not exists controls varchar(500);
alter table games add column if not exists requirements varchar(500);
alter table games add column if not exists content_warnings varchar(300);
alter table games add column if not exists stage varchar(24) not null default 'RELEASED';
alter table games add column if not exists distribution varchar(16) not null default 'FREE';
alter table games add column if not exists price_coins integer not null default 0;
alter table games add column if not exists aspect varchar(16) not null default 'WIDESCREEN';
alter table games add column if not exists version varchar(40);
alter table games add column if not exists website_url varchar(500);
alter table games add column if not exists support_url varchar(500);
alter table games add column if not exists media_ids varchar(1000);
alter table games add column if not exists plays integer not null default 0;
alter table games add column if not exists published_at timestamp;
alter table games add column if not exists suspended_at timestamp;

-- Descoberta: as consultas do catálogo são por status + ordem, e por gênero/tag.
create index if not exists idx_games_status_published on games (status, published_at);
create index if not exists idx_games_status_plays on games (status, plays);

-- Página pública do criador. Presa à conta do Énóis (user_id único): não é uma segunda identidade.
create table if not exists developer_profiles (
  user_id varchar(255) not null,
  display_name varchar(120),
  headline varchar(200),
  bio varchar(2000),
  links varchar(500),
  avatar varchar(500),
  cover varchar(500),
  updated_at timestamp not null,
  primary key (user_id)
);

-- Biblioteca do jogador (favoritos). Um por pessoa por jogo.
create table if not exists game_favorites (
  id varchar(255) not null,
  user_id varchar(255) not null,
  game_id varchar(255) not null,
  created_at timestamp not null,
  primary key (id)
);
create unique index if not exists uk_game_favorites_user_game on game_favorites (user_id, game_id);
create index if not exists idx_game_favorites_user on game_favorites (user_id, created_at);

-- Acompanhar o criador: mão única, como a inscrição do blog (não é conexão mútua).
create table if not exists developer_follows (
  id varchar(255) not null,
  follower_id varchar(255) not null,
  developer_user_id varchar(255) not null,
  created_at timestamp not null,
  primary key (id)
);
create unique index if not exists uk_developer_follows_pair on developer_follows (follower_id, developer_user_id);
create index if not exists idx_developer_follows_developer on developer_follows (developer_user_id);

-- Diário de desenvolvimento (o devlog do jogo): o que mudou em cada versão.
create table if not exists game_updates (
  id varchar(255) not null,
  game_id varchar(255) not null,
  user_id varchar(255) not null,
  title varchar(200) not null,
  body varchar(4000),
  version varchar(40),
  created_at timestamp not null,
  primary key (id)
);
create index if not exists idx_game_updates_game on game_updates (game_id, created_at);

-- Métricas: o que o SERVIDOR viu, não o que o front contou. Sem dado pessoal além do id de quem
-- está logado (e sem ele quando não há sessão).
create table if not exists game_events (
  id varchar(255) not null,
  game_id varchar(255) not null,
  kind varchar(24) not null,
  user_id varchar(255),
  created_at timestamp not null,
  primary key (id)
);
create index if not exists idx_game_events_game on game_events (game_id, kind, created_at);

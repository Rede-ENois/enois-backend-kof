-- Agregador de jogos (Parte E): o Énóis NÃO hospeda o jogo — o criador envia o LINK
-- (publicado em itch.io/site próprio), a moderação revisa e o jogo roda EMBUTIDO
-- num quadro isolado. A página de jogos do criador é HTML editável (pageHtml),
-- pela mesma tubulação das demais páginas.
create table if not exists games (
  id varchar(255) not null,
  user_id varchar(255) not null,
  slug varchar(120) not null,
  title varchar(200) not null,
  description varchar(4000),
  cover varchar(500),
  url varchar(500) not null,
  tags varchar(500),
  status varchar(16) not null,
  reviewed_by varchar(255),
  review_note varchar(500),
  submitted_at timestamp not null,
  reviewed_at timestamp,
  created_at timestamp not null,
  updated_at timestamp not null,
  primary key (id),
  constraint uk_games_user_slug unique (user_id, slug)
);

create index if not exists idx_games_user on games (user_id, status);
create index if not exists idx_games_status on games (status, submitted_at);

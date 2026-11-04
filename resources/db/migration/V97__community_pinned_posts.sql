-- Um único post fixado por comunidade (o topo do feed). Chave primária na comunidade garante
-- estruturalmente o "1 único": fixar outro substitui a linha na mesma transação.
-- Tabela própria para não tocar a linha de `posts` (que o feed principal lê o tempo todo) e
-- porque o "fixado" é um estado da COMUNIDADE, não do post.
create table if not exists community_pinned_posts (
  community_id varchar(64) not null,
  post_id varchar(64) not null,
  pinned_by varchar(64) not null,
  pinned_at timestamp not null,
  primary key (community_id)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;

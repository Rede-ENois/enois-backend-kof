-- Post AGENDADO: a linha fica FORA de `posts` até a hora marcada — não aparece em feed,
-- perfil, busca, comunidades nem notifica ninguém antes da hora. O worker publica pelo MESMO
-- caso de uso do composer, então validações, antiflood e notificações continuam valendo no
-- momento da publicação (e uma recusa vira `last_error` visível para o autor).
create table if not exists scheduled_posts (
  id varchar(255) not null,
  user_id varchar(255) not null,
  post_type varchar(32) not null,
  content text,
  page_html text,
  article_body text,
  tags text,
  media_ids text,
  community_id varchar(255),
  scheduled_at timestamp not null,
  created_at timestamp not null,
  last_error varchar(500),
  attempts int not null default 0,
  primary key (id)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;

create index if not exists idx_scheduled_posts_user on scheduled_posts (user_id, scheduled_at);
create index if not exists idx_scheduled_posts_due on scheduled_posts (scheduled_at, attempts);

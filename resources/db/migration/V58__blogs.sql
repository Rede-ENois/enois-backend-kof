-- Blogs: cada pessoa pode ter UM cantinho proprio (enois.ia.br/blog/{username}), com posts que NAO
-- entram no feed global. Quem quiser acompanhar se inscreve no blog; so entao as novidades aparecem
-- no "Para voce" (nunca no "Tudo") e geram notificacao.
--
-- Sem FK de proposito (mesma licao da V33/V46/V54: FK entre tabelas com collation divergente falha
-- no MariaDB de producao com errno 150 e derruba o boot). O id fica guardado e a leitura resolve.
-- Collation explicita porque o default do banco difere das tabelas existentes.
create table if not exists blogs (
  id varchar(255) not null,
  user_id varchar(255) not null,
  slug varchar(80) not null,
  title varchar(160) not null,
  description varchar(500),
  theme_html longtext,
  created_at timestamp not null,
  updated_at timestamp not null,
  constraint pk_blogs primary key (id)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;

create unique index uk_blogs_user on blogs (user_id);
create unique index uk_blogs_slug on blogs (slug);

-- body guarda o que o autor escreveu: HTML ja sanitizado (body_format = HTML) ou markdown-lite
-- (body_format = MARKDOWN), que o front renderiza como texto formatado. O id DESTE post e o mesmo id
-- do post-ponteiro que aparece no "Para voce" de quem segue o blog — e por isso que o card do feed
-- consegue linkar direto para ca sem guardar mais nada.
create table if not exists blog_posts (
  id varchar(255) not null,
  blog_id varchar(255) not null,
  user_id varchar(255) not null,
  title varchar(200) not null,
  body longtext not null,
  body_format varchar(16) not null,
  published_at timestamp not null,
  created_at timestamp not null,
  updated_at timestamp not null,
  constraint pk_blog_posts primary key (id)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;

create index idx_blog_posts_blog on blog_posts (blog_id, published_at);
create index idx_blog_posts_user on blog_posts (user_id);

create table if not exists blog_subscriptions (
  id varchar(255) not null,
  blog_id varchar(255) not null,
  user_id varchar(255) not null,
  created_at timestamp not null,
  constraint pk_blog_subscriptions primary key (id)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;

create unique index uk_blog_subscriptions_pair on blog_subscriptions (blog_id, user_id);
create index idx_blog_subscriptions_user on blog_subscriptions (user_id);

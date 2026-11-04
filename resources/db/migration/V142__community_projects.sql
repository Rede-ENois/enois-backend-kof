-- Projetos da comunidade: espaço NOVO e independente dos jogos. Mesmo ciclo de vida
-- (envio -> revisão -> publicado), tabela própria e página própria (/projetos).
create table if not exists community_projects (
  id varchar(255) not null,
  user_id varchar(255) not null,
  slug varchar(120) not null,
  title varchar(200) not null,
  description varchar(4000),
  short_description varchar(300),
  cover varchar(500),
  url varchar(500),
  repo_url varchar(500),
  tags varchar(500),
  category varchar(120),
  status varchar(16) not null,
  reviewed_by varchar(255),
  review_note varchar(500),
  submitted_at timestamp not null,
  reviewed_at timestamp,
  published_at timestamp,
  suspended_at timestamp,
  created_at timestamp not null,
  updated_at timestamp not null,
  primary key (id),
  constraint uk_community_projects_user_slug unique (user_id, slug)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;

create index if not exists idx_community_projects_status_submitted
  on community_projects (status, submitted_at);
create index if not exists idx_community_projects_status_published
  on community_projects (status, published_at);
create index if not exists idx_community_projects_user
  on community_projects (user_id, status);

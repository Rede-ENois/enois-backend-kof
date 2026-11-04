-- Perfil profissional (alterego corporativo): 1:1 OPCIONAL com a conta. A mesma pessoa, uma
-- versao pessoal e uma profissional — os valores da conta (faiscas, credibilidade, seguidores,
-- verificacao, segundo fator) continuam no nivel da conta, nunca duplicados por identidade.
-- O que e proprio daqui: apresentacao (nome, @, headline, bio, avatar, banner, links) e estado.
-- Nada e criado automaticamente para quem ja usa a plataforma: o perfil nasce por iniciativa.
create table if not exists corporate_profiles (
  user_id varchar(255) not null,
  username varchar(120) not null,
  name varchar(160) not null,
  headline varchar(200),
  bio varchar(2000),
  avatar varchar(500),
  banner varchar(500),
  location varchar(200),
  industry varchar(200),
  external_links varchar(1000),
  status varchar(20) not null,
  created_at timestamp not null,
  updated_at timestamp not null,
  primary key (user_id),
  constraint uk_corporate_profiles_username unique (username)
);

create index if not exists idx_corporate_profiles_status on corporate_profiles (status);

-- Identidade de autoria das publicacoes: todo post antigo e SOCIAL (a migracao so adiciona a
-- coluna com default; nenhum registro existente muda de maos).
alter table posts add column if not exists author_identity varchar(20) not null default 'SOCIAL';
create index if not exists idx_posts_author_identity on posts (author_identity);

-- Canais privados dentro das comunidades, separados por tema.
--
-- Quem participa da comunidade enxerga e publica em todos os canais dela; quem nao participa nao
-- enxerga nada. Publicacao de canal NUNCA aparece nos feeds (principal, da comunidade ou do
-- perfil): o posts.channel_id a marca e todas as consultas de feed filtram por ele.
create table if not exists community_channels (
  id varchar(64) not null,
  community_id varchar(64) not null,
  name varchar(80) not null,
  slug varchar(90) not null,
  topic varchar(40) null,
  description varchar(300) null,
  created_by varchar(64) not null,
  created_at timestamp not null,
  primary key (id),
  unique key ux_community_channel_slug (community_id, slug),
  key idx_community_channels_community (community_id, created_at)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;

alter table posts add column if not exists channel_id varchar(64) null;
create index if not exists idx_posts_channel on posts (channel_id, created_at);

-- Comunidades favoritadas (bookmark): independente de participar. Sem FK para communities de
-- proposito — FK entre collations diferentes ja quebrou o boot em producao antes; a tabela guarda
-- so os ids e a listagem filtra pelos que ainda existem.
create table favorite_communities (
  id varchar(255) not null,
  community_id varchar(255) not null,
  user_id varchar(255) not null,
  created_at timestamp not null,
  primary key (id)
);

alter table favorite_communities add constraint uk_favorite_communities_user_community unique (user_id, community_id);
create index idx_favorite_communities_user on favorite_communities (user_id, created_at);

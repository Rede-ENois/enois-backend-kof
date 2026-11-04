-- Selos de post: a marcacao que a comunidade deixa no topo do post ("importante", "dica",
-- "post duplicado"...). Um selo por pessoa por post (trocar e trocar, clicar de novo remove), como a
-- reacao. Sem FK de proposito (mesma licao de collation da V33/V46/V54/V58).
create table if not exists post_seals (
  id varchar(255) not null,
  post_id varchar(255) not null,
  user_id varchar(255) not null,
  seal varchar(32) not null,
  created_at timestamp not null,
  constraint pk_post_seals primary key (id)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;

create unique index uk_post_seals_post_user on post_seals (post_id, user_id);
create index idx_post_seals_post on post_seals (post_id);

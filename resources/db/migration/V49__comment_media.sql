-- Midia nos comentarios (imagens/videos), no mesmo modelo do post_media.
-- Sem FK para media_assets: o join table so precisa achar as linhas por comentario
-- (a colisao de collation do MariaDB em FKs ja derrubou rollout antes; aqui nao vale o risco).
create table comment_media (
  comment_id varchar(255) not null,
  media_id varchar(255) not null
);

create index idx_comment_media_comment on comment_media (comment_id);

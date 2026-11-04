-- Galeria de temas da comunidade (Fase 2 do plano de temas/moeda).
-- O pacote e JSON de TOKENS validado por schema (sem CSS livre) — a sanitizacao
-- acontece no backend antes de gravar; o campo guarda o pacote ja validado.
create table if not exists theme_gallery (
  id varchar(255) not null,
  author_id varchar(255) not null,
  name varchar(80) not null,
  description varchar(300),
  package_json longtext not null,
  mode_default varchar(10) not null,
  installs integer not null default 0,
  status varchar(16) not null,
  reported integer not null default 0,
  created_at timestamp not null,
  primary key (id)
);

create index if not exists idx_theme_gallery_status on theme_gallery (status, created_at);
create index if not exists idx_theme_gallery_author on theme_gallery (author_id);

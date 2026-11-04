-- Serviços da comunidade (mesma mecânica dos jogos): o membro oferece um serviço
-- (desenvolvimento, design, SEO, copywriting...), a moderação revisa e o serviço fica
-- publicado na aba de serviços com a página própria. O Énóis não intermedia o pagamento —
-- a página apresenta e o link (quando existir) leva ao contato do prestador.
create table if not exists service_offers (
  id varchar(255) not null,
  user_id varchar(255) not null,
  slug varchar(120) not null,
  title varchar(120) not null,
  description varchar(4000) not null,
  link varchar(500),
  category varchar(40) not null,
  status varchar(16) not null,
  reviewed_by varchar(255),
  review_note varchar(500),
  created_at timestamp not null,
  updated_at timestamp not null,
  primary key (id),
  constraint uk_service_offers_user_slug unique (user_id, slug)
);

create index if not exists idx_service_offers_user on service_offers (user_id, status);
create index if not exists idx_service_offers_status on service_offers (status, created_at);
create index if not exists idx_service_offers_category on service_offers (category, status);

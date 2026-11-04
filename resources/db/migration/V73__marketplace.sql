-- Marketplace (Fase 4 do plano de temas/moeda): o criador lista um item (v1: TEMA da
-- galeria) por um preço em faíscas; a compra fica em ESCROW até o comprador confirmar
-- (7 dias) — criador recebe preço − 10% de taxa; reembolso devolve 100%.
-- Sem FK em users (armadilha de collation); collation explícita nas tabelas novas.
create table if not exists marketplace_listings (
  id varchar(255) not null,
  seller_id varchar(255) not null,
  item_kind varchar(20) not null,
  item_id varchar(255) not null,
  title varchar(160) not null,
  description varchar(500),
  price bigint not null,
  status varchar(16) not null,
  created_at timestamp not null,
  updated_at timestamp not null,
  primary key (id),
  constraint uk_listing_item unique (item_kind, item_id, status)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;

create index if not exists idx_listings_status on marketplace_listings (status, created_at);
create index if not exists idx_listings_seller on marketplace_listings (seller_id, status);

create table if not exists marketplace_purchases (
  id varchar(255) not null,
  listing_id varchar(255) not null,
  buyer_id varchar(255) not null,
  seller_id varchar(255) not null,
  price bigint not null,
  state varchar(16) not null,
  created_at timestamp not null,
  decided_at timestamp,
  primary key (id)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;

create index if not exists idx_purchases_buyer on marketplace_purchases (buyer_id, state);
create index if not exists idx_purchases_seller on marketplace_purchases (seller_id, state);
create index if not exists idx_purchases_held on marketplace_purchases (state, created_at);

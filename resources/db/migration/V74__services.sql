-- Serviços freelance (Fase 5 do plano): ofertar (modelo Fiverr) e solicitar (demanda),
-- pagos em faíscas com ESCROW no mesmo ledger. Entregáveis e critérios de aceite são
-- obrigatórios no pedido (a lição dos microprojetos: o contrato de escopo existe antes).
-- Sem FK em users (armadilha de collation); collation explícita nas tabelas novas.
create table if not exists service_listings (
  id varchar(255) not null,
  seller_id varchar(255) not null,
  category varchar(40) not null,
  title varchar(160) not null,
  description varchar(2000) not null,
  deliverables varchar(1000) not null,
  price bigint not null,
  delivery_days integer not null,
  status varchar(16) not null,
  created_at timestamp not null,
  updated_at timestamp not null,
  primary key (id)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;

create index if not exists idx_service_listings_status on service_listings (status, category, created_at);
create index if not exists idx_service_listings_seller on service_listings (seller_id, status);

create table if not exists service_requests (
  id varchar(255) not null,
  requester_id varchar(255) not null,
  category varchar(40) not null,
  title varchar(160) not null,
  description varchar(2000) not null,
  deliverables varchar(1000) not null,
  budget_min bigint not null,
  budget_max bigint not null,
  deadline timestamp,
  status varchar(16) not null,
  created_at timestamp not null,
  updated_at timestamp not null,
  primary key (id)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;

create index if not exists idx_service_requests_status on service_requests (status, category, created_at);

create table if not exists service_proposals (
  id varchar(255) not null,
  request_id varchar(255) not null,
  user_id varchar(255) not null,
  message varchar(1000) not null,
  price bigint not null,
  status varchar(16) not null,
  created_at timestamp not null,
  primary key (id)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;

create index if not exists idx_service_proposals_request on service_proposals (request_id, status);

create table if not exists service_contracts (
  id varchar(255) not null,
  listing_id varchar(255),
  request_id varchar(255),
  buyer_id varchar(255) not null,
  seller_id varchar(255) not null,
  price bigint not null,
  escrow_state varchar(16) not null,
  deliverable_note varchar(1000),
  created_at timestamp not null,
  accepted_at timestamp,
  primary key (id)
) engine=InnoDB default charset=utf8mb4 collate=utf8mb4_uca1400_ai_ci;

create index if not exists idx_service_contracts_buyer on service_contracts (buyer_id, escrow_state);
create index if not exists idx_service_contracts_seller on service_contracts (seller_id, escrow_state);

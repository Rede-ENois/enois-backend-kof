-- Faísca: a moeda interna do Énóis (supply fixo definido no genesis, sem emissão posterior).
-- Ledger append-only com hash-chain (integridade) e idempotência por conta
-- (a mesma operação com a mesma chave nunca duplica). O saldo vive em
-- coin_accounts como SNAPSHOT — a verdade é o ledger, reconstruído pelo job de conciliação.
-- Sem FK em users (armadilha de collation); integridade na aplicação.

create table if not exists coin_accounts (
  account_id varchar(255) not null,
  balance bigint not null,
  version bigint not null default 0,
  created_at timestamp not null,
  primary key (account_id)
);

create table if not exists coin_entries (
  id varchar(255) not null,
  account_id varchar(255) not null,
  amount bigint not null,
  kind varchar(24) not null,
  ref_id varchar(255) not null,
  message varchar(300),
  idempotency_key varchar(255) not null,
  prev_hash varchar(64) not null,
  hash varchar(64) not null,
  created_at timestamp not null,
  primary key (id),
  constraint uk_coin_entry_idem unique (account_id, idempotency_key)
);

create index if not exists idx_coin_entries_account on coin_entries (account_id, created_at);

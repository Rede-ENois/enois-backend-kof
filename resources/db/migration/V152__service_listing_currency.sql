-- Serviço pode ser cobrado em faíscas (escrow) ou em reais (pagamento combinado direto).
alter table service_listings
  add column if not exists currency varchar(8) not null default 'FAISCA';

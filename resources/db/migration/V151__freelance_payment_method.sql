-- Freela pago em dinheiro (R$) ou em faíscas. Os freelas que já existiam foram
-- publicados no circuito da faísca, então o default preserva o comportamento deles.
alter table freelances add column if not exists payment_method varchar(16) not null default 'FAISCAS';

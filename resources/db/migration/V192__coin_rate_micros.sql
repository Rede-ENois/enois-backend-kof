-- A cotação de referência passa a ter precisão de micro-reais por faísca (1 centavo = 10.000 µ).
-- `brl_cents` continua existindo como leitura arredondada para clientes antigos da API.
alter table coin_rate_history add column if not exists brl_micros bigint null;
update coin_rate_history set brl_micros = brl_cents * 10000 where brl_micros is null;
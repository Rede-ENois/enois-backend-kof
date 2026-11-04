-- Sanitizacao de eventos que ja passaram.
--
-- Quando o evento vence, duas coisas acontecem: ele sai da listagem (nao e mais "proximo") e a lista
-- de presencas — que e dado pessoal (quem confirmou presenca) — e apagada, guardando apenas o total
-- agregado. `sanitized_at` marca a passagem pelo processo (idempotente) e `final_attendees_count`
-- preserva o numero sem as identidades.
--
-- Mesmos cuidados das migracoes anteriores: `if not exists` e sem FK.
alter table events add column if not exists sanitized_at timestamp null;
alter table events add column if not exists final_attendees_count int null;

-- A varredura olha os ainda nao sanitizados; o indice evita varrer a tabela inteira.
create index if not exists idx_events_sanitized on events (sanitized_at);

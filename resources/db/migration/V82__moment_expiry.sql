-- Momento (MOMENT) se apaga sozinho: o post nasce com prazo de 24 horas e um worker
-- horário aplica o soft-delete do fluxo normal (feed, cache e mídia iguais à exclusão).
alter table posts add column if not exists expires_at timestamp null;
create index if not exists idx_posts_expiry on posts (expires_at);

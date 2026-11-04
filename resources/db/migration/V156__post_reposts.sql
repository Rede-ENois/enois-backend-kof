-- Republicar: uma cópia do post no feed de quem republicou, com o crédito ao autor original.
-- Guardar a origem permite achar as cópias (limpeza quando o original é apagado) e impede
-- que a mesma pessoa republique o mesmo post duas vezes.
--
-- `repost_of_author` é o @ do autor original no momento do repost (denormalizado de propósito:
-- a listagem não precisa de um join para mostrar o "Republicado de @fulano").
alter table posts add column if not exists repost_of varchar(64) null;
alter table posts add column if not exists repost_of_author varchar(80) null;

create index if not exists idx_posts_repost_source on posts (repost_of);

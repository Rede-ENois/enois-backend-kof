-- Republicar COM OPINIÃO: a cópia leva o comentário (até 600 caracteres) no content e o card
-- mostra o post original citado. O boolean distingue esse caso do repost simples, em que a
-- cópia carrega o próprio texto original.
alter table posts add column if not exists repost_with_opinion boolean not null default false;

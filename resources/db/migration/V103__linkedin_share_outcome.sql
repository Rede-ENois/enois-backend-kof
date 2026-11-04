-- Resultado da última tentativa de share no LinkedIn, visível para a própria pessoa no painel
-- (a falha era silenciosa e só aparecia no log do pod — relato: "ativei, publiquei e não foi").
alter table linkedin_connections add column if not exists last_share_status varchar(32) null;
alter table linkedin_connections add column if not exists last_share_at timestamp null;

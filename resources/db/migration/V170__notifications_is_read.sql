-- `read` e palavra reservada no MariaDB/MySQL.
--
-- O mapeamento JPA mandava a coluna sem escape, entao o Hibernate gerava
--   update notifications set ..., read=?, ...
-- e o banco recusava com erro 1064 (erro de sintaxe). Todo insert/update de notificacao virava
-- 500: comentar um post (que gera notificacao) e "marcar tudo como lido" quebravam em producao.
--
-- Tirar a palavra reservada do caminho e mais seguro do que escapar em cada dialeto, porque os
-- testes rodam em H2 e producao em MariaDB — e os dois tratam identificadores citados de formas
-- diferentes.
drop index idx_notifications_user_read_created on notifications;

alter table notifications add column is_read boolean not null default false;

update notifications set is_read = `read`;

alter table notifications drop column `read`;

create index idx_notifications_user_is_read_created on notifications (user_id, is_read, created_at);

-- Ate 5 emblemas por perfil: URLs do CDN separadas por linha (URL nao tem quebra
-- de linha, entao a lista cabe em texto sem JSON). O emblema unico antigo vira a
-- lista de um elemento.
alter table users add column badges text null;
update users set badges = badge where badge is not null and badge != '';

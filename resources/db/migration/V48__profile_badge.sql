-- Emblema do perfil: um PNG pequeno (tamanho de favicon) que aparece ao lado do nome — no perfil, em
-- todo post e em todo comentario. Guarda a URL da midia, como avatar e banner.
alter table users add column badge varchar(500);

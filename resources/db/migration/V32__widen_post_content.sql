-- Post passa a aceitar ate 1200 caracteres (comentario continua em 800, dentro do varchar atual).
-- Sem alargar a coluna, um post de ate 1200 caracteres estouraria o varchar(1024) em producao.
alter table posts modify column content varchar(1200) not null;

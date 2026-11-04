-- "Vulgo" (aka): como a pessoa e conhecida — nome de guerra, apelido antigo, handle de outra rede.
-- Curto e opcional, exibido ao lado do nome no perfil. E diferente do apelido (nickname), que entra
-- entre parenteses no nome exibido para todo mundo: o vulgo e uma etiqueta, nao o nome.
alter table users add column aka varchar(60) null;

-- Identidade exibida: apelido, nome social e pronomes.
-- O nome social substitui o nome de cadastro para todo mundo; o apelido entra entre
-- parenteses depois do nome; os pronomes aparecem so no perfil. O nome de cadastro
-- continua no banco (verificacao: dono da conta e empresa da candidatura).
alter table users add column nickname varchar(60) null;
alter table users add column social_name varchar(160) null;
alter table users add column pronouns varchar(60) null;

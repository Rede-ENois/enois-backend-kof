-- Resgate da V110: a V110__job_salary_required.sql nasceu com o MESMO numero de uma migracao ja
-- aplicada em producao (V110__known_devices.sql, depois substituida na arvore). Como o Flyway aqui
-- roda com validate-on-migrate=false, a versao 110 ja constava aplicada e as colunas novas NUNCA
-- entraram no banco de producao — o pod novo passou a falhar na validacao do Hibernate
-- ("missing column [description] in table [jobs]") e o rollout ficou congelado no pod antigo.
--
-- O conteudo e identico ao da V110, idempotente: em bancos que ja rodaram a V110 original nao faz
-- nada; em producao (que pulou) cria as colunas que a entidade Job exige.
alter table jobs add column if not exists description longtext;
alter table jobs add column if not exists salary_min numeric(12,2);
alter table jobs add column if not exists salary_max numeric(12,2);
alter table jobs add column if not exists salary_period varchar(10);

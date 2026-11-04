-- Conserto de BURACO de histórico: a V66 (retorno do empregador) nasceu DEPOIS do
-- congelamento do pod e ANTES do topo já aplicado em produção — o Flyway com
-- validate-on-migrate=false nunca a aplicou, e a validação do Hibernate derrubava o boot
-- ("missing column [feedback] in table job_applications"). DDL IDEMPOTENTE: roda em
-- qualquer histórico, com ou sem a V66, e garante as colunas.
alter table job_applications add column if not exists feedback varchar(1000) null;
alter table job_applications add column if not exists reviewed_at timestamp null;

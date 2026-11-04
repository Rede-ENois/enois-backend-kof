-- ECA Digital (Lei 15.211/2025): data de nascimento obrigatoria para toda a base.
-- Contas existentes ficam com NULL ate regularizar; enquanto isso, acoes de escrita sao
-- bloqueadas com 403 BIRTH_DATE_REQUIRED (o front abre a tela de regularizacao).
alter table users add column birth_date date null;

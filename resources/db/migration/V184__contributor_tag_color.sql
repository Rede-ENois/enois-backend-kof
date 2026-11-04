-- Cor da tag "Contribuinte" exibida abaixo do nome. Só quem tem contribuição verificada pode
-- escolher (o endpoint valida); null = cor padrão do tema.
alter table users add column if not exists contributor_tag_color varchar(7) null;

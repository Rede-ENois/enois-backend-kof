-- Descrição do projeto importada do GitHub (ou escrita à mão); parte estruturada do card.
alter table user_projects add column if not exists description varchar(500) null;

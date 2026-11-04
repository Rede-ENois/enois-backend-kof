-- IP de origem da requisição que disparou o e-mail: rastreio de abuso (quem massiva reset de
-- senha para spamar alguém, por exemplo). Nullable: e-mails de fluxos fora de requisição não têm.
alter table email_log add column client_ip varchar(45) null;

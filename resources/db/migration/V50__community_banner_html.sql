-- Capa de comunidade em HTML/CSS (mesma tubulação da capa do perfil: sanitizada no servidor,
-- renderizada em iframe com sandbox). ALTER simples, sem FK — sem risco de collation.
alter table communities add column banner_html text;

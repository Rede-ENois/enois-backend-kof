-- E-mail de candidatura publicado pela propria vaga externa (vem na descricao da fonte, quando vem).
-- E o que permite o "agilizar envio": abrir o app de e-mail com o texto pronto e o curriculo em anexo,
-- em vez de obrigar a pessoa a garimpar o endereco no meio do anuncio.
alter table external_jobs add column apply_email varchar(320) null;

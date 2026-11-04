-- Transmissao ao vivo e local do evento: a capa ja existia (V5), faltavam estes dois.
-- `location` vale para presencial/hibrido; `stream_url` para online/hibrido.
alter table events add column stream_url varchar(500);
alter table events add column location varchar(255);

-- "Já vi o lembrete desta madrugada": a data local da noite em que a pessoa fechou o popup.
-- Guardar a data (e não só um booleano) faz o lembrete voltar sozinho à meia-noite seguinte,
-- sem job de reset, e o reload da página não o reabre, porque o estado vive no banco.
alter table user_preferences add column if not exists night_rest_dismissed_on date null;
